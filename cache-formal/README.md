# CL1 Cache Formal

`cache-formal/` 是和 `riscv-formal/` 同级的 Cache formal 工作区。当前目标是验证
CL1 Cache 子系统的公开边界行为、关键 control 操作和少量 CL1 DCache 写回语义。

## 快速入口

```sh
make -C cache-formal        # 生成 RTL，运行 cache + cover，生成报告
make -C cache-formal control # 运行 invalid/clean/refetch/clean-writeback BMC
make -C cache-formal sanity # 运行 control 场景非空 cover
make -C cache-formal status # 汇总已有结果
make -C cache-formal clean  # 删除生成产物
```

`control` 和 `sanity` 默认用 `JOBS=2` 并行运行多个 SBY task：

```sh
make -C cache-formal control JOBS=1
make -C cache-formal sanity JOBS=3
```

所有生成物集中在 `cache-formal/generated/`：

```text
generated/rtl/Cl1CacheFormal.sv
generated/sby/cache_verify_<task>/
generated/REPORT.md
```

## 文档分工

```text
README.md                 # 使用入口和目录结构
CACHE_FORMAL_DESIGN.md    # 验证目标、checker、task、参数和当前边界
PORTING.md                # 作为通用 AXI-facing cache 框架接入其它 DUT
generated/REPORT.md       # 自动生成的最新运行结果
```

## 目录结构

```text
cache-formal/
|-- cache_verify.sby
|-- cache_verify.sv
|-- common/
|   `-- cache_macros.vh
|-- generic/
|   |-- cache_check.sv
|   |-- cache_req_rsp_contract.sv
|   |-- cache_axi_master_contract.sv
|   |-- cache_axi_single_outstanding_model.sv
|   `-- cache_valid_ready_monitor.sv
|-- cl1/
|   |-- cl1_cache_check.sv
|   |-- cl1_cache_control_env.sv
|   |-- cl1_cache_control_ready_check.sv
|   |-- cl1_cache_control_invalid_check.sv
|   `-- cl1_cache_control_clean_check.sv
`-- generated/
```

当前固定 Cache 规模为 `CL1_CACHE_IDXW=7`，由 `Makefile` 在生成 RTL 时传给
`CL1_Core`。这是 DUT 结构参数，不是 checker 内部参数。
