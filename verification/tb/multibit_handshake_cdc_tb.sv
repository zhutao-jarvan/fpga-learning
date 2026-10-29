`timescale 1ns/1ps

module multibit_handshake_cdc_tb;
    logic       src_clk = 1'b0;
    logic       src_rst = 1'b1;
    logic       src_valid_i = 1'b0;
    logic [7:0] src_data_i = 8'h00;
    logic       src_ready_o;
    logic       dst_clk = 1'b0;
    logic       dst_rst = 1'b1;
    logic       dst_valid_o;
    logic [7:0] dst_data_o;

    integer errors = 0;
    integer src_accept_count = 0;
    integer dst_capture_count = 0;
    logic monitor_enabled = 1'b0;
    realtime last_src_posedge;
    realtime last_dst_posedge;
    logic previous_dst_valid = 1'b0;
    logic [7:0] expected_data [0:2];

    multibit_handshake_cdc dut (.*);

    // Same unrelated clock periods as the previous toggle exercise.
    always #4 src_clk = ~src_clk;
    always #5 dst_clk = ~dst_clk;

    task automatic check(input logic condition, input string message);
        if (condition !== 1'b1) begin
            $display("ERROR at %0t: %s", $time, message);
            errors = errors + 1;
        end
    endtask

    // Drive on falling edges; sample acceptance BEFORE NBA, inspect state AFTER.
    task automatic send_legal(input logic [7:0] data);
        integer waited;
        begin
            waited = 0;
            @(negedge src_clk);
            while (src_ready_o !== 1'b1 && waited < 20) begin
                waited = waited + 1;
                @(negedge src_clk);
            end
            if (src_ready_o !== 1'b1)
                $fatal(1, "timeout waiting for source ready before send");
            src_valid_i = 1'b1;
            src_data_i = data;
            @(posedge src_clk);
            check(src_ready_o === 1'b1, "legal transaction was not accepted");
            #1;
            check(src_ready_o === 1'b0, "source did not become busy after acceptance");
            check(dut.src_payload_hold === data, "source did not latch accepted payload");
            @(negedge src_clk);
            src_valid_i = 1'b0;
            // Deliberately change live input: destination must use the held copy.
            src_data_i = ~data;
        end
    endtask

    task automatic wait_for_return(input integer expected_count);
        integer waited;
        begin
            waited = 0;
            @(negedge src_clk);
            while ((src_ready_o !== 1'b1 || dst_capture_count < expected_count)
                   && waited < 20) begin
                waited = waited + 1;
                @(negedge src_clk);
            end
            if (src_ready_o !== 1'b1 || dst_capture_count < expected_count)
                $fatal(1, "timeout waiting for capture and acknowledgement return");
            check(dst_capture_count == expected_count, "wrong destination transaction count");
            check(dut.src_ack_ff2 === dut.src_req_toggle, "ready returned without matching ack");
        end
    endtask

    always @(posedge src_clk) begin : source_monitor
        logic accepted;
        logic [7:0] held_before;
        logic [7:0] input_before;
        logic req_before;
        last_src_posedge = $realtime;
        if (monitor_enabled && !src_rst) begin
            accepted = src_valid_i && src_ready_o;
            held_before = dut.src_payload_hold;
            input_before = src_data_i;
            req_before = dut.src_req_toggle;
            check(src_ready_o === 1'b0 || src_ready_o === 1'b1, "source ready is X/Z");
            if (accepted === 1'b1) begin
                src_accept_count = src_accept_count + 1;
                $display("SOURCE ACCEPT at %0t: data=%02h", $time, input_before);
            end
            #1;
            if (accepted === 1'b1) begin
                check(dut.src_payload_hold === input_before, "accepted data was not held");
                check(dut.src_req_toggle === ~req_before, "accepted request did not toggle");
            end else begin
                check(dut.src_payload_hold === held_before, "payload overwritten without acceptance");
                check(dut.src_req_toggle === req_before, "request changed without acceptance");
            end
        end
    end

    // Inspect registered destination outputs after NBA. A pulse is counted once
    // on its assertion edge; downstream logic samples it at the following edge.
    always @(posedge dst_clk) begin : destination_monitor
        logic [7:0] data_before;
        last_dst_posedge = $realtime;
        data_before = dst_data_o;
        #1;
        if (monitor_enabled && !dst_rst) begin
            check(dst_valid_o === 1'b0 || dst_valid_o === 1'b1, "destination valid is X/Z");
            if (dst_valid_o === 1'b1) begin
                check(previous_dst_valid === 1'b0, "destination valid lasted more than one cycle");
                if (dst_capture_count < 3)
                    check(dst_data_o === expected_data[dst_capture_count],
                          "destination data lost, corrupted or out of order");
                else
                    check(1'b0, "unexpected duplicate destination transaction");
                check(dut.dst_ack_toggle === dut.dst_req_ff2,
                      "destination capture did not acknowledge the observed request");
                dst_capture_count = dst_capture_count + 1;
                $display("DESTINATION CAPTURE edge=%0t: data=%02h", last_dst_posedge, dst_data_o);
            end else
                check(dst_data_o === data_before, "destination data changed without valid capture");
            previous_dst_valid = dst_valid_o;
        end
    end

    // $realtime catches even a sub-nanosecond change away from the proper edge.
    always @(src_ready_o or dut.src_payload_hold or dut.src_req_toggle
             or dut.src_ack_ff1 or dut.src_ack_ff2)
        if (monitor_enabled)
            check($realtime == last_src_posedge, "source state/output changed off source rising edge");

    always @(dst_valid_o or dst_data_o or dut.dst_ack_toggle
             or dut.dst_req_ff1 or dut.dst_req_ff2)
        if (monitor_enabled)
            check($realtime == last_dst_posedge, "destination state/output changed off destination rising edge");

    initial begin
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "multibit_handshake_cdc.fsdb";
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, multibit_handshake_cdc_tb);
        `else
            $dumpfile("multibit_handshake_cdc.vcd");
            $dumpvars(0, multibit_handshake_cdc_tb);
        `endif

        expected_data[0] = 8'hA5;
        expected_data[1] = 8'h3C;
        expected_data[2] = 8'hC3;

        // Both resets stay asserted across several edges of both clocks.
        repeat (3) @(posedge src_clk);
        repeat (2) @(posedge dst_clk);
        #1;
        check(src_ready_o === 1'b1, "source not ready after reset");
        check(dst_valid_o === 1'b0, "destination valid not zero after reset");
        check(dst_data_o === 8'h00, "destination data not zero after reset");
        check(dut.src_payload_hold === 8'h00, "held payload not zero after reset");
        check({dut.src_req_toggle, dut.dst_req_ff1, dut.dst_req_ff2,
               dut.dst_ack_toggle, dut.src_ack_ff1, dut.src_ack_ff2} === 6'b0,
              "request/ack state not zero after reset");
        if (errors != 0)
            $fatal(1, "reset checks failed; implement the core RTL TODOs first");
        monitor_enabled = 1'b1;
        // Both falling edges occur at 40 ns. Release at 41 ns to avoid a
        // same-time event-order ambiguity; the first acceptance is at 52 ns.
        fork
            begin
                @(negedge src_clk);
                #1 src_rst = 1'b0;
            end
            begin
                @(negedge dst_clk);
                #1 dst_rst = 1'b0;
            end
        join

        // Single transaction; live input changes immediately after acceptance.
        send_legal(8'hA5);

        // Deliberate one-edge attempt while busy. This attempt is withdrawn;
        // it must NOT enter the transfer. A real pending producer keeps valid
        // and data stable until a later ready/valid acceptance.
        @(negedge src_clk);
        src_valid_i = 1'b1;
        src_data_i = 8'h5A;
        @(posedge src_clk);
        check(src_ready_o === 1'b0, "busy-overwrite test did not reach a busy edge");
        #1;
        check(src_accept_count == 1, "busy attempt was accepted");
        check(dut.src_payload_hold === 8'hA5, "busy attempt overwrote first payload");
        @(negedge src_clk) src_valid_i = 1'b0;
        wait_for_return(1);

        // Two further legal transactions, waiting only for protocol readiness.
        send_legal(8'h3C);
        send_legal(8'hC3);
        wait_for_return(3);

        // Quiet tail exposes duplicate captures or a valid that stays asserted.
        repeat (5) @(posedge dst_clk);
        #2;
        check(src_accept_count == 3, "expected exactly three source acceptances");
        check(dst_capture_count == 3, "expected exactly three destination captures");
        check(src_ready_o === 1'b1, "source not ready after final acknowledgement");
        check(dst_valid_o === 1'b0, "destination valid did not return low");
        if (errors != 0)
            $fatal(1, "multibit_handshake_cdc: %0d error(s)", errors);
        $display("PASS: multibit_handshake_cdc directed checks passed (3 transfers)");
        $finish;
    end

    initial begin
        repeat (150) @(posedge dst_clk);
        $fatal(1, "multibit_handshake_cdc global timeout");
    end
endmodule
