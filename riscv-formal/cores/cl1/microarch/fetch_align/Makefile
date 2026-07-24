CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover

.PHONY: prepare-rtl run clean

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl
	sby -f cl1_fetch_align.sby $(SBY_TASKS)
	sh ../check_formal_cells.sh cl1_fetch_align_bmc/model/design.il cl1_fetch_align_cover/model/design.il

clean:
	rm -rf cl1_fetch_align/ cl1_fetch_align_bmc/ cl1_fetch_align_cover/
