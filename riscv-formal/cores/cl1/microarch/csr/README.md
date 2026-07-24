# CL1 CSR Microarchitecture Checks

This directory contains CL1-specific CSR module/interface checks under the
shared `microarch/` tree. They are not generic RVFI/spec checkers.

Run the fast microarchitecture suite from `riscv-formal/cores/cl1` with:

```bash
make microarch
```

Run only the grouped CSR/EXCP checks with `make microarch-csr` from the same
directory.

Available targets inside this directory:

- `make run`: run `unit`, `trap-scenarios`, and `trap-model` as one group.
- `make unit`: direct `Cl1CSR` unit-level state/reference check.
- `make trap-scenarios`: scenario-driven `Cl1EXCP` + `Cl1CSR` coupled check
  for trap and interrupt CSR side effects.
- `make trap-model`: bounded free-running `Cl1EXCP` + `Cl1CSR`
  reference-model check. It does not schedule fixed scenarios; machine CSR
  writes, interrupts, exception sources, `mret`, WFI, and pipeline busy inputs
  are symbolic each cycle. Debug-module behavior is intentionally out of scope.

SBY run directories are created under this directory.

Covered CL1 CSR behavior:

- The IDEX checker uses the CL1 architectural CSR matrix from
  `CSRs.machineReadable` and `CSRs.readOnly`: unsupported CSR accesses and
  writes to read-only CSRs must be classified as illegal.
- Supported machine CSRs include `misa`, `mstatus`, `mstatush`, `mtvec`,
  `mscratch`, `mepc`, `mcause`, `mtval`, `mip`, and `mie`.
- Machine information CSRs: `mvendorid=0`, `marchid=5`, `mimpid=0`,
  `mhartid=0`, and `mconfigptr=0`.
- Machine counters: `mcycle/mcycleh` and `minstret/minstreth` reset, write,
  carry, and increment behavior. CL1 exposes these as RV32 ISA CSRs here; this
  checker intentionally does not add the riscv-formal 64-bit `mcycle/minstret`
  CSR sideband.
- Debug CSRs exist inside `Cl1CSR`, but they are not in CL1's machine-readable
  CSR set for normal CSR instructions; the IDEX legality checker classifies
  those accesses as illegal.
- The trap scenario check is a symbolic interface-contract check, not a
  counterexample regression. It leaves PC values, `mtvec` base, exception
  cause/`mtval`, interrupt pending/enable combinations, and relevant
  `mstatus` pre-state symbolic, then proves the CL1 `Cl1EXCP` to `Cl1CSR`
  behavior for trap-controller classes: interrupt `mepc` save from `next_pc`,
  MEI > MSI > MTI priority, negative interrupt gating through global
  `mstatus.MIE` and per-source `mie`, interrupt drain/flush sequencing while
  the pipeline is non-empty, exception source priority and `mtval`
  propagation for hardware exception, ebreak, and ecall sources, same-cycle
  exception-over-interrupt priority, vectored interrupt offset `cause << 2`,
  and `mret` restoration of `mstatus.MIE/MPIE`.
- The trap model check complements the scenario check with a cycle-by-cycle
  reference model for the coupled modules. Unlike `trap-scenarios`, it
  does not force a fixed setup/event/check schedule; it proves the EXCP
  outputs, CSR-facing control, CSR state outputs, WFI halt outputs, and bore
  observer signals match the reference model across bounded arbitrary input
  traces.

An RVFI-space internal CSR cross-check is intentionally not maintained here:
the previous whole-core target did not instantiate its CL1-specific checker
and therefore produced vacuous results while dominating regression time.
ISA/RVFI checks remain architectural; CSR microarchitecture behavior is
covered by the unit, trap-scenario, trap-model, IDEX, and WB checks above.
