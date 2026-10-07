# FPGA session note - 2026-10-07

## What was learned today

- FIFO occupancy/count semantics and empty/full conditions.
- AXI-Stream valid/ready handshake and backpressure.
- Stall behavior: current beat must remain stable while `TVALID=1` and `TREADY=0`.
- TLAST semantics and how the final beat still requires a valid transfer.
- TKEEP semantics for byte-lane validity on a 64-bit AXIS interface.
- Simple FIFO-to-AXIS dataflow model using `tvalid` and `read_en`.

## What is already understood

- Basic FIFO state reasoning.
- Basic AXI-Stream transfer timing intuition.
- The difference between current state and next-state behavior.
- Why stall/backpressure matters for source-side data stability.

## What is still missing

- RTL implementation of FIFO/AXIS flows.
- Practical testbench validation.
- VCS/Verdi waveform-driven confirmation.
- More complete understanding of CDC, reset, and interface robustness.

## Next step

**AXI-Stream FIFO RTL → testbench → VCS → Verdi waveform**
