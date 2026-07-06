module cl1_if_stage_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_toBpu_prdt_take;
	(* anyseq *) reg [31:0] io_toBpu_prdt_pc;
	(* anyseq *) reg [31:0] io_toBpu_prdt_pc_ofst;
	(* anyseq *) reg        io_pplOut_ready;
	(* anyseq *) reg        io_toaligner_ready;
	(* anyseq *) reg        io_fromaligner_valid;
	(* anyseq *) reg [31:0] io_fromaligner_bits_inst;
	(* anyseq *) reg        io_fromaligner_bits_err;
	(* anyseq *) reg        io_fromdxu_flush_req;
	(* anyseq *) reg [31:0] io_fromdxu_flush_pc;
	(* anyseq *) reg [31:0] io_fromdxu_flush_pc_ofst;
	(* anyseq *) reg [4:0]  io_fromdxu_decmuldiv_info;
	(* anyseq *) reg [4:0]  io_fromdxu_dec_rs1idx;
	(* anyseq *) reg [4:0]  io_fromdxu_dec_rs2idx;
	(* anyseq *) reg [4:0]  io_fromdxu_dec_rdidx;
	(* anyseq *) reg        io_flush;
	(* anyseq *) reg [31:0] io_flush_pc;
	(* anyseq *) reg [31:0] io_flush_pc_ofst;
	(* anyseq *) reg        io_ifu_halt;
	(* anyseq *) reg        io_ifu_stall;
	(* anyseq *) reg [31:0] io_boot_addr;

	wire        io_toBpu_ir_vld;
	wire [31:0] io_toBpu_inst;
	wire [31:0] io_toBpu_instPc;
	wire        io_pplOut_valid;
	wire [31:0] io_pplOut_bits_pc;
	wire [31:0] io_pplOut_bits_inst;
	wire [31:0] io_pplOut_bits_prdt_taken;
	wire [15:0] io_pplOut_bits_cInst;
	wire        io_pplOut_bits_isCInst;
	wire        io_pplOut_bits_rvcIllegal;
	wire        io_pplOut_bits_ifu_fetch_err;
	wire        io_pplOut_bits_muldiv_b2b;
	wire        io_toaligner_valid;
	wire [31:0] io_toaligner_bits_req_pc;
	wire        io_toaligner_bits_req_redirect;
	wire        io_fromaligner_ready;
	wire [31:0] io_next_pc;
	wire [31:0] f2_pc_bore;

	Cl1IFStage dut (
		.clock(clock),
		.reset(reset),
		.io_toBpu_ir_vld(io_toBpu_ir_vld),
		.io_toBpu_inst(io_toBpu_inst),
		.io_toBpu_instPc(io_toBpu_instPc),
		.io_toBpu_prdt_take(io_toBpu_prdt_take),
		.io_toBpu_prdt_pc(io_toBpu_prdt_pc),
		.io_toBpu_prdt_pc_ofst(io_toBpu_prdt_pc_ofst),
		.io_pplOut_ready(io_pplOut_ready),
		.io_pplOut_valid(io_pplOut_valid),
		.io_pplOut_bits_pc(io_pplOut_bits_pc),
		.io_pplOut_bits_inst(io_pplOut_bits_inst),
		.io_pplOut_bits_prdt_taken(io_pplOut_bits_prdt_taken),
		.io_pplOut_bits_cInst(io_pplOut_bits_cInst),
		.io_pplOut_bits_isCInst(io_pplOut_bits_isCInst),
		.io_pplOut_bits_rvcIllegal(io_pplOut_bits_rvcIllegal),
		.io_pplOut_bits_ifu_fetch_err(io_pplOut_bits_ifu_fetch_err),
		.io_pplOut_bits_muldiv_b2b(io_pplOut_bits_muldiv_b2b),
		.io_toaligner_ready(io_toaligner_ready),
		.io_toaligner_valid(io_toaligner_valid),
		.io_toaligner_bits_req_pc(io_toaligner_bits_req_pc),
		.io_toaligner_bits_req_redirect(io_toaligner_bits_req_redirect),
		.io_fromaligner_ready(io_fromaligner_ready),
		.io_fromaligner_valid(io_fromaligner_valid),
		.io_fromaligner_bits_inst(io_fromaligner_bits_inst),
		.io_fromaligner_bits_err(io_fromaligner_bits_err),
		.io_fromdxu_flush_req(io_fromdxu_flush_req),
		.io_fromdxu_flush_pc(io_fromdxu_flush_pc),
		.io_fromdxu_flush_pc_ofst(io_fromdxu_flush_pc_ofst),
		.io_fromdxu_decmuldiv_info(io_fromdxu_decmuldiv_info),
		.io_fromdxu_dec_rs1idx(io_fromdxu_dec_rs1idx),
		.io_fromdxu_dec_rs2idx(io_fromdxu_dec_rs2idx),
		.io_fromdxu_dec_rdidx(io_fromdxu_dec_rdidx),
		.io_flush(io_flush),
		.io_flush_pc(io_flush_pc),
		.io_flush_pc_ofst(io_flush_pc_ofst),
		.io_ifu_halt(io_ifu_halt),
		.io_ifu_stall(io_ifu_stall),
		.io_next_pc(io_next_pc),
		.io_boot_addr(io_boot_addr),
		.f2_pc_bore(f2_pc_bore)
	);

