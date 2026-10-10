# AXI-Stream 输入 FSM 定向检查 - 2026-10-10

## 学习目标

理解两段式同步 FSM 中，输入 handshake 如何驱动 packet 状态转换，以及为什么没有 handshake 时状态必须保持。

## 本次练习范围

FSM 位于 `rtl/fifo/axis_fifo.sv`，状态为 `IDLE` 和 `IN_PACKET`，暂不参与 FIFO ready/valid 数据通路。独立定向 testbench 位于 `verification/tb/axis_fifo_fsm_tb.sv`。

## 已完成的定向场景

### 场景 1：接收非 TLAST beat

在 25 ns 上升沿前观察到：

```text
state      = IDLE
next_state = IN_PACKET
handshake  = 1
push       = 1
s_axis_tlast = 0
```

上升沿后：

```text
state      = IN_PACKET
next_state = IN_PACKET
```

结论：组合逻辑先计算 `next_state`，同步状态寄存器在上升沿采样并更新为 `IN_PACKET`。

### 场景 2：没有 handshake 时保持状态

在 35 ns 上升沿前观察到：

```text
s_axis_tvalid = 0
s_axis_tready = 1
s_axis_tlast  = 1
push          = 0
handshake     = 0
state         = IN_PACKET
next_state    = IN_PACKET
```

上升沿后：

```text
state         = IN_PACKET
next_state    = IN_PACKET
```

结论：`s_axis_tlast` 在没有有效输入传输时不会被 FSM 消耗；没有 handshake 就没有 packet 进度变化，状态必须保持。

## 验证结果

- 独立 `axis_fifo_fsm_tb` 已完成 VCS 编译和仿真。
- 仿真输出：`PASS: directed FSM transition check passed`。
- 已在 Verdi 中确认上述两个上升沿前后的状态、组合 next-state 和 handshake 信号。
- 同步复位场景也已完成：在 `45 ns` 上升沿前，`rst=1` 且
  `dut.state=IN_PACKET`；该上升沿之后，`dut.state` 更新为 `IDLE`。
- 复位场景只验证同步状态寄存器在上升沿更新，没有增加 `TLAST=1` 的状态
  转换场景，也没有引入 UVM 或复杂 FSM。

## 掌握说明

已通过代码检查、仿真结果和波形观察说明：

1. 能区分组合逻辑 `next_state` 与时序寄存器 `state` 的更新时间；
2. 能用 `push`/`handshake` 判断一个输入 beat 是否真正被接收；
3. 能解释无 handshake 时 `TLAST` 的变化不能推动 packet FSM 转换；
4. 能使用独立 VCS 构建目录和 FSDB/Verdi 检查一个定向 FSM 场景。

5. 能从波形中识别同步复位的关键时序：`rst` 拉高本身不立即改变状态，
   状态在下一个有效上升沿更新。

## 下一步

阶段 1 的 FSM/同步复位交付已完成。下一步进入阶段 2，先定义最小 CSR
寄存器规格，再实现一个只支持单个未完成事务的 AXI4-Lite 读写路径；暂不引入
UVM、CDC、突发事务或复杂寄存器副作用。
