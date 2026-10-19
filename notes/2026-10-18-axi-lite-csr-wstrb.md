# AXI4-Lite CSR WSTRB 部分写 - 2026-10-18

## 本次目标

为 CTRL 写路径增加最小 `WSTRB` 语义，并用一个 directed 场景验证完整写、部分
byte lane 更新和 CTRL 读回。现有 driver、场景选择和握手计数器保持不变。

## Review 结论与实现

原 RTL 虽然接收了 `s_axi_wstrb` 端口，但没有保存或使用它；完成 AW/W 后直接执行
`ctrl_rw <= wdata`，因此部分写会错误覆盖所有四个 byte lane。

本次增加：

- 保存 W handshake 时的 `s_axi_wstrb`；
- 组合生成 `ctrl_write_data`，以当前 `ctrl_rw` 为基础，按 `wstrb[i]` 选择性替换
  `wdata[i*8 +: 8]`；
- 只有合法 CTRL 地址形成写请求时，才将合并结果写入 `ctrl_rw`。

## `wstrb` 场景

1. 使用 `WSTRB=4'b1111` 将 CTRL 初始化为 `32'hCAFE_123A`；
2. 使用 `WDATA=32'hBEEF_5678`、`WSTRB=4'b0101`；
3. 检查 B handshake 和 `BRESP=OKAY`；
4. 检查 byte lane 2 和 0 更新、lane 3 和 1 保留，结果为
   `32'hCAEF_1278`；
5. 通过 CTRL 读回再次检查结果和 R handshake 后接口恢复。

第一次仿真暴露的是 checker 期望值错误：`WDATA=32'hBEEF_5678` 的 lane 2 是
`8'hEF`，不是 `8'hBE`。修正期望值后场景通过。

## 仿真证据

`wstrb` 场景：

```text
PASS: AXI LITE CSR checks passed (15 cycles)
```

最新 RTL/TB 回归全部通过：`aw_first` 9、`w_first` 10、`aw_w_parallel` 7、
`b_backpressure` 9、`read_ctrl` 11、`r_backpressure` 12、`read_status` 8、
`w_badaddr` 15 cycles。

对应波形文件为 `vcs_build/axi_lite_csr_tb/wstrb.fsdb`。Verdi 验收时应观察：
W handshake 上保存 `wdata=BEEF_5678` 和 `wstrb=0101`；CTRL 更新时 lane 2/0
取新值、lane 3/1 保持旧值；B handshake 返回 OKAY；随后读回 `CAEF_1278`。

用户已完成 Verdi 时序确认：两次 W handshake 分别发生在 45 ns 和 85 ns，
`wdata`/`wstrb` 在对应 W handshake 时保存；两次 B handshake 分别发生在 65 ns
和 105 ns；`ctrl_rw` 分别在 55 ns 和 95 ns 更新。第二次 W handshake 后，
`ctrl_write_data` 在 85 ns 上升沿的非阻塞赋值更新完成后由 `CAFE_123A` 变为
`CAEF_1278`：`WSTRB=0101` 使 lane 2 (`EF`) 和 lane 0 (`78`) 采用新数据，
lane 3/1 保留旧值。后续 CTRL 读回 `CAEF_1278`。

## 工程模式复盘

- 模式：byte-enable 写入，也称 write strobe 或 byte-lane masking。
- 解决的问题：软件对 32-bit CSR 中单个字段或 byte lane 更新时，避免破坏同一寄存器
  中其他字段。
- 关键不变量：未置位的 strobe lane 必须保持旧值；写使能仍受地址译码约束；WSTRB
  必须与 WDATA 在同一次 W handshake 中保存。
- 常见错误：把 WSTRB 当作 bit mask 而不是 byte mask；lane 编号和大小端方向弄反；
  在 W handshake 前直接使用 master 输入；非法地址仍修改寄存器。
- 教学版省略：未实现字段级权限、保留位策略、WSTRB 非法组合报告、并发 outstanding
  和寄存器副作用。
- 网络场景：驱动更新 MAC、队列、计数器控制 CSR 中的单个字段时，WSTRB 提供与
  总线宽度匹配的局部写语义。

## 当前第一个问题

本轮首个问题是 TB checker 将 `32'hBEEF_5678` 的 lane 2 误读为 `BE`；日志在
cycle 11 首先报告 CTRL 期望值错误。结合 WDATA 的 byte 分解修正为 `EF` 后，仿真
和回归均通过。
