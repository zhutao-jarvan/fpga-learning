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

    // Write domain responsibilities:
    // - derive acceptance from wr_valid_i and local not-full state;
    // - on acceptance, write mem at the CURRENT binary write address;
    // - advance the binary pointer and its Gray representation once;
    // - continuously synchronize the remote Gray read pointer through two
    //   wr_clk registers, regardless of whether a write is attempted;
    // - calculate/register full using the candidate next write pointer.

    assign wr_accept = wr_valid_i && wr_ready_o;

    // next-state 将状态决策放在寄存器前完成，让时钟沿只负责提交结果；这样状态与事务边界对齐，
    //            对外输出更干净，同时为寄存、流水化和时序优化提供了清晰切分点。
    // next state of write block
    logic wr_full_next;
    logic [PTR_WIDTH-1:0] wr_bin_next;   // wr domain
    logic [PTR_WIDTH-1:0] wr_gray_next;  // wr domain
    assign wr_bin_next  = wr_bin + wr_accept;
    assign wr_gray_next = wr_bin_next ^ (wr_bin_next >> 1);
    assign wr_ready_o = !wr_full;

    always_comb begin : wr_full_block
        // 满的时候，对于FIFO本身，write指针应该快read指针一圈
        // binary 最高位不等，低位相等 表示满
        // gray对应关系是： wr_gray 与 rd_gray_sync_ff2_wr 的高两位取反，低位相等
        // wr_gray             next state is wr_gray_next
        if (~rd_gray_sync_ff2_wr[PTR_WIDTH-1:PTR_WIDTH-2] == wr_gray_next[PTR_WIDTH-1:PTR_WIDTH-2]
            && rd_gray_sync_ff2_wr[ADDR_WIDTH-2:0] == wr_gray_next[ADDR_WIDTH-2:0]) begin
            wr_full_next    = 1'b1;
        end else begin
            wr_full_next    = 1'b0;
        end
    end

    always_ff @(posedge wr_clk) begin : write_block
        if (wr_rst) begin
            wr_bin              <=   '0;
            wr_gray             <=   '0;
            rd_gray_sync_ff1_wr <=   '0;
            rd_gray_sync_ff2_wr <=   '0;
            wr_full             <= 1'b0;
        end else begin
            if (wr_accept) begin
                wr_bin                      <= wr_bin_next;
                wr_gray                     <= wr_gray_next;
                mem[wr_bin[ADDR_WIDTH-1:0]] <= wr_data_i;
            end

            rd_gray_sync_ff1_wr <= rd_gray;
            rd_gray_sync_ff2_wr <= rd_gray_sync_ff1_wr;
            wr_full             <= wr_full_next; // wr_accept and read gray cdc update it
        end
    end

    // Read domain responsibilities:
    // - expose the current memory slot with FWFT valid/data semantics;
    // - advance the binary pointer and its Gray representation only when a
    //   valid word is accepted by the reader;
    // - continuously synchronize the remote Gray write pointer through two
    //   rd_clk registers, regardless of whether a read is attempted;
    // - calculate/register empty using the candidate next read pointer.

    assign rd_accept = rd_valid_o && rd_ready_i;
    // next state of read block
    logic rd_empty_next;
    logic [PTR_WIDTH-1:0] rd_bin_next;   // rd domain
    logic [PTR_WIDTH-1:0] rd_gray_next;  // rd domain
    assign rd_bin_next  = rd_bin + rd_accept;
    assign rd_gray_next = rd_bin_next ^ (rd_bin_next >> 1);

    always_comb begin : rd_empty_next_stat
        // rd_gray             next state is rd_gray_next
        if (rd_gray_next == wr_gray_sync_ff2_rd) begin
            rd_empty_next   = 1'b1;
        end else begin
            rd_empty_next   = 1'b0;
        end
    end

    always_comb begin : rd_empty_block
        if (rd_empty) begin
            rd_valid_o = 1'b0;
            rd_data_o  = 8'b0;
        end else begin
            rd_valid_o = 1'b1;
            rd_data_o  = mem[rd_bin[ADDR_WIDTH-1:0]];
        end
    end

    always_ff @(posedge rd_clk) begin : read_block
        if (rd_rst) begin
            rd_bin              <=   '0;
            rd_gray             <=   '0;
            wr_gray_sync_ff1_rd <=   '0;
            wr_gray_sync_ff2_rd <=   '0;
            rd_empty            <= 1'b1;
        end else begin
            if (rd_accept) begin
                rd_bin      <= rd_bin_next;
                rd_gray     <= rd_gray_next;
            end

            rd_empty            <= rd_empty_next;
            wr_gray_sync_ff1_rd <= wr_gray;
            wr_gray_sync_ff2_rd <= wr_gray_sync_ff1_rd;
        end
    end

endmodule
