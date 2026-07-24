# cl1-formal

`cl1-formal` 是 CL1 处理器核的形式化验证集成仓库，包含两个主要部分：

- [`CL1_Core/`](CL1_Core/)：CL1 Chisel 处理器核 submodule，负责生成被验证的 Verilog DUT。
- [`riscv-formal/`](riscv-formal/)：基于 riscv-formal 的 RVFI / RVFI_BUS 检查框架。

本仓库当前维护三条 riscv-formal 主验证入口：

| 验证入口 | DUT 顶层 | 配置文件 | 检查数 | 主要用途 |
|---|---|---|---:|---|
| Native CoreBus | `Cl1Top` | `checks.cfg` | 91 | 验证不经 AXI/cache 的核心 RVFI 行为 |
| AXI no-cache | `Cl1Top_AXI` | `checks_axi.cfg` | 102 | 验证 AXI 总线适配、RVFI_BUS、fault/progress |
| AXI + Cache | `Cl1Top_AXI_CACHE` | `checks_axi_cache.cfg` | 101 | 验证带 I/D cache 的处理器对外 AXI 行为和 RVFI retire 行为 |

`cache-formal/` 是独立的 cache 内部性质验证工程。`checks_axi_cache.cfg` 不直接证明 cache 内部 invariant，而是把 cache 作为处理器微结构的一部分，通过外部 AXI 事务和 RVFI trace 观察处理器整体行为。

## 环境准备

需要安装 Nix，并启用 flakes：

```text
experimental-features = nix-command flakes
```

初始化仓库：

```bash
git clone --recurse-submodules git@github.com:0611roxe/cl1-formal.git
cd cl1-formal

# 如果已经克隆过主仓库：
git submodule update --init --recursive
```

进入开发环境：

```bash
nix develop
```

## 生成 DUT

riscv-formal 使用 `riscv-formal/cores/cl1/` 下的 Verilog 文件。每次切换 `CL1_Core` 版本或修改 RVFI 接口后，都应重新生成并复制 DUT。

### Native CoreBus

```bash
make -C CL1_Core verilog-rvfi
cp CL1_Core/vsrc/Cl1Top.sv riscv-formal/cores/cl1/
```

### AXI no-cache

```bash
make -C CL1_Core verilog-rvfi-axi
cp CL1_Core/vsrc/Cl1Top_AXI.sv riscv-formal/cores/cl1/
```

`checks_axi.cfg` 和 `wrapper.sv` 期望 DUT 顶层名为 `Cl1Top_AXI`。如果某个 `CL1_Core` 分支的 `verilog-rvfi-axi` 仍生成 `Cl1Top_RVFI_AXI`，需要先让生成 target 使用 `CL1_TOP_NAME=Cl1Top_AXI`，再运行 no-cache AXI 检查。

### AXI + Cache

```bash
make -C CL1_Core verilog-rvfi-axi-cache
cp CL1_Core/vsrc/Cl1Top_AXI_CACHE.sv riscv-formal/cores/cl1/
```

`verilog-rvfi-axi-cache` 需要 `CL1_Core` 中包含 formal/RVFI v2.0 接入补丁：

- `rvfi_valid` 只由真实 WB retire pulse 驱动。
- RVFI 接口包含 `rvfi_mem_fault`、`rvfi_mem_fault_rmask`、`rvfi_mem_fault_wmask`。
- 生成顶层名为 `Cl1Top_AXI_CACHE` 的 AXI + ICache/DCache DUT。

AXI + Cache 默认使用较小的 formal cache 几何：

```bash
make -C CL1_Core verilog-rvfi-axi-cache CL1_AXI_FORMAL_CACHE_IDXW=1
```

需要扩大 cache 状态空间时可以覆盖该参数，例如：

```bash
make -C CL1_Core verilog-rvfi-axi-cache CL1_AXI_FORMAL_CACHE_IDXW=2
```

## 运行检查

以下命令在 `riscv-formal/cores/cl1` 下执行。

### Native CoreBus

```bash
cd riscv-formal/cores/cl1
make CHECKS_CFG=checks checks
make CHECKS_CFG=checks all JOBS=8
make CHECKS_CFG=checks summary
```

常用子集：

```bash
make CHECKS_CFG=checks base JOBS=8
make CHECKS_CFG=checks csr JOBS=8
make CHECKS_CFG=checks i JOBS=8
make CHECKS_CFG=checks m JOBS=8
make CHECKS_CFG=checks c JOBS=8
make CHECKS_CFG=checks fault JOBS=8
make CHECKS_CFG=checks deadlock JOBS=2
```

### AXI no-cache

