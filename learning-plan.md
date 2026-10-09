# Learning Plan

This file contains high-level learning goals and milestones for FPGA study.

- Topics: digital logic, RTL design, timing, clock domain crossing (CDC), FIFOs, verification (UVM), synthesis, implementation.
- Milestones: complete basic RTL exercises, build and verify simple projects, learn FPGA toolflow.

## Six-month practical roadmap

The roadmap targets practical participation in an industry FPGA networking team.
It records only general industry techniques and deliberately avoids product-specific
architecture, register maps, module names, addresses, and implementation details.

### 时间基准与实际推进方式

本路线以每天约 1–2 小时、每周约 10–15 小时的有效学习时间为规划基准。
“六个月”表示约 26 个学习周，总投入粗估约 260–390 小时，用于判断内容规模，
不是固定的日历截止日期，也不是必须完成的计时指标。

下文的 Month 1–6 同时代表阶段 1–6，每个阶段约按 4–5 个学习周安排。
实际执行以先修能力、练习结果和阶段交付物为依据：

- 时间充裕时（例如每天可投入 8 小时），可以在同一个日历月学习原第二、
  第三个月的内容。完成必要基础后直接推进，不等日历翻月；额外时间用于
  编写 RTL、补充测试、看波形和独立复现，不能仅凭阅读时长认定掌握。
- 工作繁忙时允许暂停半个月至一个月，暂停期间不累计学习周，也不视为落后。
  恢复时先复现最近练习、回顾关键波形与未解决问题，再接着当前任务推进。
- 各阶段核心交付物仍是完成依据。可以提前预习后续主题，但预习不等于阶段完成；
  对尚未覆盖的 FSM、复位等基础保留补齐任务。
- 每次安排学习前，先查看当前状态和可用时间，再给出可在当次完成的小任务；
  时间充足则连续安排后续任务，避免把每日任务固定成 1–2 小时上限。

计划内容和先修顺序保存在本文件；实际完成证据、当前任务、暂停/恢复位置和
下一步统一保存在 [learning-progress.md](learning-progress.md)。每日细节保存在
`notes/`，能力评估历史保存在 `assessment.md`，不在计划里重复维护进度勾选。

### 近期阶段推进门槛

| 推进方向 | 进入条件 | 下一项实践 |
| --- | --- | --- |
| 阶段 1 → 阶段 2 | 能逐拍解释 FIFO 握手、状态更新和反压；独立完成一次小 RTL 修改及自检测试；完成 MMIO/CSR 预览 | 先定义少量 RW/RO 寄存器，再实现最小 AXI4-Lite 读写路径并测试 |
| 阶段 2 → 阶段 3 | 小寄存器块通过复位、独立 AW/W、字节使能、响应反压及非法地址测试；能解释寄存器副作用 | 从双触发器电平同步开始，再推进 pulse/toggle、多位握手和异步 FIFO |

独立运行测试并解释结果，比学习了多少小时更能说明是否可以推进。
第二阶段可以提前预习，第三阶段的 CSR 跨域综合练习应建立在寄存器接口实践之上。

### Priority levels

The goal is not equal mastery of every topic.

- Be able to implement and debug: synchronous RTL, ready/valid streaming, FIFOs,
  basic AXI4-Lite CSR blocks, common CDC patterns, and focused testbenches.
- Be able to read and discuss: full AXI4, Avalon-MM/Avalon-ST-style buses,
  interconnect and protocol bridges, PCIe MMIO, Ethernet MAC data paths, and
  external-memory interfaces.
- Be able to use with team support: UVM environments, vendor IP, synthesis,
  timing constraints, regression, and CI flows.

### Month 1: RTL timing, simulation, and waveform literacy

Focus:

- synthesizable combinational and sequential SystemVerilog;
- clocked behavior, synchronous reset, nonblocking assignments, and event regions;
- finite-state machines, counters, memories, and simple pipelines;
- AXI-Stream-style valid/ready handshakes, TLAST, and backpressure;
- synchronous FIFO state, simultaneous push/pop, pointer wrap, and boundary cases;
- small self-checking testbenches, scoreboards, VCS, and Verdi waveform analysis;
- basic use of SystemVerilog packages, interfaces, and modports when reading code.

Deliverable:

- explain a FIFO transaction cycle by cycle from both RTL and waveform;
- modify a small RTL block and add a focused self-checking testbench;
- before Month 2, complete a short MMIO/CSR preview covering address, read,
  write, byte enable, response, and register reset value.

### Month 2: Debug-register and control-plane interfaces

This topic is intentionally moved forward because near-term work may require
software, RTL, and verification engineers to agree on debug-register interfaces.

Protocol skills:

- AXI4-Lite read and write channels, including independent AW/W handshakes;
- valid/ready stability, response channels, backpressure, and one-outstanding
  transaction implementations;
- byte addressing, alignment, endianness, `WSTRB`, data-width conversion, and
  unsupported-address/error responses;
- address decode, local offsets, module windows, mux/demux, arbitration, and the
  purpose of bridges to other lightweight memory-mapped buses.

Register-design skills:

- specify register name, offset, field bits, access type, reset value, clock
  domain, owner, side effects, and description before writing RTL;
- understand RW, RO, write-one-to-clear, write-one-to-set, self-clearing command,
  sticky status, pulse/event, counter, snapshot, and shadow-register semantics;
- define overflow behavior for counters: wrap, saturate, or sticky overflow;
- handle clear and increment in the same cycle with an explicitly documented
  priority rule;
