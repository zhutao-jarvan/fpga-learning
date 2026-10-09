# AXI-Stream FIFO 完整追踪与 SVA 学习记录 - 2026-10-09

## 本次阶段目标

本次从“能观察波形”推进到“能根据时钟边沿、握手信号和 RTL 状态转移解释 FIFO 行为”，并加入第一条简单的 SystemVerilog Assertion（SVA）。

涉及文件：

- `rtl/fifo/axis_fifo.sv`
- `verification/tb/axis_fifo_tb.sv`

## 1. 完整追踪一个 beat

以 `32'h1000_0001`、`TLAST=0` 的 beat 为例：

- `40 ns` 下降沿：testbench 生成输入激励，设置 `s_axis_tvalid=1`、`m_axis_tready=1`，并准备 `s_axis_tdata=32'h1000_0001`；
- `45 ns` 上升沿紧左侧：`s_axis_tvalid/s_axis_tready=1/1`，因此发生 push；同时输出侧也发生 pop，传输旧队头 `0`；
- `45 ns` 上升沿：`data_mem[1] <= s_axis_tdata` 被执行；
- `45 ns` 上升沿紧右侧：由于非阻塞赋值在 NBA 阶段更新，`data_mem[1]` 才可见为 `32'h1000_0001`，状态从 `occupancy/wr_ptr/rd_ptr=1/1/0` 变为 `1/2/1`；
- `55 ns` 上升沿紧左侧：`m_axis_tvalid/m_axis_tready=1/1`，队头为 `32'h1000_0001`，发生 pop。

关键时序规则：判断某个上升沿是否握手，使用上升沿紧左侧的 `valid && ready`；上升沿右侧观察的是非阻塞赋值更新后的状态。未复位的 `data_mem` 槽位在写入前可以是 `X`，这不影响 FIFO，因为有效性由 `occupancy` 和 `m_axis_tvalid` 管理。

## 2. occupancy 四种情况

`case ({push, pop})` 对应以下状态转移：

| push | pop | occupancy | wr_ptr | rd_ptr |
|---|---|---|---|---|
| 0 | 0 | 保持 | 保持 | 保持 |
| 1 | 0 | 加 1 | 前进 | 保持 |
| 0 | 1 | 减 1 | 保持 | 前进 |
| 1 | 1 | 保持 | 前进 | 前进 |

观察到的代表性边沿：

- `25 ns`：无 push、无 pop，状态保持 `0/0/0`；
- `35 ns`：只有 push，状态从 `0/0/0` 变为 `1/1/0`，写入 `data_mem[0]`；
- `185 ns`：只有 pop，状态从 `4/2/2` 变为 `3/2/3`，输出队头 `32'h1000_000A`；
- `45 ns`：同时 push 和 pop，状态从 `1/1/0` 变为 `1/2/1`，旧队头被输出，新 beat 写入 `data_mem[1]`。

## 3. 指针回绕与空满歧义

- `wr_ptr` 在 `65 ns` 从 `3` 回绕到 `0`，本拍写入 `data_mem[3]`；
- 回绕后下一次 push 写入 `data_mem[0]`；
- `rd_ptr` 在 `75 ns` 从 `3` 回绕到 `0`，本拍 pop `data_mem[3]`，之后队头由 `data_mem[0]` 提供。

指针是 2 位，因此 `2'b11 + 1'b1` 只保留低 2 位，结果为 `2'b00`。固定的 4 个槽位被循环复用，构成环形缓冲区。

仅凭 `wr_ptr == rd_ptr` 不能判断空或满：

- `30 ns`：`wr_ptr=rd_ptr=0`、`occupancy=0`，FIFO 为空；
- `175 ns`：`wr_ptr=rd_ptr=2`、`occupancy=4`，FIFO 已满。

本设计通过 `occupancy` 消除歧义：`occupancy=0` 产生 `m_axis_tvalid=0`，`occupancy=4` 产生 `s_axis_tready=0`。

## 4. 满载边界的吞吐限制

在 `185 ns` 上升沿紧左侧观察到：

```text
occupancy                         = 4
s_axis_tvalid/s_axis_tready      = 1/0
s_axis_tdata/push                 = 32'h1000_000E/0
m_axis_tvalid/m_axis_tready      = 1/1
m_axis_tdata/pop                  = 32'h1000_000A/1
wr_ptr/rd_ptr                     = 2/2
```

输出侧具备 pop 条件，但输入侧没有接受等待中的 beat。原因是当前 RTL 使用：

```systemverilog
s_axis_tready = (occupancy < DEPTH);
```

它只查看当前 `occupancy`，没有把同一拍即将发生的 `pop` 纳入 ready 判断。因此该拍状态变为 `occupancy=3`、`rd_ptr=3`、`wr_ptr` 保持不变，等待中的输入 beat 要到下一拍才可能被接受。这是当前实现的一个吞吐限制，尚未在本次练习中修改 RTL。

## 5. 第一个 SVA：输出反压期间保持稳定

在 `verification/tb/axis_fifo_tb.sv` 中加入：

```systemverilog
property p_output_stable_while_stalled;
    @(posedge clk) disable iff (rst)
        m_axis_tvalid && !m_axis_tready
        |=> $stable({m_axis_tvalid, m_axis_tdata, m_axis_tlast});
endproperty

a_output_stable_while_stalled:
    assert property (p_output_stable_while_stalled)
    else fail("SVA: output changed while backpressured");
```

含义：在每个上升沿采样；复位期间关闭检查；如果当前拍 `m_axis_tvalid=1` 且 `m_axis_tready=0`，则下一个上升沿采样到的 `m_axis_tvalid`、`m_axis_tdata` 和 `m_axis_tlast` 必须稳定不变。

在约 `105 ns` 观察到输出 `1/0/32'h1000_0006/0`，下一个上升沿仍为相同值，SVA 的 `$stable` 条件成立。即使下一拍 `ready` 变为 1，等待中的 beat 也必须先以原值完成握手，之后 FIFO 才能推进队头并改变输出。

## VCS 结果

使用独立的 `vcs_sva_build/` 构建目录运行 VCS，生成波形：

- FSDB：`vcs_sva_build/axis_fifo_sva.fsdb`
- 日志：`vcs_sva_build/sim.log`
- 结果：`PASS: AXI-Stream FIFO checks passed (46 beats)`
- SVA 未报告失败。

## 6. MMIO/CSR 预习

寄存器访问也需要明确的时序阶段：

1. 请求：主设备提出地址、读写方向、写数据和字节使能；
2. 接受：从设备表示可以接受请求；
3. 响应：写操作返回完成状态，读操作返回数据和状态。

它与 AXI-Stream 的联系是：`valid` 表示发送方提供了有效内容，`ready` 表示接收方可以接受，`valid && ready` 在时钟上升沿完成传输；当 `valid=1、ready=0` 时，发送方必须保持正在等待的地址、控制信息或数据。区别是 MMIO/CSR 访问带有地址和读写语义，通常还需要独立响应阶段；本次暂不实现 AXI4-Lite。

## 本阶段形成的阅读方法

- 用上升沿紧左侧的 `valid/ready` 判断握手；
- 用上升沿右侧观察非阻塞赋值完成后的新状态；
- 同时对照 `push`、`pop`、`occupancy`、读写指针和存储数组；
- 反压期间先确认输出 beat 保持稳定，再分析 ready 何时恢复；
- 指针相等必须结合 occupancy 或空满标志判断，不能单独解释为空或满；
- 用简单 SVA 把已通过波形理解的协议规则固化为自动检查。

