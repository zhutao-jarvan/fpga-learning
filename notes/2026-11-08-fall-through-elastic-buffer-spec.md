# 单槽 Fall-through Elastic Buffer - 2026-11-08

## 完成结论

阶段 4 的首项练习确定为固定 8-bit data、1-bit last 的单槽 fall-through
elastic buffer。该结构不是前向路径完全寄存的 register slice：内部为空时，输入
valid/data/last 可以组合旁路到输出，并在下游 ready 时于同一个上升沿完成输入和
输出 handshake。

若空状态下游不 ready，buffer 仍接受输入并在上升沿将该 beat 保存到唯一槽位。
满状态反压期间必须保持输出 valid/data/last；释放反压时允许输出旧 beat 并接收
替代 beat，使状态保持满并维持每拍一笔的吞吐。

用户独立完成 RTL，首先识别 TB 原先只接受“输出来自更早入队数据”的假设不适用于
fall-through 行为，并参与重新对齐验收边界。随后定位并修复 FULL 状态的反压条件，
再补齐组合输出默认赋值并统一 `always_comb` 的阻塞赋值。最终 VCS directed TB
通过 13 笔事务，用户已在 Verdi 中观察并理解全部关键波形区间。

## 验收边界

- 同步高有效复位后内部为空、输出无效、输入可接受；
- 空且下游 ready 时支持零延迟同拍旁路，不留下内部积压；
- 空且下游反压时可吸收一笔，之后必须向上游反压；
- 满且下游反压时不得覆盖或改变已保存的 data/last；
- 满且下游 ready 时支持纯 drain 或 simultaneous drain/refill；
- 连续无反压流量每拍完成一笔输入和一笔输出，无非预期气泡；
- 所有已接受 beat 不丢失、不重复、不乱序，last 始终与对应 data 配对；
- 任一上升沿计入输入和输出 handshake 后，累计积压量只能为 0 或 1。

## TB 调整

Scoreboard 在同一采样沿先记录被接受的输入，再检查被接受的输出。这样 EMPTY
状态允许本拍输入成为本拍输出；FULL 状态 simultaneous drain/refill 时，数组中
更早的 beat 仍先被检查，因此不会放松顺序要求。

满速场景期望八笔流量的八个采样沿都同时发生输入和输出 handshake，内部保持空。
一拍停顿场景期望唯一槽位吸收一笔，下一拍下游恢复时输出旧 beat 并接收新 beat。
长时间反压场景继续检查输入反压和输出稳定性。

## 验证与波形证据

`make rv_fallthrough_elastic_buffer_sim` 最终报告：

```text
PASS: rv_fallthrough_elastic_buffer directed checks passed (13 transfers)
```

TB 覆盖复位、单笔零延迟旁路、连续八拍满速传输、一拍输出停顿、长时间反压、
反压期间 valid/data/last 稳定，以及 FULL 状态 simultaneous drain/refill。用户已在
Verdi 中检查并理解 40–45 ns 的单笔旁路、60–145 ns 的满速流量、150–175 ns 的
一拍停顿及替换，以及 180–245 ns 的长反压和释放。

本结论只覆盖当前 directed 场景和 RTL 仿真；尚未进行综合、STA、lint、形式验证或
随机流量验证。

## 工程模式复盘

该设计是单槽 fall-through elastic buffer：空状态使用组合旁路获得零额外流水延迟，
下游停顿时用一个寄存槽取得数据所有权，满状态则通过 ready 向上游传播反压。团队会
在低延迟和少量突发吸收优先、且组合时序路径可接受的 ready/valid 边界使用这种模式。

核心不变量是累计积压只能为 0 或 1；输出 stall 时 valid/data/last 必须保持；FULL
状态只有当前输出被接受时才能接收替代 beat；data 与 last 始终作为一个 payload；
同拍输入输出时必须保持 FIFO 顺序。最常见的错误是把 FULL 状态的 ready 条件写反、
反压时覆盖旧数据、scoreboard 禁止合法的 same-edge bypass，以及组合逻辑缺省赋值
不完整而推断 latch。

权衡是前向 bypass 和反向 ready 都保留组合路径，虽然无反压时可以零延迟且每拍一笔，
但它并不能像完全寄存的 register slice 那样切断前向时序路径，也不能像双槽 skid
buffer 那样注册反压路径。生产实现通常还会增加参数化 payload、协议断言、lint、
随机/形式验证，并结合综合与 STA 决定是否允许组合路径。

在网络数据通路中，该模式可用于模块边界、短暂停顿吸收、包处理级之间的轻量解耦，
其中 `last` 对应包尾元数据；更宽接口还会把 keep/empty/error 等元数据与 data 一起
保持。下一项将对比前向寄存的 register slice 和双槽 skid buffer，理解时序切分与
额外存储槽之间的关系。