endmodule

module cl1_if_stage_monitor(
	input        clock,
	input        reset,
	input        io_toBpu_prdt_take,
	input        io_pplOut_valid,
	input        io_pplOut_bits_ifu_fetch_err,
	input        io_toaligner_ready,
	input        io_toaligner_valid,
	input [31:0] io_toaligner_bits_req_pc,
	input        io_toaligner_bits_req_redirect,
	input        io_fromaligner_bits_err,
	input        io_fromdxu_flush_req,
	input        io_flush,
	input [31:0] io_boot_addr,
	input        ifu_req_pending,
	input        ifu_req_pending_n,
	input        ifu_out_r_r,
	input        ifu_out_clr,
	input [31:0] stored_pc,
	input        stored_redirect,
	input        flush_pending_r,
	input        flush_pending_set,
	input        flush_real,
	input        aligner_ready,
	input        reset_req_r,
	input        aligner_bypVld_r,
	input        aligner_bypDat_err
);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire flush_pulse = io_fromdxu_flush_req | io_flush;
	wire pending_replay_ready = ifu_req_pending & ~ifu_out_r_r;
	wire flush_pending_eligible =
		ifu_req_pending_n | ifu_req_pending | (ifu_out_r_r & ~ifu_out_clr);
	wire [31:0] aligned_boot_addr = {io_boot_addr[31:1], 1'b0};
	wire expected_fetch_err = aligner_bypVld_r ? aligner_bypDat_err : io_fromaligner_bits_err;

	always @(posedge clock) begin
		if (!reset) begin
			if (pending_replay_ready)
				assert(io_toaligner_valid);

			if (ifu_req_pending & io_toaligner_valid) begin
				assert(io_toaligner_bits_req_pc == stored_pc);
				assert(io_toaligner_bits_req_redirect == stored_redirect);
			end

			if (flush_pulse & !flush_pending_eligible & !flush_pending_r)
				assert(!flush_pending_set);

			if (flush_real)
				assert(aligner_ready);

			if (reset_req_r & !ifu_req_pending & !flush_real & !io_toBpu_prdt_take
					& io_toaligner_valid)
				assert(io_toaligner_bits_req_pc == aligned_boot_addr);

			if (io_pplOut_valid)
				assert(io_pplOut_bits_ifu_fetch_err == expected_fetch_err);
		end

		if (past_valid && !$past(reset)) begin
			if ($past(io_toaligner_valid & !io_toaligner_ready)) begin
				assert(ifu_req_pending);
				assert(stored_pc == $past(io_toaligner_bits_req_pc));
				assert(stored_redirect == $past(io_toaligner_bits_req_redirect));
			end
		end
	end
endmodule

bind Cl1IFStage cl1_if_stage_monitor cl1_if_stage_monitor_i (
	.clock(clock),
	.reset(reset),
	.io_toBpu_prdt_take(io_toBpu_prdt_take),
	.io_pplOut_valid(io_pplOut_valid),
	.io_pplOut_bits_ifu_fetch_err(io_pplOut_bits_ifu_fetch_err),
	.io_toaligner_ready(io_toaligner_ready),
	.io_toaligner_valid(io_toaligner_valid),
	.io_toaligner_bits_req_pc(io_toaligner_bits_req_pc),
	.io_toaligner_bits_req_redirect(io_toaligner_bits_req_redirect),
	.io_fromaligner_bits_err(io_fromaligner_bits_err),
	.io_fromdxu_flush_req(io_fromdxu_flush_req),
	.io_flush(io_flush),
	.io_boot_addr(io_boot_addr),
	.ifu_req_pending(ifu_req_pending),
	.ifu_req_pending_n(ifu_req_pending_n),
	.ifu_out_r_r(ifu_out_r_r),
	.ifu_out_clr(ifu_out_clr),
	.stored_pc(stored_pc),
	.stored_redirect(stored_redirect),
	.flush_pending_r(flush_pending_r),
	.flush_pending_set(flush_pending_set),
	.flush_real(flush_real),
	.aligner_ready(aligner_ready),
	.reset_req_r(reset_req_r),
	.aligner_bypVld_r(aligner_bypVld_r),
	.aligner_bypDat_err(aligner_bypDat_err)
);
