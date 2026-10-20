`timescale 1ns/1ps

// Transfer discrete source-domain events into a destination clock domain.
// A source pulse toggles persistent state; the destination synchronizes that
// state and detects each observed change as a one-dst-clock pulse.
module pulse_toggle_sync (
    input  logic src_clk,
    input  logic src_rst,
    input  logic src_pulse_i,

    input  logic dst_clk,
    input  logic dst_rst,
    output logic dst_pulse_o
);
    // Keep these names for directed checks and Verdi observation.
    logic src_toggle;
    logic dst_sync_ff1;
    logic dst_sync_ff2;
    logic dst_sync_ff2_d;

    // TODO (user): implement the complete minimal toggle synchronizer.
    //
    // Source domain:
    // - synchronous active-high src_rst clears src_toggle;
    // - each src_pulse_i sampled high toggles src_toggle exactly once.
    //
    // Destination domain:
    // - synchronous active-high dst_rst clears all three destination registers;
    // - dst_sync_ff1/dst_sync_ff2 form the two-flop synchronizer;
    // - dst_sync_ff2_d stores the previous synchronized toggle value;
    // - dst_pulse_o is high when the current and delayed synchronized values differ.
    //
    // Use nonblocking assignments in clocked logic. Do not synchronize the
    // source pulse directly and do not use dst_sync_ff1 in functional logic.

    always_ff @(posedge src_clk) begin : src_toggle_pulse
        if (src_rst)
            src_toggle <= 1'b0;
        else begin
            if (src_pulse_i)
                src_toggle <= ~src_toggle;
        end
    end

    assign dst_pulse_o = dst_sync_ff2 ^ dst_sync_ff2_d;

    always_ff @(posedge dst_clk) begin : dest_async_pulse
        if (dst_rst) begin
            dst_sync_ff1   <= 1'b0;
            dst_sync_ff2   <= 1'b0;
            dst_sync_ff2_d <= 1'b0;
        end else begin
            dst_sync_ff1   <= src_toggle;
            dst_sync_ff2   <= dst_sync_ff1;
            dst_sync_ff2_d <= dst_sync_ff2;
        end
    end

endmodule
