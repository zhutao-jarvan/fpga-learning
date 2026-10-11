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
    assign s_axi_bresp = RESP_OKEY;

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

    // 拉高 s_axi_bvalid，如果收齐了 aw/w 的数据后
    always_comb begin
        if (wq_valid) begin
            s_axi_bvalid = 1'b1;
            s_axi_awready <= 1'b0; // aw
            s_axi_wready  <= 1'b0; // w
        end else begin
            s_axi_bvalid = 1'b0;
            s_axi_awready <= 1'b1; // aw
            s_axi_wready  <= 1'b1; // w
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
                wdata_valid <= 1'b1;
            end

            // B ch S -> M
            if (wq_valid && (wstate == W_REQ_SENT)) begin
                // 实际要对比地址，但是现在只有一个可以写的地址，就直接写了
                ctrl_rw <= wdata; // 不考虑同时 READ ctrl_rw
            end

            // handshake and clear 'B ch S -> M'
            if (b_transfer && (wstate == W_REQ_SENT)) begin
                waddr_valid  <= 1'b0;
                wdata_valid  <= 1'b0;
            end
        end
    end


    // CSR Read related RTL section



endmodule
