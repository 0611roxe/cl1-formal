.PHONY: run unit exec trap-scenarios trap-model clean

run: unit exec trap-scenarios trap-model

unit:
	sby -f cl1_csr_unit.sby

exec:
	sby -f cl1_csr_exec.sby

trap-scenarios:
	sby -f cl1_csr_trap_scenarios.sby

trap-model:
	sby -f cl1_csr_trap_model.sby

clean:
	rm -rf cl1_csr_unit/ cl1_csr_exec/ cl1_csr_trap_scenarios/ cl1_csr_trap_model/
