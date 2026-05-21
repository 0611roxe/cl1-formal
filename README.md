# cl1-formal

CL1 RISC-V 处理器核的形式化验证项目，集成 [CL1_Core](CL1_Core/)（Chisel 处理器，作为 submodule 维护在 `csr` 分支）和 [riscv-formal](riscv-formal/)（RISC-V 形式化验证框架）。

当前版本支持两条 formal 验证路径：默认 **native CoreBus** 路径完成 **91 / 91 PASS**；新增 **AXI + ICache/DCache** 路径完成 **98 / 98 PASS**。AXI 路径在保留原 RVFI ISA/CSR/interrupt 检查的基础上，额外启用 RVFI_BUS checker，验证外部 AXI 事务和 architectural memory 行为的一致性。

## 1. 验证配置

| 模式 | DUT 顶层 | 配置文件 | 总线观测 | 结果 |
|---|---|---|---|---|
| Native CoreBus（默认） | `Cl1Top` | `checks.cfg` | 只验证 RVFI architectural 行为，不启用 bus checker | **91 / 91 PASS** |
| AXI + Cache | `Cl1Top_AXI` | `checks_axi.cfg` | `nbus 2`，AXI write -> RVFI_BUS ch0，AXI read -> RVFI_BUS ch1 | **98 / 98 PASS** |

- **ISA/特权配置**：RV32IMC + Zicsr，单 hart，机器模式。
- **求解器**：Yosys -> boolector（默认 SMT BMC）。
- **M 扩展策略**：ALTOPS 占位（不验证真实乘除算法，只验证 MDU 控制路径 + 结果回写时序）。
- **AXI baseline**：启用 ICache/DCache，经 `CacheBus2Axi4` 转 AXI；dummy slave 返回 OKAY；`CL1_AXI_FAST_FORMAL_MEM` 使用 0 wait-state 降低 BMC 深度压力。
- **AXI checker 数量**：98 = native-equivalent 91 + 7 个 RVFI_BUS checker。

## 2. 环境准备

