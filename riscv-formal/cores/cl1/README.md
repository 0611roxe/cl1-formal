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
make deadlock-all JOBS=2
make deadlock JOBS=2
make axi-deadlock JOBS=2
make axi-cache-deadlock JOBS=2
make fault JOBS=2
make axi-fault JOBS=2
make axi-cache-fault JOBS=2
```

`deadlock-all` runs the native, AXI no-cache, and AXI-cache `hang` plus
`liveness_ch0` targets in sequence. The AXI no-cache target retains bounded
AR/AW/W/R/B backpressure; the cache target uses the zero-delay AXI memory
profile to keep the processor-plus-cache progress proof tractable.

AXI-cache liveness triggers at cycle 96 and keeps the next-retirement window
through cycle 192. It uses the same generated SBY flow and default Boolector
engine as the other checks; `genchecks.py` and its option list are unchanged.
Cache-internal arbitrary-state progress remains the responsibility of the
separate cache-formal target.

Run the CL1-specific CSR microarchitecture check:

```bash
make microarch-csr
```

This is intentionally a core-local module/interface check, not a generic
RVFI/spec checker. The sources and SBY run output live under
`microarch/csr/`. The grouped target checks the generated `Cl1CSR` module
directly and runs the coupled CSR/EXCP trap scenarios and reference model.
These microarchitecture checks are kept separate from the architectural
RVFI/spec flow.

The default `make microarch` target runs BMC for every included module and a
paired cover task for each checker that declares cover points. A checker passes
only when its assertions hold to the configured depth and every declared cover
point is reachable within that depth.

MDU checks use one grouped entry point:

```bash
make microarch-mdu                         # formal altops
make microarch-mdu MDU_MODE=smoke          # reduced real arithmetic + protocol
make microarch-mdu MDU_MODE=full           # full-width DUT/reference proof
make microarch-mdu MDU_MODE=strict         # full proof + arithmetic closure
```

`MDU_MODE=full` is a separate heavy mode for arbitrary 32-bit non-altops
multiplication and division. It is not included in `microarch` or in the
architectural RVFI/spec check groups.

`MDU_MODE=strict` adds independent full-width arithmetic closure to `full`.
It is also kept separate from `microarch` and all
architectural RVFI/spec groups. It includes signed and unsigned actual-state
division invariants, registered reference-result mappings, and reference-only
arithmetic cones. It proves strict multiplier/divider completion reachability
and rejects checker-side multiply/divide/modulo cells. This target has no
built-in timeout; runtime depends on the solver, host, and selected `JOBS`.

The `smoke`, `full`, and `strict` modes include the corresponding protocol
safety, bounded-progress, and cover tasks. The SBY file currently defines 58
small tasks so each opcode, arithmetic partition, and cover goal remains
independently selectable.

See [`microarch/README.md`](microarch/README.md) for entry points and
[`microarch/COVERAGE.md`](microarch/COVERAGE.md) for proof boundaries and
assumptions.

The microarchitecture Make entry points regenerate `Cl1Top_AXI_CACHE.sv` from
the current `CL1_Core` sources before running, so an existing copied DUT cannot
silently make a source change appear to pass against stale RTL.

## Environment Notes

- Deadlock/progress checks use bounded-latency dummy memory with stable arbitrary data instead of fixed NOP streams.
- WFI is excluded only for successful instruction fetch responses, because WFI is an architectural wait state.
- Native and AXI `fault_ch0` check RVFI fault semantics: trap, `rvfi_mem_fault`, fault masks, and `mcause`.
- Native main `hang` / `liveness` allows arbitrary native response errors and enables interrupt-progress.
- AXI no-cache `hang` / `liveness` allows OKAY or SLVERR responses, enables interrupt-progress, and uses bounded AR/AW/W/R/B backpressure.
- AXI no-cache bus/fault/progress/int/cover checks use a single-outstanding dummy slave with bounded backpressure; ordinary ISA/CSR/base checks keep zero-delay OKAY responses to avoid unnecessary state-space cost.
- AXI + cache `hang` / `liveness` keeps the same fault and interrupt-progress semantics but uses the fast zero-delay AXI memory profile.
- AXI no-cache cover requires read and write bus activity plus AR/AW/W/R/B delay coverage, so the stress environment is not vacuous.
- AXI + cache cover retains bounded AR/AW/W/R/B backpressure and independently reaches data-read, data-write, and combined read/write retirement traces.
- AXI no-cache keeps all four bus-fault checkers. AXI + cache keeps `fault_ch0` and the three data-side bus-fault checkers, but filters `bus_imem_fault_ch0` because I-cache refill/fill makes external instruction faults non-one-to-one with retire PCs without extra cache state visibility.
- AXI + cache checks observe the processor with ICache/DCache enabled through RVFI and external AXI transactions. Cache-internal invariants are kept in the separate `cache-formal full` target.
- Interrupt-progress allows arbitrary interrupts before the progress window, then quiesces irq lines so progress cannot be satisfied or defeated by a permanent interrupt stream.
- `misa` is a const-only CSR. `genchecks.py` skips strict `csrw_misa_ch0` generation and keeps `csrc_const_misa_ch0`.
- `CL1_FORMAL_ASSUME_ALIGNED_32I` models the software contract: compressed instructions may be halfword-aligned, but 32-bit instructions must start at a 32-bit-aligned PC. Reverting the FetchAlign workaround is separate from this formal-environment change.

## Limitations

- `fence` / `fence.i` do not yet have native formal semantics in this setup.
- The checks are bounded BMC/progress checks, not unbounded liveness proofs.
- The ISA/RVFI configurations use `RISCV_FORMAL_ALTOPS`; use the optional non-altops `microarch-mdu` modes for real multiply/divide datapath proofs.
