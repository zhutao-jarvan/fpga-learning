# 总体学习进度

最后更新：2026-10-16。当前状态依据仓库截至 2026-10-16 的学习日志；
没有记录的练习不推定已经完成。

## 使用方式

这是总体状态的统一入口。[learning-plan.md](learning-plan.md) 保存路线、
时间基准和阶段目标；`notes/` 保存具体观察与每日日志；`assessment.md` 保留
能力评估历史。阶段状态使用“未开始 / 进行中 / 已完成”，预习单独注明。

完成关键练习、确认阶段交付物、改变学习重点或暂停/恢复时更新本文件。
普通问答和波形细节写入日志，并在这里链接必要证据，避免重复记录。
记录学习时长是可选项；不按日历月份或小时数自动把阶段标记为完成。

## 进度提示

- 六阶段总体进度：`1/6 = 16.7%`。这里按阶段核心交付物粗粒度统计，
  不是按学习小时或代码行数计算。
- 强化阶段进度：`0/2`。两个强化阶段在六个核心阶段之后进行，不降低或重算
  已完成的核心阶段进度，具体题目根据届时的实际错误和能力缺口选择。
- 阶段 1 交付进度：`5/5 = 100%`。已完成 FIFO/ready-valid 波形理解、
  小型 RTL 与 testbench 修改、自检仿真、VCS/Verdi 工作流，以及 MMIO/CSR
  预览；阶段 2 从最小 AXI4-Lite 寄存器块开始。
- 进度口径：只有在代码、仿真结果、波形或清晰解释形成证据后才计入完成；
  预习内容会单独标注，不提前计入后续阶段完成。

## 当前状态

- 学习状态：进行中，阶段 2 起步（调试寄存器与控制面）；阶段 1 已完成。
- 时间安排：基准为每天 1–2 小时、每周 10–15 小时；近期时间较充裕，
  可能每天投入 8 小时。以后可能因项目工作连续暂停半个月至一个月。
- 当前练习：最小 AXI4-Lite CSR；AW/W/B 基本写路径及 CTRL 的 AR/R
  读取和两拍 R 反压已通过定向测试，继续扩展边界场景。
- 已有证据：Q1–Q40 评估完成；已有 FIFO 与自检 testbench；日志记录首次
  VCS 仿真通过（46 beats）及同步复位、push/pop、反压、回绕和 TLAST 的波形观察。
- 2026-10-09 已完成：独立追踪 testbench → RTL → 输出的完整 beat；验证
  occupancy 的四种更新组合；观察读写指针回绕及空/满歧义；定位并修改满状态下
  同拍 pop+push 的吞吐限制；加入并运行输出稳定性和 occupancy 上界 SVA；完成
  MMIO/CSR 的请求、接受、响应概念预习；VCS 通过 46-beat 自检。
- 已完成：FSM 基础定向检查。独立 `axis_fifo_fsm_tb` 已通过 VCS，且在 Verdi
  中确认 `IDLE + push + TLAST=0 -> IN_PACKET`、无 handshake 时保持
  `IN_PACKET`，以及 `rst=1` 时在上升沿将 `IN_PACKET` 置为 `IDLE`。
- SVA：最小的输出反压稳定性断言已加入 testbench，并在 VCS 中通过 46-beat
  仿真；后续仍需逐步扩展断言覆盖范围。
- 2026-10-11 阶段 2 起步：约 6 小时完成最小 CSR 接口、AW/W 独立接收和 B
  响应的初步 RTL/TB。在 Verdi 中确认 115 ns 完成 AW 握手、125 ns 完成 W
  握手、135 ns 完成 B 握手；说明 AW 先到、W 后到的基本路径能够工作。
  当前 testbench 自检仍不完整，B/R 反压、错误响应和读路径尚未完成。
