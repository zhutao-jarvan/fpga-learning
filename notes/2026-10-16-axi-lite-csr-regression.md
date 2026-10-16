# AXI4-Lite CSR 六场景回归 - 2026-10-16

## 已完成的仿真回归

| 场景 | VCS 结果 | 周期数 |
| --- | --- | ---: |
| `w_first` | PASS | 10 |
| `aw_first` | PASS | 9 |
| `aw_w_parallel` | PASS | 7 |
| `b_backpressure` | PASS | 9 |
| `read_ctrl` | PASS | 11 |
| `r_backpressure` | PASS | 12 |

本轮使用当前 RTL/TB 编译的 VCS `simv`。直接运行 Makefile 的 `vcs`
命令在工具启动时出现 `/bin/sh: 0: Illegal option -h`，尚未进入 RTL/TB
解析；VCS 启动脚本首行为 `#!/bin/sh -h`。改用 `bash` 调用同一 VCS 脚本后
构建并完成仿真。六个场景的日志和 FSDB 分别在
`vcs_build/axi_lite_csr_tb/<scenario>.sim.log` 和
`vcs_build/axi_lite_csr_tb/<scenario>.fsdb`。本轮没有修改 RTL 或 TB。

## 待观察与恢复点

`w_first` 仿真 PASS 只证明当前 checker 没有报错；用户尚未在 Verdi 确认
W handshake、其后两个等待周期、AW handshake、B handshake，以及
`AWREADY`、`WREADY`、`BVALID`、`wdata_valid`、`waddr_valid`、`wdata` 和
`ctrl_rw` 的变化。先由用户预测或解释关键波形，再评估波形验收。

完成这一次观察后，复查当前写路径对 `AWADDR` 的实际处理。非法地址写入
练习尚未开始；开始实现前先说明目标和验收方法，并完成至少五个结构问题。
`WSTRB` 部分写、`STATUS` 读取和阶段 2 收尾不在本次范围内。
