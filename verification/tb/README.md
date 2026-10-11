# axis_fifo_tb.sv

该 testbench 验证 32-bit、深度为 4 的 AXI-Stream 同步 FIFO，包括数据顺序、
`TLAST`、FIFO 边界、反压和输出稳定性。以下命令均从仓库根目录执行。

编译：

```sh
mkdir -p vcs_build/axis_fifo_tb
vcs -full64 -sverilog -kdb -debug_access+all -timescale=1ns/1ps \
  +define+ENABLE_FSDB \
  -top axis_fifo_tb \
  -Mdir=vcs_build/axis_fifo_tb/csrc \
  -o vcs_build/axis_fifo_tb/simv \
  -l vcs_build/axis_fifo_tb/compile.log \
  rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_tb.sv
```

仿真：

```sh
./vcs_build/axis_fifo_tb/simv \
  +fsdbfile=vcs_build/axis_fifo_tb/axis_fifo.fsdb \
  -l vcs_build/axis_fifo_tb/sim.log
```

预期结果：

```text
PASS: AXI-Stream FIFO checks passed (46 beats)
```

使用 Verdi 打开波形：

```sh
verdi -kdb \
  -simdir vcs_build/axis_fifo_tb/csrc \
  -ssf vcs_build/axis_fifo_tb/axis_fifo.fsdb
```

# axis_fifo_fsm_tb.sv

该 testbench 定向检查 FIFO 内部包状态机的状态转换、状态保持和同步复位。
以下命令均从仓库根目录执行。

编译：

```sh
mkdir -p vcs_build/axis_fifo_fsm_tb
vcs -full64 -sverilog -kdb -debug_access+all -timescale=1ns/1ps \
  +define+ENABLE_FSDB \
  -top axis_fifo_fsm_tb \
  -Mdir=vcs_build/axis_fifo_fsm_tb/csrc \
  -o vcs_build/axis_fifo_fsm_tb/simv \
  -l vcs_build/axis_fifo_fsm_tb/compile.log \
  rtl/fifo/axis_fifo.sv verification/tb/axis_fifo_fsm_tb.sv
```

仿真：

```sh
./vcs_build/axis_fifo_fsm_tb/simv \
  +fsdbfile=vcs_build/axis_fifo_fsm_tb/axis_fifo_fsm.fsdb \
  -l vcs_build/axis_fifo_fsm_tb/sim.log
```

预期结果：

```text
PASS: directed FSM transition check passed
```

使用 Verdi 打开波形：

```sh
verdi -kdb \
  -simdir vcs_build/axis_fifo_fsm_tb/csrc \
  -ssf vcs_build/axis_fifo_fsm_tb/axis_fifo_fsm.fsdb
```

# axi_lite_csr_tb.sv

该 testbench 正在用于开发最小 AXI4-Lite CSR 写路径，重点观察独立的 AW/W
握手和 B 响应。以下命令均从仓库根目录执行。

## 当前运行前提

`cur-run.log` 显示 VCS 编译已经成功。仿真长时间运行而不结束，是因为当前 TB
中的 `clk` 和 `rst` 没有初值：`clk` 从 `X` 开始时，`~clk` 仍然是 `X`，因此
不会产生有效的时钟上升沿。运行前应先在 TB 中明确初始化：

```systemverilog
logic clk = 1'b0;
logic rst = 1'b1;
```

当前 TB 在等待写响应之前还有一个中途的 `$finish`。初始化时钟和复位后，还应
将这个 `$finish` 移到全部激励及 PASS/FAIL 检查之后，否则后面的检查不会执行。
在这些条件修正之前，不应期待该 testbench 打印 PASS。

编译：

```sh
mkdir -p vcs_build/axi_lite_csr_tb
vcs -full64 -sverilog -kdb -debug_access+all -timescale=1ns/1ps \
  +define+ENABLE_FSDB \
  -top axi_lite_csr_tb \
  -Mdir=vcs_build/axi_lite_csr_tb/csrc \
  -o vcs_build/axi_lite_csr_tb/simv \
  -l vcs_build/axi_lite_csr_tb/compile.log \
  rtl/csr/axi_lite_csr.sv verification/tb/axi_lite_csr_tb.sv
```

仿真：

```sh
./vcs_build/axi_lite_csr_tb/simv \
  +fsdbfile=vcs_build/axi_lite_csr_tb/axi_lite_csr.fsdb \
  -l vcs_build/axi_lite_csr_tb/sim.log
```

使用 Verdi 打开波形：

```sh
verdi -kdb \
  -simdir vcs_build/axi_lite_csr_tb/csrc \
  -ssf vcs_build/axi_lite_csr_tb/axi_lite_csr.fsdb
```

`+define+ENABLE_FSDB` 启用 testbench 中的 FSDB dump 代码，运行时的
`+fsdbfile=<path>` 用于指定输出文件。若编译时不定义 `ENABLE_FSDB`，testbench
会改用 `$dumpfile` 和 `$dumpvars` 生成 VCD fallback。
