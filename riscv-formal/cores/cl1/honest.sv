module testbench (
	input clk,

	input         mem_ready,
	output        mem_valid,
	output        mem_instr,
	output [31:0] mem_addr,
	output [31:0] mem_wdata,
	output [3:0]  mem_wstrb,
	input  [31:0] mem_rdata,

);
	(* anyconst *) reg [31:0] monitor_insn;
	reg monitor_state = 0;
	reg [7:0] cycle = 0;

	reg resetn = 0;
	wire trap;

	always @(posedge clk) begin
		resetn <= 1;
		cycle <= cycle + 1;
		assume((!mem_valid || mem_ready) || $past(!mem_valid || mem_ready));
	end

	`RVFI_WIRES

	// TODO: Instantiate cl1 core here
	// cl1 uut (
	// 	.clk            (clk           ),
	// 	.resetn         (resetn        ),
	// 	...
	// 	`RVFI_CONN
	// );

	always @* begin
		assume (mem_rdata == monitor_insn);
		if (!monitor_state) assert (cycle < 21);
	end

	always @(posedge clk) begin
		if (rvfi_valid && monitor_insn[1:0] == 3 && rvfi_insn == monitor_insn)
			monitor_state <= 1;
		if (rvfi_valid && monitor_insn[1:0] != 3 && rvfi_insn[15:0] == monitor_insn[15:0])
			monitor_state <= 1;
	end
endmodule
