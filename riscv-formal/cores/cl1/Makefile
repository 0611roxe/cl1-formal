JOBS ?= 8

INSN_TARGETS_FROM_ISA = $(addsuffix _ch0,$(addprefix insn_,$(strip $(shell cat $(1)))))

I_TARGETS := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32i.txt)
IM_TARGETS := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32im.txt)
IC_TARGETS := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32ic.txt)
M_TARGETS := $(filter-out $(I_TARGETS),$(IM_TARGETS))
C_TARGETS := $(filter-out $(I_TARGETS),$(IC_TARGETS))

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

BASE_TARGETS := \
	reg_ch0 \
	pc_fwd_ch0 \
	pc_bwd_ch0 \
	unique_ch0 \
	causal_ch0

COVER_TARGETS := cover

SANITY_TARGETS := $(BASE_TARGETS) $(COVER_TARGETS)

SUMMARY := ./summary.sh

DEADLOCK_TARGETS := hang liveness_ch0

.PHONY: checks all i m c base cover sanity csr int deadlock summary summary-csr summary-int summary-deadlock clean

checks checks/makefile:
	python3 ../../checks/genchecks.py

all: checks/makefile
	$(MAKE) -C checks -j$(JOBS)

i: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(I_TARGETS)

m: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(M_TARGETS)

c: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(C_TARGETS)

base: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(BASE_TARGETS)

cover: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(COVER_TARGETS)

sanity: checks/makefile
	$(MAKE) -C checks -j$(JOBS) $(SANITY_TARGETS)

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
