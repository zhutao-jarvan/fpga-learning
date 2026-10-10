# AXI-Stream FIFO 吞吐修改与 FSM 入门补充 - 2026-10-09

## FIFO 满载同拍 pop+push

在原有 `s_axis_tready = (occupancy < DEPTH)` 的实现中，FIFO 满载时即使输出侧本拍会 pop，输入侧仍不能 push，因此会产生一个输入吞吐 bubble。

修改后的 ready 条件允许：

```text
occupancy < DEPTH              -> ready=1
occupancy == DEPTH && pop=1    -> ready=1
occupancy == DEPTH && pop=0    -> ready=0
```

在 `185 ns` 上升沿观察到：

```text
occupancy: 4 -> 4
wr_ptr:    2 -> 3
rd_ptr:    2 -> 3
push=1, pop=1
s_axis_tdata = 32'h1000_000E
m_axis_tdata = 32'h1000_000A
```

新 beat 写入刚刚被消费的槽位，之后在第 4 个 pop 输出；中间三个 beat 的顺序保持不变。VCS 通过：

```text
PASS: AXI-Stream FIFO checks passed (46 beats)
```

新增/保留的检查包括输出反压稳定性 SVA、occupancy 上界 SVA，以及满载且没有 pop 时不得拉高 ready 的定向检查。

## FSM 入门练习

为输入 stream 增加了一个暂不参与 FIFO 数据通路的学习用 FSM：

- `IDLE`：尚未进入一个多 beat packet；
- `IN_PACKET`：已经接收非 TLAST beat，等待 packet 结束。

当前组合状态转换使用 `push` 作为 handshake 条件：

- `IDLE + push + tlast=0 -> IN_PACKET`；
- `IDLE + push + tlast=1 -> IDLE`；
- `IN_PACKET + push + tlast=1 -> IDLE`；
- 没有 push 时保持状态。

状态寄存器使用同步高有效复位：`rst=1` 在时钟上升沿进入 `IDLE`，否则 `state <= next_state`。下一步仍需在波形中观察一个状态转换场景，并清理行尾空格/确认最终仿真。

## 学习节奏反馈

原先估计 FSM/同步复位小练习需要 10–15 分钟不准确。实际时间还包括：首次接触枚举状态和两段式 FSM 结构、作用域/声明错误、handshake 条件修正、同步状态寄存器接入，以及多轮波形和代码 review。

后续调整：

1. 对新语法或新结构，先安排一个最小可综合示例和 20–30 分钟理解/修改窗口，不再把完整练习压缩为 10–15 分钟。
2. 用户已经通过波形、断言或解释确认的知识点，记录为已确认；后续只在出现新代码风险时复查，不重复要求同一结论。
3. 每次只保留一个当前场景，但允许同一场景有“代码实现 → 编译 → 波形 → 解释”多个阶段，并明确阶段边界。
4. 六个月计划的每周 10–15 小时继续作为基准投入，不作为硬截止日期。阶段完成以交付物和独立解释为准；新概念首次练习应按实际耗时动态调整，不用日历月份推断进度。
