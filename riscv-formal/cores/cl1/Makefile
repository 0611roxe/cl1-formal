JOBS ?= 8
CHECKS_CFG ?= checks
CHECKS_DIR ?= $(CHECKS_CFG)

INSN_TARGETS_FROM_ISA = $(addsuffix _ch0,$(addprefix insn_,$(strip $(shell cat $(1)))))

I_TARGETS  := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32i.txt)
IM_TARGETS := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32im.txt)
IC_TARGETS := $(call INSN_TARGETS_FROM_ISA,../../insns/isa_rv32ic.txt)
M_TARGETS  := $(filter-out $(I_TARGETS),$(IM_TARGETS))
C_TARGETS  := $(filter-out $(I_TARGETS),$(IC_TARGETS))

BASE_TARGETS := reg_ch0 pc_fwd_ch0 pc_bwd_ch0 unique_ch0 causal_ch0
COVER_TARGETS := cover
SANITY_TARGETS := $(BASE_TARGETS) $(COVER_TARGETS)
INT_TARGETS := interrupt_ch0
DEADLOCK_TARGETS := hang liveness_ch0
BUS_TARGETS := \
	causal_mem_ch0 \
	causal_io_ch0 \
	bus_imem_ch0 \
	bus_dmem_ch0 \
	bus_dmem_io_read_ch0 \
	bus_dmem_io_write_ch0 \
	bus_dmem_io_order_ch0
NATIVE_FAULT_TARGETS := \
	fault_ch0
AXI_FAULT_TARGETS := \
	fault_ch0 \
	bus_imem_fault_ch0 \
	bus_dmem_fault_ch0 \
	bus_dmem_io_read_fault_ch0 \
	bus_dmem_io_write_fault_ch0
AXI_CACHE_FAULT_TARGETS := \
	fault_ch0 \
	bus_dmem_fault_ch0 \
	bus_dmem_io_read_fault_ch0 \
	bus_dmem_io_write_fault_ch0
FAULT_TARGETS := $(if $(filter checks_axi,$(CHECKS_CFG)),$(AXI_FAULT_TARGETS),$(if $(filter checks_axi_cache,$(CHECKS_CFG)),$(AXI_CACHE_FAULT_TARGETS),$(NATIVE_FAULT_TARGETS)))
CSR_TARGETS := \
	csrw_mtvec_ch0 \
	csrw_mepc_ch0 \
	csrw_mcause_ch0 \
	csrw_mtval_ch0 \
	csrw_mscratch_ch0 \
	csrw_mstatus_ch0 \
	csrw_mie_ch0 \
	csrc_any_mepc_ch0 \
	csrc_any_mstatus_ch0 \
	csrc_any_mie_ch0 \
	csrc_const_misa_ch0

GROUPS := i m c base cover sanity csr int deadlock bus fault
TARGETS_i := $(I_TARGETS)
TARGETS_m := $(M_TARGETS)
TARGETS_c := $(C_TARGETS)
TARGETS_base := $(BASE_TARGETS)
TARGETS_cover := $(COVER_TARGETS)
TARGETS_sanity := $(SANITY_TARGETS)
TARGETS_csr := $(CSR_TARGETS)
TARGETS_int := $(INT_TARGETS)
TARGETS_deadlock := $(DEADLOCK_TARGETS)
TARGETS_bus := $(BUS_TARGETS)
TARGETS_fault := $(FAULT_TARGETS)

SUMMARY := CHECK_DIR=$(CHECKS_DIR) ./summary.sh

empty :=
space := $(empty) $(empty)
SUMMARY_REGEX = '^($(subst $(space),|,$(strip $(1))))$$'

.PHONY: checks all summary clean csr-microarch csr-unit csr-exec clean-csr-microarch $(GROUPS) axi-checks axi-all axi-summary axi-cache-checks axi-cache-all axi-cache-summary FORCE

FORCE:

checks $(CHECKS_DIR)/makefile:
	python3 ../../checks/genchecks.py $(CHECKS_CFG)

all: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS)

$(GROUPS): $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $(TARGETS_$@)

summary:
	@$(SUMMARY)

summary-%: FORCE
	@$(SUMMARY) $(call SUMMARY_REGEX,$(TARGETS_$*))

clean:
	rm -rf $(CHECKS_DIR)/

csr-microarch:
	$(MAKE) -C csr_microarch run

csr-unit:
	$(MAKE) -C csr_microarch unit

csr-exec:
	$(MAKE) -C csr_microarch exec

clean-csr-microarch:
	$(MAKE) -C csr_microarch clean

axi-checks:
	$(MAKE) CHECKS_CFG=checks_axi clean checks

axi-all:
	$(MAKE) CHECKS_CFG=checks_axi clean all

axi-summary:
	@$(MAKE) CHECKS_CFG=checks_axi summary

axi-%: FORCE
	$(MAKE) CHECKS_CFG=checks_axi clean $*

axi-cache-checks:
	$(MAKE) CHECKS_CFG=checks_axi_cache clean checks

axi-cache-all:
	$(MAKE) CHECKS_CFG=checks_axi_cache clean all

axi-cache-summary:
	@$(MAKE) CHECKS_CFG=checks_axi_cache summary

axi-cache-%: FORCE
	$(MAKE) CHECKS_CFG=checks_axi_cache clean $*

clean-%: FORCE
	@if [ -n "$(TARGETS_$*)" ]; then \
		cd $(CHECKS_DIR) 2>/dev/null && rm -rf $(TARGETS_$*) || true; \
	else \
		rm -rf $(CHECKS_DIR)/$*; \
	fi

Makefile: ;

%: $(CHECKS_DIR)/makefile
	$(MAKE) -C $(CHECKS_DIR) -j$(JOBS) $@
