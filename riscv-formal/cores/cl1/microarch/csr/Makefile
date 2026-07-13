CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover

.PHONY: prepare-rtl run unit trap-scenarios trap-model clean

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl unit trap-scenarios trap-model

unit: prepare-rtl
	@set +e; \
	sby -f cl1_csr_unit.sby $(SBY_TASKS); \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh cl1_csr_unit_bmc/model/design.il cl1_csr_unit_cover/model/design.il || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

trap-scenarios: prepare-rtl
	@set +e; \
	sby -f cl1_csr_trap_scenarios.sby bmc; \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh cl1_csr_trap_scenarios_bmc/model/design.il - || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

trap-model: prepare-rtl
	@set +e; \
	sby -f cl1_csr_trap_model.sby bmc; \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh cl1_csr_trap_model_bmc/model/design.il - || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

clean:
	rm -rf cl1_csr_unit/ cl1_csr_unit_bmc/ cl1_csr_unit_cover/ \
		cl1_csr_trap_scenarios/ cl1_csr_trap_scenarios_bmc/ cl1_csr_trap_scenarios_cover/ \
		cl1_csr_trap_model/ cl1_csr_trap_model_bmc/ cl1_csr_trap_model_cover/