```bash
cd riscv-formal/cores/cl1
make CHECKS_CFG=checks_axi checks
make CHECKS_CFG=checks_axi all JOBS=8
make axi-summary
```

快捷目标：

```bash
make axi-checks
make axi-base JOBS=8
make axi-bus JOBS=8
make axi-fault JOBS=8
make axi-deadlock JOBS=2
make axi-summary
```

### AXI + Cache

```bash
cd riscv-formal/cores/cl1
make CHECKS_CFG=checks_axi_cache checks
make CHECKS_CFG=checks_axi_cache all JOBS=8
make axi-cache-summary
```

快捷目标：

```bash
make axi-cache-checks
make axi-cache-base JOBS=8
make axi-cache-bus JOBS=8
make axi-cache-fault JOBS=8
make axi-cache-deadlock JOBS=2
make axi-cache-summary
```

AXI + Cache 是当前最重的 riscv-formal 入口。普通 `insn_*` 目标没有启用 AXI stress backpressure；如果 `insn_lb`、`insn_lbu`、`insn_sb` 等 load/store 目标运行很久，主要原因通常是 cache hit/miss、refill、流水线 stall 和 RVFI retire 对齐状态空间变大，而不是 AXI 随机延迟。

## Make 目标

| 目标 | 用途 |
|---|---|
| `make checks` | 根据 `CHECKS_CFG` 生成检查目录，默认 `checks/` |
| `make all JOBS=8` | 运行当前配置下的全部检查 |
| `make summary` | 汇总当前配置结果 |
| `make i` / `make m` / `make c` | 运行 RV32I / RV32M(ALTOPS) / RV32C 指令检查 |
| `make base` / `make sanity` | 运行基础 RVFI 不变量 / `base + cover` |
| `make csr` / `make int` / `make deadlock` | 运行 CSR、interrupt、deadlock/liveness 子集 |
| `make bus` | 运行 AXI RVFI_BUS 子集，只在 AXI 配置下有意义 |
| `make fault` | 运行当前配置对应的 fault 子集 |
| `make <checker>` | 运行单项，例如 `make insn_lw_ch0` |
| `make summary-<group>` | 只汇总某个 group，例如 `summary-csr` |
| `make clean-<group>` | 清理某个 group 的工作目录 |
| `make clean` | 删除当前 `CHECKS_DIR` |

AXI 快捷目标：

| 目标 | 用途 |
|---|---|
| `make axi-checks` | 重新生成 `checks_axi/` |
| `make axi-all` | 清理并运行 AXI no-cache 全量验证 |
| `make axi-<group>` | 清理并运行 AXI no-cache 的某个 group |
| `make axi-summary` | 汇总 `checks_axi/` |
| `make axi-cache-checks` | 重新生成 `checks_axi_cache/` |
| `make axi-cache-all` | 清理并运行 AXI + Cache 全量验证 |
| `make axi-cache-<group>` | 清理并运行 AXI + Cache 的某个 group |
| `make axi-cache-summary` | 汇总 `checks_axi_cache/` |

CL1 微架构检查使用分组入口：

| 目标 | 用途 |
|---|---|
| `make microarch` | 运行默认模块级微架构套件 |
| `make microarch-csr` | 运行 CSR 单元、陷阱场景和陷阱模型 |
| `make microarch-mdu` | 运行 riscv-formal altops MDU 检查 |
| `make microarch-mdu MDU_MODE=smoke` | 运行缩减操作数真实算术和协议检查 |
| `make microarch-mdu MDU_MODE=full` | 运行全位宽 DUT/参考模型检查 |
| `make microarch-mdu MDU_MODE=strict` | 在 full 基础上运行独立算术闭合 |
| `make clean-microarch` | 清理微架构运行目录 |

开发时可进一步选择 `MDU_MODE=protocol|mul|div|mul-full|div-full`，但不再为这些
同类任务维护独立的 Make 子目标。

## 检查规模

| 组 | 内容 | Native | AXI no-cache | AXI + Cache |
|---|---|---:|---:|---:|
| `base` | `reg`、`pc_fwd`、`pc_bwd`、`unique`、`causal` | 5 | 5 | 5 |
| `cover` | 聚合可达性 witness | 1 | 1 | 1 |
| `deadlock` | `hang`、`liveness` | 2 | 2 | 2 |
| `int` | interrupt 入口和 CSR 副作用 | 1 | 1 | 1 |
| `csr` | CSR 写/清位/常量检查 | 11 | 11 | 11 |
| `i` | RV32I 指令 | 37 | 37 | 37 |
| `m` | RV32M 指令，使用 ALTOPS | 8 | 8 | 8 |
| `c` | RV32C 压缩指令 | 25 | 25 | 25 |
| `bus` | RVFI_BUS / AXI memory 一致性 | 0 | 7 | 7 |
| `fault` | RVFI fault 和 bus fault 映射 | 1 | 5 | 4 |
| 总计 |  | 91 | 102 | 101 |

