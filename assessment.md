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

- Interactive FPGA capability assessment completed through Q11.
- The user prefers the assessment to proceed one question at a time.
- The next assessment question should be Q12.