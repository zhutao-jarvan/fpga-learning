# AXI4-Lite CSR 地址译码与 BRESP - 2026-10-18

## 本次完成

在现有最小 AXI4-Lite CSR 上增加地址语义检查：

- `AWADDR=0x0000_0000` 作为可写 CTRL 地址，合法写返回 `OKAY`；
- 其他地址作为当前练习中的非法或不可写地址，返回 `SLVERR`；
- 非法地址不会更新 `ctrl_rw`；
- B handshake 后 `BVALID` 清零，`AWREADY/WREADY` 恢复；
- TB 增加 `accept_b2(output response)`，在 B handshake 上升沿采样 `BRESP`；
- TB 增加 `w_badaddr` 场景，先建立 CTRL 已知值，再执行非法地址写，最后读回 CTRL。

## 证据

`w_badaddr` 使用当前 RTL/TB 运行通过：

```text
PASS: AXI LITE CSR checks passed (15 cycles)
```

RTL 将 `s_axi_bresp` 改为组合地址译码：完整 AW/W 请求存在时，CTRL 地址返回
`OKAY`，其他地址返回 `SLVERR`；只有 CTRL 地址才更新 `ctrl_rw`。空闲时默认
`BRESP=OKAY`，因此 BVALID 出现时响应值由当前保存地址决定。

## 当前限制

当前设计只支持单笔 outstanding 写事务，读写不并发，WSTRB 尚未实现；STATUS
目前只作为只读路径的地址定义，尚未增加 STATUS directed read。响应组合逻辑和
寄存器写入条件仍是教学版，生产设计通常会进一步显式区分请求形成、响应保存、
写使能和副作用寄存器更新。

## 下一步

增加 STATUS (`0x0000_0004`) 合法读取场景，检查 RDATA/RRESP、R 反压期间稳定性、
R handshake 后释放；随后再处理 WSTRB 和阶段 2 收尾。
