# CL1 CSR Microarchitecture Checks

This directory contains CL1-specific CSR module/interface checks under the
shared `microarch/` tree. They are not generic RVFI/spec checkers.

Run it from `riscv-formal/cores/cl1` with:

```bash
make csr-microarch
```

Available targets:

- `make csr-unit`: direct `Cl1CSR` unit-level state/reference check.
- `make csr-exec`: RVFI-flow CSR execution check. It uses the existing
  `rvfi_testbench` and `rvfi_wrapper` flow, then binds a CL1-specific CSR
  observer into `Cl1Top_AXI_CACHE`.
- `make csr-trap-scenarios`: scenario-driven `Cl1EXCP` + `Cl1CSR` coupled
  check for trap and interrupt CSR side effects.
- `make csr-trap-model`: bounded free-running `Cl1EXCP` + `Cl1CSR`
  reference-model check. It does not schedule fixed scenarios; machine CSR
  writes, interrupts, exception sources, `mret`, WFI, and pipeline busy inputs
  are symbolic each cycle. Debug-module behavior is intentionally out of
  scope.
- `make csr-microarch`: run all CSR checks, including `csr-exec`.
- `make microarch`: run the fast microarchitecture suite from the parent
  directory. It includes `csr-unit`, `csr-trap-scenarios`, and
  `csr-trap-model`, but leaves `csr-exec` as an explicit target because it
  uses the heavier RVFI-flow wrapper.

SBY run directories are created under this directory.

Covered CL1 CSR behavior:

- The RVFI-flow check uses the CL1 architectural CSR matrix from
  `CSRs.machineReadable` and `CSRs.readOnly`: legal CSR reads must not trap,
  unsupported CSR accesses must trap, and writes to read-only CSRs must trap.
- Supported machine CSRs include `misa`, `mstatus`, `mstatush`, `mtvec`,
  `mscratch`, `mepc`, `mcause`, `mtval`, `mip`, and `mie`.
- Machine information CSRs: `mvendorid=0`, `marchid=5`, `mimpid=0`,
  `mhartid=0`, and `mconfigptr=0`.
- Machine counters: `mcycle/mcycleh` and `minstret/minstreth` reset, write,
  carry, and increment behavior. CL1 exposes these as RV32 ISA CSRs here; this
  checker intentionally does not add the riscv-formal 64-bit `mcycle/minstret`
  CSR sideband.
- Debug CSRs exist inside `Cl1CSR`, but they are not in CL1's machine-readable
  CSR set for normal CSR instructions, so `csr-exec` checks normal instruction
  accesses to them as illegal/trapping accesses.
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
  reference model for the coupled modules. Unlike `csr-trap-scenarios`, it
  does not force a fixed setup/event/check schedule; it proves the EXCP
  outputs, CSR-facing control, CSR state outputs, WFI halt outputs, and bore
  observer signals match the reference model across bounded arbitrary input
  traces.
