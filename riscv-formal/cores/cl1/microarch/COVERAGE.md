# CL1 微架构覆盖范围与假设

本文档记录 CL1 微架构检查当前的证明边界，明确默认套件预期能够捕获哪些失败、哪些检查
属于可选项，以及哪些假设属于局部环境契约。

## 目标边界

默认目标：

- `make microarch`

默认目标对 IF、IDEX、WB、Pipeline、LSU、FetchAlign、RegFile、Decode/RVC、ALU、
CSR 单元、陷阱场景和陷阱模型运行 BMC。声明了 cover 点的
检查器还会运行配对的 cover 任务。已声明的 cover 缺失或不可达会导致目标失败，而不是
仅作为 BMC-only 运行中的被动元数据。

所有用于运行检查的 Make 入口都会在求解前，根据当前 `CL1_Core` 源码重新生成或准备
生成的 RTL。父级套件会传播内部 ready 标志，避免每个模块都重复生成同一份 altops RTL。
直接调用 `sby` 有意不纳入该新鲜度契约。

可选目标：

- `make microarch-csr`：单独运行 CSR/EXCP 微架构检查组。
- `make microarch-mdu`：可选的 `CL1MDULp` riscv-formal altops 检查。
- `make microarch-mdu MDU_MODE=smoke`：可选的非 altops 真实算术检查，使用缩减的
  符号操作数。
- `make microarch-mdu MDU_MODE=full`：较重的可选非 altops 证明，使用任意
  32 位操作数。
- `make microarch-mdu MDU_MODE=strict`：严格全位宽算术证明，将 full DUT 检查与独立
  算术引理组合。

可选 MDU 目标是有针对性的算术证明，因此有意不纳入默认目标。

## 已覆盖内容

默认套件覆盖 RVFI/riscv-formal 无法直接观察，或只能经过多次流水线交互后才能观察的
局部模块契约：

- 前端请求/响应协议、冲刷处理、重放排空、预测载荷一致性和取指对齐行为。
- flush、stall、陷阱、CSR 合法性条件下译码级的副作用门控，以及存储器请求、cache
  维护请求和分支重定向的生成。
- WB 级提交门控、存储器响应处理、异常移交和写回数据选择。
- `Cl1Core` 中 IF→IDEX 和 IDEX→WB 两个寄存流水级的 ready/valid、完整 Bundle payload、
  反压保持与 flush 清空，以及中断接收时真实 DX/WB 为空和随后周期的全核 flush。
- LSU 请求协议、未完成事务跟踪、存储掩码/数据生成、cacheability 选择和 load
  符号/零扩展。
- `x0`、写可见性和 `x1_val` 的寄存器堆不变量。
- RV32I/M/CSR 和受支持 RV32C 整数压缩指令的译码器及 RVC 展开分类。
- ALU one-hot 算术、逻辑、移位和比较行为。
- CSR 单元状态模型和有界的陷阱/中断 CSR 更新场景。

## 假设审查

当前假设是局部接口契约，而不是注入错误场景。主要假设如下：

