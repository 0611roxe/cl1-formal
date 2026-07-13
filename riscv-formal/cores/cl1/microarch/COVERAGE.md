# CL1 Microarchitecture Coverage and Assumptions

This document records the current proof boundary for the CL1 microarchitecture
checks. The intent is to make it clear which failures are expected to be caught
by the default suite, which checks are optional, and which assumptions are part
of the local environment contract.

## Target Boundary

Default target:

- `make microarch`

The default target runs BMC for IF, IDEX, WB, EXCP control, LSU, FetchAlign,
RegFile, Decode/RVC, ALU, `csr-unit`, `csr-trap-scenarios`, and
`csr-trap-model`. Checkers that declare cover points also run a paired cover
task. A missing or unreachable declared cover is a target failure rather than
passive metadata in a BMC-only run.

All documented Make entry points regenerate or prepare their generated RTL
from the current `CL1_Core` sources before solving. The parent suite propagates
an internal ready flag to avoid regenerating the same altops RTL for every
module. Direct `sby` invocation is intentionally outside this freshness
contract.

Optional targets:

- `make microarch-mdu`: optional `CL1MDULp` riscv-formal altops check.
- `make microarch-mdu-real`: optional `CL1MDULp` non-altops real arithmetic
  check with reduced symbolic operands.

The optional MDU targets are intentionally not part of the default target
because they are targeted arithmetic triage proofs.

## What Is Covered

The default suite covers local module contracts that RVFI/riscv-formal cannot
observe directly or can observe only after many pipeline interactions:

- Frontend request/response protocol, flush handling, replay drain, prediction
  payload consistency, and fetch-alignment behavior.
- Decode-stage side-effect gating under flush, stall, traps, CSR legality,
  memory request generation, cache maintenance request generation, and branch
  redirect construction.
- WB-stage commit gating, memory response handling, exception handoff, and
  writeback data selection.
- EXCP trap/interrupt priority, trap target selection, WFI halt intent, and
  `mret` control behavior.
- LSU request protocol, outstanding tracking, store mask/data construction,
  cacheability selection, and load sign/zero extension.
- Register-file invariants for `x0`, write visibility, and `x1_val`.
- Decoder and RVC expansion classification for RV32I/M/CSR and supported RV32C
  integer compressed instructions.
- ALU one-hot arithmetic, logic, shift, and compare behavior.
- CSR unit state model and bounded trap/interrupt CSR update scenarios.

## Assumption Review

The current assumptions are local interface contracts, not injected-bug
scenarios. The main assumptions are:

| Area | Assumption | Rationale |
| --- | --- | --- |
| IF stage | BPU predicts taken only when IF presents a valid instruction to the BPU. | Models the connected BPU/IF protocol instead of proving arbitrary invalid BPU responses. |
| FetchAlign | IF request PC bit 0 is zero. | CL1 fetch addresses are halfword aligned. |
| FetchAlign | Bus responses require an outstanding request and stay stable under response backpressure. | Standard request/response environment contract. |
| FetchAlign | If software redirects to a halfword target, that halfword is not the first half of a 32-bit instruction. | Explicit software contract for the IF-T08 class; this is not proved as hardware support. |
| LSU | Input `memType` is one of the CL1 load/store encodings. | IDEX is separately checked to produce legal memory classes. |
| LSU | Input requests and bus responses remain stable while backpressured. | Standard Decoupled/bus protocol contract. |
| WB stage | WB input encodings match the IDEX-to-WB contract: no current `WB_PC4`, legal memory type, decoded privileged-instruction bits, and traps carry no side effects. | These are upstream pipeline contracts checked at IDEX or implied by CL1 control. |
| EXCP control | Debug ebreak is disabled. | Debug module behavior is outside the current microarchitecture target. |
| EXCP control | WB presents at most one committed privileged/trap side effect at a time, and such side effects imply `wb_valid`. | Models the WB-to-EXCP interface contract. |
| CSR unit | CSR read address is restricted to CL1 machine-readable CSRs. | Read-value assertions need a defined CSR model for the addressed register. |
| CSR trap scenarios | Scenario selector and symbolic PCs/mtvec are constrained to legal aligned setup values. | Keeps the scenario harness inside architecturally meaningful trap/interrupt setup space. |
| MDU altops | Request op is one-hot legal; busy inputs remain stable; normal nonzero divide is excluded from this triage target. | Matches the IDEX-held MDU operand contract and keeps this optional target lightweight. |
| MDU real | One legal request is issued, `out_ready` is held high, flush is disabled, and request payload remains stable while the MDU is busy. Default arithmetic operands are reduced symbolic values. | Models the IDEX-held MDU contract and keeps the non-altops arithmetic proof bounded. |

The two assumptions that deliberately reduce hardware coverage are:

- FetchAlign halfword redirect software contract. This excludes the IF-T08 class
  from hardware proof by design.
- MDU normal nonzero divide exclusion in `microarch-mdu`. That target is a
  lightweight altops triage check. The separate `microarch-mdu-real` target
  covers reduced symbolic real arithmetic in a non-altops build.

## MDU Status

