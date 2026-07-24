CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover
ROOT := ../../../../..
CL1_CORE := $(ROOT)/CL1_Core
REAL_RTL_DIR := rtl
REAL_RTL := $(REAL_RTL_DIR)/Cl1Top_AXI_CACHE_REALMDU.sv
FIRTOOL_VERSION := 1.105.0
FIRTOOL_PATCH_DIR := $(abspath $(CL1_CORE))/patch/firtool
MILL := $(or $(shell which mill),$(CL1_CORE)/mill)
JOBS ?= 6
REAL_SMOKE_MUL_TASKS := mul mulh mulhsu mulhu
REAL_SMOKE_DIV_TASKS := div rem divu remu
REAL_SMOKE_TASKS := $(REAL_SMOKE_MUL_TASKS) $(REAL_SMOKE_DIV_TASKS) special_cover
REAL_PROTOCOL_PROOF_TASKS := protocol_safety protocol_progress
REAL_PROTOCOL_COVER_TASKS := protocol_cover
REAL_PROTOCOL_TASKS := $(REAL_PROTOCOL_PROOF_TASKS) $(REAL_PROTOCOL_COVER_TASKS)
REAL_FULL_MUL_TASKS := mul_full mulh_full mulhsu_full mulhu_full
REAL_FULL_DIV_TASKS := divrem_signed_full divrem_unsigned_full
REAL_FULL_TASKS := $(REAL_FULL_MUL_TASKS) $(REAL_FULL_DIV_TASKS)
REAL_FULL_MUL_COVER_TASKS := $(addsuffix _cover,$(REAL_FULL_MUL_TASKS))
REAL_FULL_DIV_COVER_TASKS := $(addsuffix _cover,$(REAL_FULL_DIV_TASKS))
REAL_FULL_COVER_TASKS := $(REAL_FULL_MUL_COVER_TASKS) $(REAL_FULL_DIV_COVER_TASKS)
REAL_STRICT_MUL_TASKS := mul_ss_strict_pp mul_ss_strict_pn \
	mul_ss_strict_np mul_ss_strict_nn \
	mulhsu_strict_p mulhsu_strict_n mulhu_strict \
	booth_recode_signed booth_recode_unsigned \
	booth_scaled_step_signed booth_scaled_step_unsigned \
	booth_scaled_range_mulh booth_scaled_range_mulhsu booth_scaled_range_mulhu \
	booth_scaled_equiv_mulh booth_scaled_equiv_mulhsu booth_scaled_equiv_mulhu
REAL_STRICT_DIV_TASKS := div_invariant_signed_pp div_invariant_signed_pn \
	div_invariant_signed_np div_invariant_signed_nn \
	div_invariant_unsigned_pn div_invariant_unsigned_nn \
	div_invariant_unsigned_pp1 div_invariant_unsigned_np1 \
	div_invariant_unsigned_pp0 div_invariant_unsigned_np0 \
	div_range_signed div_range_unsigned div_step_signed div_step_unsigned \
	div_quotient_recode
REAL_STRICT_PROOF_TASKS := $(REAL_STRICT_MUL_TASKS) $(REAL_STRICT_DIV_TASKS)
REAL_STRICT_COMPLETION_TASKS := strict_mul_completion strict_div_completion
REAL_STRICT_TASKS := $(REAL_STRICT_PROOF_TASKS) $(REAL_STRICT_COMPLETION_TASKS)
REAL_LEVEL ?= smoke
REAL_LEVEL_smoke := $(REAL_SMOKE_TASKS) $(REAL_PROTOCOL_TASKS)
REAL_LEVEL_protocol := $(REAL_PROTOCOL_TASKS)
REAL_LEVEL_mul := $(REAL_SMOKE_MUL_TASKS)
REAL_LEVEL_div := $(REAL_SMOKE_DIV_TASKS) special_cover
REAL_LEVEL_full := $(REAL_PROTOCOL_TASKS) $(REAL_FULL_TASKS) $(REAL_FULL_COVER_TASKS) special_cover
REAL_LEVEL_mul-full := $(REAL_FULL_MUL_TASKS) $(REAL_FULL_MUL_COVER_TASKS)
REAL_LEVEL_div-full := $(REAL_FULL_DIV_TASKS) $(REAL_FULL_DIV_COVER_TASKS) special_cover
REAL_LEVEL_strict := $(REAL_LEVEL_full) $(REAL_STRICT_TASKS)
REAL_SELECTED_TASKS := $(REAL_LEVEL_$(REAL_LEVEL))
REAL_PROOF_TASKS := $(REAL_SMOKE_MUL_TASKS) $(REAL_SMOKE_DIV_TASKS) \
	$(REAL_PROTOCOL_PROOF_TASKS) $(REAL_FULL_TASKS) $(REAL_STRICT_PROOF_TASKS)
