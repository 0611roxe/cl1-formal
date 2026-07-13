`include "cl1_microarch_csr_defs.vh"

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

	function [31:0] csr_write_value;
		input [31:0] old_value;
		input [31:0] operand;
		input [2:0]  op;
		begin
			case (op[1:0])
			2'b01: csr_write_value = operand;
			2'b10: csr_write_value = old_value | operand;
			2'b11: csr_write_value = old_value & ~operand;
			default: csr_write_value = old_value;
			endcase
		end
	endfunction

	function [31:0] jal_imm;
		input [31:0] insn;
		begin
			jal_imm = {{12{insn[31]}}, insn[19:12], insn[20], insn[30:21], 1'b0};
		end
	endfunction

	wire [6:0]  opcode = io_pplIn_bits_inst[6:0];
	wire [2:0]  funct3 = io_pplIn_bits_inst[14:12];
	wire [4:0]  rs1 = io_pplIn_bits_inst[19:15];
	wire [4:0]  rs2 = io_pplIn_bits_inst[24:20];
	wire [4:0]  rd = io_pplIn_bits_inst[11:7];
	wire [11:0] csr_addr = io_pplIn_bits_inst[31:20];
	wire        active_no_kill = io_pplIn_valid & !io_flush & !io_stall;
	wire        active_clean = active_no_kill &
		!io_pplIn_bits_ifu_fetch_err & !io_pplIn_bits_rvcIllegal;
	wire        system_insn = opcode == 7'h73;
	wire        bad_csr_funct3 = system_insn & (funct3 == 3'b100);
	wire        csr_is_access = system_insn & (funct3[1:0] != 2'b00);
	wire        csr_rw_op = (funct3[1:0] == 2'b01);
	wire        csr_setclr_op = (funct3[1:0] == 2'b10) | (funct3[1:0] == 2'b11);
	wire        csr_writes = csr_is_access & (csr_rw_op | (csr_setclr_op & (rs1 != 5'h0)));
	wire        csr_reads = csr_is_access & ((csr_rw_op & (rd != 5'h0)) | csr_setclr_op);
	wire        csr_legal = csr_is_access &
		`CL1_UARCH_CSR_MACHINE_READABLE(csr_addr) &
		!(csr_writes & `CL1_UARCH_CSR_READ_ONLY(csr_addr));
	wire [31:0] csr_operand = funct3[2] ? {27'h0, rs1} : io_rs1Value;
	wire [31:0] csr_expected_wdata = csr_write_value(io_csrData, csr_operand, funct3);
	wire        priv_base = system_insn & (funct3 == 3'b000) & (rd == 5'h0) &
		(rs1 == 5'h0);
	wire        priv_ecall = priv_base & (csr_addr == 12'h000);
	wire        priv_ebreak = priv_base & (csr_addr == 12'h001);
	wire        priv_mret = priv_base & (csr_addr == 12'h302);
	wire        priv_dret = priv_base & (csr_addr == 12'h7B2);
	wire        priv_wfi = priv_base & (csr_addr == 12'h105);
	wire [4:0]  expected_priv_instr =
		{priv_wfi, priv_ecall, priv_ebreak, priv_mret, priv_dret};
	wire        supported_priv_instr = |expected_priv_instr;
	wire        is_jal = opcode == 7'h6F;
	wire        jal_redirect = active_clean & is_jal & !io_pplIn_bits_prdt_taken[0] &
		io_toifu_flush_req;
	wire        is_mdu = (opcode == 7'h33) & (io_pplIn_bits_inst[31:25] == 7'h01);
	wire [4:0]  expected_muldiv_op =
		(funct3 == 3'b000) ? 5'b00001 :
		(funct3 == 3'b001) ? 5'b00010 :
		(funct3 == 3'b010) ? 5'b00100 :
		(funct3 == 3'b011) ? 5'b01000 :
		(funct3 == 3'b100) ? 5'b10001 :
		(funct3 == 3'b101) ? 5'b10100 :
		(funct3 == 3'b110) ? 5'b10010 :
		(funct3 == 3'b111) ? 5'b11000 : 5'b00000;

	// Interface, decode, and side-effect gating assertions.
	always @(posedge clock) begin
		if (!reset) begin
			assert(io_valid == io_pplIn_valid);
			assert(io_rs1Addr == rs1);
			assert(io_rs2Addr == rs2);
			assert(io_rs1_ren == (rs1 != 5'h0));
			assert(io_rs2_ren == (rs2 != 5'h0));
			assert(io_csrAddr == csr_addr);
			assert(io_wen_x1 == (io_pplIn_valid & rd == 5'h1));

			if (io_flush | io_stall) begin
				assert(!io_pplOut_valid);
				assert(!io_pplOut_bits_csrWen);
				assert(!io_mem_valid);
				assert(!io_icache_req_valid);
				assert(!io_dcache_req_valid);
			end

			if (io_pplOut_valid) begin
				assert(io_pplOut_bits_pc == io_pplIn_bits_pc);
				assert(io_pplOut_bits_inst == io_pplIn_bits_inst);
				assert(io_pplOut_bits_cInst == io_pplIn_bits_cInst);
				assert(io_pplOut_bits_isCInst == io_pplIn_bits_isCInst);
			end

			if (io_pplOut_bits_isTrap) begin
				assert(!io_pplOut_bits_wen);
				assert(!io_pplOut_bits_csrWen);
				assert(!io_mem_valid);
			end

			if (io_mem_valid) begin
				assert(active_no_kill);
				assert(io_memNotOutStanding);
				assert(!io_pplOut_bits_isTrap);
				assert(io_mem_bits_memType == io_pplOut_bits_memType);
				assert(io_mem_bits_wdata == io_rs2Value);
			end

			if (io_icache_req_valid) begin
				assert(active_no_kill);
				assert(io_memNotOutStanding);
				assert(io_icache_req_bits_invalid);
				assert(!io_icache_req_bits_clean);
			end

			if (io_dcache_req_valid) begin
				assert(active_no_kill);
				assert(io_memNotOutStanding);
				assert(io_dcache_req_bits_invalid | io_dcache_req_bits_clean);
			end

			if (active_no_kill & io_pplIn_bits_ifu_fetch_err) begin
				assert(io_pplOut_bits_isTrap);
				assert(io_pplOut_bits_trapCode == 8'h01);
				assert(io_pplOut_bits_trapValue == io_pplIn_bits_pc);
				assert(!io_mem_valid);
				assert(!io_toifu_flush_req);
			end else if (active_no_kill & io_pplIn_bits_rvcIllegal) begin
				assert(io_pplOut_bits_isTrap);
				assert(io_pplOut_bits_trapCode == 8'h02);
				assert(io_pplOut_bits_trapValue == {16'h0, io_pplIn_bits_cInst});
				assert(!io_mem_valid);
				assert(!io_toifu_flush_req);
			end else if (active_clean & bad_csr_funct3) begin
				assert(io_pplOut_bits_isTrap);
				assert(io_pplOut_bits_trapCode == 8'h02);
				assert(io_pplOut_bits_trapValue == io_pplIn_bits_inst);
				assert(!io_pplOut_bits_csrWen);
				assert(!io_csrRen);
			end else if (active_clean & csr_is_access) begin
				if (!csr_legal) begin
					assert(io_pplOut_bits_isTrap);
					assert(io_pplOut_bits_trapCode == 8'h02);
					assert(io_pplOut_bits_trapValue == io_pplIn_bits_inst);
					assert(!io_csrRen);
					assert(!io_pplOut_bits_csrWen);
				end else begin
					assert(!io_pplOut_bits_isTrap);
					assert(io_csrRen == csr_reads);
					assert(io_pplOut_bits_csrWen == csr_writes);
					if (csr_reads)
						assert(io_pplOut_bits_rdWdat == io_csrData);
					if (csr_writes)
						assert(io_pplOut_bits_csrWdat == csr_expected_wdata);
				end
			end

			if (active_clean & supported_priv_instr) begin
				assert(!io_pplOut_bits_isTrap);
				assert(io_pplOut_bits_privInstr == expected_priv_instr);
				assert(!io_csrRen);
				assert(!io_pplOut_bits_csrWen);
				assert(!io_mem_valid);
			end

			if (jal_redirect) begin
				assert(io_toifu_flush_pc == io_pplIn_bits_pc);
				assert(io_toifu_flush_pc_ofst == jal_imm(io_pplIn_bits_inst));
			end

			if (active_clean & is_mdu) begin
				assert(!io_pplOut_bits_isTrap);
				assert(io_toifu_decmuldiv_info == expected_muldiv_op);
				assert(!io_mem_valid);
				assert(!io_icache_req_valid);
				assert(!io_dcache_req_valid);
				assert(!io_pplOut_bits_csrWen);
			end
		end
	end

	// Coverage points for the main IDEX behavior classes.
	always @(posedge clock) begin
		if (!reset) begin
			cover(io_flush);
			cover(io_stall);
			cover(io_pplOut_valid);
			cover(io_mem_valid);
			cover(io_icache_req_valid);
			cover(io_dcache_req_valid);
			cover(active_no_kill & io_pplIn_bits_ifu_fetch_err & io_pplOut_bits_isTrap);
			cover(active_no_kill & io_pplIn_bits_rvcIllegal & io_pplOut_bits_isTrap);
			cover(active_clean & bad_csr_funct3 & io_pplOut_bits_isTrap);
			cover(active_clean & csr_is_access & csr_legal & csr_reads & io_csrRen);
			cover(active_clean & csr_is_access & csr_legal & csr_writes & io_pplOut_bits_csrWen);
			cover(active_clean & csr_is_access & !csr_legal & io_pplOut_bits_isTrap);
			cover(active_clean & supported_priv_instr & (io_pplOut_bits_privInstr == expected_priv_instr));
			cover(jal_redirect);
			cover(active_clean & is_mdu & (io_toifu_decmuldiv_info == expected_muldiv_op));
		end
	end

endmodule