The current `Cl1Top_AXI_CACHE.sv` used by the formal flow is an altops build for
`CL1MDULp`, not a real multiplier/divider arithmetic build.

Evidence:

- `CL1_Core/cl1/src/scala/Cl1MDULp.scala` selects `out_bits := altops_rslt` when
  `RISCV_FORMAL_ALTOPS` is true.
- The generated `riscv-formal/cores/cl1/Cl1Top_AXI_CACHE.sv` assigns
  `io_out_bits` as `(rs1 +/- rs2) ^ bitmask`, which is the riscv-formal MDU
  replacement arithmetic.

Therefore `make microarch-mdu` currently proves:

- Legal one-hot MDU operation selection under the altops build.
- Multiplication-class altops output selection after the MDU pipeline delay.
- Immediate divide-by-zero altops response.
- Output valid/backpressure stability for the checked paths.

It does not prove real arithmetic. Real arithmetic is handled by the separate
`make microarch-mdu-real` target, which generates a non-altops
`Cl1Top_AXI_CACHE_REALMDU.sv` under `microarch/mdu/rtl/` and runs
`cl1_mdu_real.sby`.

The default real target proves:

- Real `MUL`, `MULH`, `MULHSU`, and `MULHU` results for 8-bit symbolic operands
  sign/zero-extended according to the operation class.
- Real `DIV`, `REM`, `DIVU`, and `REMU` results for nonzero 8-bit symbolic
  operands sign/zero-extended according to the operation class.
- Bounded result production with `out_ready` held high.
- Reachability of divide-by-zero quotient/remainder behavior and signed
  overflow `INT_MIN / -1` quotient/remainder behavior through cover statements.

It still does not prove:

- Arbitrary full-width 32-bit multiplication and division for all operands.
- Backpressure behavior in the non-altops arithmetic target; that remains
  covered by the altops protocol check.

Full-width multiplication tasks exist as `make -C microarch/mdu real-mul-full`,
but they are intentionally treated as heavy optional experiments. Full-width
division remains a future deep target.

### Real MDU Proof Plan

The real arithmetic proof should stay out of the default `microarch` target.
The existing RVFI flow intentionally enables `CL1_RISCV_FORMAL_ALTOPS`, so it is
valid for riscv-formal M-extension checking but is not valid for proving the
physical multiplier/divider arithmetic. A real MDU proof needs a separate,
optional non-altops generated RTL build while leaving `checks*.cfg` unchanged.

Recommended target split:

1. `mdu-real-special`: cover proof for ISA special cases.
   Cover divide-by-zero and signed overflow `INT_MIN / -1` behavior. This target
   runs after the default arithmetic tasks because signed overflow reaches the
   normal divider result path.

2. `mdu-real-mul`: real multiplication proof, one opcode per task.
   Split `MUL`, `MULH`, `MULHSU`, and `MULHU`; force one legal request, keep
   request bits stable while the unit is busy, and hold `out_ready` high for the
   arithmetic target. The checked-in default uses 8-bit symbolic operands after
   full-width and 16-bit symbolic references proved too expensive in this
   environment.

3. `mdu-real-div-small`: normal division/remainder proof on a reduced symbolic
   operand space.
   Split `DIV`, `DIVU`, `REM`, and `REMU`; the checked-in default uses nonzero
   8-bit symbolic operands after the 16-bit reference divider was too expensive
   in this environment.

4. `mdu-real-div-full`: optional full-width division proof.
   This is expected to be expensive and should not be a default target. Prefer
   quotient/remainder consistency assertions, such as
   `dividend == quotient * divisor + remainder` plus remainder range and sign
   rules, instead of building a second full divider with `/` and `%` in the
   checker. Exact ISA special cases should remain separate assertions.

Time-control rules:

- Split every opcode into an independent sby task so the solver does not
  explore all M-extension opcodes in one query.
- Prove arithmetic result correctness and backpressure behavior separately.
  Arithmetic tasks can hold `out_ready` high; the current altops check already
  covers ready/valid stability under backpressure.
- Use assumptions that describe the MDU interface contract only: one legal
  operation, stable request payload while busy, and no new request until the
  previous result is accepted.
- Start with Boolector for bit-vector proofs. If Bitwuzla is available, compare
  it on the real multiplier/divider targets and keep the faster stable engine.

## Known Non-Coverage

The current microarchitecture framework intentionally does not cover:

- Debug-module behavior and debug-triggered exception paths.
- Arbitrary full-width non-altops MDU arithmetic.
- Hardware support for IF-T08 halfword redirect into the first half of a
  32-bit instruction; this is a software contract.
- Full cache data/tag coherence proofs. Current checks cover pipeline/cache
  maintenance request contracts, not a complete cache-formal proof.
- Unbounded end-to-end liveness of the whole core. The default suite is bounded
  module-level BMC; long liveness/deadlock checks remain in the riscv-formal
  target groups.
- Arbitrary unsupported CSR behavior outside the CL1 machine-readable and
  implemented CSR model.

## Review Result

No assumption in the default suite appears to overconstrain a normal CL1 module
contract. The assumptions that intentionally narrow the state space are called
out above and should be treated as explicit proof boundaries, not hidden
hardware guarantees.
