# AGENTS.md

## Repository purpose

This repository is a long-term FPGA learning project for an experienced software and networking engineer who is relatively new to FPGA RTL development.

The goal is not to become an FPGA expert in isolation. The goal is to become productive enough to participate effectively in practical FPGA development, especially FPGA work connected to networking.

## User background

- Approximately 20 years of software engineering experience.
- Strong background in:
  - network software
  - Linux kernel
  - device drivers
  - DPDK
  - high-performance networking
- Currently learning FPGA development.
- Main technologies to learn:
  - SystemVerilog RTL
  - VCS
  - Verdi
  - UVM
- Colleagues will provide or develop the main UVM framework.
- Long-term interest: networking-oriented FPGA development.

## Learning goals

This repository is intended to support progressive, practical learning over roughly six months.

The work should emphasize:
- practical examples over long theoretical explanations
- understanding hardware behavior and timing, not just syntax
- small and understandable examples
- standard synthesizable RTL patterns
- realistic verification and waveform analysis
- gradual exposure to timing, CDC, FIFO, AXI/AXI-Stream, pipeline, and verification concepts
- connection of FPGA concepts to networking concepts whenever useful

## Learning principles

When helping with this repository:

1. Prefer practical examples over long theoretical explanations.
2. Explain hardware behavior and timing, not only SystemVerilog syntax.
3. Keep examples small and understandable.
4. Avoid unnecessary abstraction and over-engineering.
5. Prefer standard synthesizable SystemVerilog RTL.
6. Use nonblocking assignments for sequential logic.
7. Every meaningful RTL exercise should eventually have a testbench.
8. Use simulation and waveform analysis to understand behavior.
9. Gradually introduce timing, CDC, FIFO, AXI/AXI-Stream, pipeline, and verification concepts.
10. Connect FPGA concepts to networking concepts whenever useful.
11. Do not introduce UVM complexity before the basic RTL/testbench concepts are understood.
12. Preserve the user's existing learning notes and assessment history.
13. Do not silently make large structural changes to the repository.
14. When a task is educational, explain important design decisions instead of only providing code.

## Working style for new learning exercises

For new learning exercises:

1. First explain the goal.
2. Identify the FPGA concepts involved.
3. Implement the smallest reasonable example.
4. Add a testbench when appropriate.
5. Explain expected waveform and timing behavior.
6. Run available checks or simulations.
7. Summarize what was learned.
8. Update learning notes only when explicitly requested or when the task clearly calls for it.

## Important constraint

Do not assume the user wants production-quality or highly parameterized RTL for every exercise.

The primary objective is learning practical FPGA development through progressively more realistic examples.

## Repository conventions

- Use `learning-plan.md` for the roadmap and `learning-progress.md` for current
  overall status, completion evidence, remaining gaps, and the next task.
- Plan against 1–2 hours/day (10–15 hours/week), but advance by demonstrated
  understanding and exercise deliverables, not calendar months. When time is
  abundant, arrange later-stage work as soon as prerequisites are met; allow
  pauses and resume with a focused review of the last exercise.
- Treat the 10–15 hours/week figure as a planning baseline, not a deadline or
  fixed amount of progress. First-time exercises involving new SystemVerilog
  syntax, state machines, reset behavior, or waveform debugging may take
  multiple sessions; use observed effort to recalibrate later estimates.
- Once the user has demonstrated understanding with code, waveform evidence,
  or a correct explanation, do not repeatedly re-confirm the same point unless
  a new change introduces a relevant risk.
- Preserve daily notes and assessment history; do not infer mastery from elapsed
  time or generated simulation artifacts alone.

- Keep the repository structure modest and understandable.
- Preserve existing files such as README, assessment notes, the learning plan, and cheatsheet.
- Favor small, focused modules and exercises.
- Prefer direct learning value over broad framework creation.
- Do not commit or push changes unless explicitly requested.

## Guidance for future tasks

When creating or modifying contents in this repository:
- keep explanations grounded in practical FPGA engineering
- make examples readable for someone with a software engineering background
- relate digital logic and RTL to debugging, interfaces, and performance-oriented design
- treat networking use cases as important motivation, but keep exercises understandable and self-contained

## Summary

This repository should be treated as a practical FPGA learning workspace for a software/networking engineer becoming productive in RTL design, simulation, verification, and eventually networking-related FPGA development.
