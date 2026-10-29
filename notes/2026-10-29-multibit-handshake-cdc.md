# 多 bit Request/Acknowledgement CDC - 2026-10-29

## 完成结论

最小 8-bit toggle request/acknowledgement 握手 CDC 练习已完成：用户从零实现
核心 RTL，经代码评审和修改后 VCS directed TB 通过三笔事务，并提供第一笔事务
的 Verdi 时刻与保持窗口解释。工程模式复盘记录在下文。

本次只确认受控共同复位、单笔 outstanding、目标端始终可接收的教学结构；
未进行器件综合、布局、CDC 静态检查、物理时序约束或独立复位恢复验证。

## 接口与实现

- `src_valid_i && src_ready_o` 在非复位源时钟沿接受一笔数据，锁存
  `src_payload_hold` 并翻转 `src_req_toggle`。busy 期间禁止覆盖与再次翻转。
- `src_ready_o` 由本地 request 与返回 ack 第二级相等派生。复位使两者为 0，
  ready 因此为 1；复位期间仍不接受事务，两域释放后才发送。
- request 经 `dst_req_ff1/ff2` 两级同步；目标逻辑用第二级沿前值与
  `dst_ack_toggle` 比较，发现新请求后捕获 payload、产生单周期 valid 并更新 ack。
- ack 经 `src_ack_ff1/ff2` 两级同步返回。两条同步链在每个非复位本地时钟沿运行。
- `dst_valid_o` 是新数据到达的单周期通知；`dst_data_o` 保持到下一次捕获或复位。
  ack 表示 CDC 已捕获数据，不表示下游业务已经执行完毕。

相关文件：`rtl/cdc/multibit_handshake_cdc.sv`、
`verification/tb/multibit_handshake_cdc_tb.sv`、`Makefile`。

## 评审与理解修正历史

用户起初将请求理解为每源周期翻转，并担心异步相位导致目标每拍无法维持请求判断。
讨论后明确：每笔合法事务只翻转一次；源域 req/payload 保持到确认，异步相位影响
到达时刻；目标捕获后 data 靠本地寄存器保持，不需要请求条件持续为真。

进一步对齐了 valid 的有效期、数据保持与确认含义：目标 valid 只保持一个目标周期，
下一沿下游读取沿前 valid/data，随后 valid 清零，数据仍保持。目标生成 ack 与
源域收到 ack 是不同的时刻。

首次评审发现源域和目标域同时驱动 `dst_valid_o`/`dst_ack_toggle`，VCS 报
`Illegal combination of drivers`；同时 busy 分支阻止 ack 同步，可能永久等待。
删除跨域多驱动和 busy 分支后，第二次评审仍发现目标 valid 未复位，TB 在 36 ns
报 `destination valid not zero after reset`。最终用户补上复位，并将 ack 同步链
移至每个非复位源周期执行。当前问题均已关闭。

## VCS directed TB 证据

`make multibit_handshake_cdc_sim` 日志报告：

```text
PASS: multibit_handshake_cdc directed checks passed (3 transfers)
```

| 数据 | 源域接受 | 目标域捕获 |
| --- | --- | --- |
| A5 | 52 ns | 75 ns |
| 3C | 100 ns | 125 ns |
| C3 | 148 ns | 175 ns |

TB 检查了复位状态、单笔数据正确、busy 覆盖尝试被拒绝、valid 单周期、ack 返回与
ready 恢复、连续合法事务的数量和顺序，以及输出和内部状态只在所属时钟沿变化。
日志为 `vcs_build/multibit_handshake_cdc_tb/sim.log`；波形为同目录下
`multibit_handshake_cdc.fsdb`。本次 KDB 编译日志报告数据库成功生成。

## 用户波形解释与名称修正

| 第一笔事务的事件 | 时刻 |
| --- | --- |
| 锁存 A5，request 从 0 翻到 1，ready 拉低 | 52 ns |
| request 到目标第一级 `dst_req_ff1` | 55 ns |
| request 到目标第二级 `dst_req_ff2` | 65 ns |
| 目标捕获 A5，产生 valid 并更新 ack | 75 ns |
| ack 到源域第一级 `src_ack_ff1` | 76 ns |
| ack 到源域第二级 `src_ack_ff2`，ready 恢复 | 84 ns |
| 目标 valid 清零，data 保持 A5 | 85 ns |
| TB 实际接受下一笔 3C，覆盖源域 held payload | 100 ns |

