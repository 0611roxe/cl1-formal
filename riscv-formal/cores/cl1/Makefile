JOBS ?= $(shell nproc)

CSR_TARGETS := \
	trap_handler_ch0 \
	priv_insn_ch0 \
	csrw_mtvec_ch0 \
	csrw_mepc_ch0 \
	csrw_mcause_ch0 \
	csrw_mscratch_ch0 \
	csrw_mstatus_ch0 \
	csrw_mie_ch0 \
	csrw_misa_ch0 \
	csrc_any_mepc_ch0 \
	csrc_any_mstatus_ch0 \
	csrc_any_mie_ch0 \
	csrc_const_misa_ch0

SUMMARY := ./summary.sh

.PHONY: checks all csr summary summary-csr clean

checks checks/makefile:
	python3 ../../checks/genchecks.py

all: checks/makefile
	$(MAKE) -C checks -j$(JOBS)

csr: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(CSR_TARGETS)

summary:
	@$(SUMMARY)

summary-csr:
	@$(SUMMARY) 'priv|trap|csr'

clean:
	rm -rf checks/
