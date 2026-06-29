.PHONY: run unit exec clean

run: unit exec

unit:
	sby -f cl1_csr_unit.sby

exec:
	sby -f cl1_csr_exec.sby

clean:
	rm -rf cl1_csr_unit/ cl1_csr_exec/