REAL_COVER_ONLY_TASKS := special_cover $(REAL_PROTOCOL_COVER_TASKS) \
	$(REAL_FULL_COVER_TASKS) $(REAL_STRICT_COMPLETION_TASKS)
REAL_SELECTED_PROOF_TASKS := $(filter $(REAL_PROOF_TASKS),$(REAL_SELECTED_TASKS))
REAL_SELECTED_COVER_TASKS := $(filter $(REAL_COVER_ONLY_TASKS),$(REAL_SELECTED_TASKS))
REAL_SELECTED_STRICT_PROOF_TASKS := $(filter $(REAL_STRICT_PROOF_TASKS),$(REAL_SELECTED_TASKS))
REAL_SELECTED_STRICT_COVER_TASKS := $(filter $(REAL_STRICT_COMPLETION_TASKS),$(REAL_SELECTED_TASKS))
REAL_SELECTED_REGULAR_PROOF_TASKS := $(filter-out $(REAL_STRICT_PROOF_TASKS),$(REAL_SELECTED_PROOF_TASKS))
REAL_SELECTED_REGULAR_COVER_TASKS := $(filter-out $(REAL_STRICT_COMPLETION_TASKS),$(REAL_SELECTED_COVER_TASKS))

ifneq ($(filter real,$(MAKECMDGOALS)),)
ifeq ($(strip $(REAL_SELECTED_TASKS)),)
$(error unsupported REAL_LEVEL='$(REAL_LEVEL)')
endif
endif

.PHONY: prepare-rtl run real rtl-real clean FORCE

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl
	sby -f cl1_mdu_altops.sby $(SBY_TASKS)
	sh ../check_formal_cells.sh cl1_mdu_altops_bmc/model/design.il cl1_mdu_altops_cover/model/design.il

real: $(REAL_RTL)
	sby -j $(JOBS) -f cl1_mdu_real.sby $(REAL_SELECTED_TASKS)
	@set -e; for task in $(REAL_SELECTED_REGULAR_PROOF_TASKS); do \
		sh ../check_formal_cells.sh cl1_mdu_real_$$task/model/design.il -; \
	done
	@set -e; for task in $(REAL_SELECTED_REGULAR_COVER_TASKS); do \
		sh ../check_formal_cells.sh - cl1_mdu_real_$$task/model/design.il; \
	done
	@set -e; for task in $(REAL_SELECTED_STRICT_PROOF_TASKS); do \
		sh ../check_formal_cells.sh cl1_mdu_real_$$task/model/design.il - no-arith; \
	done
	@set -e; for task in $(REAL_SELECTED_STRICT_COVER_TASKS); do \
		sh ../check_formal_cells.sh - cl1_mdu_real_$$task/model/design.il no-arith; \
	done

rtl-real: $(REAL_RTL)

$(REAL_RTL): FORCE
	mkdir -p $(REAL_RTL_DIR)
	cd $(CL1_CORE) && ./patch/update-firtool.sh $(FIRTOOL_VERSION) $(FIRTOOL_PATCH_DIR) >/dev/null
	cd $(CL1_CORE) && \
		CHISEL_FIRTOOL_PATH=$(FIRTOOL_PATCH_DIR)/firtool-$(FIRTOOL_VERSION)/bin \
		CL1_TEST_MODE=cache \
		CL1_TOP_NAME=Cl1Top_AXI_CACHE_REALMDU \
		CL1_FORMAL_VERIF=true \
		CL1_RISCV_FORMAL_ALTOPS=false \
		CL1_HAS_ICACHE=true \
		CL1_HAS_DCACHE=true \
		CL1_SYN=false \
		CL1_CACHE_IDXW=1 \
		$(MILL) -i cl1.runMain Elaborate \
			--target-dir $(abspath $(REAL_RTL_DIR)) \
			--throw-on-first-error
	sed -i '/difftest\.sv/d' $(REAL_RTL)
	sed -i '/Stat\.v/d' $(REAL_RTL)

FORCE:

clean:
	rm -rf cl1_mdu_altops/ cl1_mdu_altops_bmc/ cl1_mdu_altops_cover/ \
		cl1_mdu_real/ cl1_mdu_real_*/ $(REAL_RTL_DIR)/
