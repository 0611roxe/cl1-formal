ROOT := ../../../..
CL1_CORE := $(ROOT)/CL1_Core
RTL_SOURCE := $(CL1_CORE)/vsrc/Cl1Top_AXI_CACHE.sv
RTL_DEST := ../Cl1Top_AXI_CACHE.sv
MDU_MODE ?= altops
MDU_TARGET_altops := run
MDU_TARGET_smoke := real
MDU_TARGET_protocol := real
MDU_TARGET_mul := real
MDU_TARGET_div := real
MDU_TARGET_full := real
MDU_TARGET_mul-full := real
MDU_TARGET_div-full := real
MDU_TARGET_strict := real
MDU_PREP_altops := rtl

.PHONY: rtl run csr mdu clean

rtl:
	$(MAKE) -C $(CL1_CORE) verilog-rvfi-axi-cache CL1_AXI_FORMAL_CACHE_IDXW=1
	test -s $(RTL_SOURCE)
	cp $(RTL_SOURCE) $(RTL_DEST)
	cmp -s $(RTL_SOURCE) $(RTL_DEST)

run: rtl
	$(MAKE) -C if_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C idex_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C wb_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C pipeline CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C lsu CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C fetch_align CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C regfile CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C decode CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C alu CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 unit
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 trap-scenarios
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 trap-model

csr: rtl
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 run

mdu: $(MDU_PREP_$(MDU_MODE))
	@if [ -z "$(MDU_TARGET_$(MDU_MODE))" ]; then \
		echo "ERROR: unsupported MDU_MODE='$(MDU_MODE)'" >&2; \
		exit 2; \
	fi
	$(MAKE) -C mdu CL1_MICROARCH_RTL_READY=1 \
		$(MDU_TARGET_$(MDU_MODE)) REAL_LEVEL=$(MDU_MODE)

clean:
	$(MAKE) -C if_stage clean
	$(MAKE) -C idex_stage clean
	$(MAKE) -C wb_stage clean
	$(MAKE) -C pipeline clean
	$(MAKE) -C lsu clean
	$(MAKE) -C fetch_align clean
	$(MAKE) -C regfile clean
	$(MAKE) -C decode clean
	$(MAKE) -C alu clean
	$(MAKE) -C mdu clean
	$(MAKE) -C csr clean
