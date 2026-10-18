# AXI4-Lite CSR STATUS 合法读取 - 2026-10-18

## 本次目标

在已有 AR/R 读路径和 RREADY 反压检查之上，增加 `STATUS` (`0x0000_0004`)
合法读取的 directed 场景。保持现有单一 driver、场景选择和握手计数器，不引入
UVM、随机测试或复杂 scoreboard。

## 最小设计决定

RTL 已经把 `STATUS_ADDR` 路由到 `status_o`，但 `status_o` 原先没有任何时序赋值。
因此复位后读值会是未知值，无法形成稳定的 CSR 读规格。本练习将 STATUS 定义为
只读、复位值 `32'h0000_0000`，之后保持不变；复位分支增加这一项初始化。生产设计
通常会让 STATUS 由计数器、错误标志或数据通路状态驱动，这里暂不引入副作用。

## TB 检查

`read_status` 场景执行：

1. 对 `0x0000_0004` 完成一次 AR handshake；
2. 在 `RREADY=0` 的两拍中检查 `RVALID=1`、`RDATA=0`、`RRESP=OKAY`、
   `ARREADY=0`，并确认没有 R handshake；
3. 接受 R response，检查数据和响应，随后确认 `RVALID=0`、`ARREADY=1`。

## 仿真证据

使用 `vcs_build/axi_lite_csr_tb/read_status.sim.log` 和对应
`read_status.fsdb`：

```text
PASS: AXI LITE CSR checks passed (8 cycles)
```

已有场景回归也通过：`aw_first` 9、`w_first` 10、`aw_w_parallel` 7、
`b_backpressure` 9、`read_ctrl` 11、`r_backpressure` 12、`w_badaddr` 15 cycles。

Verdi 观察重点是 STATUS AR 上升沿保存 `raddr=0x4`，下一拍响应保持期间
`raddr_valid=1`、`RVALID=1`、`RDATA=0`、`RRESP=OKAY`，R handshake 后
`raddr_valid=0`、`RVALID=0` 且 `ARREADY=1`。

用户已结合 Verdi 完成确认：`raddr=0x4` 在 45 ns 的时钟上升沿完成 AR
handshake；随后 slave 给出 `RVALID=1`、`RDATA=0`、`RRESP=OKAY`，响应保持到
75 ns 的时钟上升沿；`ARREADY` 在 70 ns 的时钟上升沿恢复为高。所有信号与
directed TB 的预期一致。

## 工程模式复盘

- 模式：只读 CSR 的地址译码、复位定义和 ready/valid 响应保持。
- 解决的问题：给软件可读的状态寄存器定义确定的上电值，并在 master 反压时保持
  响应不变，避免控制面读出未知值或丢失事务。
- 关键不变量：AR 接受后只能有一笔未完成 R；RREADY 为低时 RVALID、RDATA、
  RRESP 不变；R handshake 后释放读槽位。
- 教学版省略：STATUS 没有真实状态源，未支持并发 outstanding、CDC、错误注入和
  更完整的寄存器属性表。
- 网络场景：驱动读取链路错误、包计数、队列水位等只读状态时，会使用同样的 CSR
  读响应保持和复位值约定。

## 当前第一个问题

直接执行 `make axi_lite_csr_sim` 仍会触发 VCS 启动脚本的 `/bin/sh -h` 兼容性错误；
按已有工具环境记录使用 `bash` 调用 VCS 后，编译和全部仿真通过。后续如需打开
波形，应在 Verdi 中结合上述时间顺序解释 `raddr_valid`、`RVALID`、`RDATA`、
`RRESP`、`ARREADY` 和 `RREADY` 的关系。
