`timescale 1ns/1ps

module bit_sync_tb;
    logic clk     = 1'b0;
    logic rst     = 1'b1;
    logic async_i = 1'b0;
    logic sync_o;

    integer errors = 0;
    time last_clk_posedge;
    logic monitor_output_updates = 1'b0;

    bit_sync dut (.*);

    always #5 clk = ~clk;

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

    always @(posedge clk)
        last_clk_posedge = $time;

    // A registered destination-domain output may change only at a clk edge.
    always @(sync_o) begin
        if (monitor_output_updates && ($time != last_clk_posedge))
            fail("sync_o changed away from a target-clock rising edge");
    end

    initial begin
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "bit_sync.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, bit_sync_tb);
        `else
            $dumpfile("bit_sync.vcd");
            $dumpvars(0, bit_sync_tb);
        `endif

        // Synchronous reset: values are checked after target-clock edges.
        repeat (2) @(posedge clk);
        #1;
        check(dut.sync_ff1 === 1'b0, "stage 1 did not reset to 0");
        check(sync_o      === 1'b0, "output did not reset to 0");
        monitor_output_updates = 1'b1;
        @(negedge clk) rst = 1'b0;

        // A long high level is sampled by stage 1, then by stage 2 one edge later.
        async_i = 1'b1;
        @(posedge clk);
        #1;
        check(dut.sync_ff1 === 1'b1, "stage 1 did not sample high async_i");
        check(sync_o      === 1'b0, "sync_o changed before the second sample edge");
        @(posedge clk);
        #1;
        check(sync_o      === 1'b1, "sync_o did not become 1 after two sample edges");

        // The same two-stage delay applies when the stable level returns low.
        @(negedge clk) async_i = 1'b0;
        @(posedge clk);
        #1;
        check(dut.sync_ff1 === 1'b0, "stage 1 did not sample low async_i");
        check(sync_o      === 1'b1, "sync_o changed before the second low sample edge");
        @(posedge clk);
        #1;
        check(sync_o      === 1'b0, "sync_o did not become 0 after two sample edges");

        // A pulse wholly between two rising edges is not guaranteed to be seen.
        #1 async_i = 1'b1;
        #2 async_i = 1'b0;
        @(posedge clk);
        #1;
        check(dut.sync_ff1 === 1'b0, "stage 1 unexpectedly captured the short pulse");
        check(sync_o      === 1'b0, "sync_o unexpectedly captured the short pulse");
        @(posedge clk);
        #1;
        check(sync_o      === 1'b0, "short pulse propagated to sync_o");

        if (errors == 0)
            $display("PASS: bit_sync directed checks passed");
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end

    initial begin
        repeat (30) @(posedge clk);
        fail("global timeout");
        $finish;
    end
endmodule
