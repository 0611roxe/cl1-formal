CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover
ROOT := ../../../../..
CL1_CORE := $(ROOT)/CL1_Core
REAL_RTL_DIR := rtl
REAL_RTL := $(REAL_RTL_DIR)/Cl1Top_AXI_CACHE_REALMDU.sv
FIRTOOL_VERSION := 1.105.0
FIRTOOL_PATCH_DIR := $(abspath $(CL1_CORE))/patch/firtool
MILL := $(or $(shell which mill),$(CL1_CORE)/mill)

.PHONY: prepare-rtl run real real-mul real-mul-full real-div-small real-special-cover rtl-real clean FORCE

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl
	@set +e; \
	sby -f cl1_mdu_altops.sby $(SBY_TASKS); \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh cl1_mdu_altops_bmc/model/design.il cl1_mdu_altops_cover/model/design.il || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

real: real-mul real-div-small real-special-cover

real-mul: $(REAL_RTL)
	@set -e; \
	for task in mul mulh mulhsu mulhu; do \
		sby -f cl1_mdu_real.sby $$task; \
		sh ../check_formal_cells.sh cl1_mdu_real_$$task/model/design.il -; \
	done

real-mul-full: $(REAL_RTL)
	@set -e; \
	for task in mul_full mulh_full mulhsu_full mulhu_full; do \
		sby -f cl1_mdu_real.sby $$task; \
		sh ../check_formal_cells.sh cl1_mdu_real_$$task/model/design.il -; \
	done

real-div-small: $(REAL_RTL)
	@set -e; \
	for task in div rem divu remu; do \
		sby -f cl1_mdu_real.sby $$task; \
		sh ../check_formal_cells.sh cl1_mdu_real_$$task/model/design.il -; \
	done

real-special-cover: $(REAL_RTL)
	@set +e; \
	sby -f cl1_mdu_real.sby special_cover; \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh - cl1_mdu_real_special_cover/model/design.il || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

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
