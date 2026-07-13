module cl1_idex_stage_post_check(input clock);
	wire uarch_mdu_io_in_valid;
	wire uarch_dx_exec_done;

	cl1_idex_stage_check core (
		.clock(clock),
		.uarch_mdu_io_in_valid(uarch_mdu_io_in_valid),
		.uarch_dx_exec_done(uarch_dx_exec_done)
	);

	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	always @(posedge clock) begin
		if (past_valid && uarch_mdu_io_in_valid)
			assert(!uarch_dx_exec_done);
	end
endmodule
