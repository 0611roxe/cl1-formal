CL1_MICROARCH_RTL_READY ?= 0
SBY_TASKS := bmc cover

.PHONY: prepare-rtl run clean

prepare-rtl:
	@if [ "$(CL1_MICROARCH_RTL_READY)" != "1" ]; then $(MAKE) -C .. rtl; fi

run: prepare-rtl
	sby -f cl1_alu.sby $(SBY_TASKS)
	sh ../check_formal_cells.sh cl1_alu_bmc/model/design.il cl1_alu_cover/model/design.il

clean:
	rm -rf cl1_alu/ cl1_alu_bmc/ cl1_alu_cover/
