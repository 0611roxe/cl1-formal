JOBS ?= 8
CHECKS_CFG ?= checks
CHECKS_DIR ?= $(CHECKS_CFG)

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

SUMMARY := CHECK_DIR=$(CHECKS_DIR) ./summary.sh

empty :=
space := $(empty) $(empty)
SUMMARY_REGEX = '^($(subst $(space),|,$(strip $(1))))$$'

DEADLOCK_TARGETS := hang liveness_ch0

BUS_TARGETS := \
	causal_mem_ch0 \
	causal_io_ch0 \
	bus_imem_ch0 \
	bus_dmem_ch0 \
	bus_dmem_io_read_ch0 \
	bus_dmem_io_write_ch0 \
	bus_dmem_io_order_ch0

.PHONY: checks all i m c base cover sanity csr int deadlock bus summary summary-i summary-m summary-c summary-base summary-cover summary-sanity summary-csr summary-int summary-deadlock summary-bus clean clean-i clean-m clean-c clean-base clean-cover clean-sanity clean-csr clean-int clean-deadlock clean-bus axi-checks axi-all axi-i axi-m axi-c axi-base axi-cover axi-sanity axi-csr axi-int axi-deadlock axi-bus axi-summary

checks $(CHECKS_DIR)/makefile:
	python3 ../../checks/genchecks.py $(CHECKS_CFG)

all: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS)

i: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(I_TARGETS)

m: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(M_TARGETS)

c: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(C_TARGETS)

base: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(BASE_TARGETS)

cover: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(COVER_TARGETS)

sanity: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(SANITY_TARGETS)

csr: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(CSR_TARGETS)

INT_TARGETS := interrupt_ch0

int: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(INT_TARGETS)

deadlock: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(DEADLOCK_TARGETS)

bus: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(BUS_TARGETS)

summary:
	@$(SUMMARY)

summary-i:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(I_TARGETS))

summary-m:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(M_TARGETS))

summary-c:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(C_TARGETS))

summary-base:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(BASE_TARGETS))

summary-cover:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(COVER_TARGETS))

summary-sanity:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(SANITY_TARGETS))

summary-csr:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(CSR_TARGETS))

summary-deadlock:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(DEADLOCK_TARGETS))

summary-int:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(INT_TARGETS))

summary-bus:
	@$(SUMMARY) $(call SUMMARY_REGEX,$(BUS_TARGETS))

clean:
	rm -rf $(CHECKS_DIR)/

clean-i:        ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(I_TARGETS) || true
clean-m:        ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(M_TARGETS) || true
clean-c:        ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(C_TARGETS) || true
clean-base:     ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(BASE_TARGETS) || true
clean-cover:    ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(COVER_TARGETS) || true
clean-sanity:   ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(SANITY_TARGETS) || true
clean-csr:      ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(CSR_TARGETS) || true
clean-int:      ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(INT_TARGETS) || true
clean-deadlock: ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(DEADLOCK_TARGETS) || true
clean-bus:      ; cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(BUS_TARGETS) || true

axi-checks:
	$(MAKE) CHECKS_CFG=checks_axi clean checks

axi-all:
	$(MAKE) CHECKS_CFG=checks_axi clean all

axi-i:
	$(MAKE) CHECKS_CFG=checks_axi clean i

axi-m:
	$(MAKE) CHECKS_CFG=checks_axi clean m

axi-c:
	$(MAKE) CHECKS_CFG=checks_axi clean c

axi-base:
	$(MAKE) CHECKS_CFG=checks_axi clean base

axi-cover:
	$(MAKE) CHECKS_CFG=checks_axi clean cover

axi-sanity:
	$(MAKE) CHECKS_CFG=checks_axi clean sanity

axi-csr:
	$(MAKE) CHECKS_CFG=checks_axi clean csr

axi-int:
	$(MAKE) CHECKS_CFG=checks_axi clean int

axi-deadlock:
	$(MAKE) CHECKS_CFG=checks_axi clean deadlock

axi-bus:
	$(MAKE) CHECKS_CFG=checks_axi clean bus

axi-summary:
	@$(MAKE) CHECKS_CFG=checks_axi summary

clean-%:
	rm -rf $(CHECKS_DIR)/$*

Makefile: ;

%: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $@
