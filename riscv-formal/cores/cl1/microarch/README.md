# CL1 Microarchitecture Checks

This directory contains CL1-specific module-level checks that complement the
generic RVFI/riscv-formal flow. These checks describe local microarchitecture
contracts; they are not written as regressions for specific injected bugs.

See `COVERAGE.md` for the current proof boundary, assumption inventory, and
known non-coverage.

Directory layout:

- `if_stage/`: `Cl1IFStage` frontend request/replay/flush checks.
- `idex_stage/`: `Cl1IDEXStage` decode, issue gating, trap/redirect checks.
- `wb_stage/`: `Cl1WBStage` commit, memory-response, and exception handoff checks.
- `excp_ctrl/`: `Cl1EXCP` trap/interrupt flush and WFI halt control checks.
- `lsu/`: `Cl1LSU` load/store bus protocol, outstanding, mask, and data extension checks.
- `fetch_align/`: `FetchAlign` fetch request alignment, error propagation, and cross-word instruction assembly checks.
- `regfile/`: `Cl1RegFile` architectural register-file invariants.
- `decode/`: `Cl2Decoder` and `Cl1RVCExpander` instruction classification checks.
- `alu/`: `Cl1ALU` arithmetic, logic, shift, and compare checks.
- `mdu/`: optional `CL1MDULp` formal-altops and real-arithmetic MDU checks.
- `csr/`: `Cl1CSR` and `Cl1EXCP` CSR/trap microarchitecture checks.

Available targets from `riscv-formal/cores/cl1`:

- `make microarch`: run the default microarchitecture suite: IF, IDEX, WB,
  EXCP control, LSU, FetchAlign, RegFile,
  Decode/RVC, ALU, `csr-unit`, `csr-trap-scenarios`, and `csr-trap-model`.
    Every module runs bounded assertion checking; checkers that declare cover
    points also run a separate cover-reachability task. Each module Makefile
    rejects generated models with zero assertion cells or zero expected cover
    cells through the shared `check_formal_cells.sh` guard.
    Before the suite starts, the Make target regenerates the index-width-1
    `Cl1Top_AXI_CACHE.sv` from the current `CL1_Core` Scala sources, copies it
    into the formal core directory, and verifies that the two files match.
- `make microarch-mdu` or `make -C microarch mdu-altops`: run the optional CL1
  MDU check for the current riscv-formal altops RTL. This target checks the
  formal replacement arithmetic used by riscv-formal, not the real
  multiplier/divider result. To keep it lightweight, normal nonzero divide is
  left to a future deep MDU proof rather than this triage target.
- `make microarch-mdu-real` or `make -C microarch mdu-real`: generate an
  optional non-altops RTL for `CL1MDULp` and run real MDU arithmetic checks.
  The default real target uses reduced symbolic operands to keep BMC time
  bounded: 8-bit sign/zero-extended operands for real multiplication and
  division/remainder, plus cover points for divide-by-zero and signed overflow.
  Full-width multiplication is available as `make -C microarch/mdu
  real-mul-full`, but it is intentionally not part of the default real target.
- `make clean-microarch`: remove generated SBY run directories under this
  tree.

The module-directory Make targets perform the same RTL preparation when run
directly. Parent-suite recursion marks the freshly generated RTL as ready so a
full suite generates it only once. Invoking `sby` directly is a low-level path
and does not provide this source-freshness check. The non-altops real-MDU Make
targets always regenerate their dedicated RTL before solving.

These checks are intentionally module-level because the generic RVFI flow only
observes retired architectural behavior. Internal frontend replay state,
pipeline issue gating, killed-response drain, CSR/trap side effects, and
trap/redirect priority can be wrong without naturally producing an RVFI failure
in the bounded native checks.

Contract matrix:

| Area | Contract class | Checked behavior |
| --- | --- | --- |
| IF stage | Interface protocol | Fetch request PC alignment, pending request PC retention under backpressure, and BPU input protocol assumptions. |
| IF stage | Kill/flush behavior | Flushes cannot produce a normal pipeline output in the same cycle; killed responses are drained instead of committed. |
| IF stage | Output consistency | IF-to-IDEX PC, compressed-instruction fields, RVC illegal flag, fetch error flag, and BPU prediction bit are internally consistent. |
| IDEX stage | Side-effect gating | `flush`, `stall`, and trap states suppress writeback, CSR writes, LSU requests, cache maintenance requests, and branch redirects. |
| IDEX stage | Decode interface | Register indexes, CSR index, `x1` write hint, and pipeline payload fields match the instruction entering decode/execute. |
| IDEX stage | Trap priority | Fetch error, RVC illegal, and illegal SYSTEM/CSR encodings produce the expected trap class and trap value before ordinary side effects. |
| IDEX stage | CSR execution | Supported/read-only CSR legality, CSR read enable, CSR write enable, and CSRRW/CSRRS/CSRRC write data match the decoded instruction and CSR operand. |
| IDEX stage | Memory/cache interface | LSU request `memType` and store data match the decoded pipeline payload; cache maintenance requests carry a meaningful invalid/clean command. |
| IDEX stage | Redirect behavior | JAL misprediction redirects use the design-specified base PC and immediate source. |
| WB stage | Commit gating | Flushes, memory backpressure, and memory errors gate register writes, CSR writes, and debug commit consistently. |
| WB stage | Exception handoff | Pipeline traps and load/store access errors produce the expected exception valid, cause, tval, and WB PC outputs. |
| WB stage | Writeback data | ALU/CSR/memory writeback data, destination indexes, x1 write hint, and memory-load classification match the committed payload. |
| EXCP control | Trap/interrupt priority | Exceptions save CSR state immediately; interrupts save only after DX/WB drain and do not override an active exception. |
| EXCP control | Flush target | Trap flushes use `mtvec` direct/vector target selection, while non-overlapped `mret` flushes use the return path. |
| EXCP control | WFI halt | A committed WFI request drives IF/DX halt intent unless a raw interrupt wake-up is present. |
| LSU | Bus protocol | Requests are only issued when the input request fires; response forwarding requires an outstanding request and preserves `memNotOutStanding`. |
| LSU | Store lane data | Store masks, bus size, write enable, cacheability, and shifted write data match address and `memType`. |
| LSU | Load extension | LB/LBU/LH/LHU/LW responses select the requested lane and perform the expected sign or zero extension. |
| FetchAlign | Request protocol | IF requests produce aligned bus addresses, preserve request payload under backpressure, and use cacheability from the fetch address. |
| FetchAlign | Error propagation | Bus fetch errors always produce an IFU-visible error response instead of being swallowed by cross-word fetch handling. |
| FetchAlign | Software contract | The microarchitecture proof assumes software does not redirect to a halfword address containing the first half of a 32-bit instruction. |
| RegFile | Register invariants | `x0` always reads as zero, writes to nonzero registers are visible on both read ports the next cycle, and `x1_val` matches reads of `x1`. |
| Decode/RVC | Instruction classification | Legal RV32I/M/CSR instruction families produce the expected immediate, ALU, branch, memory, CSR, MDU, writeback, illegal, and fence control classes. |
| Decode/RVC | Compressed expansion | RVC integer load/store, jump/branch, immediate, stack-pointer, and pass-through encodings expand to the expected 32-bit opcode/register/immediate fields and illegal flags. |
| ALU | Datapath semantics | One-hot ADD/SUB/logic/shift/SLT/SLTU operations produce the expected result, and compare side outputs match signed or unsigned ordering. |
| MDU altops | Optional formal arithmetic | In the current riscv-formal altops build, multiplication operations return the expected transformed result, immediate divide-by-zero cases respond, and busy outputs remain valid under backpressure. |
| MDU real | Optional reduced arithmetic | In a generated non-altops build, one-operation real `MUL/MULH/MULHSU/MULHU/DIV/REM/DIVU/REMU` checks compare CL1 output against a reduced symbolic reference model, while special divide paths are covered for reachability. |
| CSR/EXCP | CSR state model | Implemented machine CSRs, WARL/WPRI behavior, counters, interrupt pending/enables, and trap CSR updates follow the CL1 design model. |
| CSR/EXCP | Trap model | Exception, interrupt, WFI, and `mret` control outputs match a bounded symbolic reference model. |
| All | Reachability coverage | Key request, replay, trap, CSR update, memory, cache, and redirect `cover` points are solved as separate SBY cover tasks. |

The checks intentionally avoid constraining the machine into a single injected
bug scenario. Environment assumptions are limited to local interface contracts
that the connected CL1 modules normally provide, such as BPU predictions being
valid only when IF presents a valid instruction to the BPU.

ISA/RVFI checks and microarchitecture checks are deliberately separate. The
previous whole-core CSR cross-check mixed both layers, never instantiated its
intended internal checker, and dominated runtime with a vacuous BMC. CSR
internals remain covered by the module-level CSR/EXCP, IDEX, and WB checks.
