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
	reg resetn = 0;
	wire trap;

	always @(posedge clk)
		resetn <= 1;

	`RVFI_WIRES

	// TODO: Instantiate cl1 core here
	// cl1 uut (
	// 	.clk            (clk           ),
	// 	.resetn         (resetn        ),
	// 	...
	// 	`RVFI_CONN
	// );

	integer count_dmemrd = 0;
	integer count_dmemwr = 0;
	integer count_longinsn = 0;

	always @(posedge clk) begin
		if (resetn && rvfi_valid) begin
			if (rvfi_mem_rmask)
				count_dmemrd <= count_dmemrd + 1;
			if (rvfi_mem_wmask)
				count_dmemwr <= count_dmemwr + 1;
			if (rvfi_insn[1:0] == 3)
				count_longinsn <= count_longinsn + 1;
		end
	end

	cover property (count_dmemrd);
	cover property (count_dmemwr);
	cover property (count_longinsn);

	cover property (count_dmemrd >= 1 && count_dmemwr >= 1 && count_longinsn >= 1);
	cover property (count_dmemrd >= 2 && count_dmemwr >= 2 && count_longinsn >= 2);
	cover property (count_dmemrd >= 3 && count_dmemwr >= 2 && count_longinsn >= 2);
	cover property (count_dmemrd >= 2 && count_dmemwr >= 3 && count_longinsn >= 2);
	cover property (count_dmemrd >= 2 && count_dmemwr >= 2 && count_longinsn >= 3);
endmodule
