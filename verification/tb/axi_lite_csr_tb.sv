`timescale 1ns/1ps

module axi_lite_csr_tb;
    logic        clk = 1'b0;
    logic        rst = 1'b1;  // synchronous, active high


    // CSR Write related
    // AW Channel: Master → Slave
    logic        s_axi_awvalid;
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awready;

    // W Channel: Master → Slave
    logic        s_axi_wvalid;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb = 4'b1111;
    logic        s_axi_wready;

    // B Channel: Slave → Master
    logic        s_axi_bvalid;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bready;


    // CSR Read related
    // AR Channel: Master → Slave
    logic        s_axi_arvalid;
    logic [31:0] s_axi_araddr;
    logic        s_axi_arready;

    // R Channel: Slave → Master
    logic        s_axi_rvalid;
    logic [1:0]  s_axi_rresp;
    logic [31:0] s_axi_rdata;
    logic        s_axi_rready;

    integer errors = 0;
    integer cycle = 0;
    integer wresp_cnt = 0;
    integer rresp_cnt = 0;

    integer wrq_phase;

    // Write related
    logic [31:0] wrq_data;
    logic [31:0] wrq_addr = 32'b0000_0000;

    wire aw_transfer = s_axi_awvalid && s_axi_awready;
    wire w_transfer = s_axi_wvalid && s_axi_wready;
    wire b_transfer = s_axi_bvalid && s_axi_bready;

    // 实例化语法： module_name [#(parameter_values)] instance_name (port_connections);
    // '(.*)': 将被实例化模块的端口，与当前作用域中同名的信号自动连接。
    axi_lite_csr dut (.*);

    // 第一个 always 过程块：无限重复执行后面的语句。
    // #5：延迟 5 个仿真时间单位。
    // = ： 阻塞赋值
    always #5 clk = ~clk;

    // 创建一个可以重复被调用的 task （类似于软件的函数）
    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR at cycle %0d: %0s", cycle, message);
            errors = errors + 1;
        end
    endtask

    assign s_axi_awaddr = wrq_addr;
    assign s_axi_wdata  = wrq_data;
    always_comb begin
        wrq_data = 32'b0000_0000;

        if (s_axi_wvalid)
            wrq_data = 32'b0000_0000 + wrq_phase;
    end

    // 仿照一个一个 AXI4 Lite 的 Maser 行为给 Slave 提供激励
    // Write CSR 
    always @(negedge clk) begin
        if (rst) begin
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
            s_axi_bready  <= 1'b0;
        end else begin
            case (wrq_phase)
                // AW & W in the same clk
                1: begin // clk 
                    s_axi_awvalid <= 1'b1;
                    s_axi_wvalid  <= 1'b1;

                    // b ch
                    s_axi_bready  <= 1'b1;
                end

                // AW & W in a different clk
                2: begin // forty beats, deterministic pseudo-random ready
                    s_axi_awvalid <= 1'b1;
                    if (s_axi_awvalid) begin
                        s_axi_wvalid  <= 1'b1;
                        s_axi_bready  <= 1'b1;
                    end
                end
                default: begin
                    s_axi_awvalid <= 1'b0;
                    s_axi_wvalid  <= 1'b0;
                    s_axi_bready  <= 1'b0;
                end
            endcase
        end
    end

    // 仿照一个一个 AXI4 Lite 的 Maser 行为
    always @(posedge clk) begin
        cycle = cycle + 1;

        if (rst) begin
            s_axi_awvalid <= 1'b0;
            s_axi_wvalid  <= 1'b0;
        end else begin
            // Write CSR, B ch handshake
            if (s_axi_bvalid) begin
                s_axi_bready <= 1'b1;
            end

            // Master finish transfer, init for next
            if (s_axi_bready) begin
                s_axi_awvalid <= 1'b0;
                s_axi_wvalid  <= 1'b0;
                wresp_cnt <= wresp_cnt + 1;
            end

            // Read CSR

        end
    end

    // 第四个过程块(initial)：
    initial begin
        // '$name(arguments);' 表示： 表示调用一个仿真器提供的系统任务或系统函数。
        // 正式 VCS/Verdi 流程用 ENABLE_FSDB 生成 FSDB；未定义时保留 VCD fallback。
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "axi_lite_csr.fsdb";
            // 可用 +fsdbfile=name.fsdb 覆盖默认文件名，便于不同 testcase 隔离波形。
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, axi_lite_csr_tb);
            $fsdbDumpMDA();
        `else
            // VCD 是跨工具 fallback；本学习流程的波形分析优先使用 FSDB/Verdi。
            $dumpfile("axi_lite_csr.vcd");
            $dumpvars(0, axi_lite_csr_tb);
        `endif

        $display("start run ...");
        // Two synchronous reset cycles.
        // repeat 的一般语法是：
        //      repeat (次数表达式)
        //          statement;
        // @ 可以理解为：暂停当前过程，直到指定事件发生，然后继续执行后面的语句。
        repeat (2) @(posedge clk); // 等待两个上升沿
        @(negedge clk) rst = 1'b0; // 下降沿清零rst后等 1ns
        #1;

        // AW & W 同时
        wrq_phase = 1;
        $display("wrq_phase 1 setting ...");
        wait (wresp_cnt == 3);

        @(posedge clk);
        // AW & W 异步
        wrq_phase = 2;
        $display("wrq_phase 2 setting ...");
        wait (wresp_cnt == 6);

        @(posedge clk);
        wrq_phase = 3;

        repeat (12) @(posedge clk);

        if (errors == 0)
            $display("PASS: AXI LITE CSR checks passed (%0d Cycles)", cycle);
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
