# 小型同步 AXI-Stream FIFO

这个练习把一个深度为 4、数据宽度为 32 bit 的同步 FIFO 接到 AXI-Stream
ready/valid 接口上。它用于观察几个很实用的 RTL 概念：

- FIFO 用写指针、读指针和 occupancy 表示 empty/full；
- 一个 beat 只在 `TVALID && TREADY` 同时为 1 的时钟上升沿传输；
- 下游把 `TREADY` 拉低时形成 backpressure，上游必须保持 `TVALID`、`TDATA`
  和 `TLAST`，直到传输发生；
- 本实现采用同步高有效复位，复位有效的上升沿把 occupancy 和指针清零；
- 非空 FIFO 的输出是队头数据，因此普通传输延迟至少一个时钟，连续传输时
  可以每拍一个 beat；深度满时 `s_axis_tready` 拉低，深度空时
  `m_axis_tvalid` 拉低。

这是教学用的最小实现：固定宽度和深度，不做 full 时的 simultaneous
read/write 优化，也没有异步时钟域支持。对应的自检 testbench 位于
`verification/tb/axis_fifo_tb.sv`。

## 最小异步 FIFO

`async_fifo.sv` 是固定 8-bit、4-entry 的双时钟 FIFO 练习。写域和读域分别维护
本地 binary 指针，用低地址位访问 memory；额外回绕位用于区分地址相同时的空和满。
本地 binary 指针转换成注册的 Gray 指针后，经两级同步送入远端时钟域。功能逻辑
只使用同步第二级，full/empty 根据本地候选 next pointer 注册，因此远端进展的可见性
是安全且保守的。

### 为什么 Gray full 要翻转最高两位

深度为 4 时，地址宽度为 2，带回绕位的 binary 指针宽度为 3。设读指针为：

```text
r2 r1 r0
```

FIFO 满表示写指针比读指针领先一个完整深度，即在模 8 指针空间中加 4。加 4 只翻转
binary 的额外回绕位，低地址位保持不变：

```text
读 binary： r2 r1 r0
写 binary：~r2 r1 r0
```

Binary 到 Gray 的逐位关系是：

```text
g2 = b2
g1 = b2 ^ b1
g0 = b1 ^ b0
```

代入满状态的写 binary 指针：

```text
写 g2 = ~r2              = ~(读 g2)
写 g1 = (~r2) ^ r1       = ~(r2 ^ r1) = ~(读 g1)
写 g0 = r1 ^ r0          = 读 g0
```

因此 3-bit Gray 指针的 full 条件是：写 Gray 等于同步读 Gray 的最高两位取反、
其余位保持不变：

```systemverilog
wr_gray_next == {
    ~rd_gray_sync_ff2_wr[PTR_WIDTH-1:PTR_WIDTH-2],
     rd_gray_sync_ff2_wr[PTR_WIDTH-3:0]
}
```

例如读 binary 为 `001`、读 Gray 为 `001` 时，满状态写 binary 为 `101`、写 Gray
为 `111`；对读 Gray 的最高两位取反同样得到 `111`。

这条关系针对深度为 2 的幂、并带一个额外回绕位的标准异步 FIFO 指针。不能将
binary 的“最高位不同、低位相等”直接套在 Gray 位上。empty 则直接比较本地候选
读 Gray 与同步后的写 Gray 是否完全相等。

本练习采用 FWFT/show-ahead 读接口。两个域使用受控共同复位，不支持独立复位恢复。
生产实现还需要同步器属性、异步时钟及 Gray bus skew 约束、CDC/STA 检查、目标器件
RAM 行为确认，以及系统级复位和事务恢复策略。
