`timescale 1ns/1ps

module axis_fifo_tb;
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
    integer cycle = 0;
    integer sent = 0;
    integer received = 0;
    integer saw_full = 0;
    integer saw_empty_after_data = 0;
    integer expected_count = 0;
    logic [31:0] expected_data [0:255];
    logic        expected_last [0:255];
    logic        stalled;
    logic [31:0] stalled_data;
    logic        stalled_last;
    integer phase;

    axis_fifo dut (.*);

    always #5 clk = ~clk;

    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR at cycle %0d: %0s", cycle, message);
            errors = errors + 1;
        end
    endtask

    // Inputs change away from the sampling edge, making the handshake easy
    // to inspect in a waveform and avoiding testbench/DUT race conditions.
    always @(negedge clk) begin
        if (rst) begin
            s_axis_tvalid <= 1'b0;
            m_axis_tready <= 1'b0;
        end else begin
            case (phase)
                0: begin // six beats, receiver always ready
                    m_axis_tready <= 1'b1;
                    s_axis_tvalid <= (sent < 6);
                end
                1: begin // forty beats, deterministic pseudo-random ready
                    m_axis_tready <= ((cycle % 5) != 1) && ((cycle % 7) != 3);
                    s_axis_tvalid <= (sent < 46);
                end
                default: begin
                    s_axis_tvalid <= 1'b0;
                    m_axis_tready <= 1'b1;
                end
            endcase
            if (s_axis_tvalid)
                s_axis_tdata <= 32'h1000_0000 + sent;
            s_axis_tlast <= (s_axis_tvalid && ((sent % 4) == 3));
        end
    end

    // Scoreboard samples handshakes and output data before the DUT NBA update.
    always @(posedge clk) begin : monitor
        logic push_now;
        logic pop_now;
        logic [31:0] out_data_now;
        logic out_last_now;
        cycle = cycle + 1;
        push_now = s_axis_tvalid && s_axis_tready;
        pop_now = m_axis_tvalid && m_axis_tready;
        out_data_now = m_axis_tdata;
        out_last_now = m_axis_tlast;

        if (rst) begin
            expected_count = 0;
            sent = 0;
            received = 0;
            stalled = 1'b0;
        end else begin
            if (push_now) begin
                expected_data[expected_count] = s_axis_tdata;
                expected_last[expected_count] = s_axis_tlast;
                expected_count = expected_count + 1;
                sent = sent + 1;
            end

            if (pop_now) begin
                if (expected_count == 0) begin
                    fail("output transfer occurred while scoreboard was empty");
                end else begin
                    if (out_data_now !== expected_data[0])
                        fail("data ordering or data value mismatch");
                    if (out_last_now !== expected_last[0])
                        fail("TLAST mismatch");
                    for (integer i = 0; i < 255; i = i + 1) begin
                        expected_data[i] = expected_data[i+1];
                        expected_last[i] = expected_last[i+1];
                    end
                    expected_count = expected_count - 1;
                    received = received + 1;
                end
            end

            if (m_axis_tvalid && !m_axis_tready) begin
                if (stalled && (m_axis_tdata !== stalled_data ||
                                m_axis_tlast !== stalled_last))
                    fail("output data/TLAST changed while backpressured");
                stalled = 1'b1;
                stalled_data = m_axis_tdata;
                stalled_last = m_axis_tlast;
            end else begin
                stalled = 1'b0;
            end

            if (dut.occupancy > 4)
                fail("occupancy exceeded FIFO depth");
            if (dut.occupancy == 4)
                saw_full = 1;
            if ((received != 0) && (dut.occupancy == 0))
                saw_empty_after_data = 1;
            if (dut.occupancy == 4 && s_axis_tready)
                fail("TREADY asserted while FIFO was full");
            if (dut.occupancy == 0 && m_axis_tvalid)
                fail("TVALID asserted while FIFO was empty");
        end
    end

    initial begin
        $dumpfile("axis_fifo.vcd");
        $dumpvars(0, axis_fifo_tb);

        // Two synchronous reset cycles.
        repeat (2) @(posedge clk);
        @(negedge clk) rst = 1'b0;
        #1;
        if (m_axis_tvalid !== 1'b0)
            fail("FIFO is not empty after reset");

        phase = 0;
        wait (sent == 6);
        phase = 1;
        wait (sent == 46);

        // Drain the remaining beats, then verify empty behavior.
        phase = 2;
        repeat (12) @(posedge clk);
        if (expected_count != 0)
            fail("FIFO did not drain to empty");
        if (m_axis_tvalid !== 1'b0)
            fail("TVALID remained high after FIFO drained");
        if (received != 46)
            fail("not all transmitted beats were received");
        if (!saw_full)
            fail("test never reached FIFO full");
        if (!saw_empty_after_data)
            fail("test never observed FIFO empty after transfers");

        if (errors == 0)
            $display("PASS: AXI-Stream FIFO checks passed (%0d beats)", received);
        else
            $display("FAIL: %0d error(s)", errors);
        $finish;
    end
endmodule
