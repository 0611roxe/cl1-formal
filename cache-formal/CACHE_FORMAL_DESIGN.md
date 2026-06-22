# CL1 Cache Formal Design

本文档说明 `cache-formal/` 的验证目标、checker 结构、运行任务和验证边界。

## 1. 验证目标

当前框架验证 CL1 Cache subsystem：

- `Cl1ICACHE`
- `Cl1DCACHE`
- I/D 共享外部访问路径
- AXI master bridge

AXI 只作为受控外存访问手段，不作为完整 AXI compliance 验证目标。当前结论是
bounded formal baseline，不声明完整无界 cache correctness。

## 2. 分层结构

```text
generic/cache_check.sv
  公共 Cache checker，只依赖 I-side、D-side 和 AXI master 边界。

cl1/cl1_cache_check.sv
  CL1 adapter，例化 Cl1CacheFormal 并连接公共 checker。

cl1/cl1_cache_control_env.sv
  CL1 control 专项共享环境。

cl1/cl1_cache_control_ready_check.sv
  空 invalid/clean 完成性检查。

cl1/cl1_cache_control_invalid_check.sv
  invalid 后同地址重新访问必须 refill 的检查。

cl1/cl1_cache_control_clean_check.sv
  clean dirty line 写回和二次 clean 不重复写回检查。
```

`generic/` 不依赖 CL1 内部信号，可以作为其它 AXI-facing cache 的公共层。
CL1 特有补充限制在 `cl1/` 下。

## 3. 公共 checker

公共层只看公开边界：

- I-side core request/response。
- D-side core request/response。
- AXI master AW/W/B/AR/R。

主要性质：

- valid/ready backpressure 期间 payload 稳定。
- I/D response 不返回 error。
- D-side response 对应已经接受的 D-side request。
- AXI master burst 边界满足 cache 使用所需的基本约束。
- single-outstanding AXI 外存模型支持有限 backpressure 和 response delay。

公共层选择一条 `anyconst` watched line，并维护 line 内每个 word 的参考状态：

- AXI read refill 返回 deterministic memory model 数据。
- watched line 上的 cached store 按 byte mask 更新 cache 参考值。
- 后续 watched line load 必须匹配 cache 参考值。
- watched line writeback 的每个 W beat 必须匹配 cache 参考值，并更新 memory 参考值。

这不是完整内存一致性模型，但能覆盖任意符号 line 上的 load/store/refill/writeback
数据路径。

## 4. CL1 补充 checker

主线 CL1 adapter 只额外使用一组窄语义 observe：`dcacheWriteback`。它用于检查
公共边界很难直接区分的 DCache dirty replacement 行为：

- dirty victim 被选中后，不能先发 refill/read。
- replacement writeback 必须来自 dirty replacement，不能和 clean writeback
  同时成立。
- replacement writeback 必须是 4-beat line burst，地址、mask、len、size、last
  符合 line writeback 语义。

control 专项覆盖：

- 空 ICache invalid 能完成，且不产生无关 AXI 访问。
- 空 DCache clean/invalid 能完成，且不产生无关 AXI 访问。
- ICache invalid 后同地址 fetch 在 response 前必须重新发 AXI read。
- DCache invalid 后同地址 load 在 response 前必须重新发 AXI read。
- DCache dirty line clean 必须发 clean writeback。
- clean 后 dirty 状态清除，第二次 clean 不能重复 writeback。

每个 control BMC 都有对应 `_sanity` cover。sanity 只证明场景路径非空，避免
vacuous pass；功能性结论仍以对应 BMC task 为准。

## 5. AXI 外存模型

`generic/cache_axi_single_outstanding_model.sv` 是受控外存模型：

- single outstanding read/write。
- AW/W/AR ready 可 backpressure。
- B/R response 可延迟。
- backpressure/delay 有上界，避免环境永久阻塞。
- read data 来自 checker 的 deterministic memory function。

不支持：

- 多 outstanding。
- 乱序 ID。
- 完整 AXI VIP 行为。

## 6. 参数和任务

结构参数：

| 参数 | 当前值 | 来源 |
| --- | --- | --- |
| `CL1_CACHE_IDXW` | `7` | `Makefile` 传给 `CL1_Core` elaboration |
| `WAYS` | `2` | CL1 Cache RTL 固定 |
| `BANKS` | `4` | CL1 Cache RTL 固定 |
| `DW` | `32` | CL1 Cache RTL 固定 |
| `CL1_CACHE_FORMAL` | `true` | 只在 cache-formal elaboration 中打开 `dcacheWriteback` 窄 observe |

运行参数：

| 项 | 当前值 |
| --- | --- |
| SBY 配置 | `cache_verify.sby` |
| 引擎 | `smtbmc boolector` |
| 默认并行 task 数 | `JOBS=2` |
| 主线 Top | `cl1_cache_check` |
| Control Top | `cl1_cache_control_ready_check` / `cl1_cache_control_invalid_check` / `cl1_cache_control_clean_check` |

Make 目标：

| 目标 | 内容 |
| --- | --- |
| `make all JOBS=8` | 主 cache safety + 主 cover |
| `make full JOBS=8` | `prove + control + sanity + cover`，覆盖下表全部 task |

当前 task：

| Task | Mode | Depth | 目标 |
| --- | --- | --- | --- |
| `cache` | `bmc` | `24` | 完整 Cache wrapper 边界 safety |
| `cover` | `cover` | `160` | I/D/AXI/backpressure/delay 可达性 |
| `icache_invalid` | `bmc` | `360` | 空 ICache invalid 完成性 |
| `dcache_clean` | `bmc` | `520` | 空 DCache clean 完成性 |
| `dcache_invalid` | `bmc` | `520` | 空 DCache invalid 完成性 |
| `icache_invalid_refetch` | `bmc` | `330` | ICache invalid 后同地址 fetch 必须重新 refill |
| `dcache_invalid_refetch` | `bmc` | `700` | DCache invalid 后同地址 load 必须重新 refill |
| `dcache_clean_writeback` | `bmc` | `520` | dirty clean 必须写回，且写回数据包含 store 后数据 |
| `dcache_clean_twice` | `bmc` | `850` | dirty clean 后第二次 clean 不能重复写回 |
| `*_sanity` | `cover` | 同对应 BMC | 对应 control 场景非空 |

最新运行结果见 `generated/REPORT.md`。

## 7. 命名约定

文件命名沿用 `riscv-formal` 风格：

```text
<domain>_<subject>_check.sv
```

含义：

- `*_check`：顶层 checker 或专项 checker。
- `*_contract`：协议边界检查或环境约束。
- `*_monitor`：基础 valid/ready 监控。
- `*_model`：formal 环境模型。
- `_sanity` task：只做场景非空 cover。

所有生成物都放在 `generated/` 下，避免污染 `cache-formal/` 根目录。

## 8. 当前边界

当前框架已经覆盖公共接口行为、受控 AXI 外存交互、invalid/clean 控制语义和
关键 DCache 写回行为。

当前不声明：

- 完整 AXI compliance。
- 多 outstanding 或乱序 ID 正确性。
- 完整无界 cache correctness。
- 任意所有 line 的完整内存一致性。
- ICache/DCache 内部 FSM 和 array 的逐状态证明。
