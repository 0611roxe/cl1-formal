`ifndef CL1_MICROARCH_CSR_DEFS_VH
`define CL1_MICROARCH_CSR_DEFS_VH

`define CL1_UARCH_CSR_MACHINE_READABLE(addr) ( \
	((addr) == 12'h300) || ((addr) == 12'h301) || \
	((addr) == 12'h304) || ((addr) == 12'h305) || \
	((addr) == 12'h310) || ((addr) == 12'h340) || \
	((addr) == 12'h341) || ((addr) == 12'h342) || \
	((addr) == 12'h343) || ((addr) == 12'h344) || \
	((addr) == 12'hB00) || ((addr) == 12'hB02) || \
	((addr) == 12'hB80) || ((addr) == 12'hB82) || \
	((addr) == 12'hF11) || ((addr) == 12'hF12) || \
	((addr) == 12'hF13) || ((addr) == 12'hF14) || \
	((addr) == 12'hF15) \
)

`define CL1_UARCH_CSR_READ_ONLY(addr) ( \
	((addr) == 12'hF11) || ((addr) == 12'hF12) || \
	((addr) == 12'hF13) || ((addr) == 12'hF14) || \
	((addr) == 12'hF15) \
)

`define CL1_UARCH_CSR_RETIRE_RDATA_MODEL(addr) ( \
	((addr) == 12'h301) || ((addr) == 12'h310) || \
	((addr) == 12'hF11) || ((addr) == 12'hF12) || \
	((addr) == 12'hF13) || ((addr) == 12'hF14) || \
	((addr) == 12'hF15) \
)

`endif