用户正确给出这些关键时刻、75–85 ns valid 区间、32 ns 往返延迟和 52–100 ns 的
实际 payload 保持窗口；回答中将两条同步链名称写反，已明确修正：request 进入
目标域 `dst_req_ff*`，ack 返回源域 `src_ack_ff*`。不因此重复要求解释相同过程。

65 ns 第二级沿后才更新，捕获逻辑在该沿读取的仍是旧值，所以到 75 ns 才捕获。
valid 为 0 时即使 data 保持旧值，也不通知新事务；valid 代表一次新数据通知，
不是 data 寄存器中是否存在数值。

用户解释了 68 ns 覆盖会使第一笔丢失：当时目标尚未捕获。工程上即使目标可能已
捕获，源域仍须等返回 ack 才可重用源存储，不能用本地估计代替确认。

52–84 ns 是本波形的未确认区间；84 ns ready 恢复，最早在 92 ns 源沿接受下一笔。
TB 实际到 100 ns 才接受，所以 held payload 多保持了一段时间。若不再发送，它将
继续保持。32 ns 是当前相位下的实例，不是对所有时钟组合的固定延迟保证。

## 工程模式复盘

### 模式、用途与安全边界

这是 bundled-data 的闭环单笔传输：持久 request 通知一份稳定数据，目标捕获后
返回持久 ack；源端存储只有在收到确认后才可重用。团队用这个模式跨域传递低速
且需要整字一致的配置或命令，避免逐 bit 同步造成不存在的组合值。

关键不变量是：每次源域接受只翻转一次；未确认时 payload/req 不变；功能逻辑只用
同步第二级；每个新请求只捕获一次；目标已获得本地副本后才确认；每个寄存器只有
一个所属时钟域。payload 本身不逐 bit 同步，但必须在目标捕获前全部满足建立时间，
并在捕获窗口内满足保持时间。协议保持与物理数据路径约束共同提供安全性。

### 吞吐与误用

只有一笔 outstanding，每次要等待 request 前向同步、目标捕获和 ack 返回同步，
再到后续源接受沿才能发送下一笔。它适合低速控制，不适合每拍数据或持续包流；
高吞吐和突发缓冲后续由异步 FIFO 学习。

常见误用包括：每源周期翻转 req；busy 时覆盖数据；捕获实时输入而非 held payload；
把 ack 做成窄脉冲；在同步第一级做功能判断；条件分支停止同步链；跨时钟多驱动；
将 valid 保持为高而导致重复消费；将捕获确认解释为业务执行完成。若目标会反压，
需要目标 ready 或有容量管理的本地缓冲，并重新明确确认的责任边界。

### 独立复位风险与生产设计

本练习两个域受控一起复位，双方 req/ack 状态归零，复位后才发送。独立复位可能
清除未处理请求、把状态差异误判为新事务、重复捕获或永久 busy；同步高有效复位
本身不能解决这些协议问题。生产设计必须定义事务丢弃/恢复策略，并使用初始化、
重同步或其他明确协议处理复位，不假定本实例自动支持。

生产设计通常采用经过验证的 CDC IP/结构，为同步寄存器添加工具支持的 `ASYNC_REG`
属性，确保第一级只驱动第二级、两级靠近布局，并根据时钟与事件频率评估 MTBF。
需声明异步时钟关系，检查同步链 CDC 报告和级间时序，针对 bundled-data 路径设置
适当的最大延迟/偏斜约束并确认数据到捕获沿的裕量。不能仅用宽泛的 false path
忽略跨域数据路径后，就宣称 payload 时序安全。具体属性与约束依器件和工具确定。
普通 RTL 仿真只验证数字协议，不模拟物理亚稳态，也不替代 CDC/STA/布局检查。

教学实现省略了独立复位恢复、目标反压、多个 outstanding、超时和生产物理约束；
本次不扩展 UVM、随机测试、复杂 scoreboard 或参数化框架。

### 网络 FPGA 中的用途

适合把 CSR 域中的配置字、带参数的低速命令送到功能域；也适合将功能域先在本地
锁存好的一致状态快照送回 CSR 域。它保证已锁存 payload 的跨域一致性，不能自动
让多个持续变化的状态源形成同一时刻的快照。命令已到达与业务执行完成应使用不同
语义，驱动也应区分这两个阶段。

## 下一步

进入最小异步 FIFO：先理解为什么闭环单笔结构无法提供持续流量缓冲，再学习本地
读写指针、Gray 编码、指针跨域同步与满/空边界。阶段 3 仍在进行中。
