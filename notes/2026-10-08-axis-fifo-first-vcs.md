# AXI-Stream FIFO 首次 VCS 学习记录 - 2026-10-08

## 本次完成

- 阅读 `rtl/fifo/axis_fifo.sv` 和 `verification/tb/axis_fifo_tb.sv`；
- 为 RTL 和 testbench 添加学习注释，并提交为 `5542bcc9576f1e5226fa61300536344f323736ca`；
- 在 VCS 服务器上完成第一次 VCS 仿真；
- 开始理解 SystemVerilog testbench 的过程模型、事件控制和 scoreboard。

## VCS 结果

日志文件：`vcs_build/sim.log`

- VCS 版本：W-2024.09-SP1_Full64；
- 结果：`PASS: AXI-Stream FIFO checks passed (46 beats)`；
- 仿真时间：`765000 ps`；
- testbench 正常执行 `$finish`，没有报告错误。

## 已理解的 SystemVerilog 语法

- `axis_fifo dut (.*);` 是按名称自动连接端口；它不负责参数覆盖；
- `always #5 clk = ~clk` 产生 100 MHz 仿真时钟，属于 testbench 行为；
- `task automatic fail(...)` 是可重复调用的用户任务，`automatic` 使每次调用拥有独立局部存储；
- `$dumpfile`、`$dumpvars`、`$display`、`$finish` 是系统任务；`$time`、`$clog2` 等属于系统函数；
- `repeat` 是语言循环语句；`@(posedge/negedge signal)` 是事件控制，不是函数调用；
- `!==` 是四态不全等比较，会把 `X/Z` 也视为不相等；
- `begin : monitor` 创建命名代码块和层次作用域；`monitor` 不是 `$monitor`；
- `initial` 和 `always` 块是并行仿真进程，同一过程块中的语句按顺序执行；没有时延控制时，连续语句通常发生在同一仿真时刻；
- testbench 不等同于 RTL。RTL 通常指可综合的 DUT，testbench 通常是不可综合的验证代码。

## 已理解的验证结构

当前 testbench 中的 `monitor` 块同时承担多个角色：

- 在输入握手时保存预期的 `TDATA/TLAST`；
- 在输出握手时检查数据值、顺序、丢失、重复和 `TLAST`；
- 检查 backpressure 期间输出数据稳定；
- 检查 occupancy、full/empty 和基本覆盖情况。

这属于 scoreboard、monitor 和协议 checker 的组合。Scoreboard 是验证工程模式，不是 SystemVerilog 语言结构。

## Verdi 波形分析已完成

在 Verdi 中加入并观察了以下信号：

- `clk`、`rst`；
- 输入侧 `s_axis_tvalid/tready/tdata/tlast`；
- 输出侧 `m_axis_tvalid/tready/tdata/tlast`；
- `dut.occupancy`、`dut.wr_ptr`、`dut.rd_ptr`。

### 1. reset 后 FIFO 为空

- 本设计使用高电平同步复位，`wr_ptr`、`rd_ptr` 和 `occupancy` 只在
  `rst=1` 的时钟上升沿被清零；
- reset 释放后的状态为 `occupancy=0`、`wr_ptr=0`、`rd_ptr=0`；
- `occupancy=0` 使 `m_axis_tvalid=0`，所以存储阵列中即使残留旧值，
  也不会被当作有效 AXI-Stream beat；
- 清空 FIFO 不要求擦除 `data_mem`，有效性由 FIFO 状态管理。

### 2. 正常传输中的 push 和 pop

- 第 4 个时钟上升沿只发生第一次 push；上升沿后 `occupancy` 从 0 变为 1，
  `m_axis_tvalid` 才随之变为 1；
- 第 5 个时钟上升沿紧左侧，输入和输出两侧的 valid/ready 都为 1，
  因而同一拍发生 push 和 pop；
- 该拍 pop 出 `32'h0000_0000`，同时 push 进 `32'h1000_0001`；
- 状态从 `occupancy/wr_ptr/rd_ptr = 1/1/0` 变为 `1/2/1`：一进一出，
  occupancy 不变，两个指针各前移一次；
- 同拍 push 和 pop 操作不同的 FIFO 位置，输出是原有队头，输入是新 beat。

### 3. 输出反压期间保持稳定

- 约 `105 ns` 时观察到 `m_axis_tvalid/m_axis_tready = 1/0`；
- 该拍没有 pop，`rd_ptr` 保持为 2；输入侧仍可 push，因此状态从
  `occupancy/wr_ptr/rd_ptr = 1/3/2` 变为 `2/0/2`；
