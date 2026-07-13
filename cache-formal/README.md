# CL1 Cache Formal

`cache-formal/` 是和 `riscv-formal/` 同级的 Cache formal 工作区。当前目标是验证
CL1 Cache 子系统的公开边界行为、关键 control 操作和少量 CL1 DCache 写回语义。

## 快速入口

```sh
make -C cache-formal        # 生成 RTL，运行 cache + cover，生成报告
make -C cache-formal turnover # 证明并覆盖 DCache response/request 同周期 turnover
make -C cache-formal backpressure # 证明 I/D hit/refill response 背压稳定性
make -C cache-formal control # 运行 invalid/clean/refetch/clean-writeback BMC
make -C cache-formal sanity # 运行 control 场景非空 cover
make -C cache-formal full   # 运行小几何完整回归
make -C cache-formal full-geometry # 以实际 128-index 几何运行 safety/control/sanity
make -C cache-formal status # 汇总已有结果
make -C cache-formal check-full # 要求小几何完整任务全部为当前版本 PASS
make -C cache-formal clean  # 删除生成产物
```

`control` 和 `sanity` 默认用 `JOBS=2` 并行运行多个 SBY task：

```sh
make -C cache-formal control JOBS=1
make -C cache-formal sanity JOBS=3
```

所有生成物集中在 `cache-formal/generated/`：

```text
generated/rtl/Cl1CacheFormal.sv             # 当前 SBY 输入
generated/rtl/idxw<IDXW>/Cl1CacheFormal.sv  # 按几何保留的 RTL 快照
generated/sby/idxw<IDXW>/cache_verify_<task>/
generated/reports/idxw<IDXW>/REPORT.md
```

## 文档分工

```text
README.md                 # 使用入口和目录结构
CACHE_FORMAL_DESIGN.md    # 验证目标、checker、task、参数和当前边界
PORTING.md                # 作为通用 AXI-facing cache 框架接入其它 DUT
generated/reports/        # 按 cache 几何隔离的运行报告
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

默认 formal Cache 规模为 `CL1_CACHE_IDXW=1`，确保 16-cycle 主 BMC 能越过
上电 invalidation 并覆盖正常请求路径。只运行实际 128-index 几何主 safety 时使用：

```sh
make -C cache-formal prove-full-geometry
```

该入口使用 `CL1_CACHE_IDXW=7` 和 160-cycle `cache_full` BMC。几何参数由
`Makefile` 在生成 RTL 时传给 `CL1_Core`，不是 checker 内部参数。

需要在实际几何下同时运行 `cache_full`、全部 control BMC 和对应 sanity cover 时使用：

```sh
make -C cache-formal full-geometry
```

不同 `CACHE_IDXW` 的 SBY workdir、RTL 快照和报告相互隔离；可用
`make -C cache-formal status CACHE_IDXW=7` 查看实际几何结果。

每个 SBY workdir 都记录当前配置、RTL 和 checker 输入的 SHA-256 manifest。报告会把
缺少 manifest 或 digest 不一致的旧结果标为 `STALE`。`check-all`、`check-full` 和
`check-full-geometry` 可作为 CI gate；`FAIL`、`ERROR`、`UNKNOWN`、`MISSING` 或
`STALE` 的必需 task 都会返回非零。

完整几何回归也可以分阶段恢复：

```sh
make -C cache-formal full-geometry-safety
make -C cache-formal full-geometry-control JOBS=4
make -C cache-formal full-geometry-sanity JOBS=4
make -C cache-formal check-full-geometry CACHE_IDXW=7
```
