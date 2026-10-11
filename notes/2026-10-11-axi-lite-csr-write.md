# AXI4-Lite CSR 写路径起步 - 2026-10-11

## 学习目标

从 AXI-Stream 的 ready/valid 经验过渡到最小 AXI4-Lite CSR，先单独实现并观察
AW、W、B 三个写通道。练习只支持一笔未完成事务，不引入 UVM、CDC、burst
或复杂寄存器副作用。

本次学习约 6 小时。时间主要用于首次搭建接口、RTL、testbench 和波形，而不是
追求生产级 AXI4-Lite IP。

## 已完成内容

- 定义最小寄存器规格：`CTRL` 位于 `0x0000`、属性为 RW；`STATUS` 位于
  `0x0004`、属性为 RO。
- 建立 `axi_lite_csr` 的 AXI4-Lite 端口，并统一使用 `s_axi_*` 命名。
- 初步实现 AW/W/B 写路径：分别保存写地址和写数据，用独立 valid 标志表示
  两部分是否已经接收。
- 修正 AW/W 的独立 READY 行为：接收 AW 后只关闭 `AWREADY`，仍允许 W 到达；
  W 先到时采用对称行为；收齐两部分后产生 `BVALID`。
- 建立 `axi_lite_csr_tb`、FSDB dump 和独立 VCS 构建目录。
- 重写 testbench README，并在仓库顶层增加 Makefile，支持编译、仿真和打开
  Verdi 的分步或完整命令。

## 波形证据

已在 Verdi 中确认 AW 先于 W 到达的场景：

```text
115 ns：AWVALID && AWREADY，写地址完成握手
125 ns：WVALID  && WREADY，写数据完成握手
135 ns：BVALID  && BREADY，写响应完成握手
```

这说明 slave 没有要求 AW 和 W 同拍到达，并能在两个独立通道握手后产生写响应。
最新仿真日志能够运行到结束并打印：

```text
PASS: AXI LITE CSR checks passed (30 Cycles)
```

当前 PASS 主要说明流程能够运行到结束。testbench 的自检内容仍不完整，不能据此
认定整个写路径或 AXI4-Lite CSR 练习已经通过。

## 本次理解

1. 一笔 AXI4-Lite 写事务由独立的 AW、W 请求和 B 响应组成。
2. READY 必须反映 slave 对相应通道的实际存储能力，不能在地址槽已占用时继续
   声称可以接收新的 AW。
3. 地址和数据可以在不同周期到达；只有两者都已接受，才具备执行写操作和返回
   B 响应的条件。
4. 组合逻辑使用阻塞赋值，时序寄存器使用非阻塞赋值。
5. 波形证明了当前事务顺序，但自检 testbench 仍需明确验证结果和失败条件。

## 恢复点与剩余任务

下次从 B 通道反压开始：让 `BVALID=1` 时保持 `BREADY=0` 两拍，确认
`BVALID/BRESP` 稳定且 AW/W 不接受新请求，再拉高 `BREADY` 完成握手。

完成本次最小练习还需要：

1. 为当前写场景加入真正的自检和超时保护，检查复位值、写后 `CTRL`、响应值及
   握手次数，避免没有检查内容的 PASS。
2. 补充 W 先到、AW 后到的对称场景。
3. 完成 `CTRL`/`STATUS` 的同步复位行为，并保证 RO `STATUS` 不被写操作修改。
4. 加入地址译码：合法 `CTRL` 写返回 OKAY；写 RO、未定义地址或非对齐地址返回
   SLVERR，且不能修改 `CTRL`。
5. 第一轮保持 `WSTRB=4'b1111`；完成基本读写路径后，再补字节使能测试。
6. 实现 AR/R 读路径，覆盖读取 `CTRL`、读取 `STATUS`、非法地址和 RREADY 反压。
7. 完成后在 Verdi 中集中观察五个通道和 `CTRL/STATUS`，再判断最小练习通过。

W1C、counter、snapshot、CDC、burst、UVM 和通用寄存器框架均不属于当前练习。
