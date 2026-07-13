module cl1_if_stage_post_check(input clock);
	wire uarch_io_fromdxu_flush_req;
	wire uarch_io_flush;
	wire uarch_io_toaligner_valid;
	wire uarch_io_toaligner_ready;
	wire uarch_ifu_req_pending;
	wire uarch_ifu_out_r_r;
	wire uarch_ifu_out_clr;
	wire uarch_flush_pending_r;
	wire uarch_flush_pending_set;

	cl1_if_stage_check core (
		.clock(clock),
		.uarch_io_fromdxu_flush_req(uarch_io_fromdxu_flush_req),
		.uarch_io_flush(uarch_io_flush),
		.uarch_io_toaligner_valid(uarch_io_toaligner_valid),
		.uarch_io_toaligner_ready(uarch_io_toaligner_ready),
		.uarch_ifu_req_pending(uarch_ifu_req_pending),
		.uarch_ifu_out_r_r(uarch_ifu_out_r_r),
		.uarch_ifu_out_clr(uarch_ifu_out_clr),
		.uarch_flush_pending_r(uarch_flush_pending_r),
		.uarch_flush_pending_set(uarch_flush_pending_set)
	);

	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire flush_pulse = uarch_io_fromdxu_flush_req | uarch_io_flush;
	wire ifu_req_pending_n = uarch_io_toaligner_valid & !uarch_io_toaligner_ready;
	wire flush_pending_eligible =
		ifu_req_pending_n | uarch_ifu_req_pending |
		(uarch_ifu_out_r_r & !uarch_ifu_out_clr);

	always @(posedge clock) begin
		if (past_valid && flush_pulse & !flush_pending_eligible &
				!uarch_flush_pending_r)
			assert(!uarch_flush_pending_set);
	end
endmodule