AXI + Cache 的 `fault` 少 1 项，因为默认过滤 `bus_imem_fault_ch0`。原因见下文的 cache fault 说明。

## BMC 深度

| checker 类别 | Native | AXI no-cache | AXI + Cache |
|---|---:|---:|---:|
| `insn` | 35 | 35 | 25 |
| `insn_mul.*` | 35 | 36 | 36 |
| `insn_sb` / `insn_lb` / `insn_lbu` | 35 | 64 | 32 |
| `reg` | 15 -> 25 | 15 -> 25 | 15 -> 25 |
| `pc_fwd` / `pc_bwd` | 10 -> 30 | 10 -> 30 | 10 -> 30 |
| `unique` | 1 / 10 / 30 | 1 / 20 / 32 | 1 / 20 / 32 |
| `causal` | 10 -> 30 | 10 -> 30 | 10 -> 30 |
| `causal_mem` / `causal_io` | 不启用 | 1 -> 36 | 1 -> 36 |
| `hang` | 1 -> 96 | 1 -> 112 | 1 -> 56 |
| `liveness` | 1 / 16 / 96 | 1 / 16 / 192 | 1 / 96 / 192 |
| `cover` | 1 -> 45 | 1 -> 45 | 1 -> 45 |
| `csrw` / `csr_ill` | 20 | 30 | 30 |
| `interrupt` | 20 | 34 | 34 |
| `csrc_any` / `csrc_const` | 1 -> 5 | 1 -> 5 | 1 -> 5 |
| `bus_imem` | 不启用 | 1 -> 30 | 1 -> 24 |
| other `bus_*` | 不启用 | 1 -> 30 | 1 -> 30 |
| `fault` | 24 | 24 | 24 |
| `bus_imem_fault` | 不启用 | 1 -> 30 | 默认过滤 |
| other `bus_*_fault` | 不启用 | 1 -> 30 | 1 -> 30 |

`a -> b` 表示从第 `a` 步开始检查并展开到第 `b` 步；`1 / t / d` 表示 start、trigger、depth 三段参数。

## 验证环境

### RVFI / CSR 约定

| 项 | 当前约定 |
|---|---|
| ISA | RV32IMC + Zicsr，单 hart，机器模式 |
| M 扩展 | 使用 `RISCV_FORMAL_ALTOPS`，验证 MDU 控制路径和回写时序，不证明真实乘除算法 |
| 内存模型 | `RISCV_FORMAL_ALIGNED_MEM`，sub-word 通过 word-aligned address + byte mask 验证 |
| `rvfi_trap` | 表示同步 fault；ECALL / EBREAK / MRET 按正常 retire 处理 |
| `mstatus` | 只检查 MIE/MPIE |
| `mie` | 只检查 MSIE/MTIE/MEIE |
| `mepc` | `mepc[0]` 硬连线 0；RVC 下 bit1 可写 |
| `misa` | 硬连线 `0x40001104`，保留 `csrc_const_misa_ch0`，跳过严格 `csrw_misa_ch0` |
| `mtval` | 同步 trap 写入异常附加值；interrupt / ECALL / EBREAK 写 0 |
| debug | formal-only assume 屏蔽 debug-mode flush，避免干扰 trap / interrupt / PC 链检查 |
| 32-bit 指令对齐 | `CL1_FORMAL_ASSUME_ALIGNED_32I` 建模软件约定：压缩指令可半字对齐，32-bit 指令必须 32-bit 对齐 |

### Native 环境

Native CoreBus 使用 `native_bus_dummy_slave`：

- request/response 均为 bounded latency。
- memory data 是 stable arbitrary value，不固定为 NOP。
- 普通检查中 response error 固定为 0。
- `fault_ch0`、`hang`、`liveness` 可以启用 arbitrary response error。
- deadlock/progress 环境只排除成功取指响应中的 WFI，因为 WFI 本身是架构等待。

### AXI 环境

AXI 配置使用 `axi4_dummy_slave` 和 `rvfi_bus_axi4_observer`：

