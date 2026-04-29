# CL1 riscv-formal 验证总览

> 生成自 `make summary`（91 项全部 PASS，0 FAIL，0 UNKNOWN）
> ISA 范围：RV32IMC + Zicsr + 中断 / 异常 / 调试相关基础设施
> 后端：Yosys + boolector，BMC depth = 35（insn）/ 12 (cover) / 8（hang/liveness）

## 1. 总体统计

| 维度 | 数量 |
|---|---|
| 总检查数 | **91** |
| 通过 (PASS) | **91** |
| 失败 (FAIL) | 0 |
| 未确定 (UNKNOWN) | 0 |
| 累计耗时 | ~ 35,000 s（≈ 9.7 h，单线程理论值；JOBS=8 实际墙钟约 1.2 h） |

按耗时区间分布：

| 区间 (s) | 数量 | 主要构成 |
|---|---|---|
| 0 – 30 | 11 | csrc_any_*、hang、cover、liveness、interrupt、csrw_mscratch、priv_insn、trap_handler |
| 30 – 100 | 4 | csrw_mcause / mtvec、unique、csrw_mepc |
| 100 – 200 | 8 | causal、csrw_mstatus、pc_bwd、insn_mulhsu / c_mv / csrw_mie / or / mulhu / sltiu / mul / bgeu / lui |
| 200 – 400 | 23 | M 扩展剩余、移位、比较、CB-type 跳转、auipc 等 |
| 400 – 600 | 27 | LB/SB/LH/SH、绝大多数算术/逻辑、JAL/JALR、CB/CJ 类跳转 |
| 600 – 1000 | 18 | LW/LHU、`reg`、`c_add`、c_lw / c_lwsp / c_swsp、c_addi4spn |

最慢三项：`insn_c_add_ch0` (996 s)、`insn_lw_ch0` (819 s)、`insn_c_lw_ch0` (770 s)。耗时主要由 BMC 步数 × DUT 内存路径状态空间决定。

## 2. 按检查组分类

### 2.1 基础完整性（5 项）

| Check | Time (s) | 主要验证内容 |
|---|---|---|
| reg_ch0 | 707 | 通用寄存器读/写：`rvfi_rd_wdata`、`rvfi_rs{1,2}_rdata` 与体系架构寄存器一致；x0 永远读 0 |
| pc_fwd_ch0 | 234 | 当前指令的 `pc_wdata` == 下一条指令的 `pc_rdata`（按序前向） |
| pc_bwd_ch0 | 114 | 下一条指令的 `pc_rdata` == 当前指令的 `pc_wdata`（反向追溯） |
| unique_ch0 | 50 | `rvfi_order` 单调严格递增、不重复 |
| causal_ch0 | 97 | 控制依赖正确：分支/跳转决定的取指序与体系语义一致 |

### 2.2 SBY 健全性（2 项）

| Check | Time (s) | 含义 |
|---|---|---|
| cover | 9 | 求一条 retire 至少 2 条指令的可达 trace（**找到见证 = PASS**） |
| hang | 8 | BMC 模式下 DUT 不会卡死；任意时刻在有限步内能继续 retire |

### 2.3 死锁与活性（1 项）

| Check | Time (s) | 验证 |
|---|---|---|
| liveness_ch0 | 11 | 弱公平条件下，每条 in-flight 指令最终都能 retire |

### 2.4 中断与陷入处理（2 项）

| Check | Time (s) | 验证 |
|---|---|---|
| interrupt_ch0 | 24 | 中断进入：mstatus.MIE/MPIE 转换、`mepc <- pc_rdata`、`mcause` 写入、`pc_wdata <- mtvec base` |
| trap_handler_ch0 | 31 | 异常处理通用规则：rd_addr=0、无内存副作用、PC 跳转 mtvec |

### 2.5 特权指令（1 项）

| Check | Time (s) | 验证 |
|---|---|---|
| priv_insn_ch0 | 31 | ECALL / EBREAK / MRET 的 CSR 副作用与 PC 行为；`rvfi_trap=0`（按 RVFI 约定 priv 指令是正常 retire） |

### 2.6 CSR 检查（10 项）

| Check | Time (s) | 验证 |
|---|---|---|
| csrw_mstatus_ch0 | 106 | CSRRW/CSRRS/CSRRC 对 mstatus 的读—改—写，wmask 内位与 wdata 一致 |
| csrw_mie_ch0 | 167 | 同上，作用于 mie |
| csrw_mtvec_ch0 | 36 | 同上，作用于 mtvec |
| csrw_mepc_ch0 | 65 | 同上，作用于 mepc |
| csrw_mcause_ch0 | 33 | 同上，作用于 mcause |
| csrw_mscratch_ch0 | 25 | 同上，作用于 mscratch |
| csrc_any_mstatus_ch0 | 6 | mstatus 只在被显式或隐式写时才变 |
| csrc_any_mie_ch0 | 6 | 同上，作用于 mie |
| csrc_any_mepc_ch0 | 6 | 同上，作用于 mepc |
| csrc_const_misa_ch0 | 6 | misa 恒等于 `0x40001104`（RV32IMC，硬连线） |

> `csrw_misa_ch0` 已在 `[filter-checks]` 中关闭：misa 在 DUT 中是硬连线（写被静默忽略），不符合 csrw_check"完全可写"假设；改用 `csrc_const_misa` 验证只读语义。

### 2.7 RV32I 指令（按类别合并）

