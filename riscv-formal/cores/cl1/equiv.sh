#!/bin/bash
set -ex
yosys -p '
	read_verilog -sv Cl1Top.sv
	prep -flatten -top Cl1Top
	design -stash gold

	read_verilog -sv -D RISCV_FORMAL Cl1Top.sv
	prep -flatten -top Cl1Top
	delete -port Cl1Top/rvfi_*
	design -stash gate

	design -copy-from gold -as gold Cl1Top
	design -copy-from gate -as gate Cl1Top
	memory_map; opt -fast
	equiv_make gold gate equiv
	hierarchy -top equiv

	opt -fast
	equiv_simple
	equiv_induct
	equiv_status -assert
'
