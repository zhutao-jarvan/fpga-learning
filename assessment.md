# FPGA Capability Assessment

## Background

- Approximately 20 years of software engineering experience.
- Strong background in network software, Linux kernel, drivers, DPDK, and high-performance networking.
- Beginner in FPGA RTL development.
- Goal: become practically productive in FPGA development, especially networking-related FPGA work, rather than becoming an FPGA specialist.

## RTL

- D flip-flop behavior: understood.
- `always_ff @(posedge clk)`: understood.
- Nonblocking assignment (`<=`) in sequential logic: understood.
- RHS/LHS meaning in assignment statements: understood.
- Nonblocking assignments read old values and update registers together at the clock event: understood.
- Combinational vs. sequential logic: understood.
- Basic 2:1 mux RTL: understood.
- Why incomplete combinational assignments can infer a latch: understood.
- Basic pipeline behavior across multiple registers: understood.
- Basic clock-cycle latency: understood.
- Blocking assignment behavior has been seen; sequential RTL normally uses nonblocking assignment.

## Timing

- Setup time: understood.
- Hold time: understood.
- Clock-to-Q: understood.
- Clock skew: understood.
- Jitter: understood.
- Basic register-to-register timing: understood.
- Basic maximum-frequency calculation: understood.
- For a simple combinational path `clock -> FF -> combinational logic -> FF`, the clock period must accommodate the relevant propagation delay, ignoring setup/hold when explicitly stated.
- The user understands the distinction between when a receiving flip-flop's output becomes valid and when its input must satisfy setup/hold.

## Interfaces

- AXI-Stream: introductory / currently learning.
- FIFO: introductory / currently learning.
- QSFP: introductory familiarity.
- Ready/valid and backpressure should be learned through practical AXI-Stream exercises.

## Verification / tooling

- SystemVerilog: learning.
- VCS: learning.
- Verdi: learning.
- UVM: not yet deeply involved.
- Main UVM framework will be provided/developed by colleagues.

## Practical learning status (Q12-Q40)

- FIFO basics: understood occupancy/count semantics, empty/full conditions, and the difference between current state and next-state behavior.
- FIFO edge cases: understood that simultaneous read/write can leave occupancy unchanged in a given design, but count updates should be implemented with clear, explicit state logic rather than relying on ambiguous multiple assignments.
- AXI-Stream handshake: understood `transfer = TVALID && TREADY`; `TVALID` is source-side validity, `TREADY` is sink-side readiness, and a transfer only occurs when both are high.
- Backpressure/stall: understood that when `TVALID=1` and `TREADY=0`, the current beat must remain stable across cycles until the sink accepts it.
- TLAST: understood that `TLAST` marks the last beat of a packet, but the last beat still requires `TVALID && TREADY` to complete the transfer.
- TKEEP: understood that `TKEEP` marks valid byte lanes in a beat; for a 64-bit AXIS interface, 1500-byte packet requires 188 beats, with a last beat potentially containing only a few valid bytes.
- FIFO-to-AXIS model: understood the simple hardware pattern `tvalid = !empty` and `read_en = tvalid && tready`, with stable output data when no transfer occurs.
- Current practical assessment: established basic FIFO and AXI-Stream valid/ready handshake intuition; able to reason about backpressure, TLAST, TKEEP, and stable-beat behavior in simple hardware timing flows.
- These concepts are mainly understood through Q&A and timing reasoning; they still need consolidation through actual RTL, testbench, VCS simulation, and Verdi waveform observation.

## Current learning gaps

- More RTL practice.
- FSM design.
- Reset design.
- CDC.
- Synchronous and asynchronous FIFO.
- AXI / AXI-Stream handshake semantics.
- Pipeline and throughput design.
- Synthesis.
- Static timing analysis and timing closure.
- Simulation / testbench methodology.
- VCS / Verdi practical workflow.
- FPGA architecture and resources.
- Networking-oriented FPGA datapaths.
- UVM participation.

## Assessment checkpoint

- Q1-Q40 completed.
- The next stage begins with AXI-Stream/FIFO RTL practical work.
- The user prefers the assessment to proceed one question at a time, but the current learning-state record is now updated to reflect the practical understanding gained through Q12-Q40.