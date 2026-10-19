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
    integer ar_handshakes = 0;
    integer r_handshakes = 0;
    logic test_done = 1'b0;
    string scenario;

    wire aw_transfer = s_axi_awvalid && s_axi_awready;
    wire w_transfer  = s_axi_wvalid && s_axi_wready;
    wire b_transfer  = s_axi_bvalid && s_axi_bready;
    wire ar_transfer = s_axi_arvalid && s_axi_arready;
    wire r_transfer  = s_axi_rvalid && s_axi_rready;

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

    // S -> M : 下降沿拉高 s_axi_bready，准备接收 b
    // 一直等到 b_transfer 在上升沿被检查到
    // 拉低 s_axi_bready，完成传输
    task automatic accept_b2(output logic [1:0] response);
        begin
            @(negedge clk) s_axi_bready = 1'b1;
            do @(posedge clk); while (!b_transfer); // 等到握手的上升沿
            response = s_axi_bresp; // 在 B handshake 的上升沿采样
            @(negedge clk) s_axi_bready = 1'b0;
        end
    endtask

    // S -> M : 下降沿 AR 通道写入地址，拉高 valid
    // 一直等到 ar_transfer
    // 拉低 valid
    task automatic drive_ar(input logic [31:0] address);
        begin
            @(negedge clk);
            s_axi_araddr  = address;
            s_axi_arvalid = 1'b1;
            do @(posedge clk); while (!ar_transfer);
            @(negedge clk) s_axi_arvalid = 1'b0;
        end
    endtask

    //  S -> M : R 通道 发送数据和应答
    // Master 下降沿拉高 ready 等待上升沿握手
    // 握手后，读取 data 和 response
    // 最后拉低 ready
    task automatic accept_r(
        output logic [31:0] data,
        output logic [1:0] response
    );
        begin
            @(negedge clk) s_axi_rready = 1'b1;
            do @(posedge clk); while (!r_transfer);
            data = s_axi_rdata;
            response = s_axi_rresp;
            @(negedge clk) s_axi_rready = 1'b0;
        end
    endtask

    task automatic check_single_write(input logic [31:0] expected_data);
        begin
            #1;
            check(aw_handshakes == 1, "expected exactly one AW handshake");
            check(w_handshakes == 1, "expected exactly one W handshake");
            check(b_handshakes == 1, "expected exactly one B handshake");
            check(s_axi_bresp == 2'b00, "BRESP is not OKAY");
            check(dut.ctrl_rw == expected_data, "ctrl_rw did not receive WDATA");
        end
    endtask

    task automatic run_aw_first;
        begin
            check(dut.ctrl_rw == 32'h0000_0000, "unexpected dut.ctrl_rw value after reset");
            drive_aw(32'h0000_0000);
            drive_w(32'hCAFE_1234, 4'b1111);
            accept_b();
            check_single_write(32'hCAFE_1234);
        end
    endtask

    task automatic run_w_first;
        begin
            logic [31:0] old_ctrl_rw = dut.ctrl_rw;

            drive_w(32'hCAFE_1239, 4'b1111);
            // Check aw_handshakes==0 和 ctrl_rw 未更新
            check(aw_handshakes == 0, "expected exactly one AW handshake");
            check(w_handshakes == 1, "expected exactly one W handshake");
            check(b_handshakes == 0, "expected exactly one B handshake");

            repeat (2) begin
                @(posedge clk);
                #1;
                check(s_axi_awready, "W first but awready == 0");
                check(!s_axi_wready, "W already handshake but still high");
                check(dut.ctrl_rw == old_ctrl_rw, "ctrl_rw changed only w handshake");
            end

            drive_aw(32'h0000_0000);
            check(aw_handshakes == 1, "expected exactly one AW handshake");
            check(w_handshakes == 1, "expected exactly one W handshake");
            check(b_handshakes == 0, "expected exactly one B handshake");

            accept_b();
            check(aw_handshakes == 1, "expected exactly one AW handshake");
            check(w_handshakes == 1, "expected exactly one W handshake");
            check(b_handshakes == 1, "expected exactly one B handshake");

            check_single_write(32'hCAFE_1239);
            check(!s_axi_bvalid, "BVALID did not clear after W-first B handshake");
            check(s_axi_awready, "AWREADY did not recover after W-first B handshake");
            check(s_axi_wready, "WREADY did not recover after W-first B handshake");
        end
    endtask

    task automatic run_aw_w_parallel;
        begin
            fork
                drive_aw(32'h0000_0000);
                drive_w(32'hCAFE_1235, 4'b1111);
            join
            accept_b();
            check_single_write(32'hCAFE_1235);
        end
    endtask

    task automatic run_b_backpressure;
        begin
            // BREADY remains low while the response is pending.
            @(negedge clk) s_axi_bready = 1'b0;
            fork
                drive_aw(32'h0000_0000);
                drive_w(32'hCAFE_1236, 4'b1111);
            join

            repeat (2) begin
                @(posedge clk);
                #1;
                check(!s_axi_awready, "AWREADY rose during B backpressure");
                check(!s_axi_wready, "WREADY rose during B backpressure");
                check(s_axi_bvalid, "BVALID dropped during B backpressure");
                check(s_axi_bresp == 2'b00, "BRESP changed during B backpressure");
            end

            accept_b();
            #1;
            check(!s_axi_bvalid, "BVALID did not clear after handshake");
            check(s_axi_awready, "AWREADY did not recover after B handshake");
            check(s_axi_wready, "WREADY did not recover after B handshake");
            check_single_write(32'hCAFE_1236);
        end
    endtask

    task automatic run_read_ctrl;
        logic [31:0] read_data;
        logic [1:0] read_response;
        begin
            // Establish a known CTRL value before testing the read path.
            fork
                drive_aw(32'h0000_0000);
                drive_w(32'hCAFE_1237, 4'b1111);
            join
            accept_b();
            check_single_write(32'hCAFE_1237);

            drive_ar(32'h0000_0000);
            accept_r(read_data, read_response);

            #1;
            check(ar_handshakes == 1, "expected exactly one AR handshake");
            check(r_handshakes == 1, "expected exactly one R handshake");
            check(read_response == 2'b00, "RRESP is not OKAY");
            check(read_data == 32'hCAFE_1237, "RDATA did not return CTRL");
            check(!s_axi_rvalid, "RVALID did not clear after handshake");
            check(s_axi_arready, "ARREADY did not recover after R handshake");
        end
    endtask

    task automatic run_r_backpressure;
        logic [31:0] data;
        logic [1:0] response;

        fork
            drive_aw(32'h0000_0000);
            drive_w(32'hCAFE_1238, 4'b1111);
        join

        accept_b();
        // Done: write 32'hCAFE_1238 to register CTRL

        drive_ar(32'h0000_0000);
        // Check the backpressure effected
        repeat (2) begin
            @(posedge clk);
            #1;
            check(!s_axi_arready, "ARREADY rose during R backpressure");
            check(s_axi_rdata == 32'hCAFE_1238, "RDATA changed during R backpressure");
            check(s_axi_rvalid, "RVALID dropped during R backpressure");
            check(s_axi_rresp == 2'b00, "BRESP changed during R backpressure");
        end

        accept_r(data, response);

        check(ar_handshakes == 1, "expected exactly one AR handshake");
        check(r_handshakes == 1, "expected exactly one R handshake");

        check(s_axi_arready, "ARREADY did not return 1");
        check(!s_axi_rvalid, "RVALID did not return 0");
        check(response == 2'b00, "run_r_backpressure read error BRESP");
        check(data == 32'hCAFE_1238, "run_r_backpressure read error data");
    endtask

    task automatic run_read_status;
        logic [31:0] data;
        logic [1:0] response;

        // STATUS is read-only and is reset to zero in this minimal exercise.
        drive_ar(32'h0000_0004);
        check(ar_handshakes == 1, "expected exactly one STATUS AR handshake");
        check(s_axi_rvalid, "STATUS RVALID did not assert after AR handshake");
        check(!s_axi_arready, "ARREADY remained high while STATUS response pending");

        // Hold RREADY low and verify the complete response remains stable.
        repeat (2) begin
            @(posedge clk);
            #1;
            check(s_axi_rvalid, "STATUS RVALID dropped during R backpressure");
            check(s_axi_rdata == 32'h0000_0000,
                  "STATUS RDATA changed or did not return reset value");
            check(s_axi_rresp == 2'b00, "STATUS RRESP is not OKAY");
            check(!s_axi_arready, "ARREADY rose during STATUS R backpressure");
            check(r_handshakes == 0, "STATUS R handshake occurred while RREADY was low");
        end

        accept_r(data, response);
        check(r_handshakes == 1, "expected exactly one STATUS R handshake");
        check(data == 32'h0000_0000, "STATUS RDATA is not the reset value");
        check(response == 2'b00, "STATUS RRESP is not OKAY after handshake");
        check(!s_axi_rvalid, "RVALID did not clear after STATUS R handshake");
        check(s_axi_arready, "ARREADY did not recover after STATUS R handshake");
    endtask

    task automatic run_wstrb;
        logic [31:0] data;
        logic [1:0] response;
        begin
            // Establish all four CTRL byte lanes with a full write.
            fork
                drive_aw(32'h0000_0000);
                drive_w(32'hCAFE_123A, 4'b1111);
            join
            accept_b2(response);
            check(aw_handshakes == 1, "WSTRB setup expected one AW handshake");
            check(w_handshakes == 1, "WSTRB setup expected one W handshake");
            check(b_handshakes == 1, "WSTRB setup expected one B handshake");
            check(response == 2'b00, "WSTRB setup BRESP is not OKAY");
            check(dut.ctrl_rw == 32'hCAFE_123A, "WSTRB setup did not initialize CTRL");

            // 0101 updates byte lanes 2 and 0, preserving lanes 3 and 1.
            fork
                drive_aw(32'h0000_0000);
                drive_w(32'hBEEF_5678, 4'b0101);
            join
            accept_b2(response);
            check(aw_handshakes == 2, "WSTRB partial write expected two AW handshakes");
            check(w_handshakes == 2, "WSTRB partial write expected two W handshakes");
            check(b_handshakes == 2, "WSTRB partial write expected two B handshakes");
            check(response == 2'b00, "WSTRB partial write BRESP is not OKAY");

            // CA FE 12 3A -> (lane 2=EF, lane 0=78) -> CA EF 12 78.
            check(dut.ctrl_rw == 32'hCAEF_1278,
                  "CTRL byte lanes do not match WSTRB=0101 semantics");

            drive_ar(32'h0000_0000);
            accept_r(data, response);
            check(ar_handshakes == 1, "WSTRB readback expected one AR handshake");
            check(r_handshakes == 1, "WSTRB readback expected one R handshake");
            check(response == 2'b00, "WSTRB readback RRESP is not OKAY");
            check(data == 32'hCAEF_1278, "WSTRB readback CTRL value is incorrect");
            check(!s_axi_rvalid, "WSTRB readback RVALID did not clear");
            check(s_axi_arready, "WSTRB readback ARREADY did not recover");
        end
    endtask

    task automatic run_w_badaddr;
        logic [31:0] data;
        logic [1:0] response;

        fork
            drive_aw(32'h0000_0000);
            drive_w(32'hCAFE_123a, 4'b1111);
        join
        accept_b2(response);
        check(aw_handshakes == 1, "expected exactly 1 AW handshake");
        check(w_handshakes == 1, "expected exactly 1 W handshake");
        check(b_handshakes == 1, "expected exactly 1 B handshake");
        check(response == 2'b00, "expected response == RESP_OKEY(0)");

        fork
            drive_aw(32'h0000_FFFF);
            drive_w(32'hCAFE_123b, 4'b1111);
        join

        // Accept B and response
        accept_b2(response);
        check(aw_handshakes == 2, "expected exactly 2 AW handshake");
        check(w_handshakes == 2, "expected exactly 2 W handshake");
        check(b_handshakes == 2, "expected exactly 2 B handshake");
        check(response == 2'b01, "expected response == RESP_SLVERR(1)");
        check(!s_axi_bvalid, "BVALID did not clear after bad-address B handshake");
        check(s_axi_awready && s_axi_wready, "write channels did not recover after bad-address B handshake");

        // Read the result
        drive_ar(32'h0000_0000);
        // Check the backpressure effected
        accept_r(data, response);

        check(ar_handshakes == 1, "expected exactly one AR handshake");
        check(r_handshakes == 1, "expected exactly one R handshake");

        check(response == 2'b00, "expected response == RESP_OKEY(0)");
        check(data == 32'hCAFE_123a, "expected read data 32'hCAFE_123a");
    endtask

    // Observation only: this process never drives a DUT input.
    always @(posedge clk) begin
        cycle = cycle + 1;
        if (!rst) begin
            if (aw_transfer) aw_handshakes = aw_handshakes + 1;
            if (w_transfer)  w_handshakes  = w_handshakes + 1;
            if (b_transfer)  b_handshakes  = b_handshakes + 1;
            if (ar_transfer) ar_handshakes = ar_handshakes + 1;
            if (r_transfer)  r_handshakes  = r_handshakes + 1;
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

        if (!$value$plusargs("scenario=%s", scenario))
            scenario = "aw_first";
        $display("Running scenario: %s", scenario);

        reset_dut();

        if (scenario == "aw_first")
            run_aw_first();
        else if (scenario == "w_first")
            run_w_first();
        else if (scenario == "aw_w_parallel")
            run_aw_w_parallel();
        else if (scenario == "b_backpressure")
            run_b_backpressure();
        else if (scenario == "read_ctrl")
            run_read_ctrl();
        else if (scenario == "r_backpressure")
            run_r_backpressure();
        else if (scenario == "read_status")
            run_read_status();
        else if (scenario == "wstrb")
            run_wstrb();
        else if (scenario == "w_badaddr")
            run_w_badaddr();
        else begin
            fail("unknown scenario; use aw_first, aw_w_parallel, b_backpressure, or read_ctrl");
        end

        test_done = 1'b1;
        if (errors == 0)
            $display("PASS: AXI LITE CSR checks passed (%0d cycles)", cycle);
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
