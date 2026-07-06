module cl1_idex_stage_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_pplIn_valid;
	(* anyseq *) reg [31:0] io_pplIn_bits_pc;
	(* anyseq *) reg [31:0] io_pplIn_bits_inst;
	(* anyseq *) reg [31:0] io_pplIn_bits_prdt_taken;
	(* anyseq *) reg [15:0] io_pplIn_bits_cInst;
	(* anyseq *) reg        io_pplIn_bits_isCInst;
	(* anyseq *) reg        io_pplIn_bits_rvcIllegal;
	(* anyseq *) reg        io_pplIn_bits_ifu_fetch_err;
	(* anyseq *) reg        io_pplIn_bits_muldiv_b2b;
	(* anyseq *) reg        io_pplOut_ready;
	(* anyseq *) reg        io_mem_ready;
	(* anyseq *) reg [31:0] io_rs1Value;
	(* anyseq *) reg [31:0] io_rs2Value;
	(* anyseq *) reg [31:0] io_csrData;
	(* anyseq *) reg        io_stall;
	(* anyseq *) reg        io_memNotOutStanding;
	(* anyseq *) reg        io_flush;
	(* anyseq *) reg        io_icache_req_ready;
	(* anyseq *) reg        io_dcache_req_ready;

	wire        io_pplIn_ready;
	wire        io_pplOut_valid;
	wire [1:0]  io_pplOut_bits_wbType;
	wire [31:0] io_pplOut_bits_rdWdat;
	wire [31:0] io_pplOut_bits_csrWdat;
	wire        io_pplOut_bits_wen;
	wire        io_pplOut_bits_csrWen;
	wire [3:0]  io_pplOut_bits_memType;
	wire [31:0] io_pplOut_bits_pc;
	wire [4:0]  io_pplOut_bits_privInstr;
	wire [31:0] io_pplOut_bits_inst;
	wire [15:0] io_pplOut_bits_cInst;
	wire        io_pplOut_bits_isCInst;
	wire        io_pplOut_bits_isTrap;
	wire [7:0]  io_pplOut_bits_trapCode;
	wire [31:0] io_pplOut_bits_trapValue;
	wire        io_pplOut_bits_dx_ready;
	wire        io_mem_valid;
	wire [3:0]  io_mem_bits_memType;
	wire [31:0] io_mem_bits_addr;
	wire [31:0] io_mem_bits_wdata;
	wire        io_toifu_flush_req;
	wire [31:0] io_toifu_flush_pc;
	wire [31:0] io_toifu_flush_pc_ofst;
	wire [4:0]  io_toifu_decmuldiv_info;
	wire [4:0]  io_toifu_dec_rs1idx;
	wire [4:0]  io_toifu_dec_rs2idx;
	wire [4:0]  io_toifu_dec_rdidx;
	wire [4:0]  io_rs1Addr;
	wire [4:0]  io_rs2Addr;
	wire        io_rs1_ren;
	wire        io_rs2_ren;
	wire [11:0] io_csrAddr;
	wire        io_csrRen;
	wire        io_dxu_halt_ack;
	wire        io_valid;
	wire        io_wen_x1;
	wire        io_icache_req_valid;
	wire        io_icache_req_bits_invalid;
	wire        io_icache_req_bits_clean;
	wire        io_dcache_req_valid;
	wire        io_dcache_req_bits_invalid;
	wire        io_dcache_req_bits_clean;

	Cl1IDEXStage dut (
		.clock(clock),
		.reset(reset),
		.io_pplIn_ready(io_pplIn_ready),
		.io_pplIn_valid(io_pplIn_valid),
		.io_pplIn_bits_pc(io_pplIn_bits_pc),
		.io_pplIn_bits_inst(io_pplIn_bits_inst),
		.io_pplIn_bits_prdt_taken(io_pplIn_bits_prdt_taken),
		.io_pplIn_bits_cInst(io_pplIn_bits_cInst),
		.io_pplIn_bits_isCInst(io_pplIn_bits_isCInst),
		.io_pplIn_bits_rvcIllegal(io_pplIn_bits_rvcIllegal),
		.io_pplIn_bits_ifu_fetch_err(io_pplIn_bits_ifu_fetch_err),
		.io_pplIn_bits_muldiv_b2b(io_pplIn_bits_muldiv_b2b),
		.io_pplOut_ready(io_pplOut_ready),
		.io_pplOut_valid(io_pplOut_valid),
		.io_pplOut_bits_wbType(io_pplOut_bits_wbType),
		.io_pplOut_bits_rdWdat(io_pplOut_bits_rdWdat),
		.io_pplOut_bits_csrWdat(io_pplOut_bits_csrWdat),
		.io_pplOut_bits_wen(io_pplOut_bits_wen),
		.io_pplOut_bits_csrWen(io_pplOut_bits_csrWen),
		.io_pplOut_bits_memType(io_pplOut_bits_memType),
		.io_pplOut_bits_pc(io_pplOut_bits_pc),
		.io_pplOut_bits_privInstr(io_pplOut_bits_privInstr),
		.io_pplOut_bits_inst(io_pplOut_bits_inst),
		.io_pplOut_bits_cInst(io_pplOut_bits_cInst),
		.io_pplOut_bits_isCInst(io_pplOut_bits_isCInst),
		.io_pplOut_bits_isTrap(io_pplOut_bits_isTrap),
		.io_pplOut_bits_trapCode(io_pplOut_bits_trapCode),
		.io_pplOut_bits_trapValue(io_pplOut_bits_trapValue),
		.io_pplOut_bits_dx_ready(io_pplOut_bits_dx_ready),
		.io_mem_ready(io_mem_ready),
		.io_mem_valid(io_mem_valid),
		.io_mem_bits_memType(io_mem_bits_memType),
		.io_mem_bits_addr(io_mem_bits_addr),
		.io_mem_bits_wdata(io_mem_bits_wdata),
		.io_toifu_flush_req(io_toifu_flush_req),
		.io_toifu_flush_pc(io_toifu_flush_pc),
		.io_toifu_flush_pc_ofst(io_toifu_flush_pc_ofst),
		.io_toifu_decmuldiv_info(io_toifu_decmuldiv_info),
		.io_toifu_dec_rs1idx(io_toifu_dec_rs1idx),
		.io_toifu_dec_rs2idx(io_toifu_dec_rs2idx),
		.io_toifu_dec_rdidx(io_toifu_dec_rdidx),
		.io_rs1Value(io_rs1Value),
		.io_rs2Value(io_rs2Value),
		.io_rs1Addr(io_rs1Addr),
		.io_rs2Addr(io_rs2Addr),
		.io_rs1_ren(io_rs1_ren),
		.io_rs2_ren(io_rs2_ren),
		.io_csrData(io_csrData),
		.io_csrAddr(io_csrAddr),
		.io_csrRen(io_csrRen),
		.io_stall(io_stall),
		.io_dxu_halt_ack(io_dxu_halt_ack),
		.io_memNotOutStanding(io_memNotOutStanding),
		.io_valid(io_valid),
		.io_flush(io_flush),
		.io_wen_x1(io_wen_x1),
		.io_icache_req_ready(io_icache_req_ready),
		.io_icache_req_valid(io_icache_req_valid),
		.io_icache_req_bits_invalid(io_icache_req_bits_invalid),
		.io_icache_req_bits_clean(io_icache_req_bits_clean),
		.io_dcache_req_ready(io_dcache_req_ready),
		.io_dcache_req_valid(io_dcache_req_valid),
		.io_dcache_req_bits_invalid(io_dcache_req_bits_invalid),
		.io_dcache_req_bits_clean(io_dcache_req_bits_clean)
	);

