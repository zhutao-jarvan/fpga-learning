# Learning Plan

This file contains high-level learning goals and milestones for FPGA study.

- Topics: digital logic, RTL design, timing, clock domain crossing (CDC), FIFOs, verification (UVM), synthesis, implementation.
- Milestones: complete basic RTL exercises, build and verify simple projects, learn FPGA toolflow.

## Tool workflow

The repository is edited on a machine with VS Code and ChatGPT, while a second
NFS-shared server provides VCS and Verdi. Use VCS/Verdi as the primary
compile, simulation, and waveform-debug workflow. Open-source simulators such
as Icarus Verilog are useful for quick local checks, but are supplementary.
See `notes/2026-10-08-vcs-verdi-workflow-patterns.md` for common VCS/Verdi
arguments and the distinction between portable options and project-specific
configuration.
