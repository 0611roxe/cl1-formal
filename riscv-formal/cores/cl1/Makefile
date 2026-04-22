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

DEADLOCK_TARGETS := hang liveness_ch0

.PHONY: checks all csr int deadlock summary summary-csr summary-int summary-deadlock clean

checks checks/makefile:
	python3 ../../checks/genchecks.py

all: checks/makefile
	$(MAKE) -C checks -j$(JOBS)

csr: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(CSR_TARGETS)

INT_TARGETS := interrupt_ch0

int: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(INT_TARGETS)

deadlock: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(DEADLOCK_TARGETS)

summary:
	@$(SUMMARY)

summary-csr:
	@$(SUMMARY) 'priv|trap|csr'

summary-deadlock:
	@$(SUMMARY) '^(hang|liveness)'

summary-int:
	@$(SUMMARY) '^interrupt'

clean:
	rm -rf checks/
