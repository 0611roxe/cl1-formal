# CL1 微架构检查

本目录包含 CL1 专用的模块级检查，用于补充通用的 RVFI/riscv-formal 流程。
这些检查描述局部微架构契约，而不是针对某个特定注入错误编写的回归测试。

当前证明边界、假设清单和已知未覆盖项见 [COVERAGE.md](COVERAGE.md)。

目录结构：

- `if_stage/`：`Cl1IFStage` 前端请求、重放和冲刷检查。
- `idex_stage/`：`Cl1IDEXStage` 译码、发射门控、陷阱和重定向检查。
- `wb_stage/`：`Cl1WBStage` 提交、存储器响应和异常移交检查。
- `pipeline/`：`Cl1Core` 内 IF→IDEX→WB 流水级的握手、完整 Bundle payload、反压、
  冲刷和 interrupt drain 安全性检查。
- `lsu/`：`Cl1LSU` 访存总线协议、未完成事务、掩码和数据扩展检查。
- `fetch_align/`：`FetchAlign` 取指请求对齐、错误传播和跨字指令拼接检查。
- `regfile/`：`Cl1RegFile` 架构寄存器堆不变量。
- `decode/`：`Cl2Decoder` 和 `Cl1RVCExpander` 指令分类检查。
- `alu/`：`Cl1ALU` 算术、逻辑、移位和比较检查。
- `mdu/`：可选的 `CL1MDULp` formal-altops 和真实算术 MDU 检查。
- `csr/`：`Cl1CSR` 和 `Cl1EXCP` 的 CSR/陷阱微架构检查。

在 `riscv-formal/cores/cl1` 下可用的目标：

- `make microarch`：运行默认微架构套件，包括 IF、IDEX、WB、Pipeline、
  LSU、FetchAlign、RegFile、Decode/RVC、ALU，以及 CSR 单元、陷阱场景和陷阱模型。
  每个模块都运行有界断言检查；声明了 cover 点的检查器还会运行独立的
  cover 可达性任务。每个模块的 Makefile 都通过共享的
  `check_formal_cells.sh` 防护脚本拒绝断言单元数为零或预期 cover 单元数为零的
  生成模型。套件开始前，Make 目标会基于当前 `CL1_Core` Scala 源码重新生成
  index-width-1 的 `Cl1Top_AXI_CACHE.sv`，将其复制到形式验证 core 目录，并验证
  两份文件一致。
  Pipeline 默认目标运行全核 `bmc/cover`。该任务直接例化 `Cl1Core`，证明
  IF→IDEX 和 IDEX→WB 两个
  `PipelineConnect` 边界在握手、反压和 flush 下正确传递 valid 及 Bundle 中的全部
  payload 字段；中断只能在真实 DX/WB 均为空后接收，随后产生全核 flush。cover 还要求
  同一次连续 drain-stall 区间内先出现流水非空、再接收中断。该 cover 证明场景可达，
  不把任意总线环境下的最终中断接收声明为无界 liveness。这些是微架构内部协议和时序
  性质，不依赖也不改变 ISA/RVFI 检查。
- `make microarch-csr`：单独运行 CSR 单元、陷阱场景和陷阱参考模型这一组检查。
- `make microarch-mdu`：运行可选的 CL1 MDU
  检查，目标为当前 riscv-formal altops RTL。此目标检查 riscv-formal 使用的
  形式算术替代实现，而不检查真实乘除法器结果。为保持轻量，普通非零除法不纳入
  此分诊目标，而由非 altops 的 `smoke`、`full` 和 `strict` 模式覆盖。
- `make microarch-mdu MDU_MODE=smoke`：为 `CL1MDULp`
  生成可选的非 altops RTL，并运行真实 MDU 算术检查。`smoke` 算术任务使用缩减的
  符号操作数以限制 BMC 时间：真实乘法以及除法/求余使用经符号或零扩展的 8 位
  操作数，同时用 cover 点检查除零和有符号溢出。独立协议任务使用任意 32 位请求，
  检查结果反压保持、flush 取消、单请求单响应、连续两次正常请求和有界完成。
- `make microarch-mdu MDU_MODE=full`：运行较重的
  可选全位宽非 altops 证明。四种 32 位乘法操作的两个操作数都保持完全符号化，
  有符号和无符号商/余数也以成对任务进行检查。full 任务使用 `btormc` 和逐周期的
  radix-4 Booth/非恢复除法参考不变量，而不是直接用数学运算符构造第二个全位宽
  乘除法器。
  配对 cover 任务用于证明完成路径可达。算术和 cover 任务并行运行，可通过
  `JOBS` 调整并发上限。这是覆盖所有输入的微架构算法证明，而不是针对直接数学
  运算符的独立全位宽等价性证明。
