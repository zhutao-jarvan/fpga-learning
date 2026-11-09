# 双槽 Registered-ready Skid Buffer - 2026-11-09

## 完成结论

阶段 4 完成固定 8-bit data、1-bit last 的双槽 registered-ready skid buffer。
练习采用引导补全模式：接口、EMPTY/ONE/TWO 状态、head/tail payload 寄存器、
handshake 和 directed TB 已提供，用户完成输出译码、状态转换及 payload 移动。

实现没有输入到输出的 fall-through 路径；`s_ready_o` 仅由注册状态译码，不组合
依赖 `m_ready_i`。EMPTY 和 ONE 可以接收输入，TWO 对上游反压。下游在 ONE 状态
停顿时，第二槽吸收上游因一拍刹车距离而合法送入的 beat。

## 行为确认

- EMPTY 接受首笔后进入 ONE，首笔最早在下一上升沿完成输出 handshake；
- ONE 的四种 `{s_accept, m_accept}` 组合均有明确行为；
- ONE 同拍 drain/refill 时，新输入直接替换已输出的 head，状态保持 ONE；
- ONE 停顿但接受输入时，新 beat 写入 tail 并进入 TWO；
- TWO 保持旧 head 稳定并拉低 `s_ready_o`；
- TWO 释放时先输出旧 head，再在该上升沿把 tail 提升为新 head，FIFO 顺序不变；
- 连续无反压时，初始填充一拍后达到每拍一笔的稳态吞吐。

`make rv_registered_ready_skid_buffer_sim` 重新编译并运行通过：

```text
PASS: rv_registered_ready_skid_buffer directed checks passed (11 transfers)
```

TB 覆盖复位、首笔寄存、连续满速、一拍停顿、长反压、TWO 释放、输出稳定、
容量上界以及 data/last 的顺序和配对。本结论尚不包括综合、STA、lint、形式验证
或随机流量验证。

## 工程模式复盘

该模式用第二个存储槽换取反向 ready 路径的时序切分。下游反压不能组合传播到
上游，因此上游可能再完成一笔 handshake；tail 槽保存这笔刹车距离内的数据。
它适合长 ready 链、模块边界和高频流水线，但相较单槽结构增加一个 payload 槽，
而且从 TWO 释放时不能同拍接收第三笔。

核心不变量是 occupancy 只能为 0、1、2；head 永远是最老 beat；tail 只在 TWO
有效；输出 stall 时 head 必须稳定；任何已接受 beat 必须恰好输出一次且保持顺序。
常见错误包括只注册 ready 却不增加容量、ONE 停顿时覆盖 head、TWO 释放时交换
head/tail 顺序，以及把 next-value `_d` 误认为已经更新的寄存值 `_q`。

生产实现通常还会参数化完整 payload，加入协议断言、非法状态断言、随机或形式
验证，并结合综合和 STA 确认 ready 路径确已切断。在网络数据通路中，它常用于
解析、分类、查表、队列和 MAC/PCS 等流水级边界，吸收短暂停顿并改善反压时序。
