`timescale 1ns/1ps

// From-scratch exercise: one outstanding bundled-data transfer with toggle req/ack.
// Both domains use synchronous active-high reset and must be reset together.
// No traffic until both resets are released. Destination always accepts a pulse.
module multibit_handshake_cdc (
    input  logic       src_clk,
    input  logic       src_rst,
    input  logic       src_valid_i,
    input  logic [7:0] src_data_i,
    output logic       src_ready_o,

    input  logic       dst_clk,
    input  logic       dst_rst,
    output logic       dst_valid_o,
    output logic [7:0] dst_data_o
);
    // Keep these names for the directed TB and Verdi observation.
    logic [7:0] src_payload_hold;
    logic       src_req_toggle;
    logic       dst_req_ff1;
    logic       dst_req_ff2;
    logic       dst_ack_toggle;
    logic       src_ack_ff1;
    logic       src_ack_ff2;

    // TODO (user): write the core RTL after predicting one transaction.
    //
    // Source domain:
    // - reset payload, request and both ack synchronizer stages to zero;
    // - synchronize dst_ack_toggle through src_ack_ff1/src_ack_ff2;
    // - derive ready from local request and the returned SECOND ack stage;
    // - latch src_data_i and change request only on valid && ready;
    // - otherwise keep payload and request unchanged, including while busy.
    //
    // Destination domain:
    // - reset both request stages, ack, data and valid to zero;
    // - synchronize src_req_toggle through dst_req_ff1/dst_req_ff2;
    // - use the SECOND request stage to recognize an unacknowledged request;
    // - capture the held payload, assert registered valid and acknowledge it;
    // - valid lasts exactly one destination cycle; data holds between captures.
    //
    // Use nonblocking assignments in always_ff blocks. Stage 1 drives only
    // stage 2. Do not synchronize payload bit by bit or capture live src_data_i.
    // The source holding interval and physical data-path timing constraints
    // together ensure that all payload bits settle before destination capture.
    // This scaffold intentionally contains no drivers; compile != exercise PASS.
    
    assign src_ready_o = (src_req_toggle == src_ack_ff2);
    
    always_ff @(posedge src_clk) begin : src_domain_handshake
        if (src_rst) begin
            src_payload_hold <= 8'b0000_0000;
            src_req_toggle   <= 1'b0;
            src_ack_ff1      <= 1'b0;
            src_ack_ff2      <= 1'b0;
        end else begin 
            if (src_valid_i && src_ready_o) begin
                // TX src domain handshake req
                src_payload_hold <= src_data_i;
                src_req_toggle   <= ~src_req_toggle;
            end

            // handover 'handshake ack' from dest domain 
            src_ack_ff1      <= dst_ack_toggle;
            src_ack_ff2      <= src_ack_ff1; 
        end
    end

    always_ff @(posedge dst_clk) begin : dst_domain_handshake
        if (dst_rst) begin
            dst_data_o  <= 8'b0000_0000;

            dst_req_ff1 <= 1'b0;
            dst_req_ff2 <= 1'b0;
            dst_ack_toggle <= 1'b0;
            dst_valid_o    <= 1'b0;
        end else begin
            if (dst_req_ff2 ^ dst_ack_toggle) begin
                // New request need to handle
                dst_data_o     <= src_payload_hold;
                dst_valid_o    <= 1'b1;

                // TX dst domain handshake ack
                dst_ack_toggle <= dst_req_ff2;
            end else begin
                dst_valid_o    <= 1'b0;
            end

            // handover 'handshake req' from src domain
            dst_req_ff1 <= src_req_toggle;
            dst_req_ff2 <= dst_req_ff1;
        end
    end

endmodule
