# Cache Formal Porting Guide

`generic/` 可以作为轻量 AXI-facing cache 验证层复用。接入新 DUT 时，原则是：
不改 DUT RTL，不改公共 checker，新增一层 adapter 完成协议映射。

## 1. 可复用文件

```text
common/cache_macros.vh
generic/cache_check.sv
generic/cache_req_rsp_contract.sv
generic/cache_axi_master_contract.sv
generic/cache_axi_single_outstanding_model.sv
generic/cache_valid_ready_monitor.sv
```

公共层提供：

- core/cache request-response contract。
- AXI master 必要边界检查。
- single-outstanding AXI 外存模型。
- watched line load/store/refill/writeback 数据一致性检查。
- I/D/AXI/backpressure/response-delay cover。

`cache_req_rsp_contract.sv` 将方向职责拆开：连接 DUT core-side 端口时通常设置
`REQUEST_ASSUME_MODE=1`、`RESPONSE_ASSUME_MODE=0`，使上游 request 成为环境约束，
而 DUT 的 response 顺序、数量和 `last` 成为断言。只有 response 本身来自 formal
环境模型时才应启用 `RESPONSE_ASSUME_MODE`。

adapter 不应把 core-side `rsp.ready` 固定为 `1`，除非目标协议明确禁止 response
背压。公共 contract 会检查 response 在 stall 期间保持 valid、data、error 和 last；
DUT 必须在 core handshake 前保留响应，必要时把下游 memory response 反压或缓冲。

## 2. Adapter 需要提供的信号

新 DUT 建议新增自己的目录，例如：

```text
mycache/mycache_cache_check.sv
```

adapter 负责例化 DUT，并把 DUT 信号转换到 `cache_check.sv` 需要的抽象边界：

- I-side：request valid/ready/address/cache，response valid/data/error。
- D-side：request valid/ready/address/data/write enable/mask/cache/size，response valid/data/error。
- AXI master：AW/W/B/AR/R 五通道必要字段。

如果 DUT 的 core-side 协议不同，应在 adapter 中转换，不要把 DUT 私有协议写进
`generic/`。

## 3. 可选 observe

公共层不需要 tag、valid、dirty、FSM 或 array 内部状态。

只有当某个性质无法通过公开边界表达时，才建议在 DUT adapter 下添加小而语义化的
observe。例如 CL1 当前只保留 `dcacheWriteback` observe，用于区分 dirty
replacement writeback 和 clean writeback。

## 4. 接入步骤

1. 生成 cache-only DUT RTL 到 `generated/rtl/`。
2. 新增 adapter，例如 `mycache/mycache_cache_check.sv`。
3. 在 adapter 中例化 DUT 和 `generic/cache_check.sv`。
4. 在 `cache_verify.sby` 增加 task、top 和 `[files]`。
5. 先跑 `cache` BMC，再跑 `cover`。
6. 如需 control 操作语义，再仿照 `cl1/cl1_cache_control_*_check.sv` 添加 DUT 专项。

AXI 模型仍然只是受控外存模型，不是 AXI VIP。完整设计边界见
`CACHE_FORMAL_DESIGN.md`。
