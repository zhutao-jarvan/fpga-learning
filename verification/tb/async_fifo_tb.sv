`timescale 1ns/1ps

module async_fifo_tb;
    logic       wr_clk = 1'b0;
    logic       wr_rst = 1'b1;
    logic       wr_valid_i = 1'b0;
    logic [7:0] wr_data_i = 8'h00;
    logic       wr_ready_o;

    logic       rd_clk = 1'b0;
    logic       rd_rst = 1'b1;
    logic       rd_valid_o;
    logic [7:0] rd_data_o;
    logic       rd_ready_i = 1'b0;

    integer errors = 0;
    integer wr_accept_count = 0;
    integer rd_accept_count = 0;
    integer rejected_write_count = 0;
    integer rejected_read_edges = 0;
    logic [7:0] expected_data [0:63];
    logic monitor_enabled = 1'b0;
    logic previous_stall = 1'b0;
    logic [7:0] previous_stall_data = 8'h00;

    async_fifo dut (.*);

    // Unrelated clocks: 8 ns write period, 10 ns read period.
    always #4 wr_clk = ~wr_clk;
    always #5 rd_clk = ~rd_clk;

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            $display("ERROR at %0t: %s", $time, message);
            errors = errors + 1;
        end
    endtask

    task automatic write_word(input logic [7:0] data);
        integer waited;
        begin
            waited = 0;
            @(negedge wr_clk);
            while (wr_ready_o !== 1'b1 && waited < 40) begin
                waited = waited + 1;
                @(negedge wr_clk);
            end
            if (wr_ready_o !== 1'b1)
                $fatal(1, "timeout waiting for write ready");
            wr_valid_i = 1'b1;
            wr_data_i = data;
            @(posedge wr_clk);
            check(wr_ready_o === 1'b1, "write task did not reach an acceptance edge");
            @(negedge wr_clk);
            wr_valid_i = 1'b0;
        end
    endtask

    task automatic read_word;
        integer waited;
        begin
            waited = 0;
            @(negedge rd_clk);
            rd_ready_i = 1'b1;
            while (rd_valid_o !== 1'b1 && waited < 40) begin
                waited = waited + 1;
                @(negedge rd_clk);
            end
            if (rd_valid_o !== 1'b1)
                $fatal(1, "timeout waiting for read valid");
            @(posedge rd_clk);
            check(rd_valid_o === 1'b1, "read task did not reach an acceptance edge");
            @(negedge rd_clk);
            rd_ready_i = 1'b0;
        end
    endtask

    // Small ordered reference list: every accepted write is appended and every
    // accepted read is compared with the next entry.  No random/UVM machinery.
    always @(posedge wr_clk) begin : write_monitor
        if (monitor_enabled && !wr_rst) begin
            check(wr_ready_o === 1'b0 || wr_ready_o === 1'b1,
                  "wr_ready_o is X/Z");
            if (wr_valid_i && wr_ready_o) begin
                expected_data[wr_accept_count] = wr_data_i;
                wr_accept_count = wr_accept_count + 1;
            end else if (wr_valid_i && !wr_ready_o) begin
                rejected_write_count = rejected_write_count + 1;
            end
        end
    end

    always @(posedge rd_clk) begin : read_monitor
        if (monitor_enabled && !rd_rst) begin
            check(rd_valid_o === 1'b0 || rd_valid_o === 1'b1,
                  "rd_valid_o is X/Z");
            // Compare edge-visible values.  If the previous edge saw valid
            // without ready, the same item must still be offered at this edge.
            if (previous_stall) begin
                check(rd_valid_o === 1'b1,
                      "FWFT valid dropped while reader applied backpressure");
                check(rd_data_o === previous_stall_data,
                      "FWFT data changed while reader applied backpressure");
            end
            if (rd_valid_o && rd_ready_i) begin
                check(rd_accept_count < wr_accept_count,
                      "read accepted without an earlier accepted write");
                check(rd_data_o === expected_data[rd_accept_count],
                      "read data was lost, duplicated, corrupted or reordered");
                rd_accept_count = rd_accept_count + 1;
            end else if (!rd_valid_o && rd_ready_i) begin
                rejected_read_edges = rejected_read_edges + 1;
            end
            previous_stall = rd_valid_o && !rd_ready_i;
            previous_stall_data = rd_data_o;
        end
    end

    initial begin : directed_test
        integer count_before;
        integer waited;
        integer concurrent_start;

        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "async_fifo.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, async_fifo_tb);
        `else
            $dumpfile("async_fifo.vcd");
            $dumpvars(0, async_fifo_tb);
        `endif

        // Assert both synchronous resets across several edges in both domains.
        repeat (3) @(posedge wr_clk);
        repeat (2) @(posedge rd_clk);
        #1;
        check(wr_ready_o === 1'b1, "FIFO must be writable after reset");
        check(rd_valid_o === 1'b0, "FIFO must not be readable after reset");
        check(dut.wr_bin === 3'b000 && dut.wr_gray === 3'b000,
              "write pointers did not reset to zero");
        check(dut.rd_bin === 3'b000 && dut.rd_gray === 3'b000,
              "read pointers did not reset to zero");
        check({dut.rd_gray_sync_ff1_wr, dut.rd_gray_sync_ff2_wr,
               dut.wr_gray_sync_ff1_rd, dut.wr_gray_sync_ff2_rd} === 12'b0,
              "pointer synchronizer stages did not reset to zero");
        check(dut.wr_full === 1'b0 && dut.rd_empty === 1'b1,
              "full/empty reset state is wrong");
        if (errors != 0)
            $fatal(1, "reset checks failed; implement the async FIFO core TODOs first");

        // Controlled joint release; traffic starts only after both are low.
        fork
            begin @(negedge wr_clk); #1 wr_rst = 1'b0; end
            begin @(negedge rd_clk); #1 rd_rst = 1'b0; end
        join
        monitor_enabled = 1'b1;

        // Empty-side rejection: ready alone must not consume anything.
        count_before = rd_accept_count;
        @(negedge rd_clk) rd_ready_i = 1'b1;
        repeat (2) @(posedge rd_clk);
        @(negedge rd_clk) rd_ready_i = 1'b0;
        check(rd_accept_count == count_before, "empty read changed the read count");

        // One write, delayed visibility in the read domain, FWFT stability, read.
        write_word(8'hA5);
        check(rd_valid_o === 1'b0,
              "empty cleared without remote-pointer synchronization delay");
        waited = 0;
        while (rd_valid_o !== 1'b1 && waited < 10) begin
            waited = waited + 1;
            @(posedge rd_clk);
            #1;
        end
        check(rd_valid_o === 1'b1 && rd_data_o === 8'hA5,
              "first word did not become visible through FWFT");
        repeat (2) @(posedge rd_clk);
        #1;
        check(rd_valid_o === 1'b1 && rd_data_o === 8'hA5,
              "FWFT word was not held during backpressure");
        read_word();
        @(posedge rd_clk);
        #1;
        check(rd_valid_o === 1'b0, "FIFO did not become empty after only word was read");

        // Fill all four slots, reject a fifth write, release one slot, refill it.
        write_word(8'h10);
        write_word(8'h11);
        write_word(8'h12);
        write_word(8'h13);
        #1;
        check(wr_ready_o === 1'b0, "four accepted writes did not make FIFO full");
        count_before = wr_accept_count;
        @(negedge wr_clk);
        wr_valid_i = 1'b1;
        wr_data_i = 8'hDE;
        @(posedge wr_clk);
        #1;
        check(wr_accept_count == count_before,
              "write was accepted while FIFO was full");
        @(negedge wr_clk) wr_valid_i = 1'b0;

        read_word();
        check(wr_ready_o === 1'b0,
              "full cleared immediately without read-pointer synchronization");
        waited = 0;
        while (wr_ready_o !== 1'b1 && waited < 10) begin
            waited = waited + 1;
            @(posedge wr_clk);
            #1;
        end
        check(wr_ready_o === 1'b1,
              "write side did not observe the released slot");
        write_word(8'h14);
        repeat (4) read_word();

        // More than two complete address cycles proves both pointers wrap.
        repeat (10) begin
            write_word(8'h40 + (wr_accept_count & 8'h1f));
            read_word();
        end

        // Concurrent producer/consumer with periodic read backpressure.
        concurrent_start = wr_accept_count;
        fork
            begin : producer
                integer i;
                for (i = 0; i < 12; i = i + 1)
                    write_word(8'h80 + i);
            end
            begin : consumer
                integer target;
                integer cycle;
                target = rd_accept_count + 12;
                cycle = 0;
                while (rd_accept_count < target) begin
                    @(negedge rd_clk);
                    rd_ready_i = ((cycle % 3) != 0);
                    cycle = cycle + 1;
                end
                rd_ready_i = 1'b0;
            end
        join
        check(wr_accept_count == concurrent_start + 12,
              "concurrent producer did not deliver all words");
        check(rd_accept_count == wr_accept_count,
              "concurrent traffic ended with missing or duplicate words");

        repeat (5) @(posedge rd_clk);
        #1;
        check(rd_valid_o === 1'b0, "FIFO not empty after final drain");
        check(rejected_write_count >= 1, "full-write rejection was not exercised");
        check(rejected_read_edges >= 1, "empty-read rejection was not exercised");
        if (errors != 0)
            $fatal(1, "async_fifo: %0d error(s)", errors);
        $display("PASS: async_fifo directed checks passed (%0d transfers)",
                 rd_accept_count);
        $finish;
    end

    initial begin
        repeat (1000) @(posedge rd_clk);
        $fatal(1, "async_fifo global timeout");
    end
endmodule
