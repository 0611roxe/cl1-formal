# cl1-formal

CL1 RISC-V 处理器核的形式化验证项目，集成 [CL1_Core](CL1_Core/)（Chisel 处理器）和 [riscv-formal](riscv-formal/)（RISC-V 形式化验证框架）。

## 环境准备

需要安装 [Nix](https://nixos.org/download/) (≥ 2.7)，并在 `~/.config/nix/nix.conf` 中启用：

```
experimental-features = nix-command flakes
```

## 快速开始

```bash
# 1. 进入开发环境（首次会下载依赖，耗时较长）
cd cl1-formal
nix develop

# 2. 生成 Verilog
cd CL1_Core
make verilog

# 3. 复制生成的 Cl1Top.sv 到验证目录
cp vsrc/Cl1Top.sv ../riscv-formal/cores/cl1/

# 4. 进入验证目录
cd ../riscv-formal/cores/cl1

# 5. 生成形式化验证检查
make checks        # 等价于 python3 ../../checks/genchecks.py

# 6. 运行验证
make all           # 跑全部 check（可用 JOBS=N 覆盖并发度）
make csr           # 仅跑 CSR / trap / 特权指令相关 check
make int           # 仅跑中断 check（interrupt_ch0）

# 7. 查看结果汇总
make summary       # 所有 check
make summary-csr   # 仅 CSR / trap / 特权指令
make summary-int   # 仅中断 check

# 8. 清理
make clean         # 删除生成的 checks/
```

### `make csr` 覆盖的检查

| 类别 | Target |
|---|---|
| 异常 / 特权指令 | `trap_handler_ch0` / `priv_insn_ch0` |
| CSR 写 (`csrw_*`) | `mtvec` / `mepc` / `mcause` / `mscratch` / `mstatus` / `mie` / `misa` |
| CSR 杂散写保护 (`csrc_*`) | `any_mepc` / `any_mstatus` / `any_mie` / `const_misa` |

### `make int` 覆盖的检查



| 断言 | 含义 |
|---|---|
| A1 | `mcause.interrupt == 1`（异步中断标志位） |
| A2 | `mcause.code ∈ {3, 7, 11}`（MSI / MTI / MEI，M-mode 合法异步原因） |
| A3 | `mstatus.MPIE == 1`（进入 handler 前 MIE 被保存为 1；异步中断只会在 MIE=1 时被接受） |
| A4 | `mstatus.MIE  == 0`（进入 handler 时全局中断被屏蔽） |
| A5 | `mepc` 4 字节对齐 |
| A6 | `pc_rdata` 4 字节对齐（handler 第一条指令的地址） |

同时包含 3 条 `cover` 目标，分别产生原因为 3 / 7 / 11 的中断入口 witness trace。


## 总线模式选择

在 `riscv-formal/cores/cl1/checks.cfg` 中配置：

- **Native Bus**（默认）：保持 `` `define CL1_USE_NATIVE_BUS `` 启用，使用 `Cl1Top.sv`
- **AXI Bus**：注释掉该行，使用 `Cl1Top_AXI.sv`

## 项目结构

```
cl1-formal/
├── flake.nix              # 统一 Nix 开发环境
├── CL1_Core/              # Chisel 处理器核源码
│   ├── build.sc           # Mill 构建配置
│   ├── cl1/src/scala/     # Chisel 源码
│   └── vsrc/              # 生成的 Verilog（make verilog 后）
└── riscv-formal/          # RISC-V 形式化验证框架
    ├── checks/            # 通用验证检查模块
    ├── insns/             # 指令规范
    └── cores/cl1/         # CL1 核验证配置
        ├── checks.cfg     # 验证参数配置
        ├── wrapper.sv     # RVFI wrapper
        ├── Makefile       # checks / all / csr / int / summary
        ├── summary.sh     # 汇总 SBY 运行结果
        └── checks/        # 生成的验证任务（make checks 后）
```