- `make microarch-mdu MDU_MODE=strict`：包含 `full` 的任务，并增加独立算术构造以
  闭合其参考算法。严格乘法器从被跟踪的请求中
  独立导出两个移位加法操作数，并将该证明与 Booth 重叠、重编码和缩放定理组合。
  严格除法器证明有符号和无符号实际状态的商/余数恒等式、中间与最终余数边界、
  符号规则、商重编码以及已寄存参考结果的映射。仅参考模型不包含 DUT/协议锥。
  严格 completion cover 用于确认乘法结果映射和普通除法完成路径可达。严格模型还会
  拒绝对应检查器侧 `*`、`/` 或 `%` 的算术单元。该目标不设置超时，实际运行时间取决于
  求解器、主机和 `JOBS`。
- `make clean-microarch`：删除本目录树下生成的 SBY 运行目录。

需要只跑某一类真实 MDU 任务时，仍使用同一入口并选择
`MDU_MODE=protocol|mul|div|mul-full|div-full`。在 `microarch/mdu` 目录直接运行时，
等价入口为 `make real REAL_LEVEL=<mode>`；不再为每一类任务维护独立 Make 子目标。

直接运行各模块目录中的 Make 目标时，也会执行相同的 RTL 准备。父级套件递归会将
刚生成的 RTL 标记为已就绪，因此整套测试只生成一次。直接调用 `sby` 属于低层入口，
不会执行源码新鲜度检查。非 altops 的真实 MDU Make 目标在求解前始终重新生成其专用
RTL。

这些检查有意采用模块级形式，因为通用 RVFI 流程只能观察退休后的架构行为。内部前端
重放状态、流水线发射门控、被取消响应的排空、CSR/陷阱副作用以及陷阱/重定向优先级即使
出错，也未必会在有界的原生检查中自然产生 RVFI 失败。

契约矩阵：

