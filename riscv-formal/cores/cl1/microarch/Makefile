ROOT := ../../../..
CL1_CORE := $(ROOT)/CL1_Core
RTL_SOURCE := $(CL1_CORE)/vsrc/Cl1Top_AXI_CACHE.sv
RTL_DEST := ../Cl1Top_AXI_CACHE.sv

.PHONY: rtl run csr csr-all csr-unit csr-trap-scenarios csr-trap-model if-stage idex-stage mdu-altops mdu-real clean clean-csr

rtl:
	$(MAKE) -C $(CL1_CORE) verilog-rvfi-axi-cache CL1_AXI_FORMAL_CACHE_IDXW=1
	test -s $(RTL_SOURCE)
	cp $(RTL_SOURCE) $(RTL_DEST)
	cmp -s $(RTL_SOURCE) $(RTL_DEST)

run: rtl
	$(MAKE) -C if_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C idex_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C wb_stage CL1_MICROARCH_RTL_READY=1 run
	$(MAKE) -C excp_ctrl CL1_MICROARCH_RTL_READY=1 run
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

csr-all: rtl
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 run

csr-unit: rtl
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 unit

csr-trap-scenarios: rtl
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 trap-scenarios

csr-trap-model: rtl
	$(MAKE) -C csr CL1_MICROARCH_RTL_READY=1 trap-model

if-stage: rtl
	$(MAKE) -C if_stage CL1_MICROARCH_RTL_READY=1 run

idex-stage: rtl
	$(MAKE) -C idex_stage CL1_MICROARCH_RTL_READY=1 run

mdu-altops: rtl
	$(MAKE) -C mdu CL1_MICROARCH_RTL_READY=1 run

mdu-real:
	$(MAKE) -C mdu CL1_MICROARCH_RTL_READY=1 real

clean:
	$(MAKE) -C if_stage clean
	$(MAKE) -C idex_stage clean
	$(MAKE) -C wb_stage clean
	$(MAKE) -C excp_ctrl clean
	$(MAKE) -C lsu clean
	$(MAKE) -C fetch_align clean
	$(MAKE) -C regfile clean
	$(MAKE) -C decode clean
	$(MAKE) -C alu clean
	$(MAKE) -C mdu clean
	$(MAKE) -C csr clean

clean-csr:
	$(MAKE) -C csr clean
