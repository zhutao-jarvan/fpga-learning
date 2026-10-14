# AXI4-Lite CSR 读反压与事务释放 - 2026-10-14

## 本次目标与结果

用户在现有 driver/scenario/monitor/checker 结构中完成独立的
`r_backpressure` 场景：先用 AW/W/B 将 CTRL 写为 `32'hCAFE_1238`，
再读取 `0x0000_0000`，保持 `RREADY=0` 两个完整周期，最后完成 R handshake。
本次未修改 RTL。

VCS 仿真结果：

| 场景 | 结果 | 周期数 |
| --- | --- | ---: |
| `r_backpressure` | PASS | 12 |
| `read_ctrl` | PASS | 11 |
| `aw_first` | PASS | 9 |
| `aw_w_parallel` | PASS | 7 |
| `b_backpressure` | PASS | 9 |

`r_backpressure` 检查响应反压期间的 `RVALID/RDATA/RRESP/ARREADY`，
完成后的 `RVALID/ARREADY`、返回值及 AR/R handshake 次数。三个写场景
使用当前仿真程序重新运行并通过。此前记录的 `read_ctrl` 释放失败在本次
运行中未复现；没有本次 RTL 修改或失败复现证据，暂不归因。

## Verdi 波形观察

- 85 ns：AR handshake。
- 95 ns、105 ns：`RREADY=0`；`RVALID=1`、`RDATA=32'hCAFE_1238`、
  `RRESP=2'b00`、`ARREADY=0`，两次采样一致；R handshake 计数保持 0。
- 115 ns：`RREADY=1` 时发生唯一一次 R handshake。该上升沿后，
  `raddr_valid` 从 1 变为 0，`rstate` 从 `R_REQ_SENT` 回到 `R_IDLE`；
  `RVALID` 清零，`ARREADY` 恢复。最终 AR/R handshake 次数均为 1。
- `read_ctrl` 也观察到 R handshake 后相同的状态释放和接口恢复。

## 工程模式

这是单笔 outstanding 请求的“保存请求、保持响应、握手后释放”模式。
读地址已被接收但响应未被 master 接收时，`RVALID`、`RDATA`、`RRESP`
必须保持；`ARREADY=0` 防止新地址覆盖当前保存槽。只有
`RVALID && RREADY` 的采样上升沿才能结束事务。常见错误是用错误通道
的握手清除地址、过早改变响应，或只检查读数据而漏查资源释放。

本练习只覆盖一个 CTRL 地址、单笔读事务及定向时序；生产设计还需处理
地址解码、错误响应、并发请求、寄存器副作用等。相同握手与反压规则会出现在
网络设备的 MMIO 控制寄存器、描述符状态读取和控制面互连中。

## 下次恢复点

先简短复查 `r_backpressure` 的 95/105/115 ns 波形和两个读场景的结果。
随后再选择一个新的阶段 2 定向目标；W-first、地址错误、WSTRB、STATUS
读取和阶段 2 收尾均不计入今天的完成范围。
