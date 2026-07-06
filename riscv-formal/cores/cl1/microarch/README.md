# CL1 Microarchitecture Checks

This directory contains CL1-specific module-level checks that complement the
generic RVFI/riscv-formal flow. These checks describe local microarchitecture
contracts; they are not written as regressions for specific injected bugs.

Directory layout:

- `if_stage/`: `Cl1IFStage` frontend request/replay/flush checks.
- `idex_stage/`: `Cl1IDEXStage` decode, issue gating, trap/redirect checks.
- `csr/`: `Cl1CSR` and `Cl1EXCP` CSR/trap microarchitecture checks.

Available targets from `riscv-formal/cores/cl1`:

- `make microarch`: run the fast microarchitecture suite: IF, IDEX,
  `csr-unit`, `csr-trap-scenarios`, and `csr-trap-model`.
- `make if-stage-uarch`: check `Cl1IFStage` request replay, flush-pending,
  killed-response drain, reset fetch target, and fetch-error propagation.
- `make idex-stage-uarch`: check `Cl1IDEXStage` CSR/privileged decode,
  multi-cycle issue gating, memory outstanding gating, trap-vs-redirect
  priority, and JAL immediate redirect generation.
- `make csr-microarch`: run the full CSR microarchitecture suite, including
  the RVFI-flow `csr-exec` check.
- `make csr-unit`, `make csr-exec`, `make csr-trap-scenarios`,
  `make csr-trap-model`: run individual CSR checks under `csr/`.
- `make clean-microarch`: remove generated SBY run directories under this
  tree.

These checks are intentionally module-level because the generic RVFI flow only
observes retired architectural behavior. Internal frontend replay state,
pipeline issue gating, killed-response drain, CSR/trap side effects, and
trap/redirect priority can be wrong without naturally producing an RVFI failure
in the bounded native checks.
