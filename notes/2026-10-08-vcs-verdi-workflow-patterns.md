# VCS/Verdi 工程化工作流记录 - 2026-10-08

本记录总结大型 SystemVerilog/UVM 工程中常见的 VCS 和 Verdi 参数模式。
重点是可迁移的工作方法，不记录具体工程的路径、测试名或专用宏。

## 推荐的分层流程

大型验证工程通常分成四步：

1. 用 `vlogan` 编译 RTL、testbench、UVM package 和 filelist；
2. 用 `vcs` 完成 elaboration，生成 `simv`；
3. 运行 `simv`，传入 testcase、运行参数和波形开关；
4. 用 Verdi 打开 FSDB，并使用与 elaboration 对应的 `csrc`/KDB 信息进行源码和层次调试。

将编译输出放到每个 testcase 的独立目录，可以避免不同回归任务互相覆盖日志、`simv`、`csrc`、`ucli.key` 和 FSDB。

## 常见的 vlogan 参数

```sh
vlogan -full64 -sverilog -kdb \
  -timescale=1ns/1ps \
  +incdir+<uvm_include_dir> \
  <uvm_pkg.sv> -f <filelist.f> -l vlogan.log
```

- `-full64`：使用 64 位编译/仿真模式；
- `-sverilog`：启用 SystemVerilog 语法；
- `-kdb`：生成供 Verdi/KDB 调试的设计数据库，常和 `-debug_access+all` 配合；
- `-timescale=1ns/1ps`：统一没有显式 `` `timescale`` 的源文件的时间单位/精度；
- `+incdir+...`：增加 `` `include`` 和 package 搜索目录；
- `-f filelist.f`：从 filelist 读取源文件和编译选项；
- `-l`：保存编译日志。

`+define+MACRO=value` 很常见，用于在编译期选择板卡数量、数据宽度或仿真模式。它是 compile-time configuration，不等同于运行时 `+ARG=value`。

UVM 工程常显式编译 `uvm_pkg.sv`，并通过 `+define+UVM_NO_DPI` 关闭不需要的 DPI；这些选项只适用于相应的 UVM/环境配置，不应机械加入小型 RTL 仿真。

## 常见的 VCS elaboration 参数

```sh
vcs -full64 -sverilog -kdb -debug_access+all \
  -top <tb_top> \
  -Mdir=csrc \
  -o simv \
  -l vcs.log
```

- `-top <tb_top>`：指定仿真顶层；大型工程中显式指定更可靠；
- `-Mdir=csrc`：指定 VCS 中间文件目录，便于按 testcase 隔离；
- `-o simv`：指定仿真可执行文件名；
- `-l vcs.log`：保存 elaboration 日志；
- `-debug_access+all`：为 Verdi 提供较完整的信号访问和调试能力，代价是编译时间、仿真性能和数据库大小增加；
- `-kdb`：生成 Verdi 的设计数据库信息。

`-assert svaext` 是启用扩展 SVA 支持的常见选择，但只有工程使用相应断言时才需要。`-ignore initializer_driver_checks` 属于特定工程的兼容选项，不应作为默认参数。

## 常见的 simv 运行参数

```sh
./simv \
  +UVM_TESTNAME=<test_name> \
  +fsdb +fsdbfile=<wave.fsdb> \
  -l <test_name>.log
```

- `+UVM_TESTNAME=...`：UVM 常见的 testcase 选择方式；
- `-l ...`：保存该 testcase 的运行日志；
- `+fsdb`、`+fsdbfile=...`：一种常见的运行时波形开关约定，但前提是 testbench、PLI 或工程封装代码实际解析这些 plusarg；VCS 不会仅因这两个参数就保证生成 FSDB；
- 若 testbench 直接调用 `$fsdbDumpfile`/`$fsdbDumpvars`，波形文件名和开关行为应以 testbench 代码为准。

波形文件应放在 testcase 输出目录中，避免多个仿真同时写同一个 FSDB。

## 常见的 Verdi 参数

```sh
verdi -kdb -simdir csrc -ssf <wave.fsdb>
```

- `-ssf`：打开指定 FSDB；
- `-simdir csrc`：指定与 VCS elaboration 对应的仿真调试目录，使源码、层次和信号关联更完整；
- `-kdb`：使用 VCS 生成的 KDB 调试信息。

只有 VCD 的小型练习可以使用：

```sh
verdi -vcd <wave.vcd>
```

VCD 可用于基本波形观察，但相较于带 KDB 的 FSDB，源码跳转、层次关联和调试信息通常较少。

## 常见的库映射方式

VCS 从工作目录读取 `synopsys_sim.setup` 很常见。典型内容会将 `DEFAULT`、`work` 和厂商/第三方库映射到当前 testcase 的工作目录或共享库目录。这样可以让 `vlogan` 和 `vcs` 使用同一套库映射、隔离每个 testcase 的 `work/`，并复用只需编译一次的厂商模型库。

具体库名、路径和 `LIBRARY_SCAN` 设置取决于工程，不应复制到通用练习中。

## 工程化经验

- 编译日志、elaboration 日志、运行日志和 FSDB 应分别保留；
- testcase 目录隔离比把所有产物放在脚本目录更适合回归和并行运行；
- `filelist.f` 负责源文件集合，Makefile/脚本负责参数和流程，testbench 负责事务、检查和波形调用；
- Verdi 诊断问题时，`-kdb`、`-debug_access+all`、`-Mdir` 和 `-simdir` 是一组相关选项；
- FSDB 能否生成取决于 testbench/PLI 配置，不能仅凭 `verdi -ssf` 命令推断；
- `clean` 脚本应只删除明确的 testcase 输出目录，避免误删共享库或其他回归结果。

## 对当前学习项目的适用方式

当前小型 FIFO 可以继续使用单条 VCS 命令直接编译；进入 UVM、多个 testcase 和回归阶段后，再引入 `filelist.f`、独立 `sim_output/<testcase>/`、`synopsys_sim.setup`、FSDB 运行开关和 Verdi `-simdir`。不要为了模仿大型工程而提前加入厂商库、UVM DPI 或复杂 Makefile。
