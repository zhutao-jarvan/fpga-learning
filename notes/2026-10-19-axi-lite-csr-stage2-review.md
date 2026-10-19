# AXI4-Lite CSR 阶段 2 工程模式复盘 - 2026-10-19

## 收尾结论

阶段 2 暂不标记为已完成。九个现有 directed 场景全部通过；首次收尾检查发现的
`CTRL` 复位值问题已经修复，并由新一轮回归和 FSDB 波形确认。当前只剩新增复位
checker 的 X-safe 语义需要闭环。

## 完整 directed 回归

2026-10-19 使用同一次 VCS 编译生成的 `simv` 运行全部场景：

| 场景 | 结果 | cycles |
| --- | --- | ---: |
| `aw_first` | PASS | 9 |
| `w_first` | PASS | 10 |
| `aw_w_parallel` | PASS | 7 |
| `b_backpressure` | PASS | 9 |
| `read_ctrl` | PASS | 11 |
| `r_backpressure` | PASS | 12 |
| `read_status` | PASS | 8 |
| `wstrb` | PASS | 15 |
| `w_badaddr` | PASS | 15 |

直接执行 `make axi_lite_csr_compile` 仍因 VCS 包装脚本的 `#!/bin/sh -h` 与当前
`/bin/sh` 不兼容而失败。本次沿用已有工具记录，以 `bash` 显式运行同一个 VCS
脚本完成编译；该工具问题与 DUT 回归结果分开记录。

## 第一个问题：CTRL 复位值未定义

RTL 的同步复位分支会清除写事务状态，但没有给 `ctrl_rw` 赋值；相对地，
`status_o` 明确定义为 `32'h0000_0000`。现有 CTRL 读取场景都会先完整写入 CTRL，
因此掩盖了复位后的未知值。

仿真日志 `read_status.sim.log` 报告：

```text
Running scenario: read_status
PASS: AXI LITE CSR checks passed (8 cycles)
```

对同一次仿真的 `read_status.fsdb` 做 Verdi FSDB 信号报告，得到：

```text
time(ps)  rst  ctrl_rw    status_o
5000      1    xxxxxxxx   00000000
15000     1    xxxxxxxx   00000000
25000     1    xxxxxxxx   00000000
35000     0    xxxxxxxx   00000000
```

这段波形说明同步复位上升沿确实初始化了 STATUS，却没有初始化 CTRL；复位释放后
CTRL 仍为 X。软件通常需要确定的 CSR 复位契约，因此在定义并验证 CTRL 复位值前，
阶段 2 不宜关闭。

最小收尾动作应是：先明确 CTRL 的教学规格复位值；在 RTL 同步复位分支实现它；
增加一个复位后、不经写入而直接读取 CTRL 的 directed 检查；再运行九个既有场景
和该复位场景，并在波形中确认复位上升沿、R 反压和 R handshake。

## 修复后复查

用户已在写路径同步复位分支增加 `ctrl_rw <= 32'h0000_0000`，并在 `aw_first`
开始写事务前检查 CTRL 复位值。重新编译后的九个场景再次全部 PASS，cycle 数不变。
`aw_first.fsdb` 的复位窗口为：

```text
time(ps)  rst  ctrl_rw    status_o
5000      1    00000000   00000000
15000     1    00000000   00000000
25000     1    00000000   00000000
35000     0    00000000   00000000
```

这证明 RTL 的 CTRL 复位问题已修复。当前第一个 TB 问题是新增检查使用
`dut.ctrl_rw == 32'h0000_0000`：当 `ctrl_rw` 为 X 时，比较结果也是 X；现有
`check` task 中的 `if (!condition)` 不保证把 X 判为失败。因此该检查可能无法防止
原问题回归。将复位值比较改为 X-safe 的 case equality（`===`）后重新运行回归，
即可关闭这一项。

## 已验证的工程模式

1. **单笔 outstanding 槽位**：AW、W 分别占用保存槽；两者齐备后关闭
   `AWREADY/WREADY` 并产生 B 响应。AR 被接受后关闭 `ARREADY`，直到 R
   handshake 释放读槽。实现简单且容易观察，代价是吞吐有限。
2. **AW/W 独立接收**：地址和数据不要求同拍或固定先后顺序；AW-first、W-first
   和并行到达均由独立 valid 标志汇合成一笔写请求。这是 AXI4-Lite 写通道必须
   保持的基本解耦。
3. **反压期间保持响应**：BREADY 或 RREADY 为低时，事务槽不释放，BVALID 或
   RVALID 保持；现有 directed 场景和 Verdi 观察已覆盖响应稳定与 handshake 后恢复。
4. **地址译码与写保护**：只有保存地址为 CTRL 时才产生寄存器写使能；非法写返回
   SLVERR，且读回证明 CTRL 未改变。
5. **WSTRB byte-lane 合并**：WDATA 与 WSTRB 在同一次 W handshake 保存；四个
   byte lane 分别选择新数据或旧 CTRL 值。未使能 lane 保持不变。
6. **寄存器属性**：CTRL 是 RW，STATUS 是 RO；STATUS 已定义并验证零复位值。
   CTRL 的 RW 数据路径已验证，但复位契约正是本次发现的首个未闭环项。

这些模式解决的是软件控制面请求可能分通道、响应可能受反压、寄存器具有不同权限
以及局部 byte 写入不能破坏其他字段的问题。在网络 FPGA 中，它们会出现在队列
控制、错误状态、统计快照、MAC/端口配置和调试寄存器中。

## 与生产级设计的差距和保留风险

以下是本练习已声明或尚未覆盖的范围，不作为本轮新增问题继续展开：

- 只允许单笔 outstanding，未追求背靠背请求吞吐，也没有读写并发的规格与检查；
- 假设 CSR 与 AXI 接口同一时钟域，未处理 CDC、异步复位释放或状态快照一致性；
- 只验证 `WSTRB=1111` 和 `0101`，尚未定义 `WSTRB=0000`、不支持的 strobe
  组合、保留 byte/field 的处理策略；
- 没有 W1C、read-clear、self-clear、pulse、sticky bit、计数器快照等寄存器副作用；
- 没有覆盖读写同一寄存器同拍时的优先级，也没有验证并发写会不会影响被反压的
  RDATA；
- 生产实现通常会显式保存 response/data，使用统一寄存器描述或生成流程，并配套
  协议断言、lint、CDC、综合和时序检查；本练习刻意没有引入这些复杂度。

## 阶段 3 前的准备

先关闭 CTRL 复位 checker 的 X-safe 语义，再把阶段 2 标记为完成。之后进入阶段 3 时，从最小
两级同步器开始，明确“单 bit 电平可同步，多 bit 数据不能逐 bit 直接同步”，随后
再练习 pulse/toggle、多位握手和异步 FIFO。寄存器副作用、读写并发和更完整覆盖
可作为后续强化项，不要求在进入阶段 3 前扩展成本练习的新功能。
