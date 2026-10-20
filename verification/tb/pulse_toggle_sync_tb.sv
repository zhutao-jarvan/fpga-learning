`timescale 1ns/1ps

module pulse_toggle_sync_tb;
    logic src_clk     = 1'b0;
    logic src_rst     = 1'b1;
    logic src_pulse_i = 1'b0;
    logic dst_clk     = 1'b0;
    logic dst_rst     = 1'b1;
    logic dst_pulse_o;

    integer errors = 0;
    integer dst_pulse_count = 0;
    time last_dst_posedge;
    logic monitor_output_updates = 1'b0;

    pulse_toggle_sync dut (.*);

    // Deliberately unrelated clocks: source period 8 ns, destination period 10 ns.
    always #4 src_clk = ~src_clk;
    always #5 dst_clk = ~dst_clk;

    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR at %0t: %0s", $time, message);
            errors = errors + 1;
        end
    endtask

    task automatic check(input logic condition, input [1023:0] message);
        begin
            if (condition !== 1'b1)
                fail(message);
        end
    endtask

    task automatic send_src_event;
        begin
            @(negedge src_clk) src_pulse_i = 1'b1;
            @(posedge src_clk);
            @(negedge src_clk) src_pulse_i = 1'b0;
        end
    endtask

    always @(posedge dst_clk) begin
        last_dst_posedge = $time;
        if (!dst_rst && dst_pulse_o)
            dst_pulse_count = dst_pulse_count + 1;
    end

    always @(dst_pulse_o) begin
        if (monitor_output_updates && ($time != last_dst_posedge))
            fail("dst_pulse_o changed away from a destination-clock rising edge");
    end

    initial begin
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "pulse_toggle_sync.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, pulse_toggle_sync_tb);
        `else
            $dumpfile("pulse_toggle_sync.vcd");
            $dumpvars(0, pulse_toggle_sync_tb);
        `endif

        // Exercise both synchronous resets in their own clock domains.
        repeat (3) @(posedge src_clk);
        repeat (2) @(posedge dst_clk);
        #1;
        check(dut.src_toggle    === 1'b0, "src_toggle did not reset to 0");
        check(dut.dst_sync_ff1  === 1'b0, "destination stage 1 did not reset");
        check(dut.dst_sync_ff2  === 1'b0, "destination stage 2 did not reset");
        check(dut.dst_sync_ff2_d === 1'b0, "delayed destination state did not reset");
        check(dst_pulse_o       === 1'b0, "destination pulse was high after reset");
        monitor_output_updates = 1'b1;

        @(negedge src_clk) src_rst = 1'b0;
        @(negedge dst_clk) dst_rst = 1'b0;

        // First event: source toggle rises, then crosses and creates one dst pulse.
        send_src_event();
        check(dut.src_toggle === 1'b1, "first event did not toggle source state high");
        @(posedge dst_clk);
        #1;
        check(dut.dst_sync_ff1 === 1'b1, "destination stage 1 missed first toggle");
        check(dut.dst_sync_ff2 === 1'b0, "destination stage 2 changed too early");
        check(dst_pulse_o      === 1'b0, "destination pulse asserted too early");
        @(posedge dst_clk);
        #1;
        check(dut.dst_sync_ff2 === 1'b1, "destination stage 2 missed first toggle");
        check(dst_pulse_o      === 1'b1, "first destination pulse did not assert");
        @(posedge dst_clk);
        #1;
        check(dst_pulse_o      === 1'b0, "first destination pulse lasted over one cycle");

        // Second, well-separated event toggles the persistent state back low.
        send_src_event();
        check(dut.src_toggle === 1'b0, "second event did not toggle source state low");
        @(posedge dst_clk);
        #1;
        check(dut.dst_sync_ff2 === 1'b0, "destination stage 2 missed second toggle");
        check(dst_pulse_o      === 1'b1, "second destination pulse did not assert");
        @(posedge dst_clk);
        #1;
        check(dst_pulse_o      === 1'b0, "second destination pulse lasted over one cycle");
        check(dst_pulse_count  == 2, "expected two well-separated destination events");

        // Two source events before the destination observes either change cancel.
        // This deliberately violates the event-spacing requirement.
        repeat (5) @(negedge src_clk);
        src_pulse_i = 1'b1;
        repeat (2) @(posedge src_clk);
        @(negedge src_clk) src_pulse_i = 1'b0;
        check(dut.src_toggle === 1'b0, "rapid event pair did not return toggle to old value");
        repeat (3) @(posedge dst_clk);
        #1;
        check(dst_pulse_o     === 1'b0, "rapid event pair left a destination pulse high");
        check(dst_pulse_count == 2, "destination unexpectedly observed rapid event pair");

        if (errors == 0)
            $display("PASS: pulse_toggle_sync directed checks passed");
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin
        repeat (60) @(posedge dst_clk);
        fail("global timeout");
        $finish;
    end
endmodule
