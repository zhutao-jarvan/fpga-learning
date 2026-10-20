# 总体学习进度

最后更新：2026-10-20。当前状态依据仓库截至 2026-10-20 的学习日志；
没有记录的练习不推定已经完成。

## 使用方式

这是总体状态的统一入口。[learning-plan.md](learning-plan.md) 保存路线、
时间基准和阶段目标；`notes/` 保存具体观察与每日日志；`assessment.md` 保留
能力评估历史。阶段状态使用“未开始 / 进行中 / 已完成”，预习单独注明。

完成关键练习、确认阶段交付物、改变学习重点或暂停/恢复时更新本文件。
普通问答和波形细节写入日志，并在这里链接必要证据，避免重复记录。
记录学习时长是可选项；不按日历月份或小时数自动把阶段标记为完成。

## 进度提示

- 六阶段总体进度：`2/6 = 33.3%`。这里按阶段核心交付物粗粒度统计，
  不是按学习小时或代码行数计算。
- 强化阶段进度：`0/2`。两个强化阶段在六个核心阶段之后进行，不降低或重算
  已完成的核心阶段进度，具体题目根据届时的实际错误和能力缺口选择。
- 阶段 1 交付进度：`5/5 = 100%`。已完成 FIFO/ready-valid 波形理解、
  小型 RTL 与 testbench 修改、自检仿真、VCS/Verdi 工作流，以及 MMIO/CSR
  预览；阶段 2 从最小 AXI4-Lite 寄存器块开始。
- 进度口径：只有在代码、仿真结果、波形或清晰解释形成证据后才计入完成；
  预习内容会单独标注，不提前计入后续阶段完成。

## 当前状态

- 学习状态：进行中，阶段 3（CDC、复位与异步缓冲）；阶段 1、2 已完成。
- 时间安排：基准为每天 1–2 小时、每周 10–15 小时；近期时间较充裕，
  可能每天投入 8 小时。以后可能因项目工作连续暂停半个月至一个月。
- 当前练习：双触发器电平同步和 pulse/toggle CDC 已完成；下一项为多 bit 握手 CDC，
  重点理解请求、稳定 payload、目标域捕获和 acknowledgement 返回。
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
- 2026-10-18 完成地址译码与非法写 directed TB：增加 `accept_b2` 在 B handshake
  上升沿采样 `BRESP`，增加 `w_badaddr`；合法 CTRL 写返回 `OKAY`，非法地址返回
  `SLVERR` 且不改变 CTRL，B handshake 后接口恢复。当前 RTL 将 `BRESP` 组合逻辑
  化为基于保存地址的响应，并仅在 CTRL 地址更新 `ctrl_rw`。`w_badaddr` 通过 15
  cycles；下一步为 STATUS 合法读取和读路径验收。记录见
  `notes/2026-10-18-axi-lite-csr-address-response.md`。
- 2026-10-18 完成 STATUS 合法读取 directed TB：将只读 `status_o` 的教学版复位值
  定义为 `32'h0000_0000`，新增 `read_status` 场景，验证 STATUS AR handshake、
  RVALID/RDATA/RRESP、两拍 RREADY 反压稳定性，以及 R handshake 后 RVALID 清零和
  ARREADY 恢复。场景通过 8 cycles；`aw_first`、`w_first`、`aw_w_parallel`、
  `b_backpressure`、`read_ctrl`、`r_backpressure`、`w_badaddr` 回归全部通过。
  用户已在 Verdi 中确认 45 ns 完成 `raddr=0x4` AR handshake，响应保持到 75 ns，
  `ARREADY` 在 70 ns 恢复。记录见 `notes/2026-10-18-axi-lite-csr-status-read.md`。
- 2026-10-18 完成 WSTRB directed TB：保存 W handshake 的 `WSTRB`，按 byte lane
  合并 `WDATA` 与现有 CTRL；`WSTRB=1111` 初始化后，`WSTRB=0101` 将
  `CAFE_123A` 更新为 `CAEF_1278`。`wstrb` 场景通过 15 cycles，最新 RTL/TB 的
  八个场景全部回归通过。首次失败是 checker 将 lane 2 期望为 `BE`，已根据
  `BEEF_5678` 的实际 byte 分解修正。记录见
  `notes/2026-10-18-axi-lite-csr-wstrb.md`。阶段 2 剩余重点是工程模式复盘和
  收尾检查。用户已在 Verdi 中确认两次 W handshake 为 45/85 ns、两次 B handshake
  为 65/105 ns，`ctrl_rw` 在 55/95 ns 更新，随后 CTRL 读回 `CAEF_1278`。
