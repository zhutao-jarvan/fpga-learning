`timescale 1ns/1ps

// From-scratch exercise: minimal 8-bit, 4-entry asynchronous FIFO.
//
// Reset contract for this exercise:
// - wr_rst and rd_rst are synchronous, active high in their own domains;
// - the two domains are reset together under system control;
// - no transfer is attempted until both resets have been released;
// - independent reset recovery and reset CDC are intentionally unsupported.
//
// Read interface contract: FWFT/show-ahead.
// When rd_valid_o is 1, rd_data_o already presents the oldest FIFO word.
// If rd_ready_i is 0, rd_valid_o and rd_data_o must remain stable.  A word is
// consumed only at an rd_clk rising edge with rd_valid_o && rd_ready_i.
module async_fifo (
    input  logic       wr_clk,
    input  logic       wr_rst,
    input  logic       wr_valid_i,
    input  logic [7:0] wr_data_i,
    output logic       wr_ready_o,

    input  logic       rd_clk,
    input  logic       rd_rst,
    output logic       rd_valid_o,
    output logic [7:0] rd_data_o,
    input  logic       rd_ready_i
);
    localparam integer DEPTH      = 4;
    localparam integer ADDR_WIDTH = 2;
    localparam integer PTR_WIDTH  = ADDR_WIDTH + 1;

    logic [7:0] mem [0:DEPTH-1];

    // Keep these names: the directed TB and later Verdi work observe them.
    logic [PTR_WIDTH-1:0] wr_bin;   // wr domain
    logic [PTR_WIDTH-1:0] wr_gray;  // wr domain
    logic [PTR_WIDTH-1:0] rd_bin;
    logic [PTR_WIDTH-1:0] rd_gray;

    logic [PTR_WIDTH-1:0] rd_gray_sync_ff1_wr;
    logic [PTR_WIDTH-1:0] rd_gray_sync_ff2_wr;  // wr domain
    logic [PTR_WIDTH-1:0] wr_gray_sync_ff1_rd;
    logic [PTR_WIDTH-1:0] wr_gray_sync_ff2_rd;

    logic wr_full;
    logic rd_empty;
    logic wr_accept;
    logic rd_accept;

    assign wr_gray = wr_bin ^ (wr_bin >> 1);
    assign rd_gray = rd_bin ^ (rd_bin >> 1);

    always_comb begin : wr_full_block
        // 满的时候，对于FIFO本身，write指针应该快read指针一圈
        // binary 最高位不等，低位相等 表示满
        // gray对应关系是： wr_gray 与 rd_gray_sync_ff2_wr 的高两位取反，低位相等
        if (~rd_gray_sync_ff2_wr[PTR_WIDTH-1:PTR_WIDTH-2] == wr_gray[PTR_WIDTH-1:PTR_WIDTH-2]
            && rd_gray_sync_ff2_wr[ADDR_WIDTH-2:0] == wr_gray[ADDR_WIDTH-2:0]) begin
            wr_full    = 1'b1;
            wr_ready_o = 1'b0;
        end else begin
            wr_full    = 1'b0;
            wr_ready_o = 1'b1;
        end
    end

    // Write domain responsibilities:
    // - derive acceptance from wr_valid_i and local not-full state;
    // - on acceptance, write mem at the CURRENT binary write address;
    // - advance the binary pointer and its Gray representation once;
    // - continuously synchronize the remote Gray read pointer through two
    //   wr_clk registers, regardless of whether a write is attempted;
    // - calculate/register full using the candidate next write pointer.

    assign wr_accept = wr_valid_i & wr_ready_o;
    always_ff @(posedge wr_clk) begin : write_block
        if (wr_rst) begin
            wr_bin              <=   '0;
            rd_gray_sync_ff1_wr <=   '0;
            rd_gray_sync_ff2_wr <=   '0;
        end else begin
            if (wr_accept) begin
                wr_bin <= wr_bin + PTR_WIDTH'(1);
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data_i;
            end

            rd_gray_sync_ff1_wr <= rd_gray;
            rd_gray_sync_ff2_wr <= rd_gray_sync_ff1_wr;
        end
    end

    // Read domain responsibilities:
    // - expose the current memory slot with FWFT valid/data semantics;
    // - advance the binary pointer and its Gray representation only when a
    //   valid word is accepted by the reader;
    // - continuously synchronize the remote Gray write pointer through two
    //   rd_clk registers, regardless of whether a read is attempted;
    // - calculate/register empty using the candidate next read pointer.
    always_comb begin : rd_empty_block
        // 最高位不等，低位相等
        if (rd_gray == wr_gray_sync_ff2_rd) begin
            rd_empty   = 1'b1;
            rd_valid_o = 1'b0;
            rd_data_o  = 8'b0;
        end else begin
            rd_empty   = 1'b0;
            rd_valid_o = 1'b1;
            rd_data_o  = mem[rd_bin[ADDR_WIDTH-1:0]];
        end
    end


    assign rd_accept = rd_valid_o & rd_ready_i;
    always_ff @(posedge rd_clk) begin : read_block
        if (rd_rst) begin
            rd_bin              <=   '0;
            wr_gray_sync_ff1_rd <=   '0;
            wr_gray_sync_ff2_rd <=   '0;
        end else begin
            if (rd_accept) begin
                rd_bin <= rd_bin + PTR_WIDTH'(1);
            end

            wr_gray_sync_ff1_rd <= wr_gray;
            wr_gray_sync_ff2_rd <= wr_gray_sync_ff1_rd;
        end
    end

endmodule
