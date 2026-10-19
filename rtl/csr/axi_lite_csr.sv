`timescale 1ns/1ps

// 设计假设 CSR read/write 不会同时发生
// 不处理 burst、ID、CDC、寄存器副作用
// 只保留一笔尚未完成的事务
module axi_lite_csr (
    input  logic        clk,
    input  logic        rst,  // synchronous, active high


    // CSR Write related
    // AW Channel: Master → Slave
    input  logic        s_axi_awvalid,
    input  logic [31:0] s_axi_awaddr,
    output logic        s_axi_awready,

    // W Channel: Master → Slave
    input  logic        s_axi_wvalid,
    input  logic [31:0] s_axi_wdata,
    input  logic [3:0]  s_axi_wstrb,
    output logic        s_axi_wready,

    // B Channel: Slave → Master
    output logic        s_axi_bvalid,
    output logic [1:0]  s_axi_bresp,
    input  logic        s_axi_bready,


    // CSR Read related
    // AR Channel: Master → Slave
    input  logic        s_axi_arvalid,
    input  logic [31:0] s_axi_araddr,
    output logic        s_axi_arready,

    // R Channel: Slave → Master
    output logic        s_axi_rvalid,
    output logic [1:0]  s_axi_rresp,
    output logic [31:0] s_axi_rdata,
    input  logic        s_axi_rready
);
    localparam logic [31:0] CTRL_ADDR   = 32'h0000_0000;
    localparam logic [31:0] STATUS_ADDR = 32'h0000_0004;

    // CSR register define
    logic [31:0] ctrl_rw;   // ADDR 0x0000, RW
    logic [31:0] status_o;  // ADDR 0x0004, RO

    // Common codes
    typedef enum logic {
        RESP_OKEY,
        RESP_SLVERR
    } csr_resp_t;


    // CSR Write related RTL section
    wire aw_transfer = s_axi_awvalid && s_axi_awready;
    wire w_transfer = s_axi_wvalid && s_axi_wready;
    wire b_transfer = s_axi_bvalid && s_axi_bready;

    logic waddr_valid;
    logic wdata_valid;
    wire wq_valid = waddr_valid && wdata_valid;
    logic [31:0] waddr;
    logic [31:0] wdata;
    logic [3:0]  wstrb;
    logic [31:0] ctrl_write_data;

    typedef enum logic [1:0] {
        W_IDLE,
        W_AW_SENT,
        W_W_SENT,
        W_REQ_SENT // main used state
    } wstate_t;
    
    wstate_t wstate, next_wstate;

    always_comb begin
        next_wstate = wstate;

        if (aw_transfer || w_transfer || b_transfer) begin
            case (wstate)
            W_IDLE: begin
                if (aw_transfer && w_transfer)
                    next_wstate = W_REQ_SENT;
                else if (aw_transfer)
                    next_wstate = W_AW_SENT;
                else if (w_transfer)
                    next_wstate = W_W_SENT;
            end

            W_AW_SENT: begin
                if (w_transfer)
                    next_wstate = W_REQ_SENT;
            end

            W_W_SENT: begin
                if (aw_transfer)
                    next_wstate = W_REQ_SENT;
            end

            W_REQ_SENT: begin
                if (b_transfer)
                    next_wstate = W_IDLE;
            end

            default: next_wstate = W_IDLE;
            endcase
        end
    end

    // 根据aw/w数据收集状态来设置
    always_comb begin : s_write_handshakes
        // 默认可以接收 aw/w
        s_axi_bvalid = 1'b0;
        s_axi_awready = 1'b1; // aw
        s_axi_wready  = 1'b1; // w

        if (wq_valid) begin
            s_axi_bvalid = 1'b1;  // b only
            s_axi_awready = 1'b0;
            s_axi_wready  = 1'b0;
        end else if (waddr_valid) begin
            s_axi_bvalid = 1'b0;
            s_axi_awready = 1'b0;
            s_axi_wready  = 1'b1; // w only
        end else if (wdata_valid) begin
            s_axi_bvalid = 1'b0;
            s_axi_awready = 1'b1; // aw only
            s_axi_wready  = 1'b0;
        end
    end

    always_comb begin : b_response
        s_axi_bresp = RESP_OKEY;

        if (wq_valid && (wstate == W_REQ_SENT)) begin
            if (waddr != CTRL_ADDR)
                s_axi_bresp = RESP_SLVERR;
        end
    end

    // Merge each enabled WDATA byte into the current CTRL value.
    // Elaboration：
    //     “这个设计最终有哪些实例、哪些参数、哪些信号和连接？”
    // Synthesis：
    //     “这些已经确定的 RTL 行为要用哪些硬件资源实现？”
    // for 语法含义跟软件类似，但是作用不一样，接近于 '重复生成相同结构'
    //      ：例题中 综合工具通常会生成四个并行的8位 2:1 mux:
    //                      wstrb[0]
    //                         |
    //     ctrl_rw[7:0] ---- 0:1 mux ---- ctrl_write_data[7:0]
    //     wdata[7:0]  -----/
    //                      wstrb[1]
    //                         |
    //     ctrl_rw[15:8] --- 0:1 mux ---- ctrl_write_data[15:8]
    //     wdata[15:8] ----/
    //  注意：以上是过程型 for, 还有 生成型 for: 
    //  generate for 是 elaboration 阶段展开的，用来生成多个模块实例、连续赋值或结构。
    //     generate
    //     for (genvar i = 0; i < 4; i++) begin : gen_and
    //         assign y[i] = a[i] & b[i];
    //     end
    //     endgenerate
    //
    //     ctrl_write_data[byte_lane*8 +: 8] 中的 'byte_lane*8 +: 8':
    //          含义是: '起始位 +: 位宽', 此处的含义是：
    //                 byte_lane 0 ->  [0  + : 8] == [ 7:0]
    //                 byte_lane 1 ->  [8  + : 8] == [15:0]
    //                 byte_lane 2 ->  [16 + : 8] == [23:0]
    //                 byte_lane 3 ->  [24 + : 8] == [31:0]
    always_comb begin : ctrl_wstrb_merge
        ctrl_write_data = ctrl_rw;
        for (int byte_lane = 0; byte_lane < 4; byte_lane++) begin
            if (wstrb[byte_lane])
                ctrl_write_data[byte_lane*8 +: 8] = wdata[byte_lane*8 +: 8];
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            waddr_valid   <= 1'b0;
            wdata_valid   <= 1'b0;
            wstate        <= W_IDLE;
        end else begin
            wstate <= next_wstate;

            // AW ch M -> S
            if (aw_transfer && (waddr_valid != 1'b1)) begin
                waddr <= s_axi_awaddr;
                waddr_valid <= 1'b1;
            end

            // W ch M -> S    
            if (w_transfer && (wdata_valid != 1'b1)) begin
                wdata <= s_axi_wdata;
                wstrb <= s_axi_wstrb;
                wdata_valid <= 1'b1;
            end

            // B ch S -> M
            if (wq_valid && (wstate == W_REQ_SENT))
                if (waddr == CTRL_ADDR)
                    ctrl_rw <= ctrl_write_data;

            // handshake and clear 'B ch S -> M'
            if (b_transfer && (wstate == W_REQ_SENT)) begin
                waddr_valid  <= 1'b0;
                wdata_valid  <= 1'b0;
            end
        end
    end


    // CSR Read related RTL section
    wire ar_transfer = s_axi_arvalid && s_axi_arready;
    wire r_transfer  = s_axi_rvalid && s_axi_rready;

    logic raddr_valid;
    logic [31:0] raddr;
    assign s_axi_rresp = RESP_OKEY;

    typedef enum logic {
        R_IDLE,
        R_REQ_SENT // main used state
    } rstate_t;

    rstate_t rstate, next_rstate;

    always_comb begin
        next_rstate = rstate;

        if (ar_transfer || r_transfer) begin
            case (rstate)
            R_IDLE: begin
                if (ar_transfer)
                    next_rstate = R_REQ_SENT;
            end

            R_REQ_SENT: begin
                if (r_transfer)
                    next_rstate = R_IDLE;
            end

            default: next_rstate = R_IDLE;
            endcase
        end
    end

    // 根据r数据收集状态来设置
    always_comb begin
        if (raddr_valid) begin
            s_axi_arready = 1'b0;
            s_axi_rvalid  = 1'b1; // r
        end else begin
            s_axi_arready = 1'b1; // ar
            s_axi_rvalid  = 1'b0;
        end
    end

    // Address route
    always_comb begin : reg_addr
        case (raddr)
        CTRL_ADDR:   s_axi_rdata = ctrl_rw;
        STATUS_ADDR: s_axi_rdata = status_o;
        default: s_axi_rdata = 32'hDEAD_BEEF;
        endcase
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            raddr_valid   <= 1'b0;
            rstate        <= R_IDLE;
            status_o      <= 32'h0000_0000;
        end else begin
            rstate <= next_rstate;

            // AR ch M -> S
            if (ar_transfer && (raddr_valid != 1'b1)) begin
                raddr <= s_axi_araddr;
                raddr_valid <= 1'b1;
            end

            // handshake and clear 'R ch S -> M'
            if (r_transfer && (rstate == R_REQ_SENT)) begin
                raddr_valid  <= 1'b0;
            end
        end
    end

endmodule
