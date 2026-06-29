# cl1

RISC-V formal verification setup for the CL1 core.

## Configurations

| Configuration | DUT | Scope |
|---|---|---|
| `checks.cfg` | `Cl1Top.sv` | Native CoreBus main checks, including `fault_ch0`, native fault-progress and interrupt-progress in `hang` / `liveness` |
| `checks_axi.cfg` | `Cl1Top_AXI.sv` | AXI no-cache main checks, including full bus-fault coverage |
| `checks_axi_cache.cfg` | `Cl1Top_AXI_CACHE.sv` | AXI + cache main checks; keeps RVFI/data-side fault checks and filters `bus_imem_fault_ch0` |

`CL1_USE_NATIVE_BUS` selects the native-bus DUT. It is defined by `checks.cfg`. AXI configs leave it undefined. `checks_axi.cfg` instantiates `Cl1Top_AXI`; `checks_axi_cache.cfg` defines `CL1_USE_AXI_CACHE_DUT` and instantiates `Cl1Top_AXI_CACHE`. The cache DUT is generated with ICache/DCache enabled; the default formal cache geometry is intentionally small (`CL1_AXI_FORMAL_CACHE_IDXW=1`) so the processor-plus-cache AXI path is present without turning every riscv-formal check into a large cache-internal proof.

## Usage

Generate the DUT Verilog in the top-level repository, then copy it here:

```bash
make -C ../../../CL1_Core verilog-rvfi
cp ../../../CL1_Core/vsrc/Cl1Top.sv .

make -C ../../../CL1_Core verilog-rvfi-axi
cp ../../../CL1_Core/vsrc/Cl1Top_AXI.sv .

make -C ../../../CL1_Core verilog-rvfi-axi-cache
cp ../../../CL1_Core/vsrc/Cl1Top_AXI_CACHE.sv .
```

To enlarge the AXI formal cache geometry for a targeted run:

```bash
make -C ../../../CL1_Core verilog-rvfi-axi-cache CL1_AXI_FORMAL_CACHE_IDXW=2
cp ../../../CL1_Core/vsrc/Cl1Top_AXI_CACHE.sv .
```

Run the native main checks:

```bash
make checks
make all JOBS=8
make summary
```

Run the AXI main checks:

```bash
make axi-checks
make axi-all JOBS=8
make axi-summary
```

Run the AXI + cache main checks:

```bash
make axi-cache-checks
make axi-cache-all JOBS=8
make axi-cache-summary
```

Run progress-focused subsets:

```bash
make deadlock JOBS=2
make axi-deadlock JOBS=2
make axi-cache-deadlock JOBS=2
make fault JOBS=2
make axi-fault JOBS=2
make axi-cache-fault JOBS=2
```

Run the CL1-specific CSR microarchitecture check:

```bash
make csr-microarch
```

This is intentionally a core-local module/interface check, not a generic
RVFI/spec checker. The sources and SBY run output live under
`csr_microarch/`. `make csr-unit` checks the generated `Cl1CSR` module
directly. `make csr-exec` uses the normal `rvfi_testbench`/`rvfi_wrapper`
execution flow, then binds a CL1-specific CSR observer into
`Cl1Top_AXI_CACHE` to compare retired-execution CSR behavior against internal
CSR state and EXCP-facing CSR wiring.

## Environment Notes

- Deadlock/progress checks use bounded-latency dummy memory with stable arbitrary data instead of fixed NOP streams.
- WFI is excluded only for successful instruction fetch responses, because WFI is an architectural wait state.
- Native and AXI `fault_ch0` check RVFI fault semantics: trap, `rvfi_mem_fault`, fault masks, and `mcause`.
- Native main `hang` / `liveness` allows arbitrary native response errors and enables interrupt-progress.
- AXI main `hang` / `liveness` allows OKAY or SLVERR responses, enables interrupt-progress, and uses bounded AR/AW/W/R/B backpressure.
- AXI bus/fault/progress/int/cover checks use a single-outstanding dummy slave with bounded backpressure; ordinary ISA/CSR/base checks keep zero-delay OKAY responses to avoid unnecessary state-space cost.
- AXI cover requires read and write bus activity plus AR/AW/W/R/B delay coverage, so the stress environment is not vacuous.
- AXI no-cache keeps all four bus-fault checkers. AXI + cache keeps `fault_ch0` and the three data-side bus-fault checkers, but filters `bus_imem_fault_ch0` because I-cache refill/fill makes external instruction faults non-one-to-one with retire PCs without extra cache state visibility.
- AXI + cache checks observe the processor with ICache/DCache enabled through RVFI and external AXI transactions. Cache-internal invariants are kept in the separate `cache-formal full` target.
- Interrupt-progress allows arbitrary interrupts before the progress window, then quiesces irq lines so progress cannot be satisfied or defeated by a permanent interrupt stream.
- `misa` is a const-only CSR. `genchecks.py` skips strict `csrw_misa_ch0` generation and keeps `csrc_const_misa_ch0`.
- `CL1_FORMAL_ASSUME_ALIGNED_32I` models the software contract: compressed instructions may be halfword-aligned, but 32-bit instructions must start at a 32-bit-aligned PC. Reverting the FetchAlign workaround is separate from this formal-environment change.

## Limitations

- `fence` / `fence.i` do not yet have native formal semantics in this setup.
- The checks are bounded BMC/progress checks, not unbounded liveness proofs.
- `RISCV_FORMAL_ALTOPS` checks M-extension control and retirement behavior without proving the real multiply/divide datapath result.