| 区域 | 契约类别 | 检查行为 |
| --- | --- | --- |
| IF 级 | 接口协议 | 取指请求 PC 对齐、反压期间保留待处理请求 PC，以及 BPU 输入协议假设。 |
| IF 级 | 取消/冲刷行为 | 冲刷不能在同一周期产生正常流水线输出；被取消的响应应被排空而不是提交。 |
| IF 级 | 输出一致性 | IF 到 IDEX 的 PC、压缩指令字段、RVC 非法标志、取指错误标志和 BPU 预测位在内部保持一致。 |
| IDEX 级 | 副作用门控 | `flush`、`stall` 和陷阱状态抑制写回、CSR 写、LSU 请求、cache 维护请求和分支重定向。 |
| IDEX 级 | 译码接口 | 寄存器索引、CSR 索引、`x1` 写提示和流水线载荷字段与进入译码/执行的指令一致。 |
| IDEX 级 | 陷阱优先级 | 取指错误、RVC 非法以及非法 SYSTEM/CSR 编码在普通副作用之前产生预期的陷阱类别和陷阱值。 |
| IDEX 级 | CSR 执行 | 支持项/只读项 CSR 合法性、CSR 读使能、CSR 写使能以及 CSRRW/CSRRS/CSRRC 写数据与译码后的指令和 CSR 操作数一致。 |
| IDEX 级 | 存储器/cache 接口 | LSU 请求 `memType` 和存储数据与译码后的流水线载荷一致；cache 维护请求携带有效的 invalidate/clean 命令。 |
| IDEX 级 | 重定向行为 | JAL 误预测重定向使用设计规定的基准 PC 和立即数来源。 |
| WB 级 | 提交门控 | 冲刷、存储器反压和存储器错误以一致方式门控寄存器写、CSR 写和调试提交。 |
| WB 级 | 异常移交 | 流水线陷阱和 load/store 访问错误产生预期的异常有效信号、cause、tval 和 WB PC 输出。 |
| WB 级 | 写回数据 | ALU/CSR/存储器写回数据、目的索引、x1 写提示和 load 分类与提交载荷一致。 |
| EXCP 控制 | 陷阱/中断优先级 | 异常立即保存 CSR 状态；中断只在 DX/WB 排空后保存，且不会覆盖活动异常。 |
| EXCP 控制 | 冲刷目标 | 陷阱冲刷使用 `mtvec` 直接/向量目标选择；无重叠的 `mret` 冲刷使用返回路径。 |
| EXCP 控制 | WFI 停机 | 已提交的 WFI 请求产生 IF/DX 停机意图，除非存在原始中断唤醒。 |
| LSU | 总线协议 | 只有输入请求握手时才发出请求；响应转发要求存在未完成请求，并保持 `memNotOutStanding` 语义。 |
| LSU | 存储通道数据 | 存储掩码、总线 size、写使能、cacheability 和移位后的写数据与地址及 `memType` 一致。 |
| LSU | 载入扩展 | LB/LBU/LH/LHU/LW 响应选择请求的通道，并执行预期的符号扩展或零扩展。 |
| FetchAlign | 请求协议 | IF 请求在握手时产生对齐的总线地址，并根据取指地址选择 cacheability；未握手载荷遵循 `Decoupled` 而非 `Irrevocable` 语义。 |
| FetchAlign | 错误传播 | 总线取指错误始终产生 IFU 可见的错误响应，不会被跨字取指处理吞掉。 |
| FetchAlign | 软件契约 | 微架构证明假设软件不会重定向到一个包含 32 位指令前半部分的半字地址。 |
| RegFile | 寄存器不变量 | `x0` 始终读为零；对非零寄存器的写入在下一周期对两个读端口均可见；`x1_val` 与读取 `x1` 一致。 |
| Decode/RVC | 指令分类 | 合法 RV32I/M/CSR 指令族产生预期的立即数、ALU、分支、存储器、CSR、MDU、写回、非法和 fence 控制类别。 |
| Decode/RVC | 压缩指令展开 | RVC 整数 load/store、跳转/分支、立即数、栈指针和直通编码展开为预期的 32 位 opcode、寄存器、立即数字段和非法标志。 |
| ALU | 数据通路语义 | one-hot ADD/SUB/逻辑/移位/SLT/SLTU 操作产生预期结果，比较侧带输出与有符号或无符号顺序一致。 |
| MDU altops | 可选形式算术 | 在当前 riscv-formal altops 构建中，乘法操作返回预期的变换结果，立即除零路径产生响应，且 busy 输出在反压期间保持有效。 |
| MDU real | 可选缩减算术与协议 | 在生成的非 altops 构建中，单次真实 `MUL/MULH/MULHSU/MULHU/DIV/REM/DIVU/REMU` 检查将 CL1 输出与缩减的符号参考模型比较；独立任务检查任意 32 位请求下的反压、flush、响应计数、连续请求和有界进度。 |
| MDU real full | 可选全位宽算术 | 在非 altops 构建中，逐 opcode 检查任意 32 位乘法；成对的有符号/无符号商余数实例与逐周期 Booth/非恢复除法参考比较，同时检查精确的除零/溢出、有界结果和完成 cover 属性。独立的直接运算符等价性仍仅限于缩减 real 目标。 |
| MDU real strict | 可选独立算术闭合 | 全位宽 DUT/参考证明与操作数导出的二进制移位加法乘法器、缩放/未缩放 Booth 等价性，以及有符号/无符号实际状态非恢复除法的商余数恒等式、范围、符号、重编码和寄存结果映射定理组合，检查器侧不使用 `*`、`/` 或 `%`。 |
| CSR/EXCP | CSR 状态模型 | 已实现的机器级 CSR、WARL/WPRI 行为、计数器、中断 pending/enable 和陷阱 CSR 更新遵循 CL1 设计模型。 |
| CSR/EXCP | 陷阱模型 | 异常、中断、WFI 和 `mret` 控制输出与有界符号参考模型一致。 |
| 全部 | 可达性覆盖 | 关键请求、重放、陷阱、CSR 更新、存储器、cache 和重定向 `cover` 点作为独立 SBY cover 任务求解。 |

这些检查有意避免将机器约束到单一的注入错误场景。环境假设仅限于相连 CL1 模块通常
提供的局部接口契约，例如只有 IF 向 BPU 提供有效指令时，BPU 预测才有效。

模块契约采用 producer guarantee 到 consumer assumption 的闭合关系：IDEX 证明输出
`wbType/memType/privInstr` 合法以及陷阱/特权指令不携带普通寄存器和 CSR 副作用；WB
据此证明特权事件互斥并且所有 EXCP 事件都蕴含 `wb_valid`。异常可以与指令位中译码出的
`ecall/mret` 重叠，EXCP/CSR 陷阱模型会直接证明异常优先级，而不再假设该重叠不存在。

ISA/RVFI 检查与微架构检查刻意保持分离。此前的全核 CSR 交叉检查混合了两个层次，
没有例化预期的内部检查器，并被空洞的 BMC 主导运行时间。CSR 内部行为仍由模块级
CSR/EXCP、IDEX 和 WB 检查覆盖。
