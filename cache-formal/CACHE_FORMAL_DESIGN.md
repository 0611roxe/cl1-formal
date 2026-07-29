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
- core request payload 和合法性是环境假设；request ready 及全部 response 行为是 DUT 断言。
- I/D response 不返回 error，且只能对应已经接受、尚未完成的 request。
- response beat/last 必须匹配 request len；旧 response 与新 request 同周期 turnover 后必须保留新 request 状态。
- I/D response 在 `valid && !ready` 期间必须保持 valid、data、error 和 last 稳定。
- AXI master burst 边界满足 cache 使用所需的基本约束。
- single-outstanding AXI 外存模型支持有限 backpressure 和 response delay。

公共层选择一条 `anyconst` watched line，并维护 line 内每个 word 的参考状态：

- AXI read refill 返回 deterministic memory model 数据。
- 使用 `ARPROT[2]` 区分 ICache 和 DCache refill，并分别更新两份 cache 参考状态。
- ICache refill 后的后续 fetch response 必须匹配 ICache 参考值；DCache store 不会在
  没有 `fence.i` 的情况下被错误地传播到 ICache 参考状态。
- watched line 上的 cached store 按 byte mask 更新 DCache 参考值，后续 load 必须匹配
  合并后的字节数据。
- dirty watched line 在 DCache 再次 refill 前必须先完成 line writeback。
- watched line writeback 必须是 full-strobe line burst，每个 W beat 必须匹配对应的
  DCache word，并同步更新 memory 参考值。

这不是完整内存一致性模型，但能覆盖任意符号 line 上的 load/store/refill/writeback
数据路径。上述功能性质只在真实 request/response/AXI handshake 和参考 word 已知时触发；
checker 不通过固定请求地址、固定命中结果或强制 refill 建立功能结论。对应 cover 独立确认
I/D refill 后访问、partial store 后 load 和完整 line writeback 路径可达。

## 4. CL1 补充 checker

主线 CL1 adapter 只额外使用一组窄语义 observe：`dcacheWriteback`。它用于检查
公共边界很难直接区分的 DCache dirty replacement 行为：

- dirty victim 被选中后，不能先发 refill/read。
- replacement writeback 必须来自 dirty replacement，不能和 clean writeback
  同时成立。
- replacement writeback 必须是 4-beat line burst，地址、mask、len、size、last
  符合 line writeback 语义。
- replacement 的内部 CacheBus writeback payload 在 backpressure 时保持稳定，首个已接受
  writeback beat 与随后外部 AXI AW 的地址和 burst 属性一致。

control 专项覆盖：

- 空 ICache invalid 能完成，且不产生无关 AXI 访问。
- 空 DCache clean/invalid 能完成，且不产生无关 AXI 访问。
- ICache invalid 后同地址 fetch 在 response 前必须重新发 AXI read。
- DCache invalid 后同地址 load 在 response 前必须重新发 AXI read。
- DCache dirty line clean 必须发 clean writeback。
- clean 后 dirty 状态清除，第二次 clean 不能重复 writeback。

每个 control BMC 都有对应 `_sanity` cover。sanity 只证明场景路径非空，避免
vacuous pass；功能性结论仍以对应 BMC task 为准。

`data_sanity` 同样不承担功能证明。它只关闭 AXI delay、保持 response ready，并让上游按
single-outstanding 契约连续提供任意合法 DCache 请求；地址、读写操作和 replacement way
仍由求解器选择。主 `cache` / `cache_full` checker 不使用这些场景约束。

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
| `CL1_CACHE_IDXW` | 默认 `1`；full geometry 为 `7` | `Makefile` 传给 `CL1_Core` elaboration |
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
| `make full JOBS=8` | 小几何 `cache + cache_full + turnover + backpressure + data_sanity + control + sanity + cover` |
| `make full-geometry JOBS=8` | `IDXW=7` 下运行 `cache_full + control + sanity` |

当前 task：

| Task | Mode | Depth | 目标 |
| --- | --- | --- | --- |
| `cache` | `bmc` | `16` | 小几何 operational Cache wrapper 边界 safety |
| `cache_full` | `bmc` | `160` | 深度 operational/data safety；小几何 `full` 和实际几何回归都会运行 |
| `cover` | `cover` | `160` | I/D/AXI/backpressure/delay 可达性 |
| `turnover` | `bmc` | `20` | 连续 DCache load 环境下的 response/request turnover safety |
| `turnover_sanity` | `cover` | `20` | turnover 场景非空；当前 witness 在 step 18 |
| `backpressure` | `bmc` | `24` | I/D hit/refill response stall 时 valid/payload 稳定并最终 handshake |
| `backpressure_sanity` | `cover` | `24` | I/D hit/refill 四种 stall/recovery 场景非空 |
| `data_sanity` | `cover` | `48` | partial store/load、dirty replacement、内部 writeback 到 AXI 和完整 line writeback 路径非空 |
| `icache_invalid` | `bmc` | `360` | 空 ICache invalid 完成性 |
| `dcache_clean` | `bmc` | `520` | 空 DCache clean 完成性 |
| `dcache_invalid` | `bmc` | `520` | 空 DCache invalid 完成性 |
| `icache_invalid_refetch` | `bmc` | `330` | ICache invalid 后同地址 fetch 必须重新 refill |
| `dcache_invalid_refetch` | `bmc` | `700` | DCache invalid 后同地址 load 必须重新 refill |
| `dcache_clean_writeback` | `bmc` | `520` | dirty clean 必须写回，且写回数据包含 store 后数据 |
| `dcache_clean_twice` | `bmc` | `850` | dirty clean 后第二次 clean 不能重复写回 |
| `*_sanity` | `cover` | 同对应 BMC | 对应 control 场景非空 |

最新运行结果按几何保存于 `generated/reports/idxw<IDXW>/REPORT.md`，对应的 SBY
workdir 和 RTL 快照也使用相同几何标签，避免混合不同 elaboration 的结果。
每个 task 另有输入 digest manifest；报告只把与当前 SBY 配置、RTL 和 checker 文件
完全一致的结果视为当前结果，否则显示为 `STALE`。

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
