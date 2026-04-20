# cl1

RISC-V formal verification for cl1 core.

## Configuration

### CL1_USE_NATIVE_BUS Macro

The `CL1_USE_NATIVE_BUS` macro controls which bus interface is used for the CL1 core:

- **With `CL1_USE_NATIVE_BUS` defined**: Instantiates the native bus version of the CL1 core (`Cl1Top.sv`)
- **Without `CL1_USE_NATIVE_BUS` defined**: Instantiates the AXI bus version of the CL1 core (`Cl1Top_AXI.sv`)

## Usage

1) Generate `Cl1Top.sv` first and place it in this directory (`cores/cl1/`)

   Example:

       cp /path/to/cl1_core/vsrc/Cl1Top.sv ./Cl1Top.sv

   Notes:

   - `Cl1Top.sv` is required by formal checks.
   - If you want AXI mode, prepare `Cl1Top_AXI.sv` in the same directory.

2) Select bus mode in `checks.cfg`

    - Native bus mode: keep `define CL1_USE_NATIVE_BUS enabled.
    - AXI mode: comment out `define CL1_USE_NATIVE_BUS.

3) Generate checks

    python3 ../../checks/genchecks.py

4) Run checks

    make -C checks -j$(nproc)