- 2026-10-11 学习策略调整：新的关键机制、工程高风险点和个人重复错误优先安排
  小型从零构建；已理解的样板工作改用骨架补全或阅读调试。学习证据以设计推理、
  波形预测、代码评审、故障定位和定向修改为主，不以独立编写全部代码为目标。
- 2026-10-12 完成 AW/W/B 写路径 directed-TB 子目标：重构单一 driver 和
  scenario/driver/monitor/checker 分层；验证 AW-first、AW/W 并行和 BREADY 两拍
  反压；在 B handshake 后检查 BVALID 清零、AWREADY/WREADY 恢复和 CTRL 写入；
  增加 `+scenario=<name>` 选择与 Makefile 场景参数。三个场景均通过轻量仿真，
  并在 Verdi 中完成关键波形解释。进入 AR/R 前仍需进行理解确认；阶段 2 的
  W-first、地址错误、WSTRB 和寄存器访问类型测试尚未完成。
- 2026-10-12 AR/R 起步：第一版 RTL 已能完成 AR/R handshake，并正确返回预先
  写入 `CTRL` 的 `32'hCAFE_1237` 和 OKAY；TB 已增加独立 `read_ctrl` scenario。
  当时 checker 暴露 R handshake 后 `RVALID` 未清零、`ARREADY` 未恢复。
- 2026-10-14 完成读路径定向子目标：用户新增 `r_backpressure` TB 场景，
  在两拍 `RREADY=0` 期间检查响应和 `ARREADY`，再检查 R handshake 后接口
  恢复及 AR/R 各一次握手。`r_backpressure`、`read_ctrl` 和三个已有写场景
  全部通过；Verdi 确认 95/105 ns 响应保持、115 ns 后读状态释放。
  本次没有修改 RTL；2026-10-12 的释放失败未复现，根因仍未知。
- 2026-10-14 完成 W-first 写事务 directed TB：W handshake 后在两个连续
  上升沿检查 `AWREADY=1`、`WREADY=0`、AW/B 尚未 handshake 且 CTRL 未更新；
  随后完成 AW/B handshake，检查 `CTRL=32'hCAFE_1239` 以及 B handshake
  后 `BVALID` 清零、AWREADY/WREADY 恢复。`w_first` 仿真通过 10 cycles，
  未修改 RTL。W-first 的 Verdi 波形尚待用户观察和解释。
- 2026-10-16 回归六个场景：`w_first` 10、`aw_first` 9、`aw_w_parallel` 7、
  `b_backpressure` 9、`read_ctrl` 11、`r_backpressure` 12 cycles，均为 VCS
  仿真 PASS。VCS 启动脚本的 `#!/bin/sh -h` 与当前 `/bin/sh` 不兼容；通过
  `bash` 调用该脚本完成构建，随后运行同一 `simv`。这只构成仿真证据；
  W-first 波形验收、写地址语义复查和非法地址练习均待继续。

## 阶段总览

| 阶段（原月份） | 状态 | 完成证据 / 剩余重点 |
| --- | --- | --- |
| 1：RTL、仿真与波形 | 已完成 | FIFO 波形追踪、满载吞吐修改、VCS 自检、最小 SVA、FSM 和同步复位定向波形均有证据 |
| 2：调试寄存器与控制面 | 进行中 | AW/W/B、CTRL 读取及 B/R 两拍反压已通过定向检查；待 W-first、地址错误、WSTRB、STATUS 读取等 |
| 3：CDC、复位与异步缓冲 | 未开始 | 待同步器、pulse/toggle、多位握手及异步 FIFO 实践 |
| 4：网络数据通路与性能 | 未开始 | 待带反压、包边界和 CSR 的小型流水线 |
| 5：验证与团队工作流 | 未开始 | 待断言、覆盖、现有团队 UVM 框架实践 |
| 6：综合、时序与综合项目 | 未开始 | 待集成项目和综合/时序报告 |

## 强化阶段总览