| 类别 | 检查项 | 范围 (s) | 说明 |
|---|---|---|---|
| 加 / 减 / 比较 | add, addi, sub, slt, slti, sltu, sltiu | 176 – 430 | 算术与有符号/无符号比较 |
| 逻辑 / 立即 | and, andi, or, ori, xor, xori | 168 – 626 | 按位运算 |
| 移位 | sll, slli, srl, srli, sra, srai | 425 – 521 | 算术与逻辑移位 |
| Load | lb, lbu, lh, lhu, lw | 464 – 819 | sub-word 通过 word-shifted rmask 验证；非对齐自动触发 trap |
| Store | sb, sh, sw | 453 – 637 | 同上，store 路径 |
| 分支 | beq, bne, blt, bltu, bge, bgeu | 194 – 640 | 条件分支与 PC 计算 |
| 跳转 | jal, jalr | 573 – 580 | 链接寄存器 + 目标 PC |
| 立即装载 | lui, auipc | 195 – 440 | 高位立即数装载 |

合计 36 项 RV32I 指令检查。

### 2.8 RV32M 扩展（8 项）— ALTOPS 模式

| Check | Time (s) | DUT 实现 | spec 比对方式 |
|---|---|---|---|
| insn_mul_ch0 | 185 | Booth radix-4，~17 拍 | `(rs1+rs2) ^ 0x5876063e` |
| insn_mulh_ch0 | 238 | 同上 | `(rs1+rs2) ^ 0xf6583fb7` |
| insn_mulhsu_ch0 | 147 | 同上（带符号修正） | `(rs1-rs2) ^ 0xecfbe137` |
| insn_mulhu_ch0 | 175 | 同上 | `(rs1+rs2) ^ 0x949ce5e8` |
| insn_div_ch0 | 461 | 恢复余数除法器 ~34 拍 | `(rs1-rs2) ^ 0x7f8529ec` |
| insn_divu_ch0 | 417 | 同上 | `(rs1-rs2) ^ 0x10e8fd70` |
| insn_rem_ch0 | 198 | 同上 | `(rs1-rs2) ^ 0x8da68fa5` |
| insn_remu_ch0 | 476 | 同上 | `(rs1-rs2) ^ 0x3138d0e1` |

ALTOPS 用一组按指令异或的"伪运算"代替真乘除，将 BMC 状态空间从 2³² × 2³² 降到 2³² 量级，使 35 步 BMC 在分钟级完成。验证的是 **MDU 的控制路径与结果上送时序**，乘除数据通路本身需另行 RTL/FV/Spike 联合验证。

### 2.9 RV32C 扩展（19 项）

| 类别 | 检查项 | 范围 (s) | 说明 |
|---|---|---|---|
| 立即/装载 | c.li, c.lui, c.addi, c.addi16sp, c.addi4spn | 307 – 704 | 含 SP 偏移合法性 |
| 寄存器算术 | c.add, c.sub, c.and, c.or, c.xor, c.mv, c.andi, c.srli, c.srai, c.slli | 149 – 996 | 全部映射到对应 RV32I 比对 |
| 内存 | c.lw, c.lwsp, c.sw, c.swsp | 350 – 770 | 受 sub-word 与 SP 偏移影响 |
| 跳转 | c.j, c.jal, c.jr, c.jalr | 222 – 597 | RAS 与目标 PC |
| 分支 | c.beqz, c.bnez | 268 – 508 | 偏移立即数 9 位 sign-ext |

## 3. 关键设计决定

| 项 | 选择 | 备注 |
|---|---|---|
| 内存对齐模式 | `RISCV_FORMAL_ALIGNED_MEM` 开 | sub-word 用 word 地址 + byte-shifted rmask；DUT LSU 把非对齐捕获为 LOAD/STORE_ADDR_MISALIGNED 异常 |
| `rvfi_trap` 语义 | 仅同步异常（misalign），ECALL/EBREAK/MRET 算正常 retire | 与上游 priv_insn_check 约定一致 |
| M 扩展 | ALTOPS | bitmask 与 [insn_*.v](riscv-formal/insns/) 完全对齐；正算法验证留给联合仿真 |
| misa | 硬连线 `0x40001104`（RV32IMC）；写忽略 | 流片版本是 `0x40000104`（缺 M 位），formal-only 改动；filter 关掉 csrw_misa |
| CSR 接入 | mstatus/mie/mip/mepc/mcause/mtvec/mscratch/misa | 显式 + 隐式写（陷入/MRET）联合驱动 wmask/wdata |
| 调试请求 | `chisel3.assume(!dbg_flush)` | 屏蔽 debug 模式刷新对 PC 的扰动，避免 pc_fwd / trap_handler / interrupt 误报 |

## 4. 复跑指南

```bash
./run.sh all JOBS=8         # 全量
./run.sh m   JOBS=8         # M 扩展 8 项
./run.sh csr JOBS=4         # CSR 组
./run.sh insn_lw_ch0        # 单项
./run.sh clean-csr csr      # 清掉 CSR 组工作目录后重跑
```

## 5. 已知后续工作

- Phase 2 cover：back-to-back load/store、divzero、pipeline flush 等 cover 语句
- M 扩展去 ALTOPS 后的真实算法验证（需要更深 BMC 或 k-induction）
- LSU 字节地址 → word 地址重构（如想去掉 RVFI wrapper 中的 `& ~3` mask）
- Phase 3：将 priv/CSR 检查文档化到 `docs/`；补 `summary-m`、`summary-i`、`summary-c` 子目标
