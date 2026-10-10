`timescale 1ns/1ps

// Minimal directed testbench for the packet-state FSM inside axis_fifo.
module axis_fifo_fsm_tb;
    logic        clk = 1'b0;
    logic        rst = 1'b1;
    logic [31:0] s_axis_tdata = 32'b0;
    logic        s_axis_tlast = 1'b0;
    logic        s_axis_tvalid = 1'b0;
    logic        s_axis_tready;
    logic [31:0] m_axis_tdata;
    logic        m_axis_tlast;
    logic        m_axis_tvalid;
    logic        m_axis_tready = 1'b0;

    integer errors = 0;

    axis_fifo dut (.*);

    always #5 clk = ~clk;

    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR: %0s", message);
            errors = errors + 1;
        end
    endtask

    initial begin
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "axis_fifo_fsm.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, axis_fifo_fsm_tb);
        `else
            $dumpfile("axis_fifo_fsm.vcd");
            $dumpvars(0, axis_fifo_fsm_tb);
        `endif

        // Synchronous reset: hold rst high for two rising edges.
        repeat (2) @(posedge clk);

        // Set up one non-last input beat away from the sampling edge.
        @(negedge clk);
        rst            = 1'b0;
        s_axis_tvalid  = 1'b1;
        s_axis_tlast   = 1'b0;
        s_axis_tdata   = 32'h1234_5678;

        if (dut.state != 0)
            fail("dut.state != IDLE");

        // This is the target rising edge: push should be 1 here.
        @(posedge clk);
        #1;

        // TODO: Add checks for the target transition.
        // Check that the input handshake occurred and that the FSM is now
        // in IN_PACKET after accepting a beat with s_axis_tlast=0.
        // Use fail("...") for a failed check.  Do not add a second packet
        // scenario yet.
        if (dut.push == 0)
            fail("Push == 0");
        if (dut.handshake == 0)
            fail("Handshake == 0");
        if (s_axis_tlast != 0)
            fail("s_axis_tlast != 0");
        // IN_PACKET == 1
        if (dut.state != 1)
            fail("dut.state != IN_PACKET");

        // waiting a negedge
        @(negedge clk);
        s_axis_tvalid = 1'b0;
        s_axis_tlast = 1'b1;

        #3;
        // check stable
        if (dut.push != 0)
            fail("1 Push != 0");
        if (dut.handshake != 0)
            fail("1 Handshake != 0");
        // IN_PACKET == 1
        if (dut.state != 1)
            fail("1 dut.state != IN_PACKET");

        @(posedge clk);
        #1;
        if (dut.state != 1)
            fail("1 dut.state != IN_PACKET");

        if (errors == 0)
            $display("PASS: directed FSM transition check passed");
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
