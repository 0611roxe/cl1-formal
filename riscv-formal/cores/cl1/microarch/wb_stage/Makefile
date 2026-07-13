CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover

.PHONY: prepare-rtl run clean

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl
	@set +e; \
	sby -f cl1_wb_stage.sby $(SBY_TASKS); \
	sby_rc=$$?; \
	check_rc=0; \
	sh ../check_formal_cells.sh cl1_wb_stage_bmc/model/design.il cl1_wb_stage_cover/model/design.il || check_rc=$$?; \
	if [ "$$sby_rc" -ne 0 ]; then exit $$sby_rc; fi; \
	exit $$check_rc

clean:
	rm -rf cl1_wb_stage/ cl1_wb_stage_bmc/ cl1_wb_stage_cover/