需要安装 [Nix](https://nixos.org/download/) (>= 2.7)，并在 `~/.config/nix/nix.conf` 中启用：

```text
experimental-features = nix-command flakes
```

## 3. 克隆仓库

`CL1_Core` 是 submodule，需要递归初始化：

```bash
git clone --recurse-submodules git@github.com:0611roxe/cl1-formal.git

# 如果已经克隆过主仓库：
git submodule update --init --recursive
```

## 4. 快速开始

### 4.1 Native CoreBus 路径

```bash
# 1. 进入开发环境（首次会下载依赖，耗时较长）
cd cl1-formal
nix develop

# 2. 生成 Verilog
cd CL1_Core
make verilog-native

# 3. 复制生成的 Cl1Top.sv 到验证目录
cp vsrc/Cl1Top.sv ../riscv-formal/cores/cl1/

# 4. 进入验证目录
cd ../riscv-formal/cores/cl1

# 5. 生成形式化验证检查
make checks

# 6. 运行验证
make all JOBS=8

# 7. 查看结果汇总
make summary
```

### 4.2 AXI + Cache 路径

```bash
# 1. 进入开发环境
cd cl1-formal
nix develop

# 2. 生成 AXI + ICache/DCache 顶层
cd CL1_Core
make verilog-axi-cache

# 3. 复制生成的 Cl1Top_AXI.sv 到验证目录
cp vsrc/Cl1Top_AXI.sv ../riscv-formal/cores/cl1/

# 4. 进入验证目录
cd ../riscv-formal/cores/cl1

# 5. 生成 AXI formal 检查
make CHECKS_CFG=checks_axi checks

# 6. 运行 AXI 全量验证
make CHECKS_CFG=checks_axi all JOBS=8

# 7. 查看 AXI 汇总
make axi-summary
```

常用子集：

```bash
make i                  # 37 条 RV32I
make m                  # 8 条 RV32M (ALTOPS)
make c                  # 25 条 RV32C
make base               # reg + pc_fwd + pc_bwd + unique + causal
make sanity             # base + cover
make csr                # priv_insn + trap_handler + csrw_* + csrc_*
make int                # interrupt
make deadlock           # hang + liveness
make insn_lw_ch0        # 单项（任意 target 名直接传给子 make）
make summary-i          # 只汇总 RV32I
make summary-m          # 只汇总 RV32M (ALTOPS)
make summary-c          # 只汇总 RV32C
make summary-base       # 只汇总 reg / pc / unique / causal
make summary-cover      # 只汇总 aggregate cover
make summary-sanity     # 只汇总 base + cover
make summary-csr        # 只汇总 CSR / priv / trap
make summary-int        # 只汇总 interrupt
make summary-deadlock   # 只汇总 hang + liveness
make CHECKS_CFG=checks_axi bus          # AXI 配置下运行 RVFI_BUS checker
make CHECKS_CFG=checks_axi summary-bus  # AXI 配置下汇总 RVFI_BUS checker
make clean-csr          # 清 CSR 组工作目录后再跑 make csr
make clean              # 删除生成的 checks/
```

AXI 快捷目标：

```bash
make axi-checks         # 生成 checks_axi/
make axi-all            # 运行 AXI 全量验证
make axi-base
make axi-cover
make axi-deadlock
make axi-csr
make axi-int
make axi-bus
make axi-summary
```

## 5. 测试情况总结

### 5.1 Native CoreBus

测试命令：

```bash
cd riscv-formal/cores/cl1
make checks
make all JOBS=8
make summary
```

`make summary` 结果摘录：

```text
STATUS       TIME  CHECK
------       ----  -----
PASS            6  csrc_any_mepc_ch0
PASS            6  csrc_any_mie_ch0
PASS            6  csrc_any_mstatus_ch0
PASS            6  csrc_const_misa_ch0
...
PASS          819  insn_lw_ch0
PASS          996  insn_c_add_ch0

Total: 91   PASS: 91   FAIL: 0   UNKNOWN: 0   (never ran): 0
```

这个结果覆盖 base / sanity / deadlock / interrupt / CSR / RV32I / RV32M(ALTOPS) / RV32C 全部目标。

### 5.2 AXI + Cache

测试命令：

```bash
cd riscv-formal/cores/cl1
make CHECKS_CFG=checks_axi checks
make CHECKS_CFG=checks_axi all JOBS=8
make axi-summary
```

`make axi-summary` 结果：

```text
Total: 98 PASS: 98 FAIL: 0 UNKNOWN: 0 (never ran): 0
```

AXI 路径覆盖 native-equivalent 的 ISA / CSR / interrupt / cover / deadlock / RV32I / RV32M(ALTOPS) / RV32C 检查，并额外覆盖 7 个 RVFI_BUS checker：

```text
causal_mem_ch0
causal_io_ch0
bus_imem_ch0
bus_dmem_ch0
bus_dmem_io_read_ch0
bus_dmem_io_write_ch0
bus_dmem_io_order_ch0
```

## 6. 检查项总表

riscv-formal 把“通道”（channel，即一条已 retire 指令的 RVFI 快照）作为基本观测单位。每个 checker 在 BMC 深度 N 内枚举所有可能的 trace，验证某个不变量在所有 trace 上成立。

| 组 | Make target | 项数 | 包含的 checker | 一句话验证内容 |
|---|---|---|---|---|
| **base** | `make base` | 5 | `reg_ch0` | rd_addr / rd_wdata 与体系架构寄存器一致；x0 永远读 0 |
| | | | `pc_fwd_ch0` | 当前指令的 `rvfi_pc_wdata` 等于下一条指令的 `rvfi_pc_rdata`（前向链） |
| | | | `pc_bwd_ch0` | 反向：下一条 `rvfi_pc_rdata` 等于当前 `rvfi_pc_wdata` |
| | | | `unique_ch0` | `rvfi_order` 单调严格递增、不重复（每条指令恰好 retire 一次） |
| | | | `causal_ch0` | RVFI 通道之间存在合法因果（前一条 retire 后下一条才能 retire） |
| **sanity** | `make sanity` | base + cover | `cover` | 求一条 aggregate witness trace：至少 2 条 retire，且同一 trace 中出现 load->store、store->load、DIV/REM rs2=0、同步 trap、非顺序 PC 更新 |
| **deadlock** | `make deadlock` | 2 | `hang` | DUT 不会卡死（`RISCV_FORMAL_DEADLOCK_ENV` 下任意时刻 <=20 步内可继续 retire） |
| | | | `liveness_ch0` | 弱公平条件下，每条 in-flight 指令最终都能 retire（30 步内见证） |
| **int** | `make int` | 1 | `interrupt_ch0` | 中断进入：mstatus.MIE -> 0、MPIE 保存原 MIE、`mepc <- pc_rdata`、`mcause` 写入、`pc_wdata <- mtvec.base` |
| **csr** | `make csr` | 13 (filter 后 12 跑) | `priv_insn_ch0` | ECALL/EBREAK/MRET 的 PC 与 CSR 副作用；按 RVFI 约定 `rvfi_trap=0`（priv 指令是正常 retire） |
| | | | `trap_handler_ch0` | 通用陷入处理：rd_addr=0、无内存副作用、PC <- mtvec |
| | | | `csrw_mstatus_ch0` | CSRRW/CSRRS/CSRRC 在 `any_mask=0x88`（MIE+MPIE 位）内的读-改-写语义 |
| | | | `csrw_mie_ch0` | 同上，`any_mask=0x888`（MSIE/MTIE/MEIE） |
| | | | `csrw_mtvec_ch0` | mtvec 全位可读写 |
| | | | `csrw_mepc_ch0` | mepc，`any_mask=0xfffffffe`（bit0 硬连线 0，IALIGN=32） |
| | | | `csrw_mcause_ch0` | mcause 全位 |
| | | | `csrw_mscratch_ch0` | mscratch 全位 |
| | | | ~~`csrw_misa_ch0`~~ | **被 `[filter-checks]` 关掉**：misa 是硬连线只读，不满足 csrw 的“可写”假设 |
| | | | `csrc_any_mstatus_ch0` | mstatus 在 `any_mask` 外的位永不被打扰（写 0 是 0、写 1 是 1 保持） |
| | | | `csrc_any_mie_ch0` | 同上，作用于 mie |
| | | | `csrc_any_mepc_ch0` | 同上，作用于 mepc |
| | | | `csrc_const_misa_ch0` | misa 任何时刻恒等于 `0x40001104`（验证 misa 的“只读常量”语义，替代 csrw_misa） |
| **i** | `make i` | 37 | `insn_<x>_ch0`，`<x>` 属于 isa_rv32i.txt | 每条 RV32I 指令：操作数读取、ALU 结果、PC 更新、内存访问 mask/addr/wdata 与参考模型一致 |
| **m** | `make m` | 8 | `insn_{mul,mulh,mulhsu,mulhu,div,divu,rem,remu}_ch0` | 同上，但参考模型用 ALTOPS（每条指令一组 32 位 bitmask，与 riscv-formal/insns/insn_*.v 完全一致） |
| **c** | `make c` | 25 | `insn_c_<x>_ch0` | 每条 RV32C 压缩指令：解压、寄存器选择、立即数符号扩展、SP/RAS 行为 |
| **bus** | `make CHECKS_CFG=checks_axi bus` / `make axi-bus` | 7 | `causal_mem_ch0`、`causal_io_ch0`、`bus_imem_ch0`、`bus_dmem_ch0`、`bus_dmem_io_read_ch0`、`bus_dmem_io_write_ch0`、`bus_dmem_io_order_ch0` | AXI read/write observer 产生 RVFI_BUS 事件，验证外部 AXI 事务和 RVFI memory 行为一致 |
| **summary** | `make summary` / `make axi-summary` | 91 / 98 | 全部 | 汇总并按 PASS/FAIL/UNKNOWN 统计 |

91 项包括：5 (base) + 1 (cover) + 2 (deadlock) + 1 (int) + 12 (csr，filter 后) + 37 (i) + 8 (m) + 25 (c)。

98 项 AXI 检查包括：上述 91 项 native-equivalent checker + 7 项 RVFI_BUS checker。AXI 配置使用 `nbus 2` 和 `buslen 32`，其中 channel 0 观测 AXI write，channel 1 观测 AXI read。

### 6.1 Cover witness

`cover` 是一个**聚合可达性目标**（aggregate witness），不是功能正确性证明。它用于确认 solver 能在同一条 trace 中同时走到几个关键微架构场景，反向佐证 RTL 没有把这些场景静态屏蔽掉。具体定义见 [riscv-formal/cores/cl1/checks.cfg](riscv-formal/cores/cl1/checks.cfg) 的 `[cover]` 段。

native cover 观测 5 个事件（每个事件用一个 sticky 寄存器记录"是否曾在本 trace 出现过"，最终一次性 cover 它们的合取）：

| 事件 | 含义 | 触发条件（基于 `channel[0]`） |
|---|---|---|
| `seen_ch0_load_store` | back-to-back load -> store | 上一拍 retire 的是 load（opcode `0000011`），当前拍 retire 的是 store（opcode `0100011`） |
| `seen_ch0_store_load` | back-to-back store -> load | 反向，验证两个方向都能背靠背 retire |
| `seen_ch0_divrem_zero` | M 扩展除零 | DIV/DIVU/REM/REMU 且 `rs2_rdata == 0` 时仍能正常 retire（ALTOPS 占位下走完控制路径） |
| `seen_ch0_trap` | 同步异常 trap | retire 时 `channel[0].trap` 为 1（当前主要由 load/store 非对齐触发） |
| `seen_ch0_nonseq_pc` | 非顺序 PC 更新 | 非 trap retire 且 `pc_wdata != pc_rdata + 4`（分支跳转、jal/jalr、c.j、MRET 等） |

最终 cover 语句：

```systemverilog
always @* if (!reset)
    cover (channel[0].cnt_insns >= 2 &&
           seen_ch0_load_store && seen_ch0_store_load &&
           seen_ch0_divrem_zero && seen_ch0_trap && seen_ch0_nonseq_pc);
```

`channel[0].cnt_insns >= 2` 把 trace 长度下界拉到至少 2 条 retire，避免 solver 用 1 拍就同时"打勾"所有事件。

AXI cover 在此基础上额外要求：

| 事件 | 含义 | 触发条件 |
|---|---|---|
| `seen_axi_read` | 至少出现一次 AXI read data bus 事务 | `rvfi_bus_valid[1] && rvfi_bus_data[1] && |rvfi_bus_rmask` |
| `seen_axi_write` | 至少出现一次 AXI write data bus 事务 | `rvfi_bus_valid[0] && rvfi_bus_data[0] && |rvfi_bus_wmask` |

运行与查看：

```bash
make cover           # 单跑 cover，BMC 深度 45
make sanity          # base (5) + cover (1) -> 共 6 项，全部 PASS
make summary-cover   # cover 子目标 summary
```

当前结果：`make cover` 在 step 45 内可达；`make sanity` 6/6 PASS。witness trace 落在 `checks/cover/engine_0/trace*.vcd`，可以用 `gtkwave` 直接打开确认上述 5 个事件按预期 sticky。

## 7. RV32I 指令明细

| 子类 | 指令 |
|---|---|
| 寄存器算术 | add, sub, and, or, xor, slt, sltu |
| 立即算术 | addi, andi, ori, xori, slti, sltiu |
| 移位 | sll, slli, srl, srli, sra, srai |
| 装载 | lb, lbu, lh, lhu, lw |
| 存储 | sb, sh, sw |
| 条件分支 | beq, bne, blt, bltu, bge, bgeu |
| 跳转 | jal, jalr |
| 立即 | lui, auipc |

## 8. RV32C 指令明细

| 子类 | 指令 |
|---|---|
| 立即 / 寄存器算术 | c.li, c.lui, c.addi, c.addi16sp, c.addi4spn, c.add, c.sub, c.mv, c.and, c.or, c.xor, c.andi, c.srli, c.srai, c.slli |
| 内存 | c.lw, c.lwsp, c.sw, c.swsp |
| 跳转 | c.j, c.jal, c.jr, c.jalr |
| 分支 | c.beqz, c.bnez |

## 9. 关键设计决定

| 项 | 选择 | 备注 |
|---|---|---|
| `rvfi_trap` 语义 | 只在 load/store 非对齐异常拉高；ECALL/EBREAK/MRET -> `rvfi_trap=0` 正常 retire | 与 `priv_insn_check` 中 `assert(!rvfi.trap)` 兼容 |
| 内存模型 | `RISCV_FORMAL_ALIGNED_MEM` 开 | sub-word 通过 word-aligned addr + byte-shifted mask 验证 |
| M 扩展 | `RISCV_FORMAL_ALTOPS` 开 | bitmask: MUL=`5876063e` MULH=`f6583fb7` MULHSU=`ecfbe137` MULHU=`949ce5e8` DIV=`7f8529ec` DIVU=`10e8fd70` REM=`8da68fa5` REMU=`3138d0e1` |
| CSR mask | mstatus `any_mask=0x88`、mie `any_mask=0x888`、mepc `any_mask=0xfffffffe` | 限制 csrw 检查只在可写位上比对 |
| 调试请求 | formal-only `chisel3.assume` 屏蔽 debug-mode 刷新 | 避免 BMC 选 anyinit 把 PC 拉去 dexc，导致 pc_fwd / trap_handler / interrupt 误报 |
| ENV defines | `RISCV_FORMAL_INTERRUPT`（int 组）/ `RISCV_FORMAL_DEADLOCK_ENV`（hang & liveness） | 在 checks.cfg 的 `[defines <check>]` 段按需切换 |
| 总线模式 | `CL1_EXPOSE_CORE_BUS=true` 生成 native CoreBus top；`false` 生成 AXI master top | 通过 `make verilog-native` / `make verilog-axi-cache` 切换 |
| AXI RVFI_BUS | AXI write observer -> ch0，AXI read observer -> ch1 | `checks_axi.cfg` 中 `nbus 2` / `buslen 32` 打开 bus checker |
| DCache uncached mask | uncached single transaction 使用 `req_mask_reg`，不复用只在写请求更新的 `wdat_mask_r` | 修正 uncached read mask 保真度，是功能语义修正 |
| AXI byte address | `CacheBus2Axi4` 用 `PriorityEncoder(mask)` 重构 `AWADDR/ARADDR` 低位 | formal 下 LSU 输出 word-aligned addr + byte mask，AXI 协议需要 byte address |
| AXI formal memory | `CL1_AXI_FAST_FORMAL_MEM` 固定 0 wait-state，OKAY response | 当前 baseline 聚焦 AXI/cache/ISA 一致性；任意 wait-state 和 error response 可后续增强 |

## 10. RV32-Zicsr / Priv 约定

本项目采用以下约定来对齐 CL1 的实现和 riscv-formal 的 RVFI 语义。

| 主题 | 约定 | 对应 checker |
|---|---|---|
| ECALL / EBREAK / MRET | 这些指令在 RVFI 中按“正常 retire”处理，`rvfi_valid=1` 且 `rvfi_trap=0`；它们的控制流变化通过 CSR 副作用和 `pc_wdata` 体现 | `priv_insn_ch0` |
| load/store 非对齐 | load/store 地址非对齐视为同步异常，WB 阶段把 `rvfi_trap` 拉高；同时不能发出真实内存请求 | `trap_handler_ch0`、相关 `insn_l*` / `insn_s*` |
| `rvfi_trap` | 只表示同步 fault 类异常；不把 ECALL / EBREAK / MRET 这种特权控制流归入 trap | `priv_insn_ch0`、`trap_handler_ch0` |
| `mstatus` | 只检查 MIE(bit3) 和 MPIE(bit7) 的可写行为，其他位按 `csrc_any` 保护 | `csrw_mstatus_ch0`、`csrc_any_mstatus_ch0` |
| `mie` | 只检查 MSIE(bit3)、MTIE(bit7)、MEIE(bit11) 的可写行为 | `csrw_mie_ch0`、`csrc_any_mie_ch0` |
| `mepc` | bit0 硬连线 0；formal 中用 `any_mask=0xfffffffe` 约束可写位 | `csrw_mepc_ch0`、`csrc_any_mepc_ch0` |
| `misa` | 硬连线 `0x40001104`（RV32IMC），写入被忽略；因此关闭 `csrw_misa_ch0`，改用 const 检查 | `csrc_const_misa_ch0` |
| 中断进入 | 外部/定时/软件中断进入时，`mepc <- pc_rdata`，`mcause.interrupt=1`，`mstatus.MPIE` 保存原 MIE，`mstatus.MIE` 清零，PC 跳到 `mtvec.base` | `interrupt_ch0` |
| 调试模式 | formal-only 屏蔽 debug-mode 相关刷新，使陷入进入 mtvec 而不是 debug exception base | base / trap / interrupt 相关检查 |

CSR 通道通过 RVFI 显式暴露 `mstatus`、`mie`、`mip`、`mepc`、`mcause`、`mtvec`、`mscratch`、`misa` 的 rmask/wmask/rdata/wdata。显式 CSR 指令写和陷入/MRET 造成的隐式写都应反映在对应 CSR 通道中。

`csrw_misa_ch0` 被 filter 的原因不是“misa 不验证”，而是 riscv-formal 的 `csrw_check` 假设目标 CSR 可写；CL1 的 `misa` 在本配置中是硬连线只读，所以使用 `csrc_const_misa_ch0` 验证它始终等于 RV32IMC 常量。

## 11. 总线模式选择

本项目保留 native CoreBus 和 AXI + Cache 两套 formal 入口。

### 11.1 Native CoreBus

- Verilog 生成：`cd CL1_Core && make verilog-native`
- 顶层模块：`Cl1Top`
- formal 配置：[riscv-formal/cores/cl1/checks.cfg](riscv-formal/cores/cl1/checks.cfg)
- wrapper 宏：`` `define CL1_USE_NATIVE_BUS ``
- 总线环境：`native_bus_dummy_slave`
- checker 数量：91

native 路径直接暴露 CL1 内部 `ibus` / `dbus` CoreBus，不启用 riscv-formal bus checker。

### 11.2 AXI + Cache

- Verilog 生成：`cd CL1_Core && make verilog-axi-cache`
- 顶层模块：`Cl1Top_AXI`
- formal 配置：[riscv-formal/cores/cl1/checks_axi.cfg](riscv-formal/cores/cl1/checks_axi.cfg)
- wrapper 宏：不定义 `CL1_USE_NATIVE_BUS`
- 总线环境：`axi4_dummy_slave`
- bus observer：[riscv-formal/cores/cl1/rvfi_bus_axi4_guard.sv](riscv-formal/cores/cl1/rvfi_bus_axi4_guard.sv)
- checker 数量：98

AXI 路径启用 ICache/DCache，执行流为：

```text
IFU/LSU -> ICache/DCache -> CacheBus -> CacheBus2Axi4 -> AXI master
       -> axi4_dummy_slave
       -> AXI read/write observer
       -> RVFI_BUS ch1/ch0
```

RVFI architectural memory 字段仍然来自 LSU 请求/响应；RVFI_BUS 来自 AXI 外部事务。bus checker 负责验证两者一致。

当前 `checks_axi.cfg` 过滤 fault 类 bus checker：

```text
fault_ch.*
bus_imem_fault_ch.*
bus_dmem_fault_ch.*
bus_dmem_io_read_fault_ch.*
bus_dmem_io_write_fault_ch.*
```

原因是 baseline dummy slave 返回 OKAY，不建模 AXI SLVERR/DECERR。后续如果要覆盖 error response，需要先扩展 AXI memory model，再打开这些 fault checker。

## 12. 项目结构

```text
cl1-formal/
├── flake.nix              # 统一 Nix 开发环境
├── .gitmodules            # submodule 声明
├── CL1_Core/              # Chisel 处理器核源码（submodule，跟踪 csr 分支）
│   ├── build.sc           # Mill 构建配置
│   ├── cl1/src/scala/     # Chisel 源码
│   └── vsrc/              # 生成的 Verilog（make verilog 后）
└── riscv-formal/          # RISC-V 形式化验证框架
    ├── checks/            # 通用验证检查模块
    ├── insns/             # 指令规范
    └── cores/cl1/         # CL1 核验证配置
        ├── checks.cfg     # native CoreBus 验证参数配置
        ├── checks_axi.cfg # AXI + Cache 验证参数配置
        ├── wrapper.sv     # RVFI/RVFI_BUS wrapper
        ├── rvfi_bus_axi4_guard.sv # AXI observer include guard
        ├── Makefile       # checks / all / csr / int / summary
        ├── summary.sh     # 汇总 SBY 运行结果
        ├── checks/        # native 生成的验证任务
        └── checks_axi/    # AXI 生成的验证任务
```
