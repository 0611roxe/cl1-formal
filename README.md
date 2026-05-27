# cl1-formal

CL1 RISC-V 处理器核的形式化验证仓库，集成 [CL1_Core](CL1_Core/)（Chisel 处理器，submodule，跟踪 `dev` 分支）和 [riscv-formal](riscv-formal/)。

当前维护两条验证入口：

| 模式 | DUT 顶层 | 配置文件 | 检查项 | 当前结果 |
|---|---|---|---:|---|
| Native CoreBus | `Cl1Top` | `checks.cfg` | 92 | 92 / 92 PASS |
| AXI + Cache | `Cl1Top_AXI` | `checks_axi.cfg` | 99 | 99 / 99 PASS |

AXI 路径在 native-equivalent RVFI 检查之外，额外启用 7 个 RVFI_BUS checker，用于比对外部 AXI 事务和 architectural memory 行为。

## 环境

需要安装 [Nix](https://nixos.org/download/) (>= 2.7)，并启用 flakes：

```text
experimental-features = nix-command flakes
```

初始化仓库：

```bash
git clone --recurse-submodules git@github.com:0611roxe/cl1-formal.git

# 已克隆主仓库时：
git submodule update --init --recursive
```

进入开发环境：

```bash
cd cl1-formal
nix develop
```

## 快速开始

### Native CoreBus

```bash
cd cl1-formal

make -C CL1_Core verilog-native
cp CL1_Core/vsrc/Cl1Top.sv riscv-formal/cores/cl1/

cd riscv-formal/cores/cl1
make checks
make all JOBS=8
make summary
```

### AXI + Cache

```bash
cd cl1-formal

make -C CL1_Core verilog-axi-cache
cp CL1_Core/vsrc/Cl1Top_AXI.sv riscv-formal/cores/cl1/

cd riscv-formal/cores/cl1
make CHECKS_CFG=checks_axi checks
make CHECKS_CFG=checks_axi all JOBS=8
make axi-summary
```

## Make 目标

以下命令在 `riscv-formal/cores/cl1` 下执行。

| 目标 | 用途 |
|---|---|
| `make checks` | 根据 `CHECKS_CFG` 生成检查目录，默认 `checks/` |
| `make all JOBS=8` | 运行当前配置下全部检查 |
| `make summary` | 汇总当前配置结果 |
| `make i` / `make m` / `make c` | 分别运行 RV32I / RV32M(ALTOPS) / RV32C 指令检查 |
| `make base` / `make sanity` | 基础 RVFI 不变量 / `base + cover` |
| `make csr` / `make int` / `make deadlock` | CSR、interrupt、deadlock/liveness 子集 |
| `make <checker>` | 运行单项，例如 `make insn_lw_ch0` |
| `make summary-<group>` | 只汇总某个 group，例如 `summary-csr` |
| `make clean-<group>` | 清理某个 group 的工作目录 |
| `make clean` | 删除当前 `CHECKS_DIR` |

AXI 快捷目标：

| 目标 | 等价用途 |
|---|---|
| `make axi-checks` | 重新生成 `checks_axi/` |
| `make axi-all` | 重新生成并运行 AXI 全量验证 |
| `make axi-<group>` | 重新生成并运行 AXI 下的 group，例如 `axi-base` / `axi-bus` |
| `make axi-summary` | 汇总 `checks_axi/` |

`bus` group 只在 AXI 配置下有意义。

## 验证规模

### 检查项

| 组 | target | 项数 | 内容 |
|---|---|---:|---|
| base | `make base` | 5 | `reg`、`pc_fwd`、`pc_bwd`、`unique`、`causal` |
| cover | `make cover` | 1 | 聚合可达性 witness |
| sanity | `make sanity` | 6 | `base + cover` |
| deadlock | `make deadlock` | 2 | `hang`、`liveness` |
| int | `make int` | 1 | interrupt 入口和 CSR 副作用 |
| csr | `make csr` | 13 | CSR / priv / trap 检查，包含 `mtval`；`csrw_misa_ch0` 被 filter |
| i | `make i` | 37 | RV32I 指令 |
| m | `make m` | 8 | RV32M 指令，使用 ALTOPS |
| c | `make c` | 25 | RV32C 压缩指令 |
| bus | `make axi-bus` | 7 | RVFI_BUS / AXI memory 一致性 |

Native 总计 92 项：`base + cover + deadlock + int + csr + i + m + c`。

AXI 总计 99 项：92 项 native-equivalent checker + 7 项 RVFI_BUS checker。AXI 配置使用 `nbus 2` / `buslen 32`，write 事务映射到 bus ch0，read 事务映射到 bus ch1。

### BMC 深度

| checker 类别 | Native `checks.cfg` | AXI `checks_axi.cfg` |
|---|---:|---:|
| `insn` | 35 | 25 |
| `insn_mul.*` | 35 | 34 |
| `reg` | 15 -> 25 | 10 -> 20 |
| `pc_fwd` / `pc_bwd` | 10 -> 30 | 10 -> 24 |
| `unique` | 1 / 10 / 30 | 1 / 20 / 32 |
| `causal` | 10 -> 30 | 10 -> 24 |
| `hang` | 1 -> 20 | 1 -> 18 |
| `liveness` | 1 / 10 / 30 | 1 / 20 / 34 |
| `cover` | 1 -> 45 | 1 -> 24 |
| `csr` / `trap` / `priv` | 20 | 18 |
| `interrupt` | 20 | 34 |
| `csrc_any` / `csrc_const` | 1 -> 5 | 1 -> 5 |
| `bus_*` | 不启用 | 1 -> 24 |

`a -> b` 表示从第 `a` 步开始检查并展开到第 `b` 步；`1 / t / d` 表示 start、trigger、depth 三段参数。

## 关键约定

| 项 | 当前约定 |
|---|---|
| ISA / privilege | RV32IMC + Zicsr，单 hart，机器模式 |
| 求解器 | Yosys -> boolector，默认 SMT BMC |
| 内存模型 | `RISCV_FORMAL_ALIGNED_MEM`，sub-word 通过 word-aligned addr + byte mask 验证 |
| M 扩展 | `RISCV_FORMAL_ALTOPS`，验证 MDU 控制路径和回写时序，不证明真实乘除算法 |
| `rvfi_trap` | 只表示同步 fault；ECALL / EBREAK / MRET 按正常 retire 处理 |
| CSR | `mstatus` 只检查 MIE/MPIE；`mie` 只检查 MSIE/MTIE/MEIE；`mepc[0]` 硬连线 0 |
| `misa` | 硬连线 `0x40001104`，关闭 `csrw_misa_ch0`，使用 `csrc_const_misa_ch0` |
| `mtval` | 同步 trap 写入异常附加值；interrupt / ECALL / EBREAK 写 0 |
| interrupt | 检查 `mepc <- pc_rdata`、`mcause.interrupt=1`、MIE/MPIE 更新、PC 跳转到 `mtvec.base` |
| debug | formal-only assume 屏蔽 debug-mode 刷新，避免干扰 trap / interrupt / PC 链检查 |

Native cover witness 当前要求同一 trace 中出现 load->store、store->load、DIV/REM rs2=0、同步 trap、非顺序 PC；AXI cover 作为 cache/bus smoke witness，要求至少 2 条 retire 且出现 AXI read 和 write。

## 总线模式

| 模式 | Verilog 生成 | wrapper 选择 | 总线环境 |
|---|---|---|---|
| Native CoreBus | `make -C CL1_Core verilog-native` | 定义 `CL1_USE_NATIVE_BUS` | `native_bus_dummy_slave` |
| AXI + Cache | `make -C CL1_Core verilog-axi-cache` | 不定义 `CL1_USE_NATIVE_BUS` | `axi4_dummy_slave` + AXI observer |

AXI 执行流：

```text
IFU/LSU -> ICache/DCache -> CacheBus -> CacheBus2Axi4 -> AXI master
       -> axi4_dummy_slave -> AXI observer -> RVFI_BUS
```

`checks_axi.cfg` 当前过滤 fault 类 bus checker，因为 baseline dummy slave 固定返回 OKAY，不建模 AXI SLVERR/DECERR。

## 目录结构

```text
cl1-formal/
├── flake.nix
├── CL1_Core/                  # Chisel 处理器核 submodule
└── riscv-formal/
    └── cores/cl1/
        ├── checks.cfg         # Native CoreBus 配置
        ├── checks_axi.cfg     # AXI + Cache 配置
        ├── wrapper.sv
        ├── rvfi_bus_axi4_guard.sv
        ├── Makefile
        └── summary.sh
```