| 区域 | 假设 | 理由 |
| --- | --- | --- |
| IF 级 | 只有 IF 向 BPU 提供有效指令时，BPU 才预测 taken。 | 对相连 BPU/IF 协议建模，而不是证明任意无效 BPU 响应。 |
| FetchAlign | IF 请求 PC 的 bit 0 为零。 | CL1 取指地址按半字对齐。 |
| FetchAlign | 总线响应要求存在未完成请求。 | 防止环境注入无对应请求的响应；数据只在握手时采样。 |
| FetchAlign | 如果软件重定向到半字目标，该半字不是 32 位指令的前半部分。 | IF-T08 类别的显式软件契约；不将其证明为硬件支持。 |
| LSU | 输入 `memType` 是 CL1 load/store 编码之一。 | IDEX 已被独立检查会产生合法存储器类别。 |
| WB 级 | WB 输入编码符合 IDEX-to-WB 契约：当前不存在 `WB_PC4`、存储器类型合法、特权指令位已译码且陷阱不携带寄存器/CSR 副作用。 | 这些条件已由 IDEX producer 断言直接证明。 |
| Pipeline | debug 请求固定为关闭；AXI ready/response 输入保持任意。 | 调试行为不属于当前目标；任意 AXI 环境会扩大安全性质的状态空间。Pipeline cover 仅用于证明被检查的流水级、异常和中断锥可激活，不作为 AXI 协议正确性的证据。 |
| CSR 单元 | CSR 读地址限制为 CL1 机器级可读 CSR。 | 读值断言要求被寻址寄存器具有已定义的 CSR 模型。 |
| CSR 陷阱场景 | 场景选择器、符号 PC 和 mtvec 被约束为合法且对齐的设置值。 | 将场景 harness 限制在架构上有意义的陷阱/中断配置空间。 |
| MDU altops | 请求操作为合法 one-hot；busy 期间输入保持稳定；此分诊目标排除普通非零除法。 | 匹配 IDEX 保持 MDU 操作数的契约，并维持该可选目标的轻量性。 |
| MDU real arithmetic | 发出一个合法请求，`out_ready` 保持为高，禁用 flush，且 MDU busy 期间请求载荷保持稳定。`smoke` 使用缩减的符号操作数；`full` 保持 32 位操作数任意；`strict` 的分区并集覆盖完整 32 位输入空间。 | 对 IDEX 保持 MDU 操作数的契约建模，并将算术正确性与反压/取消协议分离。 |
| MDU real protocol | 不使用环境 `assume`；harness 自行生成最多两个合法请求并在请求活动期间保持载荷。 | 将任意反压、flush 和任意 32 位操作数的协议证明与算术参考模型分离。 |

`Decoupled` 接口只在 `valid && ready` 时传输载荷，并不等同于
`Irrevocable`。因此 FetchAlign 和 LSU 不再假设未握手期间的请求或响应载荷稳定；相关
checker 只检查握手时被消费的数据。MDU 是例外：结果状态会等待 `out_ready`，协议任务
明确证明 `out_valid && !out_ready` 期间结果保持不变。

## 契约闭合

当前已建立并验证以下组合关系：

- IDEX 输出的 `wbType`、`memType` 和 `privInstr` 满足 WB 的输入编码假设。
- IDEX 发往 LSU 的有效请求始终使用合法 load/store `memType`。
- IDEX 的陷阱和特权指令不会携带普通寄存器或 CSR 写副作用。
- WB 输出的 `ecall/mret/wfi` 互斥，所有特权/异常事件都蕴含 `wb_valid`。
- IF→IDEX 在 downstream ready 时逐周期传递 valid，以及 PC、指令、预测、压缩指令、
  取指异常和 `muldiv_b2b` 等全部 Bundle payload；在反压时保持整个流水级，并在全核
  flush 后清除 valid。
- IDEX→WB 在 downstream ready 时逐周期传递写回类型、结果、CSR、memory、PC、指令、
  压缩指令、trap 和 `dx_ready` 等全部 Bundle payload；在反压时保持整个流水级。
- 中断接收只能发生在真实 DX/WB 均为空时；新的异常请求和已接收的中断都在下一周期
  产生全核 flush。同一次连续 drain-stall 区间内从流水非空到中断接收的 cover 可达。
  这些行为性质不依赖 EXCP 输入端某一根具体连线的等式。
- trap 与输入指令中恰好译码出的 `ecall/mret` 可以重叠；EXCP 和 CSR 参考模型证明
  trap 保存及冲刷目标具有优先级，而不是通过互斥假设排除该情况。

关键的有意覆盖缩减包括：

- Pipeline 的 interrupt drain 证明是接收条件和 flush 的安全性质，并以 cover 证明一次
  连续 drain 场景可达；它不在任意 AXI 停顿下声明中断最终一定被接收的无界 liveness。
- FetchAlign 半字重定向软件契约。该契约按设计将 IF-T08 类别排除在硬件证明之外。
- `microarch-mdu` 中对 MDU 普通非零除法的排除。该目标是轻量的 altops 分诊检查；
  独立的 `microarch-mdu MDU_MODE=smoke` 模式在非 altops 构建中覆盖缩减符号域上的
  真实算术。

## MDU 状态

默认 ISA/RVFI 与 `make microarch` 使用的 `Cl1Top_AXI_CACHE.sv` 是 `CL1MDULp` 的
altops 构建，而不是真实乘除法算术构建。

依据：