- define coherent access to values wider than the software-visible bus, including
  snapshot/latch rules instead of assuming two reads are atomic;
- distinguish configuration, live status, event history, statistics, error cause,
  and error injection registers;
- reserve address space and bits for compatibility, and provide version/capability
  discovery where useful.

Cross-module and software-contract skills:

- define a stable block-level CSR contract so each RTL module owns local registers
  while a top-level control path owns routing and address allocation;
- agree on reset behavior, access latency, timeouts, ordering, concurrent access,
  invalid access, and CDC behavior;
- treat register documentation as an ABI shared by RTL, verification, drivers,
  diagnostics, and user-space tools;
- keep a single structured register description when the team has generation
  support, and generate or mechanically check RTL constants, software headers,
  documentation, and verification expectations;
- review interfaces using examples of complete read, write, clear, snapshot,
  timeout, and error sequences.

Verification skills:

- write directed tests for reset values, legal reads/writes, byte enables,
  read-only protection, side effects, invalid addresses, and backpressure;
- use a reference model/scoreboard for register state;
- introduce simple SVA for local protocol and register invariants without
  introducing a full UVM environment prematurely;
- debug one transaction end to end in Verdi from bus request through address
  decode to the target register and response.

Deliverable:

- a small reusable AXI4-Lite register bank with two or more access types;
- a concise generic register specification and software-visible header/example;
- a soft/RTL/verification interface-review checklist and passing directed tests.

### Month 3: CDC, reset, and asynchronous buffering

Focus:

- metastability and why RTL simulation does not model it directly;
- two-flop synchronization for levels, pulse/toggle transfer, and handshake-based
  multi-bit transfer;
- asynchronous FIFOs, Gray-coded pointers, full/empty detection, and reset release;
- moving configuration, status, counters, and clear commands between CSR and
  functional clock domains;
- CDC constraints and tool reports at an introductory level.

Deliverable:

- implement and verify representative single-bit, pulse, multi-bit, and async-FIFO
  crossings, and explain why each pattern is safe for its payload.

### Month 4: Networking data paths and performance-oriented RTL

Focus:

- packet-oriented streaming, SOP/EOP or TLAST metadata, empty/keep information,
  and error metadata;
- skid buffers, register slices, arbitration, mux/demux, width adaptation, packet
  FIFOs, packet drop policy, and flow control;
- latency versus throughput, one-beat-per-cycle operation, combinational ready
  paths, and pipeline placement;
- introductory full AXI4 concepts: separate channels, bursts, IDs, ordering, and
  outstanding transactions;
- reading Ethernet MAC, PCIe streaming/MMIO, and external-memory interfaces as
  system integration boundaries rather than attempting to master every IP block.

Deliverable:

- build and verify a small packet pipeline that sustains continuous traffic,
  propagates backpressure, preserves packet boundaries, and exposes useful CSRs.

### Month 5: Scalable verification and team workflows

Focus:

- SVA sequences/properties for handshake stability, bounds, and request/response;
- functional coverage and identifying untested boundary scenarios;
- UVM transaction, sequence, driver, monitor, scoreboard, agent, environment,
  and test concepts;
- use and extend an existing team UVM framework rather than building one from zero;
- VCS filelists, compile/elaboration/run separation, Verdi/KDB/FSDB debug,
  regressions, reproducible seeds, and failure triage;
- protocol VIP and bus-functional models at a practical integration level.

Deliverable:

- add a focused testcase, checker/assertion, and coverage point to an existing
  verification environment and independently triage a failing regression.

### Month 6: Synthesis, timing, and an integrated capstone

Focus:

- FPGA memories, vendor IP integration, synthesis reports, and resource tradeoffs;
- clocks, generated clocks, setup/hold, timing exceptions, and timing closure basics;
- build automation, CI, hardware smoke tests, and software/hardware bring-up;
- integrated debug using waveforms, CSRs, counters, sticky error state, and packet
  observations.

Deliverable:

- complete a small networking-oriented design containing a streaming data path,
  buffering/backpressure, at least one CDC boundary, a software-visible debug CSR
  block, focused assertions/testbench coverage, and a basic synthesis/timing report.

## Register-interface review checklist

Use this checklist when software, RTL, and verification engineers define a debug
register interface:

1. What diagnostic question does each field answer, and who owns its definition?
2. Are address, width, alignment, endianness, access type, and reset value explicit?
3. What exactly causes a counter/event bit to update, clear, overflow, or saturate?
4. What happens when hardware updates a field in the same cycle software clears it?
5. Are multiword values coherent, or is a snapshot/latch protocol required?
6. Is the register in another clock or reset domain, and what CDC mechanism is used?
7. What response is returned for invalid, unsupported, misaligned, or timed-out access?
8. Are reserved bits and future-compatible address gaps defined?
9. Can software discover interface version and capabilities?
10. Do RTL, verification, documentation, and software constants share one source
    or have an automated consistency check?
11. Are production-safe observation controls separated from disruptive debug or
    error-injection controls?
12. Is there a minimal read/write/clear/snapshot/error test plan agreed before RTL
    and driver implementation diverge?

## Tool workflow

The repository is edited on a machine with VS Code and ChatGPT, while a second
NFS-shared server provides VCS and Verdi. Use VCS/Verdi as the primary
compile, simulation, and waveform-debug workflow. Open-source simulators such
as Icarus Verilog are useful for quick local checks, but are supplementary.
See `notes/2026-10-08-vcs-verdi-workflow-patterns.md` for common VCS/Verdi
arguments and the distinction between portable options and project-specific
configuration.
