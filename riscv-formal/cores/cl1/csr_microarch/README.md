# CL1 CSR Microarchitecture Checks

This directory contains CL1-specific CSR module/interface checks. They are not
generic RVFI/spec checkers.

Run it from `riscv-formal/cores/cl1` with:

```bash
make csr-microarch
```

Available targets:

- `make csr-unit`: direct `Cl1CSR` unit-level state/reference check.
- `make csr-exec`: RVFI-flow CSR execution check. It uses the existing
  `rvfi_testbench` and `rvfi_wrapper` flow, then binds a CL1-specific CSR
  observer into `Cl1Top_AXI_CACHE`.
- `make csr-microarch`: run both checks.

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