- read/write 分别映射到 RVFI_BUS channel 1 / channel 0。
- `ar_prot` / `aw_prot` 用于区分 instruction/data 访问。
- AXI slave 建模 single outstanding read 和 single outstanding write。
- 普通 ISA/CSR/base 检查使用 zero-delay OKAY response。
- `bus`、`fault`、`interrupt` 和 `cover` 相关目标启用 `CL1_AXI_STRESS_BACKPRESSURE`。
- stress 模式下 AR/AW/W/R/B 都有 bounded nondeterministic delay，当前最大 4 cycle。
- fault/progress 相关目标启用 `CL1_AXI_FAULT_FORMAL_MEM`，允许 OKAY 或 SLVERR。

`CL1_AXI_FAST_FORMAL_MEM` 不对普通检查全局启用。AXI + Cache 的 `hang` / `liveness`
单独使用 fast memory 控制 processor-plus-cache progress 的状态空间；`bus` / `fault` /
`interrupt` / `cover` 仍保留 bounded backpressure。

### Progress / Interrupt 环境

`hang` 和 `liveness` 使用 progress 环境：

- 允许环境在检查窗口前给出任意 memory data。
- fault-progress 目标允许 memory response 为 OKAY 或 fault。
- interrupt-progress 目标允许窗口前 interrupt 任意出现。
- 在 progress 窗口前 quiesce interrupt，避免 permanent interrupt stream 让 deadlock/liveness 语义失真。
- AXI + Cache 的 liveness 在第 96 周期触发，并展开到第 192 周期；该目标检查冷启动后的集成进展，cache 内部任意状态性质由独立 cache-formal 目标覆盖。

## AXI + Cache 说明

AXI + Cache 执行流：

```text
IFU/LSU -> ICache/DCache -> CacheBus -> CacheBus2Axi4 -> AXI master
       -> axi4_dummy_slave -> AXI observer -> RVFI_BUS
```

这条主线验证的是“带 cache 的处理器”：

- 指令退休、PC 链、寄存器写回和 CSR 副作用仍通过 RVFI 检查。
- 外部 AXI read/write 行为通过 RVFI_BUS observer 检查。
- data-side fault、bus fault、interrupt-progress、deadlock/progress 仍保留。
- cache 内部 tag/data/refill/writeback invariant 不在此处直接证明，应该由 `cache-formal` 独立覆盖。

`checks_axi_cache.cfg` 默认过滤 `bus_imem_fault_ch0`。现有 riscv-formal I-side bus fault checker 假设外部 instruction fault 和被检查 PC 的 retired fault 一一对应；但 I-cache refill/prefetch 可以提前读取整条 cache line，一个外部 instruction read fault 不一定对应当前 retire PC。严格证明 I-cache instruction fault attribution 需要 cache-aware checker，至少需要观察或重建 refill/fill 状态。

## Cover

Native cover 当前要求同一 trace 中覆盖：

- load -> store
- store -> load
- DIV/REM rs2=0
- 同步 trap
- 非顺序 PC

AXI cover 额外要求：

- 至少 2 条 retire。
- 同一 trace 中出现 AXI read 和 AXI write。
- 覆盖 AR/AW/W/R/B 五类 bounded backpressure delay。

## 已知边界

| 项 | 说明 |
|---|---|
| `fence` / `fence.i` | 当前尚未加入原生语义支持；如果要验证 cache/fetch/memory ordering，需要额外建模 |
| 时间范围 | 当前是 bounded BMC/progress 证明，不是无限时域 liveness 证明 |
| M 扩展算法 | 三条 ISA/RVFI 主线使用 `RISCV_FORMAL_ALTOPS`；真实乘除算法由独立的 `microarch-mdu` 非 altops 模式证明 |
| AXI + Cache I-side fault | 默认过滤 `bus_imem_fault_ch0`，需要 cache-aware checker 才能严格恢复 |
| cache 内部性质 | AXI + Cache 主线不证明 cache 内部 invariant；由 `cache-formal` 独立验证 |
| 软件对齐约定 | 32-bit 指令要求 32-bit 对齐；FetchAlign RTL workaround 不属于当前 formal 环境假设的一部分 |

## 目录结构

```text
cl1-formal/
├── README.md
├── flake.nix
├── CL1_Core/                    # CL1 Chisel 处理器核 submodule
├── cache-formal/                # 独立 cache formal 工程
└── riscv-formal/
    └── cores/cl1/
        ├── checks.cfg           # Native CoreBus 主配置
        ├── checks_axi.cfg       # AXI no-cache 主配置
        ├── checks_axi_cache.cfg # AXI + Cache 主配置
        ├── wrapper.sv           # CL1 riscv-formal wrapper
        ├── rvfi_bus_axi4_guard.sv
        ├── microarch/           # CL1 专用模块级与真实 MDU 检查
        ├── Makefile
        └── summary.sh
```