- 当 `RISCV_FORMAL_ALTOPS` 为 true 时，
  `CL1_Core/cl1/src/scala/Cl1MDULp.scala` 选择 `out_bits := altops_rslt`。
- 生成的 `riscv-formal/cores/cl1/Cl1Top_AXI_CACHE.sv` 将 `io_out_bits` 赋值为
  `(rs1 +/- rs2) ^ bitmask`，即 riscv-formal 的 MDU 替代算术。

因此，`make microarch-mdu` 当前证明：

- altops 构建下合法的 one-hot MDU 操作选择。
- MDU 流水线延迟后的乘法类 altops 输出选择。
- 立即除零的 altops 响应。
- 被检查路径上的输出 valid/反压稳定性。

它不证明真实算术。真实算术由独立的 `make microarch-mdu MDU_MODE=smoke` 模式处理；
该模式在
`microarch/mdu/rtl/` 下生成非 altops 的 `Cl1Top_AXI_CACHE_REALMDU.sv`，并运行
`cl1_mdu_real.sby`。

`MDU_MODE=smoke` 证明：

- 对于根据操作类别进行符号/零扩展的 8 位符号操作数，真实 `MUL`、`MULH`、
  `MULHSU` 和 `MULHU` 结果正确。
- 对于根据操作类别进行符号/零扩展的非零 8 位符号操作数，真实 `DIV`、`REM`、
  `DIVU` 和 `REMU` 结果正确。
- 在 `out_ready` 保持为高时，于有界时间内产生结果。
- 通过 cover 语句证明除零商/余数行为以及有符号溢出 `INT_MIN / -1` 商/余数行为可达。
- 对任意 32 位合法操作，在任意结果反压和 flush 下保持单请求单响应记账正确。
- 结果反压期间 `out_valid/out_bits` 保持稳定，flush 后旧结果不会重新出现。
- `out_ready` 保持为高时任意合法操作在 42 个活动周期内到达结果；cover 已到达连续
  两次正常请求完成、普通乘法/除法、除零反压和 flush 取消路径。

`MDU_MODE=smoke` 仍不证明：

- 任意操作数上的完整 32 位乘除法。

独立的 `make microarch-mdu MDU_MODE=full` 模式取消操作数位宽缩减。它独立检查四种乘法
opcode，并以商/余数对检查有符号和无符号除法。逐周期 Booth 和非恢复除法不变量检查
MDU 的 ALU 请求和最终结果位；除零和 `INT_MIN / -1` 仍采用精确的独立断言。由于这些
证明比默认目标更重，因此保持为可选项。

`make microarch-mdu MDU_MODE=strict` 包含 `full` 的所有任务，并增加独立参考模型算术
闭合。乘法在未缩放 radix-4 Booth 状态旁维护一个独立的二进制移位加法累加器。该移位加法
构造直接从被跟踪的操作数和阶段计数导出乘数位及移位后的被乘数，逐步证明 Booth
重叠修正，并独立证明缩放的高半实现等价于未缩放乘积。除法证明实际的有符号和无符号
参考状态递推，使用构造性恒等式 `prefix = qd + remainder`、精确中间范围
`-|divisor| <= remainder < |divisor|`、最终余数范围/符号以及有符号数位商编码。
轻量的后状态断言还将已证明的算术值连接到寄存后的参考输出。操作数位分区使实际状态
证明保持可解，其并集覆盖完整输入空间。仅参考任务不包含 DUT 及其协议状态，因此生成
模型只包含算术参考锥。这些严格任务不使用检查器侧的 `*`、`/` 或 `%` 运算符，生成
模型会执行对应的禁用算术单元检查。专用严格 completion cover 用于确认乘法器结果映射
和普通除法完成路径可达。该目标不设置固定时间上限；运行时间受求解器、硬件资源和
`JOBS` 影响，其他 real 模式更适合作为常规回归。

### 真实 MDU 证明结构

真实算术证明应与默认 `microarch` 目标分离。现有 RVFI 流程有意启用
`CL1_RISCV_FORMAL_ALTOPS`，因此适用于 riscv-formal M 扩展检查，但不能用于证明物理
乘除法器算术。真实 MDU 证明需要独立、可选的非 altops 生成 RTL，同时保持
`checks*.cfg` 不变。

任务分组通过同一个 `real` 目标的 `REAL_LEVEL` 参数选择：

