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

    // 实例化语法： module_name [#(parameter_values)] instance_name (port_connections);
    // '(.*)': 将被实例化模块的端口，与当前作用域中同名的信号自动连接。
    axis_fifo dut (.*);

    // 第一个 always 过程块：无限重复执行后面的语句。
    // #5：延迟 5 个仿真时间单位。
    // = ： 阻塞赋值
    always #5 clk = ~clk;

    // 创建一个可以重复被调用的 task （类似于软件的函数）
    task automatic fail(input [1023:0] message);
        begin
            $display("ERROR at cycle %0d: %0s", cycle, message);
            errors = errors + 1;
        end
    endtask

    // Once the output is stalled, the presented beat must remain unchanged.
    // 以下代码块含义(property此处是对信号在多个时钟采样点之间应该满足的关系进行描述。
    //      p_output_stable_while_stalled 是属性名称)：
    // - @(posedge clk)：只在每个上升沿采样；
    // - disable iff (rst)：禁用并终止该属性当前正在进行的检查；其中 iff = if and only if （当且仅当）
    // - 左侧：本拍输出有效但未被接收；
    // - |=> 称为 non-overlapped implication（非重叠蕴含）；
    //     前件 |=> 后件
    //     如果本次上升沿前件成立，那么在下一个上升沿检查后件。
    //   注意： a |-> b  表示重叠蕴含：从当前采样周期开始检查 b
    // - $stable(...)：三个信号拼接后比较每个周期是否一致
    property p_output_stable_while_stalled;
        @(posedge clk) disable iff (rst)
            m_axis_tvalid && !m_axis_tready
            |=> $stable({m_axis_tvalid, m_axis_tdata, m_axis_tlast});
    endproperty

    a_output_stable_while_stalled:
        assert property (p_output_stable_while_stalled)
        else fail("SVA: output changed while backpressured");

    property p_valid_occupancy;
        @(posedge clk) disable iff(rst)
            !rst |-> (dut.occupancy <= 3'd4);
    endproperty

    a_valid_occupancy:
        assert property (p_valid_occupancy)
        else fail("SVA: invalid occupancy value");

    // Inputs change away from the sampling edge, making the handshake easy
    // to inspect in a waveform and avoiding testbench/DUT race conditions.
    // 第二个 always 过程块：下降沿产生下一次上升沿需要的 pop & push 和测试数据激励
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
    // ': monitor' 是给 ‘begin ... end’ 的语句块命名，方便仿真器查看波形
    // 第三个 always 过程块：上升沿执行 Scoreboard
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
            if (dut.occupancy == 4 && !pop_now && s_axis_tready)
                fail("TREADY asserted while FIFO was full but no pop");
            if (dut.occupancy == 0 && m_axis_tvalid)
                fail("TVALID asserted while FIFO was empty");
        end
    end

    // 第四个过程块(initial)：
    initial begin
        // '$name(arguments);' 表示： 表示调用一个仿真器提供的系统任务或系统函数。
        // 正式 VCS/Verdi 流程用 ENABLE_FSDB 生成 FSDB；未定义时保留 VCD fallback。
        `ifdef ENABLE_FSDB
            string fsdb_file;
            fsdb_file = "axis_fifo.fsdb";
            // 可用 +fsdbfile=name.fsdb 覆盖默认文件名，便于不同 testcase 隔离波形。
            $value$plusargs("fsdbfile=%s", fsdb_file);
            $fsdbDumpfile(fsdb_file);
            $fsdbDumpvars(0, axis_fifo_tb);
            $fsdbDumpMDA();
        `else
            // VCD 是跨工具 fallback；本学习流程的波形分析优先使用 FSDB/Verdi。
            $dumpfile("axis_fifo.vcd");
            $dumpvars(0, axis_fifo_tb);
        `endif

        // Two synchronous reset cycles.
        // repeat 的一般语法是：
        //      repeat (次数表达式)
        //          statement;
        // @ 可以理解为：暂停当前过程，直到指定事件发生，然后继续执行后面的语句。
        repeat (2) @(posedge clk); // 等待两个上升沿
        @(negedge clk) rst = 1'b0; // 下降沿清零rst后等 1ns
        #1;
        if (m_axis_tvalid !== 1'b0)
            fail("FIFO is not empty after reset");

        // 前 6 连续 beat 属于 phase 0
        phase = 0;
        wait (sent == 6);
        phase = 1;
        // 中 40 非连续beat 属于 phase 1，测试反压
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
