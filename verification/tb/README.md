# AXI-Stream FIFO exercise

This testbench drives a 32-bit, depth-4 synchronous FIFO through two phases:

- six beats with `m_axis_tready` continuously high;
- forty beats with deterministic ready deassertions to create backpressure.

The scoreboard checks ordering, `TLAST`, empty/full indications, reset, and
that output data remains stable while `m_axis_tvalid=1` and `m_axis_tready=0`.

The repository is edited on one machine and simulated on an NFS-shared server.
The primary learning workflow is VCS for compilation/simulation, FSDB for
waveform output, and Verdi for waveform analysis. Run the following commands
on the VCS/Verdi server from the same NFS-shared repository root:

```sh
rm -rf vcs_build
mkdir -p vcs_build
vcs -full64 -sverilog -kdb -debug_access+all -timescale=1ns/1ps \
  +define+ENABLE_FSDB \
  -top axis_fifo_tb \
  -Mdir=vcs_build/csrc \
  -o vcs_build/simv \
  rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_tb.sv
./vcs_build/simv +fsdb +fsdbfile=vcs_build/axis_fifo.fsdb \
  -l vcs_build/sim.log
```

The `rm -rf vcs_build` command only removes the generated VCS build directory
for this exercise. Do not use it with a broader path.

The expected result is:

```text
PASS: AXI-Stream FIFO checks passed (46 beats)
```

The expected waveform is `vcs_build/axis_fifo.fsdb`. Open it with Verdi and
associate the VCS debug directory:

```sh
verdi -kdb -simdir vcs_build/csrc -ssf vcs_build/axis_fifo.fsdb
```

The current testbench also accepts a different FSDB filename:

```sh
./vcs_build/simv +fsdbfile=vcs_build/axis_fifo_backpressure.fsdb \
  -l vcs_build/backpressure.log
```

`ENABLE_FSDB` selects `$fsdbDumpfile`, `$fsdbDumpvars`, and `$fsdbDumpMDA` in
the testbench. If VCS reports that these FSDB system tasks are unavailable,
load the VCS/Verdi PLI setup provided by the server before compiling. The
exact PLI path depends on the installed Verdi version.

Without `+define+ENABLE_FSDB`, the testbench writes `axis_fifo.vcd` through
`$dumpfile/$dumpvars`. This is retained only as a portable fallback and is not
the waveform format used in subsequent learning examples.

Useful signals to add in Verdi are `s_axis_tvalid`,
`s_axis_tready`, `m_axis_tvalid`, `m_axis_tready`, `m_axis_tdata`,
`m_axis_tlast`, and the internal `dut.occupancy`, `dut.wr_ptr`, and `dut.rd_ptr`.