| 强化阶段 | 状态 | 选择与交付方式 |
| --- | --- | --- |
| 1：针对性重构与故障练习 | 未开始 | 核心六阶段后，根据实际证据选择 2–4 个高价值缺口，完成小型 RTL/TB、波形和工程总结 |
| 2：工程迁移与陌生代码实践 | 未开始 | 阅读非本人从零编写的模块，完成需求变更、定向 testcase 和一次故障定位 |

## 下一步与充裕时间安排

按下面顺序推进，每项通过解释、代码或测试结果确认后再安排下一项：

1. 先由用户预测并在 Verdi 核对 W-first 的 W 握手、两个等待周期、AW 握手和
   B 握手，解释 `AWREADY/WREADY/BVALID`、保存槽及 `ctrl_rw` 的变化；
   仿真 PASS 不代替该波形验收。
2. 复查 AWADDR 在当前写路径中的实际用途，再补充同步复位、合法/非法地址和
   RO 写保护；第一轮写操作保持
   `WSTRB=4'b1111`，基本路径稳定后再检查字节使能。
3. 扩展 AR/R 读路径，定向测试 `STATUS` 和非法地址；该部分继续由用户负责
   关键握手、响应保持和检查逻辑。
4. 通过代码、VCS 和 Verdi 证据后，再逐步扩展寄存器副作用、SVA 和覆盖。
5. 阶段 2 核心实践通过后，继续安排阶段 3 的 CDC 小练习，
   不受“必须到第三个日历月”的限制。

每次学习仍优先采用“一个场景 → 用户观察和解释 → 提示与验证”的节奏。
时间充足时增加当天完成的任务数量；先确认掌握情况再扩展内容。

## 暂停与恢复

当前没有已记录的暂停。暂停时补充：暂停日期、当前任务、最后通过的测试、
未解决问题、恢复时的第一个动作。恢复后先运行最近练习并解释一段关键波形；
如发现遗忘，只针对该缺口复习，然后继续原任务。

## 关键记录

- [能力评估历史](assessment.md)：Q1–Q40 及基础能力快照。
- [2026-10-07 AXIS 评估](notes/2026-10-07-axis-assessment.md)：FIFO/AXIS 时序理解。
- [2026-10-08 FIFO 首次 VCS 与 Verdi](notes/2026-10-08-axis-fifo-first-vcs.md)：
  仿真结果、波形观察及待继续任务。
- [2026-10-09 FIFO 追踪与 SVA](notes/2026-10-09-axis-fifo-trace-sva.md)：
  完整 beat 追踪、occupancy、指针回绕、满载吞吐限制、SVA 和 MMIO/CSR 预习。
- [2026-10-10 FSM 定向检查](notes/2026-10-10-axis-fsm-directed-check.md)：
  独立 testbench、`IDLE -> IN_PACKET` 转换、无 handshake 状态保持及 Verdi 证据。
- [2026-10-11 AXI4-Lite CSR 写路径起步](notes/2026-10-11-axi-lite-csr-write.md)：
  最小寄存器规格、AW/W 独立接收、B 响应、VCS/Verdi 波形证据和恢复点。
- [2026-10-12 AXI4-Lite CSR TB 重构与 B 反压](notes/2026-10-12-axi-lite-csr-tb-refactor.md)：
  并行 AW/W、B 反压、单场景运行、Makefile 参数化和波形解释。
- [2026-10-14 AXI4-Lite CSR 读反压](notes/2026-10-14-axi-lite-csr-read-backpressure.md)：
  两拍 R 反压、响应稳定性、读事务释放和五个场景回归。
- [2026-10-16 AXI4-Lite CSR 六场景回归](notes/2026-10-16-axi-lite-csr-regression.md)：
  六个场景的 VCS 结果、工具启动问题和 W-first 波形待验收点。
- [工具环境](notes/2026-10-08-tool-environment.md)：两台机器与 NFS 共享工作流。
- 2026-10-09：确认采用弹性学习节奏；完成 FIFO 状态分析、最小 SVA 和 MMIO/CSR 预习。
