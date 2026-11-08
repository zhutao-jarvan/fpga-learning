`timescale 1ns/1ps

module rv_register_slice_tb;
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
    integer simultaneous_count = 0;
    logic [7:0] expected_data [0:127];
    logic       expected_last [0:127];
    logic       monitor_enabled = 1'b0;
    logic       previous_stall = 1'b0;
    logic [7:0] previous_stall_data = 8'h00;
    logic       previous_stall_last = 1'b0;

    rv_register_slice dut (.*);

    always #5 clk = ~clk;

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            $display("ERROR at cycle %0d (%0t): %s", cycle, $time, message);
            errors = errors + 1;
        end
    endtask

    // Apply all traffic away from the active edge.  The caller can inspect
    // ready/valid during the following half-cycle before the acceptance edge.
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

    // Ordered scoreboard plus the protocol's backpressure and one-slot
    // capacity invariants.  Record an accepted input before checking output so
    // an empty fall-through buffer may accept and emit that same beat on the
    // same edge.  When a beat was already buffered, the older array entry is
    // still checked first, so simultaneous drain/refill preserves ordering.
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
                      "m_valid_o dropped while output was backpressured");
                check(m_data_o === previous_stall_data,
                      "m_data_o changed while output was backpressured");
                check(m_last_o === previous_stall_last,
                      "m_last_o changed while output was backpressured");
            end

            if (in_now) begin
                expected_data[input_count] = s_data_i;
                expected_last[input_count] = s_last_i;
                input_count = input_count + 1;
            end

            if (out_now) begin
                check(output_count < input_count,
                      "output accepted without an earlier or same-edge input beat");
                if (output_count < input_count) begin
                    check(m_data_o === expected_data[output_count],
                          "data was lost, duplicated, corrupted, or reordered");
                    check(m_last_o === expected_last[output_count],
                          "last did not remain paired with its data beat");
                end
                output_count = output_count + 1;
            end

            if (in_now && out_now)
                simultaneous_count = simultaneous_count + 1;

            queued_after = input_count - output_count;
            check(queued_after >= 0,
                  "more outputs than accepted inputs were observed");
            check(queued_after <= 1,
                  "fall-through buffer retained more than one beat");

            previous_stall = m_valid_o && !m_ready_i;
            previous_stall_data = m_data_o;
            previous_stall_last = m_last_o;
        end
    end

    initial begin : directed_test
        integer before_in;
        integer before_out;
        integer before_simultaneous;
        integer i;

        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "rv_register_slice.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, rv_register_slice_tb);
        `else
            $dumpfile("rv_register_slice.vcd");
            $dumpvars(0, rv_register_slice_tb);
        `endif

        // 1. Reset state: empty output and capacity available upstream.
        repeat (3) @(posedge clk);
        #1;
        check(dut.full_q === 1'b0, "full_q did not reset empty");
        check(m_valid_o === 1'b0, "m_valid_o asserted after reset");
        check(s_ready_o === 1'b1, "empty buffer must be ready after reset");
        if (errors != 0)
            $fatal(1, "reset checks failed; implement the elastic-buffer TODOs");

        @(negedge clk);
        rst = 1'b0;
        monitor_enabled = 1'b1;

        // 2. One beat with zero-latency fall-through.  While empty and the
        // consumer is ready, the same beat is accepted at both interfaces and
        // no internal occupancy remains after the edge.
        before_in = input_count;
        before_out = output_count;
        before_simultaneous = simultaneous_count;
        drive(1'b1, 8'hA5, 1'b1, 1'b1);
        #1;
        check(s_ready_o === 1'b1, "empty buffer did not accept the single beat");
        check(m_valid_o === 1'b1 && m_data_o === 8'hA5 && m_last_o === 1'b1,
              "single beat did not fall through while the buffer was empty");
        @(posedge clk); #1;
        check(input_count == before_in + 1 && output_count == before_out + 1,
              "single fall-through beat was not accepted at both interfaces");
        check(simultaneous_count == before_simultaneous + 1,
              "single fall-through transfer was not counted as simultaneous");
        check(dut.full_q === 1'b0,
              "successful empty-state fall-through unexpectedly occupied the slot");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        #1;
        check(m_valid_o === 1'b0,
              "output remained valid after the fall-through source withdrew valid");
        @(posedge clk);

        // 3. Continuous full-rate traffic while empty and never stalled.  All
        // eight beats pass through on their input acceptance edge, so all eight
        // edges have simultaneous input/output handshakes and no stored beat.
        before_in = input_count;
        before_out = output_count;
        before_simultaneous = simultaneous_count;
        for (i = 0; i < 8; i = i + 1) begin
            drive(1'b1, 8'h10 + i, (i == 7), 1'b1);
            #1 check(s_ready_o === 1'b1,
                     "full-rate producer saw an unexpected ready bubble");
            check(m_valid_o === 1'b1 && m_data_o === (8'h10 + i),
                  "full-rate beat did not use the empty-state bypass path");
            @(posedge clk);
            #1 check(dut.full_q === 1'b0,
                     "unstalled fall-through traffic unexpectedly occupied the slot");
        end
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;
        check(input_count == before_in + 8,
              "full-rate run did not accept one input per cycle");
        check(output_count == before_out + 8,
              "full-rate run did not produce all eight beats");
        check(simultaneous_count == before_simultaneous + 8,
              "full-rate run did not pass all eight beats on their input edges");

        // 4. A one-cycle output pause.  Beat 21 arrives while the empty
        // consumer is paused, so the slot absorbs it.  On the next cycle the
        // consumer releases and beat 22 simultaneously replaces beat 21.
        before_in = input_count;
        before_out = output_count;
        before_simultaneous = simultaneous_count;
        drive(1'b1, 8'h21, 1'b0, 1'b0);
        #1;
        check(s_ready_o === 1'b1,
              "empty buffer did not accept the beat that encountered a pause");
        check(m_valid_o === 1'b1 && m_data_o === 8'h21 && m_last_o === 1'b0,
              "paused beat was not visible through the empty-state bypass");
        @(posedge clk);
        drive(1'b1, 8'h22, 1'b1, 1'b1);
        #1 check(s_ready_o === 1'b1,
                 "release cycle did not permit simultaneous drain/refill");
        check(m_valid_o === 1'b1 && m_data_o === 8'h21 && m_last_o === 1'b0,
              "release cycle did not present the older buffered beat first");
        @(posedge clk); #1;
        check(m_valid_o === 1'b1 && m_data_o === 8'h22 && m_last_o === 1'b1,
              "refill beat did not replace the drained beat");
        check(input_count == before_in + 2 && output_count == before_out + 1,
              "one-cycle pause did not absorb one beat and release the older beat");
        check(simultaneous_count == before_simultaneous + 1,
              "pause release did not perform one drain/refill");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;
        check(output_count == before_out + 2 && m_valid_o === 1'b0,
              "one-cycle-pause sequence did not drain the replacement beat");

        // 5. Long backpressure: the empty slot first absorbs beat 31.  Beat 32
        // is then held by the producer while the stored output remains stable.
        drive(1'b1, 8'h31, 1'b0, 1'b0);
        #1 check(s_ready_o === 1'b1,
                 "empty buffer did not absorb the first backpressured beat");
        @(posedge clk);
        for (i = 0; i < 4; i = i + 1) begin
            drive(1'b1, 8'h32, 1'b1, 1'b0);
            #1 check(s_ready_o === 1'b0,
                     "upstream was not backpressured while the one slot was full");
            @(posedge clk); #1;
            check(m_valid_o === 1'b1 && m_data_o === 8'h31 && m_last_o === 1'b0,
                  "stored output changed during long backpressure");
        end

        // 6. Explicit simultaneous drain/refill after the long stall.
        before_in = input_count;
        before_out = output_count;
        before_simultaneous = simultaneous_count;
        drive(1'b1, 8'h32, 1'b1, 1'b1);
        #1 check(s_ready_o === 1'b1,
                 "full buffer did not become ready when its output drained");
        @(posedge clk); #1;
        check(input_count == before_in + 1 && output_count == before_out + 1,
              "release edge did not accept input and output together");
        check(simultaneous_count == before_simultaneous + 1,
              "simultaneous drain/refill was not observed");
        check(m_valid_o === 1'b1 && m_data_o === 8'h32 && m_last_o === 1'b1,
              "new beat was not retained after simultaneous drain/refill");
        drive(1'b0, 8'h00, 1'b0, 1'b1);
        @(posedge clk); #1;

        check(input_count == output_count,
              "test ended with missing, duplicate, or undrained beats");
        check(m_valid_o === 1'b0, "buffer was not empty at test end");
        if (errors != 0)
            $fatal(1, "rv_register_slice: %0d error(s)", errors);
        $display("PASS: rv_register_slice directed checks passed (%0d transfers)",
                 output_count);
        $finish;
    end

    initial begin
        repeat (200) @(posedge clk);
        $fatal(1, "rv_register_slice global timeout");
    end
endmodule
