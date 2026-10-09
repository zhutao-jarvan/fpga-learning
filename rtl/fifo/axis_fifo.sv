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
    /* 用户写入FIFO的时候，确定哪些Data是一个group的
     * @last_mem 用来逻辑上切断 stream */
    logic        last_mem [0:DEPTH-1];
    logic [1:0]  wr_ptr;
    logic [1:0]  rd_ptr;
    logic [2:0]  occupancy; /* 表示 FIFO 中的有效数据数量 */

    wire push = s_axis_tvalid && s_axis_tready;
    wire pop  = m_axis_tvalid && m_axis_tready;

    // 这一段组合逻辑只是用来表示数据关系，数据 push & pop 由时序逻辑控制
    always_comb begin
        // 只要FIFO没满或者确定会发生pop, @s_axis_tready 就一直拉高，表示可写
        if (occupancy < DEPTH)
            s_axis_tready = 1'b1;
        else begin
           // occupancy == DEPTH
           if (pop)
                s_axis_tready = 1'b1;
           else
                s_axis_tready = 1'b0;
        end

        // 只要FIFO没空, @m_axis_tvalid 就一直拉高，表示可读 */
        m_axis_tvalid = (occupancy != 0);

        // Drive a benign value while empty; it is ignored because valid is 0.
        if (m_axis_tvalid) begin
            // 输出当前有效数据
            m_axis_tdata = data_mem[rd_ptr];
            m_axis_tlast = last_mem[rd_ptr];
        end else begin
            // 无数据输出，设置全0
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
                // 存入一个数据，且写指针后移
                data_mem[wr_ptr] <= s_axis_tdata;
                last_mem[wr_ptr] <= s_axis_tlast;
                wr_ptr           <= wr_ptr + 1'b1;
            end

            if (pop)
                rd_ptr <= rd_ptr + 1'b1; // 读指针后移

            // update 有效数据计数; push & pop & update 都是同步执行的
            case ({push, pop})
                2'b10: occupancy <= occupancy + 1'b1;
                2'b01: occupancy <= occupancy - 1'b1;
                default: occupancy <= occupancy;
            endcase
        end
    end
endmodule