1. `REAL_LEVEL=protocol`：真实非 altops MDU 协议证明。
   安全任务允许任意结果反压和 flush，进度任务在 `out_ready` 保持为高时检查所有合法
   操作的有界完成，cover 任务到达连续请求、反压和取消路径。该目标不建立算术参考锥。

2. `REAL_LEVEL=div`：缩减符号操作数除法/求余以及 ISA 特殊情况 cover。
   覆盖普通 `DIV/DIVU/REM/REMU`、除零和有符号溢出 `INT_MIN / -1` 行为。

3. `REAL_LEVEL=mul`：真实乘法证明，每个任务对应一种 opcode。
   分别处理 `MUL`、`MULH`、`MULHSU` 和 `MULHU`；强制发出一个合法请求，在单元 busy
   期间保持请求位稳定，并在算术目标中保持 `out_ready` 为高。在本环境中证明完整位宽
   和 16 位符号参考的代价过高，因此签入的默认配置使用 8 位符号操作数。

4. `REAL_LEVEL=div-full`：可选的全位宽除法证明。
   此目标仍位于默认目标之外。它使用逐周期非恢复除法参考状态机，检查商和余数两个
   DUT 实例的 ALU 请求，并逐位比较最终结果，而不使用 `/` 和 `%` 构造第二个除法器。
   精确的 ISA 特殊情况由独立断言检查。

5. `REAL_LEVEL=mul-full`：可选的全位宽四种乘法及配对完成 cover。

6. `REAL_LEVEL=strict`：独立的全位宽算术闭合。
   它将完整 DUT/参考任务与操作数导出的二进制移位加法乘法、Booth 重编码/缩放、
   有符号和无符号实际状态非恢复除法不变量、局部步骤/范围引理、商重编码以及被除数
   前缀重构定理组合。它与 ISA/RVFI 检查及协议/反压检查保持分离。

时间控制规则：

- 将每种 opcode 拆分为独立 sby 任务，避免求解器在一个查询中探索所有 M 扩展 opcode。
- 必要时按操作数高位对严格算术进行分区。有符号任务使用 bit 31 的符号情况；最难的
  无符号除法象限还会按除数 bit 30 分区。所有分区的并集覆盖完整 32 位操作数空间。
- 分离算术结果正确性和协议行为的证明。算术任务保持 `out_ready` 为高；独立的真实
  MDU 协议任务覆盖反压、flush、连续请求和 ready/valid 稳定性。
- 将环境假设限制为 MDU 接口契约：一个合法操作、busy 期间请求载荷稳定，并且在前一
  结果被接受前不发出新请求。严格任务还可以使用穷尽的操作数位分区；局部组合引理则
  使用显式归纳前提，例如输入余数范围和算术恒等式。
- 全位宽证明任务主要使用 `btormc`；配对 cover、缩减算术和局部组合引理使用
  Boolector `smtbmc`。
  将严格等式聚合为一个 bad-state 属性，避免 `btormc` 针对每个结果位重复相同的
  UNSAT 搜索。

## 已知未覆盖项

当前微架构框架有意不覆盖：

- 调试模块行为和调试触发的异常路径。
- 不受限长度的非 altops MDU 连续请求流以及当前生成配置中被固定为 false 的 `b2b`
  旁路；协议 harness 最多跟踪两个请求，算术目标仍检查一个已接受请求。
- 使用检查器侧 `*`、`/` 或 `%` 的直接运算符全位宽比较。严格目标改用独立的移位
  加法乘法器和构造性除法恒等式；缩减的直接运算符任务覆盖 8 位符号域。
- 对重定向至 32 位指令前半部分的 IF-T08 半字地址提供硬件支持；这是软件契约。
- 完整的 cache 数据/tag 一致性证明。当前检查覆盖流水线/cache 维护请求契约，而不是
  完整的 cache 形式证明。
- 整核无界端到端活性。默认套件是有界的模块级 BMC；长时间活性/死锁检查仍位于
  riscv-formal 目标组中。
- CL1 机器级可读及已实现 CSR 模型之外的任意不受支持 CSR 行为。

## 审查结论

默认套件中没有发现会过度约束正常 CL1 模块契约的假设。上述有意缩小状态空间的假设
应视为显式证明边界，而不是隐藏的硬件保证。
