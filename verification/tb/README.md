# AXI-Stream FIFO exercise

This testbench drives a 32-bit, depth-4 synchronous FIFO through two phases:

- six beats with `m_axis_tready` continuously high;
- forty beats with deterministic ready deassertions to create backpressure.

The scoreboard checks ordering, `TLAST`, empty/full indications, reset, and
that output data remains stable while `m_axis_tvalid=1` and `m_axis_tready=0`.

The repository is edited on one machine and simulated on an NFS-shared server.
The primary workflow is VCS plus Verdi; Icarus is provided for a quick local
check when VCS is not available.

## Quick local check with Icarus

Run from the repository root:

```sh
mkdir -p build
iverilog -g2012 -s axis_fifo_tb -o build/axis_fifo_tb \
  rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_tb.sv
vvp build/axis_fifo_tb
```

## Primary VCS simulation

On the VCS server, run from the same NFS-shared repository root:

```sh
rm -rf vcs_build
mkdir -p vcs_build
vcs -full64 -sverilog -debug_access+all \
  -top axis_fifo_tb \
  -o vcs_build/simv \
  rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_tb.sv
./vcs_build/simv -l vcs_build/sim.log
```

The expected result is:

```text
PASS: AXI-Stream FIFO checks passed (46 beats)
```

The current testbench writes `axis_fifo.vcd`. GTKWave can open it directly:

```sh
gtkwave axis_fifo.vcd
```

When the VCS/Verdi environment is configured for FSDB, replace the VCD dump
calls in the testbench with `$fsdbDumpfile`/`$fsdbDumpvars`, then inspect the
result with:

```sh
verdi -ssf axis_fifo.fsdb
```

Useful signals to add in Verdi or GTKWave are `s_axis_tvalid`,
`s_axis_tready`, `m_axis_tvalid`, `m_axis_tready`, `m_axis_tdata`,
`m_axis_tlast`, and the internal `dut.occupancy`.