endmodule

module cl1_idex_stage_monitor(
	input        clock,
	input        reset,
	input        io_pplIn_valid,
	input [31:0] io_pplIn_bits_pc,
	input [31:0] io_pplIn_bits_inst,
	input [31:0] io_pplIn_bits_prdt_taken,
	input        io_pplIn_bits_rvcIllegal,
	input        io_pplIn_bits_ifu_fetch_err,
	input        io_stall,
	input        io_memNotOutStanding,
	input        io_flush,
	input        io_pplOut_bits_csrWen,
	input [4:0]  io_pplOut_bits_privInstr,
	input        io_pplOut_bits_isTrap,
	input        io_mem_valid,
	input        io_toifu_flush_req,
	input [31:0] io_toifu_flush_pc,
	input [31:0] io_toifu_flush_pc_ofst,
	input        dxHasTrap,
	input        dx_exec_done,
	input        brchmis_flush_pluse,
	input [4:0]  decoder_muldivOp,
	input        mdu_io_in_valid
);
	function csr_is_read_only;
		input [11:0] addr;
		begin
			csr_is_read_only =
				addr == 12'hF11 || addr == 12'hF12 || addr == 12'hF13 ||
				addr == 12'hF14 || addr == 12'hF15;
		end
	endfunction

	function csr_is_supported;
		input [11:0] addr;
		begin
			csr_is_supported =
				addr == 12'h300 || addr == 12'h301 || addr == 12'h304 ||
				addr == 12'h305 || addr == 12'h310 || addr == 12'h340 ||
				addr == 12'h341 || addr == 12'h342 || addr == 12'h343 ||
				addr == 12'h344 || addr == 12'hB00 || addr == 12'hB02 ||
				addr == 12'hB80 || addr == 12'hB82 || addr == 12'hF11 ||
				addr == 12'hF12 || addr == 12'hF13 || addr == 12'hF14 ||
				addr == 12'hF15;
		end
	endfunction

	function [31:0] jal_imm;
		input [31:0] insn;
		begin
			jal_imm = {{12{insn[31]}}, insn[19:12], insn[20], insn[30:21], 1'b0};
		end
	endfunction

	wire [2:0]  funct3 = io_pplIn_bits_inst[14:12];
	wire [11:0] csr_addr = io_pplIn_bits_inst[31:20];
	wire [4:0]  csr_arg = io_pplIn_bits_inst[19:15];
	wire        is_system = io_pplIn_bits_inst[6:0] == 7'h73;
	wire        is_csr_access = is_system & funct3 != 3'b000;
	wire        csr_no_write_access =
		is_csr_access & (funct3[1:0] == 2'b10 || funct3[1:0] == 2'b11) & csr_arg == 5'h0;
	wire        csr_write_access =
		is_csr_access & (funct3[1:0] == 2'b01 ||
			((funct3[1:0] == 2'b10 || funct3[1:0] == 2'b11) & csr_arg != 5'h0));
	wire        active_clean_decode =
		io_pplIn_valid & !io_flush & !io_stall &
		!io_pplIn_bits_ifu_fetch_err & !io_pplIn_bits_rvcIllegal;
	wire        is_jal = io_pplIn_bits_inst[6:0] == 7'h6F;
	wire        jal_unpredicted =
		active_clean_decode & is_jal & !io_pplIn_bits_prdt_taken[0] & !dx_exec_done;
	wire        trapped_active =
		io_pplIn_valid & dxHasTrap & !io_flush & !io_stall;
	wire        mdu_reissue_window =
		io_pplIn_valid & dx_exec_done & !io_flush & !io_stall &
		!dxHasTrap & (|decoder_muldivOp);

	always @(posedge clock) begin
		if (!reset) begin
			if (active_clean_decode & csr_no_write_access)
				assert(!io_pplOut_bits_csrWen);

			if (active_clean_decode & csr_no_write_access & csr_is_supported(csr_addr))
				assert(!io_pplOut_bits_isTrap);

			if (active_clean_decode & csr_write_access & csr_is_read_only(csr_addr))
				assert(io_pplOut_bits_isTrap);

			if (active_clean_decode & io_pplIn_bits_inst == 32'h30200073) begin
				assert(io_pplOut_bits_privInstr == 5'b00010);
				assert(!io_pplOut_bits_isTrap);
			end

			if (jal_unpredicted) begin
				assert(io_toifu_flush_req);
				assert(io_toifu_flush_pc == io_pplIn_bits_pc);
				assert(io_toifu_flush_pc_ofst == jal_imm(io_pplIn_bits_inst));
			end

			if (mdu_reissue_window)
				assert(!mdu_io_in_valid);

			if (!io_memNotOutStanding)
				assert(!io_mem_valid);

			if (trapped_active) begin
				assert(!brchmis_flush_pluse);
				assert(!io_toifu_flush_req);
			end
		end
	end
endmodule

bind Cl1IDEXStage cl1_idex_stage_monitor cl1_idex_stage_monitor_i (
	.clock(clock),
	.reset(reset),
	.io_pplIn_valid(io_pplIn_valid),
	.io_pplIn_bits_pc(io_pplIn_bits_pc),
	.io_pplIn_bits_inst(io_pplIn_bits_inst),
	.io_pplIn_bits_prdt_taken(io_pplIn_bits_prdt_taken),
	.io_pplIn_bits_rvcIllegal(io_pplIn_bits_rvcIllegal),
	.io_pplIn_bits_ifu_fetch_err(io_pplIn_bits_ifu_fetch_err),
	.io_stall(io_stall),
	.io_memNotOutStanding(io_memNotOutStanding),
	.io_flush(io_flush),
	.io_pplOut_bits_csrWen(io_pplOut_bits_csrWen),
	.io_pplOut_bits_privInstr(io_pplOut_bits_privInstr),
	.io_pplOut_bits_isTrap(io_pplOut_bits_isTrap),
	.io_mem_valid(io_mem_valid),
	.io_toifu_flush_req(io_toifu_flush_req),
	.io_toifu_flush_pc(io_toifu_flush_pc),
	.io_toifu_flush_pc_ofst(io_toifu_flush_pc_ofst),
	.dxHasTrap(dxHasTrap),
	.dx_exec_done(dx_exec_done),
	.brchmis_flush_pluse(brchmis_flush_pluse),
	.decoder_muldivOp(_decoder_io_out_muldivOp),
	.mdu_io_in_valid(mdu.io_in_valid)
);
