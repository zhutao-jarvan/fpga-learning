`timescale 1ns/1ps

module rv_registered_ready_skid_buffer_tb;
    logic       clk = 1'b0;
    logic       rst = 1'b1;

    logic       s_valid_i = 1'b0;
    logic [7:0] s_data_i = 8'h00;
    logic       s_last_i = 1'b0;
    logic       s_ready_o;

    logic       m_valid_o;
    logic [7:0] m_data_o;
    logic       m_last_o;
    logic       m_ready_i = 1'b0;

    integer errors = 0;
    integer cycle = 0;
    integer input_count = 0;
    integer output_count = 0;
    logic [7:0] expected_data [0:127];
    logic       expected_last [0:127];
    logic       monitor_enabled = 1'b0;
    logic       previous_stall = 1'b0;
    logic [7:0] previous_stall_data = 8'h00;
    logic       previous_stall_last = 1'b0;

    rv_registered_ready_skid_buffer dut (.*);

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            $display("ERROR at cycle %0d (%0t): %s", cycle, $time, message);
            errors = errors + 1;
        end
    endtask

    task automatic drive(
        input logic       valid,
        input logic [7:0] data,
        input logic       last,
        input logic       ready
    );
        @(negedge clk);
        s_valid_i = valid;
        s_data_i  = data;
        s_last_i  = last;
        m_ready_i = ready;
    endtask

    // Ordered scoreboard plus protocol, stability, and two-entry capacity
    // checks.  Sampling occurs before sequential NBA updates at each edge.
    always @(posedge clk) begin : monitor
        logic in_now;
        logic out_now;
        integer queued_after;

        cycle = cycle + 1;
        in_now = s_valid_i && s_ready_o;
        out_now = m_valid_o && m_ready_i;

        if (monitor_enabled && !rst) begin
            check(s_ready_o === 1'b0 || s_ready_o === 1'b1,
                  "s_ready_o is X/Z");
            check(m_valid_o === 1'b0 || m_valid_o === 1'b1,
                  "m_valid_o is X/Z");

            if (previous_stall) begin
                check(m_valid_o === 1'b1,
                      "m_valid_o dropped while output was stalled");
                check(m_data_o === previous_stall_data,
                      "m_data_o changed while output was stalled");
                check(m_last_o === previous_stall_last,
                      "m_last_o changed while output was stalled");
            end

            if (in_now) begin
                expected_data[input_count] = s_data_i;
                expected_last[input_count] = s_last_i;
                input_count = input_count + 1;
            end

            if (out_now) begin
                check(output_count < input_count,
                      "output accepted without an earlier input beat");
                if (output_count < input_count) begin
                    check(m_data_o === expected_data[output_count],
                          "data was lost, duplicated, corrupted, or reordered");
                    check(m_last_o === expected_last[output_count],
                          "last did not remain paired with its data beat");
                end
                output_count = output_count + 1;
            end

            queued_after = input_count - output_count;
            check(queued_after >= 0, "more outputs than inputs were accepted");
            check(queued_after <= 2, "skid buffer retained more than two beats");

            previous_stall = m_valid_o && !m_ready_i;
            previous_stall_data = m_data_o;
            previous_stall_last = m_last_o;
        end
    end

    initial begin : directed_test
        integer before_in;
        integer before_out;
        integer i;

        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "rv_registered_ready_skid_buffer.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, rv_registered_ready_skid_buffer_tb);
        `else
            $dumpfile("rv_registered_ready_skid_buffer.vcd");
            $dumpvars(0, rv_registered_ready_skid_buffer_tb);
        `endif

        // 1. Reset produces EMPTY with input capacity and no output beat.
        repeat (3) @(posedge clk);
        #1;
        check(dut.state_q === 2'd0, "state_q did not reset to EMPTY");
        check(s_ready_o === 1'b1, "EMPTY must advertise input capacity");
        check(m_valid_o === 1'b0, "EMPTY unexpectedly presented an output");
        if (errors != 0)
            $fatal(1, "reset/output-decode checks failed; complete RTL TODOs");

        @(negedge clk);
        rst = 1'b0;
        monitor_enabled = 1'b1;

        // 2. Registered first beat: A is accepted at E0 but cannot also leave
        // at E0.  It becomes visible after E0 and leaves at E1.
        before_in = input_count;
        before_out = output_count;
        drive(1'b1, 8'hA1, 1'b1, 1'b1);
        #1;
        check(s_ready_o === 1'b1, "EMPTY did not accept first beat A1");
        check(m_valid_o === 1'b0, "first beat incorrectly used fall-through");
        @(posedge clk); #1;
        check(dut.state_q === 2'd1, "accepting A1 did not enter ONE");
        check(m_valid_o === 1'b1 && m_data_o === 8'hA1 && m_last_o === 1'b1,
              "A1 was not presented from the registered head slot");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;
        check(dut.state_q === 2'd0, "draining A1 did not return to EMPTY");
        check(input_count == before_in + 1 && output_count == before_out + 1,
              "registered single-beat sequence had wrong handshake counts");

        // 3. Continuous full-rate traffic.  After the initial one-cycle fill,
        // ONE performs simultaneous drain/refill every cycle without bubbles.
        before_in = input_count;
        before_out = output_count;
        for (i = 0; i < 4; i = i + 1) begin
            drive(1'b1, 8'h10 + i, (i == 3), 1'b1);
            #1 check(s_ready_o === 1'b1,
                     "full-rate producer saw an unexpected ready bubble");
            @(posedge clk); #1;
            check(dut.state_q === 2'd1,
                  "full-rate traffic did not retain exactly one registered beat");
            check(m_valid_o === 1'b1 && m_data_o === (8'h10 + i),
                  "head slot did not advance to the newly accepted beat");
        end
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;
        check(dut.state_q === 2'd0, "full-rate sequence did not drain to EMPTY");
        check(input_count == before_in + 4 && output_count == before_out + 4,
              "full-rate sequence did not transfer four ordered beats");

        // 4. One-cycle pause.  A21 is already in head.  Although downstream
        // stalls, ready is still high in ONE, so B22 is accepted into tail and
        // the buffer becomes TWO.  On release, TWO drains A21 but cannot yet
        // accept C23; the held C23 is accepted on the following edge.
        drive(1'b1, 8'h21, 1'b0, 1'b0);
        @(posedge clk); #1;
        check(dut.state_q === 2'd1 && m_data_o === 8'h21,
              "pause setup did not place A21 in ONE/head");

        before_in = input_count;
        before_out = output_count;
        drive(1'b1, 8'h22, 1'b0, 1'b0);
        #1 check(s_ready_o === 1'b1,
                 "ONE did not allow the braking-distance beat B22");
        @(posedge clk); #1;
        check(dut.state_q === 2'd2, "stalled ONE plus B22 did not enter TWO");
        check(s_ready_o === 1'b0, "TWO did not backpressure upstream");
        check(m_data_o === 8'h21, "TWO did not keep older A21 at output");

        drive(1'b1, 8'h23, 1'b1, 1'b1);
        #1 check(s_ready_o === 1'b0,
                 "TWO incorrectly accepted C23 on its release edge");
        @(posedge clk); #1;
        check(dut.state_q === 2'd1 && m_data_o === 8'h22,
              "release did not promote B22 from tail to head");
        check(s_ready_o === 1'b1, "ONE did not reassert ready after release");

        drive(1'b1, 8'h23, 1'b1, 1'b1);
        @(posedge clk); #1;
        check(dut.state_q === 2'd1 && m_data_o === 8'h23,
              "ONE did not simultaneously drain B22 and accept C23");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;
        check(dut.state_q === 2'd0, "one-pause sequence did not drain to EMPTY");
        check(input_count == before_in + 2 && output_count == before_out + 3,
              "one-pause sequence had wrong handshake counts");

        // 5. Long backpressure.  A31 remains the output, B32 occupies tail,
        // and held C33 cannot enter until one edge after downstream releases.
        drive(1'b1, 8'h31, 1'b0, 1'b0);
        @(posedge clk); #1;
        drive(1'b1, 8'h32, 1'b1, 1'b0);
        @(posedge clk); #1;
        check(dut.state_q === 2'd2 && m_data_o === 8'h31,
              "long-stall setup did not retain A31/B32 in FIFO order");

        for (i = 0; i < 2; i = i + 1) begin
            drive(1'b1, 8'h33, 1'b1, 1'b0);
            #1 check(s_ready_o === 1'b0, "TWO accepted C33 during long stall");
            @(posedge clk); #1;
            check(dut.state_q === 2'd2 && m_data_o === 8'h31,
                  "state/output changed during long backpressure");
        end

        before_in = input_count;
        before_out = output_count;
        drive(1'b1, 8'h33, 1'b1, 1'b1);
        #1 check(s_ready_o === 1'b0,
                 "registered ready changed combinationally on release");
        @(posedge clk); #1;
        check(dut.state_q === 2'd1 && m_data_o === 8'h32,
              "release did not drain A31 and promote B32");
        check(input_count == before_in && output_count == before_out + 1,
              "TWO release should output one beat without accepting C33");

        drive(1'b1, 8'h33, 1'b1, 1'b1);
        @(posedge clk); #1;
        check(dut.state_q === 2'd1 && m_data_o === 8'h33,
              "C33 was not accepted after registered ready reasserted");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;

        check(dut.state_q === 2'd0, "test did not finish in EMPTY");
        check(input_count == output_count,
              "test ended with missing, duplicated, or undrained beats");
        if (errors != 0)
            $fatal(1, "rv_registered_ready_skid_buffer: %0d error(s)", errors);
        $display("PASS: rv_registered_ready_skid_buffer directed checks passed (%0d transfers)",
                 output_count);
        $finish;
    end

    initial begin
        repeat (250) @(posedge clk);
        $fatal(1, "rv_registered_ready_skid_buffer global timeout");
    end
endmodule
