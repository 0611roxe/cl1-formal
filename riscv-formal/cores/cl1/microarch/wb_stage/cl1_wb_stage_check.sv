module cl1_wb_stage_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_pplIn_valid;
	(* anyseq *) reg [1:0]  io_pplIn_bits_wbType;
	(* anyseq *) reg [31:0] io_pplIn_bits_rdWdat;
	(* anyseq *) reg [31:0] io_pplIn_bits_csrWdat;
	(* anyseq *) reg        io_pplIn_bits_wen;
	(* anyseq *) reg        io_pplIn_bits_csrWen;
	(* anyseq *) reg [3:0]  io_pplIn_bits_memType;
	(* anyseq *) reg [31:0] io_pplIn_bits_pc;
	(* anyseq *) reg [4:0]  io_pplIn_bits_privInstr;
	(* anyseq *) reg [31:0] io_pplIn_bits_inst;
	(* anyseq *) reg [15:0] io_pplIn_bits_cInst;
	(* anyseq *) reg        io_pplIn_bits_isCInst;
	(* anyseq *) reg        io_pplIn_bits_isTrap;
	(* anyseq *) reg [7:0]  io_pplIn_bits_trapCode;
	(* anyseq *) reg [31:0] io_pplIn_bits_trapValue;
	(* anyseq *) reg        io_pplIn_bits_dx_ready;
	(* anyseq *) reg        io_mem_valid;
	(* anyseq *) reg [31:0] io_mem_bits_rdata;
	(* anyseq *) reg [3:0]  io_mem_bits_err;
	(* anyseq *) reg        io_flush;

	wire        io_pplIn_ready;
	wire        io_mem_ready;
	wire        io_dbg_wb_valid;
	wire        io_dbg_wb_commit;
	wire        io_dbg_wb_is_ebrk;
	wire        io_dbg_wb_is_dret;
	wire [31:0] io_dbg_wb_pc;
	wire        io_toExcp_cmt_ecall;
	wire        io_toExcp_cmt_mret;
	wire        io_toExcp_cmt_wfi;
	wire        io_toExcp_wb_valid;
	wire [31:0] io_toExcp_wb_pc;
	wire        io_toExcp_excp_valid;
	wire [7:0]  io_toExcp_excp_code;
	wire [31:0] io_toExcp_excp_tval;
	wire [31:0] io_wdata;
	wire [31:0] io_csrWdat;
	wire [31:0] io_forwardDat;
	wire        io_wen;
	wire [4:0]  io_rd_idx;
	wire        io_csrWen;
	wire [11:0] io_csr_idx;
	wire        io_valid;
	wire [15:0] io_cInst;
	wire [31:0] io_inst;
	wire        io_is_mem_load;
	wire        io_isEret;
	wire        io_wen_x1;
	wire        wb_diff_cmt_bore;

	Cl1WBStage dut (
		.clock(clock),
		.reset(reset),
		.io_pplIn_ready(io_pplIn_ready),
		.io_pplIn_valid(io_pplIn_valid),
		.io_pplIn_bits_wbType(io_pplIn_bits_wbType),
		.io_pplIn_bits_rdWdat(io_pplIn_bits_rdWdat),
		.io_pplIn_bits_csrWdat(io_pplIn_bits_csrWdat),
		.io_pplIn_bits_wen(io_pplIn_bits_wen),
		.io_pplIn_bits_csrWen(io_pplIn_bits_csrWen),
		.io_pplIn_bits_memType(io_pplIn_bits_memType),
		.io_pplIn_bits_pc(io_pplIn_bits_pc),
		.io_pplIn_bits_privInstr(io_pplIn_bits_privInstr),
		.io_pplIn_bits_inst(io_pplIn_bits_inst),
		.io_pplIn_bits_cInst(io_pplIn_bits_cInst),
		.io_pplIn_bits_isCInst(io_pplIn_bits_isCInst),
		.io_pplIn_bits_isTrap(io_pplIn_bits_isTrap),
		.io_pplIn_bits_trapCode(io_pplIn_bits_trapCode),
		.io_pplIn_bits_trapValue(io_pplIn_bits_trapValue),
		.io_pplIn_bits_dx_ready(io_pplIn_bits_dx_ready),
		.io_mem_ready(io_mem_ready),
		.io_mem_valid(io_mem_valid),
		.io_mem_bits_rdata(io_mem_bits_rdata),
		.io_mem_bits_err(io_mem_bits_err),
		.io_dbg_wb_valid(io_dbg_wb_valid),
		.io_dbg_wb_commit(io_dbg_wb_commit),
		.io_dbg_wb_is_ebrk(io_dbg_wb_is_ebrk),
		.io_dbg_wb_is_dret(io_dbg_wb_is_dret),
		.io_dbg_wb_pc(io_dbg_wb_pc),
		.io_toExcp_cmt_ecall(io_toExcp_cmt_ecall),
		.io_toExcp_cmt_mret(io_toExcp_cmt_mret),
		.io_toExcp_cmt_wfi(io_toExcp_cmt_wfi),
		.io_toExcp_wb_valid(io_toExcp_wb_valid),
		.io_toExcp_wb_pc(io_toExcp_wb_pc),
		.io_toExcp_excp_valid(io_toExcp_excp_valid),
		.io_toExcp_excp_code(io_toExcp_excp_code),
		.io_toExcp_excp_tval(io_toExcp_excp_tval),
		.io_flush(io_flush),
		.io_wdata(io_wdata),
		.io_csrWdat(io_csrWdat),
		.io_forwardDat(io_forwardDat),
		.io_wen(io_wen),
		.io_rd_idx(io_rd_idx),
		.io_csrWen(io_csrWen),
		.io_csr_idx(io_csr_idx),
		.io_valid(io_valid),
		.io_cInst(io_cInst),
		.io_inst(io_inst),
		.io_is_mem_load(io_is_mem_load),
		.io_isEret(io_isEret),
		.io_wen_x1(io_wen_x1),
		.wb_diff_cmt_bore(wb_diff_cmt_bore)
	);

	localparam [1:0] WB_ALU = 2'h0;
	localparam [1:0] WB_CSR = 2'h1;
	localparam [1:0] WB_MEM = 2'h2;

	localparam [3:0] MEM_NONE = 4'h0;
	localparam [3:0] MEM_LB   = 4'h2;
	localparam [3:0] MEM_LBU  = 4'h3;
	localparam [3:0] MEM_LH   = 4'h4;
	localparam [3:0] MEM_LHU  = 4'h5;
	localparam [3:0] MEM_LW   = 4'h6;
	localparam [3:0] MEM_SB   = 4'hA;
	localparam [3:0] MEM_SH   = 4'hC;
	localparam [3:0] MEM_SW   = 4'hE;

	function legal_mem_type;
		input [3:0] mem_type;
		begin
			case (mem_type)
			MEM_NONE, MEM_LB, MEM_LBU, MEM_LH, MEM_LHU, MEM_LW,
			MEM_SB, MEM_SH, MEM_SW: legal_mem_type = 1'b1;
			default: legal_mem_type = 1'b0;
			endcase
		end
	endfunction

	function [31:0] expected_wdata;
		input [1:0]  wb_type;
		input [31:0] rd_wdat;
		input [31:0] mem_rdata;
		begin
			case (wb_type)
			WB_MEM: expected_wdata = mem_rdata;
			WB_CSR: expected_wdata = rd_wdat;
			default: expected_wdata = rd_wdat;
			endcase
		end
	endfunction

	wire mem_access = |io_pplIn_bits_memType;
	wire mem_load = !io_pplIn_bits_memType[3] & |io_pplIn_bits_memType[2:0];
	wire mem_store = io_pplIn_bits_memType[3] & |io_pplIn_bits_memType[2:0];
	wire wait_mem_resp = !io_pplIn_bits_isTrap & mem_access;
	wire mem_fire = io_mem_ready & io_mem_valid;
	wire mem_error = wait_mem_resp & mem_fire & |io_mem_bits_err;
	wire active_wait_mem_resp = io_pplIn_valid & wait_mem_resp;
	wire ready_go = !wait_mem_resp | mem_fire;
	wire wb_commit = io_pplIn_valid & ready_go & !io_flush;
	wire [7:0] mem_error_code = mem_store ? 8'h07 : 8'h05;
	wire priv_form = io_pplIn_bits_inst[6:0] == 7'h73 &
		io_pplIn_bits_inst[11:7] == 5'h0 &
		io_pplIn_bits_inst[19:15] == 5'h0 &
		io_pplIn_bits_inst[14:12] == 3'h0;
	wire [4:0] expected_priv_instr = {
		priv_form & (io_pplIn_bits_inst[31:20] == 12'h105),
		priv_form & (io_pplIn_bits_inst[31:20] == 12'h000),
		priv_form & (io_pplIn_bits_inst[31:20] == 12'h001),
		priv_form & (io_pplIn_bits_inst[31:20] == 12'h302),
		priv_form & (io_pplIn_bits_inst[31:20] == 12'h7B2)
	};

	// Environment assumptions describe the already-checked IDEX-to-WB
	// encoding contract, not a specific instruction stream.
	always @* begin
		assume(!io_pplIn_valid || io_pplIn_bits_wbType != 2'h3);
		assume(!io_pplIn_valid || legal_mem_type(io_pplIn_bits_memType));
		assume(!io_pplIn_valid || io_pplIn_bits_privInstr == expected_priv_instr);

		if (io_pplIn_valid && io_pplIn_bits_isTrap) begin
			assume(io_pplIn_bits_memType == MEM_NONE);
			assume(!io_pplIn_bits_wen);
			assume(!io_pplIn_bits_csrWen);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert(io_valid == io_pplIn_valid);
			assert(io_dbg_wb_valid == io_pplIn_valid);
			assert(io_toExcp_wb_valid == io_pplIn_valid);
			assert(io_dbg_wb_pc == io_pplIn_bits_pc);
			assert(io_toExcp_wb_pc == io_pplIn_bits_pc);
			assert(io_inst == io_pplIn_bits_inst);
			assert(io_cInst == io_pplIn_bits_cInst);
			assert(io_rd_idx == io_pplIn_bits_inst[11:7]);
			assert(io_csr_idx == io_pplIn_bits_inst[31:20]);
			assert(io_csrWdat == io_pplIn_bits_csrWdat);
			assert(io_forwardDat == io_pplIn_bits_rdWdat);
			if (io_pplIn_valid)
				assert(io_wdata == expected_wdata(io_pplIn_bits_wbType,
					io_pplIn_bits_rdWdat, io_mem_bits_rdata));
			assert(io_is_mem_load == mem_load);
			assert(io_isEret == (io_pplIn_valid & io_pplIn_bits_privInstr[1]));
			assert(io_wen_x1 == (io_pplIn_bits_wen &
				(io_pplIn_bits_inst[11:7] == 5'h1)));

			assert(io_mem_ready == (io_pplIn_valid & mem_access));
			assert(io_pplIn_ready == (!io_pplIn_valid | ready_go | io_flush));

			if (io_flush) begin
				assert(!io_wen);
				assert(!io_csrWen);
				assert(!io_dbg_wb_commit);
			end

			if (mem_error) begin
				assert(!io_wen);
				assert(!io_csrWen);
				assert(io_toExcp_excp_valid);
				assert(io_toExcp_excp_code == mem_error_code);
			end

			if (io_pplIn_valid & io_pplIn_bits_isTrap) begin
				assert(io_toExcp_excp_valid);
				assert(io_toExcp_excp_code == io_pplIn_bits_trapCode);
				assert(io_toExcp_excp_tval == io_pplIn_bits_trapValue);
			end

			if (io_toExcp_excp_valid & !mem_error)
				assert(io_pplIn_valid & io_pplIn_bits_isTrap);

			assert(io_toExcp_excp_valid ==
				((io_pplIn_valid & io_pplIn_bits_isTrap) | mem_error));
			assert(io_toExcp_excp_tval == io_pplIn_bits_trapValue);
			assert(io_wen == (wb_commit & io_pplIn_bits_wen & !mem_error));
			assert(io_csrWen == (wb_commit & io_pplIn_bits_csrWen & !mem_error));
			assert(io_dbg_wb_commit == wb_commit);
			assert(io_toExcp_cmt_ecall == (io_pplIn_valid & io_pplIn_bits_privInstr[3]));
			assert(io_toExcp_cmt_mret == (io_pplIn_valid & io_pplIn_bits_privInstr[1]));
			assert(!io_toExcp_cmt_wfi);
			assert(io_dbg_wb_is_ebrk == (io_pplIn_valid & io_pplIn_bits_privInstr[2]));
			assert(io_dbg_wb_is_dret == (io_pplIn_valid & io_pplIn_bits_privInstr[0]));

			if (active_wait_mem_resp & !mem_fire & !io_flush) begin
				assert(!io_pplIn_ready);
				assert(!io_wen);
				assert(!io_csrWen);
				assert(!io_dbg_wb_commit);
			end

			if (wb_commit & !mem_error & io_pplIn_bits_wen)
				assert(io_wen);

			if (wb_commit & !mem_error & io_pplIn_bits_csrWen)
				assert(io_csrWen);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(io_pplIn_valid & !mem_access & io_dbg_wb_commit);
			cover(io_pplIn_valid & mem_access & !io_mem_valid);
			cover(io_pplIn_valid & mem_access & mem_fire & !mem_error);
			cover(mem_error);
			cover(io_flush & io_pplIn_valid);
			cover(io_pplIn_valid & io_pplIn_bits_isTrap & io_toExcp_excp_valid);
			cover(io_pplIn_valid & io_pplIn_bits_privInstr[3] & io_toExcp_cmt_ecall);
			cover(io_pplIn_valid & io_pplIn_bits_privInstr[1] & io_toExcp_cmt_mret);
		end
	end

endmodule
