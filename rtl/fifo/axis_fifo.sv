`timescale 1ns/1ps

// Small synchronous AXI-Stream FIFO for learning.
// Reset is synchronous and active high: state is cleared on the rising edge
// where rst is high.  A transfer happens only when valid and ready are both 1.
module axis_fifo (
    input  logic        clk,
    input  logic        rst,

    input  logic [31:0] s_axis_tdata,
    input  logic        s_axis_tlast,
    input  logic        s_axis_tvalid,
    output logic        s_axis_tready,

    output logic [31:0] m_axis_tdata,
    output logic        m_axis_tlast,
    output logic        m_axis_tvalid,
    input  logic        m_axis_tready
);
    localparam integer DEPTH = 4;

    logic [31:0] data_mem [0:DEPTH-1];
    logic        last_mem [0:DEPTH-1];
    logic [1:0]  wr_ptr;
    logic [1:0]  rd_ptr;
    logic [2:0]  occupancy; /* 表示 FIFO 中的有效数据数量 */

    wire push = s_axis_tvalid && s_axis_tready;
    wire pop  = m_axis_tvalid && m_axis_tready;

    always_comb begin
        s_axis_tready = (occupancy < DEPTH);
        m_axis_tvalid = (occupancy != 0);

        // Drive a benign value while empty; it is ignored because valid is 0.
        if (m_axis_tvalid) begin
            m_axis_tdata = data_mem[rd_ptr];
            m_axis_tlast = last_mem[rd_ptr];
        end else begin
            m_axis_tdata = 32'b0;
            m_axis_tlast = 1'b0;
        end
    end

    always_ff @(posedge clk) begin
        if (rst) begin
            wr_ptr    <= 2'b0;
            rd_ptr    <= 2'b0;
            occupancy <= 3'b0;
        end else begin
            if (push) begin
                data_mem[wr_ptr] <= s_axis_tdata;
                last_mem[wr_ptr] <= s_axis_tlast;
                wr_ptr           <= wr_ptr + 1'b1;
            end

            if (pop)
                rd_ptr <= rd_ptr + 1'b1;

            case ({push, pop})
                2'b10: occupancy <= occupancy + 1'b1;
                2'b01: occupancy <= occupancy - 1'b1;
                default: occupancy <= occupancy;
            endcase
        end
    end
endmodule
