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
