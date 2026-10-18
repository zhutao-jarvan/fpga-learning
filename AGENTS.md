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

This repository is intended to support six progressive core stages followed by
two adaptive reinforcement stages, with roughly eight months as a scale estimate
rather than a fixed deadline.

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

## AI-assisted learning and exercise selection

Use three exercise modes according to learning value:

1. From-scratch construction for a new, important hardware mechanism.
2. Guided completion where a scaffold is provided and the user implements the
   key state, handshake, boundary, or checking logic.
3. Reading and debugging where the user predicts, reviews, verifies, and makes
   focused changes to existing code.

Do not require every RTL module or testbench to start from an empty file. A new
critical mechanism should still be constructed in one small example. Prefer
from-scratch work for ready/valid behavior, reset, FSMs, FIFO boundaries, CDC,
CSR access semantics, pipeline stalls, arbitration, and other areas that are
high-risk, commonly error-prone, repeatedly misunderstood by the user, or whose
cycle-by-cycle behavior the user cannot yet predict.

Once understanding has been demonstrated, use scaffolds and existing code
instead of repeating syntax, boilerplate, or mechanical expansion. AI may
provide port scaffolding, repetitive logic, basic testbench tasks, build scripts,
and reference implementations. The user should continue to own specification
reasoning, state and timing analysis, boundary cases, waveform prediction, code
review, and focused behavioral changes.

Before starting a new exercise that the user did not build from scratch, briefly
explain its goal, main modules, key data/control paths, the user's task,
explicit non-goals, and acceptance method, in proportion to the exercise's
complexity. Ask focused questions only when the answers could change the design,
timing expectations, or acceptance checks, or reveal a meaningful gap in the
user's understanding. There is no fixed question count; skip questions when
prior code, explanations, or waveform evidence already establish the needed
understanding. Do not pause implementation for routine testcases, small features,
or edits within an established exercise. Revisit only the parts affected by a
material change in scope or a newly observed misunderstanding.

AI-generated code is not accepted merely because it compiles. It must be
explained, simulated, checked, and inspected in waveforms in proportion to its
risk. Measure understanding by the ability to explain design choices,
cycle-by-cycle behavior, failure modes, and the impact of a change, rather than
by authorship or lines of code.

## Engineering-pattern review

After each complete exercise or meaningful sub-goal has passed its stated
checks, add a short engineering-oriented explanation covering:

1. The design pattern or engineering technique demonstrated.
2. The problem it solves and why engineering teams use it.
3. Its key invariants, tradeoffs, and common mistakes.
4. What the educational implementation omits compared with production RTL.
5. Where it appears in networking data paths, control planes, drivers, or debug.

Do not repeat this review after every small edit or code-review iteration. Add
it when a complete learning objective has evidence, and record it in the
corresponding learning note when that exercise calls for a note.

## Working style for new learning exercises

For new learning exercises:

1. First explain the goal.
2. Identify the FPGA concepts involved.
3. Select the from-scratch, guided-completion, or reading-and-debugging mode and
   explain why it fits the learning goal.
4. Construct, complete, or review the smallest reasonable example for that mode.
5. Add or adapt a testbench when appropriate.
6. Explain expected waveform and timing behavior.
7. Run available checks or simulations.
8. Summarize what was learned and, after a completed objective, explain the
   applicable engineering pattern.
9. Update learning notes only when explicitly requested or when the task clearly calls for it.

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
