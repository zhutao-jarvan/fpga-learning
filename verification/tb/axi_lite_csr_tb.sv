`timescale 1ns/1ps

module axi_lite_csr_tb;
    logic clk = 1'b0;
    logic rst = 1'b1;

    logic        s_axi_awvalid;
    logic [31:0] s_axi_awaddr;
    logic        s_axi_awready;
    logic        s_axi_wvalid;
    logic [31:0] s_axi_wdata;
    logic [3:0]  s_axi_wstrb;
    logic        s_axi_wready;
    logic        s_axi_bvalid;
    logic [1:0]  s_axi_bresp;
    logic        s_axi_bready;
    logic        s_axi_arvalid;
    logic [31:0] s_axi_araddr;
    logic        s_axi_arready;
    logic        s_axi_rvalid;
    logic [1:0]  s_axi_rresp;
    logic [31:0] s_axi_rdata;
    logic        s_axi_rready;

    integer cycle = 0;
    integer errors = 0;
    integer aw_handshakes = 0;
    integer w_handshakes = 0;
    integer b_handshakes = 0;
    logic test_done = 1'b0;

    wire aw_transfer = s_axi_awvalid && s_axi_awready;
    wire w_transfer  = s_axi_wvalid && s_axi_wready;
    wire b_transfer  = s_axi_bvalid && s_axi_bready;

    axi_lite_csr dut (.*);

    always #5 clk = ~clk;

    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR at cycle %0d: %0s", cycle, message);
            errors = errors + 1;
        end
    endtask

    task automatic check(input logic condition, input [1023:0] message);
        begin
            if (!condition)
                fail(message);
        end
    endtask

    // The scenario process is the sole driver of all AXI master inputs.
    // 模拟 Master reset slave 的操作
    task automatic reset_dut;
        begin
            @(negedge clk);
            rst           = 1'b1;
            s_axi_awvalid = 1'b0;
            s_axi_awaddr  = 32'b0;

            s_axi_wvalid  = 1'b0;
            s_axi_wdata   = 32'b0;
            s_axi_wstrb   = 4'b0;

            s_axi_bready  = 1'b0;

            s_axi_arvalid = 1'b0;
            s_axi_araddr  = 32'b0;
            s_axi_rready  = 1'b0;

            // 两个 cycle 后，拉低 rst
            repeat (2) @(posedge clk);
            @(negedge clk) rst = 1'b0; 
        end
    endtask

    // M -> S : 在下降沿给出 aw 的激励，地址由参数传入
    task automatic drive_aw(input logic [31:0] address);
        begin
            @(negedge clk);
            s_axi_awaddr  = address;
            s_axi_awvalid = 1'b1;
            do @(posedge clk); while (!aw_transfer);
            @(negedge clk) s_axi_awvalid = 1'b0;
        end
    endtask

    // M -> S : 在下降沿给出 w 的激励，数据和 storbe 由参数传入
    task automatic drive_w(input logic [31:0] data, input logic [3:0] strobe);
        begin
            @(negedge clk);
            s_axi_wdata  = data;
            s_axi_wstrb  = strobe;
            s_axi_wvalid = 1'b1;
            do @(posedge clk); while (!w_transfer);
            @(negedge clk) s_axi_wvalid = 1'b0;
        end
    endtask

    // S -> M : 下降沿拉高 s_axi_bready，准备接收 b
    // 一直等到 b_transfer 在上升沿被检查到
    // 拉低 s_axi_bready，完成传输
    task automatic accept_b;
        begin
            @(negedge clk) s_axi_bready = 1'b1;
            do @(posedge clk); while (!b_transfer);
            @(negedge clk) s_axi_bready = 1'b0;
        end
    endtask

    // Observation only: this process never drives a DUT input.
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (!rst) begin
            if (aw_transfer) aw_handshakes = aw_handshakes + 1;
            if (w_transfer)  w_handshakes  = w_handshakes + 1;
            if (b_transfer)  b_handshakes  = b_handshakes + 1;
        end
    end

    // Global guard against a broken handshake or a missing completion.
    // 一个单独的 initial 块来要检测死锁 （测试最多持续200个 cycle）
    initial begin
        repeat (200) @(posedge clk);
        if (!test_done) begin
            fail("global timeout");
            $finish;
        end
    end

    initial begin
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "axi_lite_csr.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, axi_lite_csr_tb);
            $fsdbDumpMDA();
        `else
            $dumpfile("axi_lite_csr.vcd");
            $dumpvars(0, axi_lite_csr_tb);
        `endif

        reset_dut();

        // Scenario layer: one AW-first write, with W delayed by a cycle.
        drive_aw(32'h0000_0000);
        drive_w(32'hCAFE_1234, 4'b1111);
        accept_b();

        #1;
        check(aw_handshakes == 1, "expected exactly one AW handshake");
        check(w_handshakes == 1, "expected exactly one W handshake");
        check(b_handshakes == 1, "expected exactly one B handshake");
        check(s_axi_bresp == 2'b00, "BRESP is not OKAY");
        check(dut.ctrl_rw == 32'hCAFE_1234, "ctrl_rw did not receive WDATA");

        test_done = 1'b1;
        if (errors == 0)
            $display("PASS: AXI LITE CSR checks passed (%0d cycles)", cycle);
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
