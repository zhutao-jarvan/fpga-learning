# AXI4-Lite CSR TB 重构与 B 反压 - 2026-10-12

## 学习目标

在不修改 RTL、不引入 UVM 的前提下，把最小 AXI4-Lite CSR 写路径 testbench
整理成可继续扩展的 directed-test 结构，并通过波形理解 AW/W 并行、B 通道
反压以及握手后的资源释放。

## 已完成内容

- 删除 `wrq_phase` 驱动方式，保证每个 AXI master 输入只有一个 driver。
- 将场景编排与通道 driver 分离；保留 `drive_aw`、`drive_w`、`accept_b`、
  `reset_dut`、`check` 和 `fail` 等小 task。
- 使用 `fork...join` 同时产生 AW/W 激励，确认 AW 和 W 可以同周期独立握手，
  不必等待一个通道完成后才启动另一个通道。
- 完成 B 通道反压 directed 场景：`BREADY=0` 保持两个完整周期，检查
  `BVALID`、`BRESP`、`AWREADY` 和 `WREADY`，再完成 B handshake。
- 在 B handshake 后检查 `BVALID` 清零、`AWREADY/WREADY` 恢复，以及 `ctrl_rw`
  的写入结果。
- 将场景提取为 `run_aw_first`、`run_aw_w_parallel` 和 `run_b_backpressure`，
  通过 `+scenario=<name>` 每次只运行一个场景，减少波形和失败日志的歧义。
- Makefile 增加 `AXI_CSR_SCENARIO` 参数，并按场景生成独立 FSDB 和仿真日志。

## 波形和仿真证据

已在 Verdi 中观察到：

- AW-first 场景中 AW 先握手，W 随后握手，收齐后产生 B 响应。
- AW/W 并行场景中两个请求通道可以在同一周期握手。
- `BREADY=0` 时，`BVALID` 和 `BRESP` 保持，`AWREADY/WREADY` 保持低电平。
- B handshake 上升沿后，DUT 清除 `waddr_valid`、`wdata_valid`，`wstate` 回到
  `W_IDLE`，随后 `BVALID` 清零且 `AWREADY/WREADY` 恢复。

三个独立场景均通过轻量仿真检查：

```text
aw_first       PASS (9 cycles)
aw_w_parallel  PASS (7 cycles)
b_backpressure PASS (9 cycles)
```

`git diff --check` 通过。当前环境的 VCS wrapper 在 Make 执行期间仍报告
`/bin/sh: 0: Illegal option -h`；VCS/Verdi 生产流程的最终复跑需要在 wrapper
正常的环境确认，轻量仿真仅作为补充检查。

## 本次理解

1. AW 和 W 是独立的 AXI4-Lite 请求通道，testbench 可以并行驱动而不制造不必要的
   等待气泡。
2. VALID 侧必须保持 VALID 和 payload，直到对应的 VALID/READY handshake 上升沿。
3. BREADY 低电平时，slave 已声明响应有效但尚未完成传输，因此 BVALID/BRESP 必须
   保持稳定，且当前单事务 RTL 不应继续接收新的 AW/W。
4. handshake 完成后，DUT 的时序状态先释放保存的地址/数据，组合输出随后恢复 READY。
5. directed TB 可以保留多个场景，但通过 plusarg 每次只运行一个场景，更利于波形、
   日志和失败定位。

## 当前边界与下一步

AW/W/B 写路径的本次 directed-TB 子目标已完成，但阶段 2 仍未完成。尚未覆盖：

- W-first 对称场景；
- 合法/非法地址和 RO 写保护；
- WSTRB 部分写；
- AR/R 读路径及 RREADY 反压。

进入 AR/R 代码练习前，先通过问答确认本次 driver、scenario、monitor、checker、
timeout 和 ready/valid 时序理解。确认后再实现最小读路径，并继续保持一次只运行
一个明确场景的 TB 结构。

## AR/R 前理解确认

通过 10 个问题确认了以下内容：

- 能识别 channel driver 的信号所有权，并说明 monitor 只观察、不产生激励；
- 能解释 AW/W 独立握手以及 `waddr_valid`、`wdata_valid` 对独立存储槽的表示；
- 能解释 B 反压期间 `BVALID/BRESP` 的稳定要求，以及单 outstanding 设计关闭
  `AWREADY/WREADY` 的原因；
- 能按时序状态更新、组合输出重算的顺序解释 B handshake 后的资源释放；
- 理解 NBA 更新造成的采样时机问题、全局 timeout 的用途，以及单场景仿真对
  握手计数和故障定位的帮助。

需要继续强化的工程表述：未完成事务期间错误接收下一笔请求，通常描述为
“覆盖未完成事务的保存槽”或“违反单 outstanding 约束”；READY 是由组合逻辑
反映内部资源是否可用，不是被单独释放的时序状态。综合判断：当前 AW/W/B 子目标
理解合格，可以进入 AR/R 读路径。
