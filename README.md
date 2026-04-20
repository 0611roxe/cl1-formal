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

# 4. 生成形式化验证检查
cd ../riscv-formal/cores/cl1
python3 ../../checks/genchecks.py

# 5. 运行验证
make -C checks -j$(nproc)
```

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
        └── checks/        # 生成的验证任务（genchecks.py 后）
```
