{
  description = "Unified dev environment for CL1_Core + riscv-formal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";
    nur.url = "github:nix-community/NUR";
  };

  outputs = { self, nixpkgs, nur }:
    let
      system = "x86_64-linux";

      pkgs = import nixpkgs {
        inherit system;
        overlays = [ nur.overlays.default ];
        config = { allowUnfree = true; };
      };

      # Cross-compilation toolchain for RISC-V 32-bit
      pkgsRiscv = import nixpkgs {
        inherit system;
        crossSystem = {
          config = "riscv32-none-elf";
          gcc.abi = "ilp32";
        };
      };

      # === Python environment (merged from both projects) ===
      verilog-vcd = pkgs.python3Packages.buildPythonPackage rec {
        pname = "Verilog_VCD";
        version = "1.11";
        pyproject = true;
        build-system = [ pkgs.python3Packages.setuptools ];
        src = pkgs.python3Packages.fetchPypi {
          inherit pname version;
          hash = "sha256-L/peNxHFfRMS3EEaGRih+PFx/xDwQ8d0n7Epq3ZCaDo=";
        };
        doCheck = false;
      };

      python = pkgs.python310.withPackages (ps: [
        ps.pexpect
        ps.pyaml
        ps.kconfiglib
        verilog-vcd
      ]);

      # === Wrapper scripts for riscv-formal (expects riscv32-unknown-elf-*) ===
      riscvGcc = pkgs.writeShellScriptBin "riscv32-unknown-elf-gcc" ''
        exec ${pkgsRiscv.buildPackages.gcc}/bin/riscv32-none-elf-gcc "$@"
      '';
      riscvObjdump = pkgs.writeShellScriptBin "riscv32-unknown-elf-objdump" ''
        exec ${pkgsRiscv.buildPackages.binutils}/bin/riscv32-none-elf-objdump "$@"
      '';

      openocd-riscv = pkgs.nur.repos.bendlas.openocd-riscv;

    in {
      devShells."${system}" = {
        default = pkgs.mkShell {
          packages = [
            # --- CL1_Core: Chisel / Verilator / simulation ---
            pkgs.mill
            pkgs.verilator
            pkgs.gtkwave
            pkgs.zlib
            pkgs.spike
            pkgs.dtc
            pkgs.espresso
            pkgs.ccache
            pkgs.scons
            openocd-riscv

            # --- riscv-formal: formal verification ---
            pkgs.yosys
            pkgs.sby
            pkgs.boolector
            pkgs.z3

            # --- Shared: Python ---
            python
            pkgs.python3Packages.kconfiglib

            # --- Shared: RISC-V cross toolchain ---
            pkgsRiscv.buildPackages.gcc
            pkgsRiscv.buildPackages.gdb
            riscvGcc
            riscvObjdump
          ];

          shellHook = ''
            export OBJCACHE=ccache
            echo "============================================"
            echo "  cl1-formal unified dev environment"
            echo ""
            echo "  CL1_Core:"
            echo "    cd CL1_Core && make verilog"
            echo ""
            echo "  riscv-formal (in cores/cl1/):"
            echo "    cp ./CL1_Core/vsrc/Cl1Top.sv ./riscv-formal/cores/cl1/CL1Top.sv"
            echo "    cd riscv-formal/cores/cl1"
            echo "    python3 ../../checks/genchecks.py"
            echo "    make -C checks -j$(nproc)"
            echo "============================================"
          '';
        };
      };

      # Legacy attribute for older Nix versions (< 2.7)
      devShell."${system}" = self.devShells."${system}".default;
    };
}