- FIFO 队头为 `32'h1000_0006/0`，在上升沿前后保持不变；
- 接收端未接受 beat 时，发送端必须保留同一个 `TDATA/TLAST`，直到一次
  `TVALID && TREADY` 握手完成。

### 4. FIFO 满时产生输入反压

- 约 `165 ns` 时，状态从 `occupancy/wr_ptr/rd_ptr = 3/1/2` 变为 `4/2/2`；
- 上升沿前还有一个空槽，`s_axis_tvalid/s_axis_tready = 1/1`，所以
  `32'h1000_000d/0` 成功 push；
- 上升沿后 `occupancy=4`，组合逻辑立即使 `s_axis_tready=0`；
- FIFO 通过拉低 ready 告诉输入侧上游暂时不能接收新 beat，避免覆盖
  尚未输出的数据。

### 5. 最后一个 TLAST beat

- 约 `655 ns` 上升沿紧左侧，`m_axis_tvalid/m_axis_tready = 1/1`，
  `m_axis_tdata/m_axis_tlast = 32'h1000_002b/1`；
- 该上升沿完成 TLAST beat 的传输和 pop；
- 上升沿后 `rd_ptr` 从 3 回绕到 0，`occupancy` 从 3 降为 2，输出随即显示
  下一个队头 `32'h1000_002c/0`；
- `TLAST` 是随数据传输的报文边界标志，不是 FIFO 清空或复位命令。

## 今天形成的波形阅读方法

- 判断一次传输，先看时钟上升沿紧左侧的 `TVALID && TREADY`；
- 上升沿右侧显示的是时序逻辑通过非阻塞赋值更新后的新状态；
- 不要用上升沿右侧刚变化的 valid/ready，反推刚过去的上升沿发生了握手；
- 同时对照 `occupancy` 和读写指针，可以区分 push、pop、同时 push/pop 和停顿；
- data 使用 32 位 hexadecimal 显示，并展开 Value 列，避免高位被界面遮挡；
- 指针相等本身不能判断 FIFO 空或满，本设计由 `occupancy` 区分状态。

## 下次学习建议

下一次继续用“观察一个场景、先回答、再获得提示”的方式，从波形阅读推进到
testbench 与 RTL 的对应关系。建议依次完成：

1. 追踪一个 beat 从 testbench 产生、push 入 FIFO、存入 `data_mem`，再到 pop 输出；
2. 对照 `push`、`pop` 和 `case ({push, pop})`，解释 occupancy 的四种更新情况；
3. 观察读写指针从 3 回绕到 0，确认环形缓冲区行为；
4. 解释当前实现满状态下即使同拍可以 pop，为什么该拍仍不能同时接收新 push；
5. 如时间允许，开始把已观察的协议规则写成简单 SystemVerilog assertion。

### 下次会话提示词

```text
请继续指导我学习 AXI-Stream FIFO。昨天我已经用 Verdi 完成第一次 VCS 波形分析，
理解了同步 reset、valid/ready 握手、同时 push/pop、输出反压、FIFO 满反压、
指针回绕和 TLAST 传输。最重要的规则是：用时钟上升沿紧左侧的 valid/ready
判断握手，上升沿右侧是非阻塞赋值更新后的新状态。

今天请仍然采用“每次只观察一个场景 -> 让我报告时间、握手、数据、occupancy、
读写指针和我的解释 -> 如果不完整先问引导问题”的方式，不要直接给完整答案。

当前文件：
- rtl/fifo/axis_fifo.sv
- verification/tb/axis_fifo_tb.sv

请按以下顺序指导我：
1. 完整追踪一个 beat 从 testbench 激励到 push、存储，再到 pop 输出；
2. 用波形验证 occupancy 在 push/pop 四种组合下的变化；
3. 观察 wr_ptr 和 rd_ptr 从 3 回绕到 0；
4. 分析当前 FIFO 满时不能在同一拍 pop+push 的吞吐限制；
5. 如果前面理解正确，再介绍一个最简单的 AXI-Stream 稳定性 assertion，暂时不要引入 UVM。

请从第 1 个场景开始，只告诉我要加入或定位哪些信号，然后等待我的观察结果。
```

## 备注

本日志合并了用户从另一个会话提供的 QA 摘要。不同 ChatGPT/Codex 会话之间不会自动共享对话记录；后续应将重要的问答摘要或波形观察结果贴回当前会话或写入仓库。