- 2026-10-19 完成阶段 2 工程模式复盘和九场景完整回归：`aw_first` 9、
  `w_first` 10、`aw_w_parallel` 7、`b_backpressure` 9、`read_ctrl` 11、
  `r_backpressure` 12、`read_status` 8、`wstrb` 15、`w_badaddr` 15 cycles，
  全部 PASS。收尾检查发现首个问题：RTL 没有给 `ctrl_rw` 定义复位值，现有 TB
  也没有复位后直接读 CTRL；`read_status.fsdb` 显示 5/15/25 ns 的复位上升沿及
  35 ns 复位释放后 `ctrl_rw=xxxxxxxx`，而 `status_o=00000000`。阶段 2 暂不标记
  完成；记录见 `notes/2026-10-19-axi-lite-csr-stage2-review.md`。
- 2026-10-19 修复后复查：写路径同步复位分支已增加 `ctrl_rw <= 32'h0000_0000`；
  九个场景再次全部 PASS。`aw_first.fsdb` 显示 5/15/25 ns 复位上升沿及 35 ns
  复位释放后 `ctrl_rw=status_o=00000000`。RTL 问题已关闭；新增 TB 检查仍使用
  四态 `==`，当 CTRL 为 X 时可能无法令现有 `check` task 失败，待改为 X-safe
  比较并回归后将阶段 2 标记完成。
- 2026-10-19 阶段 2 正式完成：CTRL 复位 checker 已由四态 `==` 改为 X-safe 的
  case equality（`===`），X/Z 会明确触发失败。重新编译后九个 directed 场景全部
  PASS，cycle 数为 9、10、7、9、11、12、8、15、15。阶段 3 已开始，首项为
  从零构建双触发器单 bit 电平同步器。
- 2026-10-19 完成阶段 3 首个 CDC 练习：用户从零实现同步高有效复位的两级单 bit
  电平同步器，`make bit_sync_sim` directed TB 通过。Verdi 中确认输入拉高时第一级/
  第二级分别在 25/35 ns 更新，拉低时分别在 45/55 ns 更新；55–65 ns 之间的短脉冲
  被漏采。用户能解释两级非阻塞采样和输出只随目标时钟更新；并补充理解 RTL 数字
  波形不能模拟真实 setup/hold 违例后的模拟亚稳行为。记录见
  `notes/2026-10-19-bit-sync.md`。
- 2026-10-20 完成 pulse/toggle CDC：用户从零实现源域 toggle、目标域两级同步和
  XOR 变化检测，directed TB 通过。Verdi 中确认 60 ns 源事件、65/75 ns 两级传播、
  75–85 ns 目标脉冲，并解释第二个反向 toggle 仍产生正脉冲，以及快速事件对因
  翻转两次恢复原值而丢失。记录见 `notes/2026-10-20-pulse-toggle-sync.md`。

## 阶段总览

| 阶段（原月份） | 状态 | 完成证据 / 剩余重点 |
| --- | --- | --- |
| 1：RTL、仿真与波形 | 已完成 | FIFO 波形追踪、满载吞吐修改、VCS 自检、最小 SVA、FSM 和同步复位定向波形均有证据 |
| 2：调试寄存器与控制面 | 已完成 | CTRL 零复位、X-safe checker、九场景回归及工程复盘均已闭环 |
| 3：CDC、复位与异步缓冲 | 进行中 | 单 bit 电平与 pulse/toggle 已完成；待多 bit 握手和异步 FIFO 实践 |
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

1. 定义最小多 bit 握手 CDC 的源/目标接口、payload 稳定窗口及一次事务时序。
2. 从零实现 request/acknowledgement 往返路径，并用 directed TB 检查数据一致性、
   busy 期间禁止覆盖和连续事务。
3. 完成 Verdi 逐拍解释和工程复盘后，再进入异步 FIFO。
   读写并发、寄存器副作用和更完整覆盖保留为后续强化项。

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
- [2026-10-19 AXI4-Lite CSR 阶段 2 工程模式复盘](notes/2026-10-19-axi-lite-csr-stage2-review.md)：
  九场景回归、工程模式、生产级差距、CTRL 复位值问题和阶段 3 前准备。
- [2026-10-19 双触发器单 bit 电平同步器](notes/2026-10-19-bit-sync.md)：
  从零 RTL、directed TB、Verdi 两拍传播与短脉冲漏采、工程安全边界和生产差距。
- [2026-10-20 Pulse/Toggle CDC](notes/2026-10-20-pulse-toggle-sync.md)：
  源域事件编码、目标域脉冲恢复、快速事件丢失边界、复位与生产约束。
- [工具环境](notes/2026-10-08-tool-environment.md)：两台机器与 NFS 共享工作流。
- 2026-10-09：确认采用弹性学习节奏；完成 FIFO 状态分析、最小 SVA 和 MMIO/CSR 预习。
