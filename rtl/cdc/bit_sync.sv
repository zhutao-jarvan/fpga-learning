`timescale 1ns/1ps

// Minimal two-flop synchronizer for a single-bit level.
//
// async_i is not timed to clk. Both synchronizer registers must belong to the
// clk domain. This exercise intentionally uses synchronous active-high reset.
module bit_sync (
    input  logic clk,
    input  logic rst,
    input  logic async_i,
    output logic sync_o
);
    // Keep this name so the directed TB and Verdi exercise can observe stage 1.
    logic sync_ff1;

    always_ff @(posedge clk) begin : async_bit_cdc
        if (rst) begin
            sync_ff1 <= 0;
            sync_o   <= 0;
        end else begin
            sync_ff1 <= async_i;
            sync_o   <= sync_ff1;
        end
    end

endmodule
