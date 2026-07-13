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
		.f2_pc_bore(f2_pc_bore)
	);

	wire flush_pulse = io_fromdxu_flush_req | io_flush;
	wire raw_is_c = io_toBpu_inst[1:0] != 2'b11;
	wire req_fire = io_toaligner_valid & io_toaligner_ready;

	reg boot_fetch_seen = 1'b0;
	reg boot_clean_window = 1'b1;

	always @(posedge clock) begin
		if (reset) begin
			boot_fetch_seen <= 1'b0;
			boot_clean_window <= 1'b1;
		end else begin
			if (req_fire)
				boot_fetch_seen <= 1'b1;
			else if (!boot_fetch_seen & (flush_pulse | io_toBpu_prdt_take))
				boot_clean_window <= 1'b0;

		end
	end

	// Environment assumptions: keep BPU prediction meaningful without
	// constraining the fetch/aligner handshake space.
	always @* begin
		assume(!io_toBpu_prdt_take || io_toBpu_ir_vld);
	end

	// Interface and pipeline assertions.
	always @(posedge clock) begin
		if (!reset) begin
			if (io_toaligner_valid)
				assert(io_toaligner_bits_req_pc[0] == 1'b0);

			assert(io_next_pc[0] == 1'b0);

			if (flush_pulse)
				assert(!io_pplOut_valid);

			if (!boot_fetch_seen & boot_clean_window & !flush_pulse & !io_toBpu_prdt_take &
					!io_ifu_halt & !io_ifu_stall & io_toaligner_valid)
				assert(io_toaligner_bits_req_pc == 32'h80000000);

			if (io_pplOut_valid) begin
				assert(io_pplOut_bits_pc == io_toBpu_instPc);
				assert(io_pplOut_bits_cInst == io_toBpu_inst[15:0]);
				assert(io_pplOut_bits_isCInst == raw_is_c);
				assert(io_pplOut_bits_prdt_taken[31:1] == 31'h0);
				assert(io_pplOut_bits_prdt_taken[0] == io_toBpu_prdt_take);
				if (!io_pplOut_bits_isCInst)
					assert(!io_pplOut_bits_rvcIllegal);
			end
		end

		if (past_valid && !$past(reset)) begin
			if ($past(io_toaligner_valid & !io_toaligner_ready)) begin
				assert(io_toaligner_valid);
				if (!io_toaligner_ready) begin
					assert(io_toaligner_bits_req_pc == $past(io_toaligner_bits_req_pc));
				end
			end

			if ($past(flush_pulse & io_fromaligner_valid & io_fromaligner_ready &
					(!io_pplOut_ready | !io_toaligner_ready | io_ifu_stall)))
				assert(io_fromaligner_ready);
		end
	end

	// Coverage points: these do not constrain the proof, but make it visible
	// whether the checker can still reach the important IF-stage situations.
	always @(posedge clock) begin
		if (!reset) begin
			cover(io_toaligner_valid);
			cover(io_toaligner_valid & !io_toaligner_ready);
			cover(io_toaligner_valid & io_toaligner_ready);
			cover(io_fromaligner_valid & io_fromaligner_ready);
			cover(flush_pulse);
			cover(io_pplOut_valid);
			cover(io_pplOut_valid & io_pplOut_bits_isCInst);
			cover(io_pplOut_valid & !io_pplOut_bits_isCInst);
			cover(io_pplOut_valid & io_pplOut_bits_ifu_fetch_err);
			cover(io_toBpu_prdt_take);
		end
	end

endmodule
