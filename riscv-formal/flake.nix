{
  description = "Development environment for riscv-formal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };

              # 2. Cross-compilation package set for the TARGET (RISC-V)
       pkgsRiscv = import nixpkgs {
         inherit system;
         crossSystem = {
           config = "riscv32-none-elf";
           gcc.abi = "ilp32";
         };
       };

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
        python = pkgs.python3.withPackages (ps: [
          verilog-vcd
        ]);

        riscvGcc = pkgs.writeShellScriptBin "riscv32-unknown-elf-gcc" ''
          exec ${pkgsRiscv.buildPackages.gcc}/bin/riscv32-none-elf-gcc "$@"
        '';
        riscvObjdump = pkgs.writeShellScriptBin "riscv32-unknown-elf-objdump" ''
          exec ${pkgsRiscv.buildPackages.binutils}/bin/riscv32-none-elf-objdump "$@"
        '';
      in {
        devShells.default = pkgs.mkShell {
          packages = with pkgs; [
            python
            yosys
            sby
            boolector
            z3
            gtkwave
            pkgsRiscv.buildPackages.gcc
            riscvGcc
            riscvObjdump
          ];
        };
      });
}
