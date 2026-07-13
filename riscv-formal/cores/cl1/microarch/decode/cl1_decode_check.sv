module cl1_decode_check(input clock);
	(* anyseq *) reg [31:0] dec_inst;
	(* anyseq *) reg [15:0] rvc_inst;

	wire [4:0] dec_imm_type;
	wire [9:0] dec_alu_op;
	wire [3:0] dec_a_sel;
	wire [3:0] dec_b_sel;
	wire [8:0] dec_j_type;
	wire [3:0] dec_mem_type;
	wire [1:0] dec_wb_type;
	wire       dec_wb_wen;
	wire [3:0] dec_csr_type;
	wire [4:0] dec_muldiv_op;
	wire       dec_illegal;
	wire       dec_fencei;

	wire [31:0] rvc_out;
	wire        rvc_illegal;

	Cl2Decoder decoder (
		.io_inst(dec_inst),
		.io_out_immType(dec_imm_type),
		.io_out_aluOp(dec_alu_op),
		.io_out_aSel(dec_a_sel),
		.io_out_bSel(dec_b_sel),
		.io_out_jType(dec_j_type),
		.io_out_memType(dec_mem_type),
		.io_out_wbType(dec_wb_type),
		.io_out_wbWen(dec_wb_wen),
		.io_out_csrType(dec_csr_type),
		.io_out_muldivOp(dec_muldiv_op),
		.io_out_illegal(dec_illegal),
		.io_out_fencei(dec_fencei)
	);

	Cl1RVCExpander rvc (
		.io_inst(rvc_inst),
		.io_out(rvc_out),
		.io_illegal(rvc_illegal)
	);

	localparam [4:0] IMM_U = 5'b10000;
	localparam [4:0] IMM_I = 5'b01000;
	localparam [4:0] IMM_B = 5'b00100;
	localparam [4:0] IMM_S = 5'b00010;
	localparam [4:0] IMM_J = 5'b00001;

	localparam [3:0] ASEL_REG    = 4'b0001;
	localparam [3:0] ASEL_PC     = 4'b0010;
	localparam [3:0] ASEL_CSRIMM = 4'b0100;
	localparam [3:0] ASEL_Z      = 4'b1000;

	localparam [3:0] BSEL_IMM  = 4'b0001;
	localparam [3:0] BSEL_REG  = 4'b0010;
	localparam [3:0] BSEL_CSR  = 4'b0100;
	localparam [3:0] BSEL_FOUR = 4'b1000;

	localparam [9:0] ALU_ADD  = 10'b1000000000;
	localparam [9:0] ALU_SUB  = 10'b0100000000;
	localparam [9:0] ALU_AND  = 10'b0010000000;
	localparam [9:0] ALU_OR   = 10'b0001000000;
	localparam [9:0] ALU_XOR  = 10'b0000100000;
	localparam [9:0] ALU_SLL  = 10'b0000010000;
	localparam [9:0] ALU_SLT  = 10'b0000001000;
	localparam [9:0] ALU_SLTU = 10'b0000000100;
	localparam [9:0] ALU_SRL  = 10'b0000000010;
	localparam [9:0] ALU_SRA  = 10'b0000000001;

	localparam [8:0] J_JAL  = 9'b100000000;
	localparam [8:0] J_EQ   = 9'b010000000;
	localparam [8:0] J_NE   = 9'b001000000;
	localparam [8:0] J_GE   = 9'b000100000;
	localparam [8:0] J_GEU  = 9'b000010000;
	localparam [8:0] J_LT   = 9'b000001000;
	localparam [8:0] J_LTU  = 9'b000000100;
	localparam [8:0] J_JALR = 9'b000000010;
	localparam [8:0] J_XXX  = 9'b000000001;

	localparam [3:0] MEM_XXX = 4'b0000;
	localparam [3:0] MEM_SB  = 4'b1010;
	localparam [3:0] MEM_SH  = 4'b1100;
	localparam [3:0] MEM_SW  = 4'b1110;
	localparam [3:0] MEM_LB  = 4'b0010;
	localparam [3:0] MEM_LBU = 4'b0011;
	localparam [3:0] MEM_LH  = 4'b0100;
	localparam [3:0] MEM_LHU = 4'b0101;
	localparam [3:0] MEM_LW  = 4'b0110;

	localparam [1:0] WB_ALU = 2'b00;
	localparam [1:0] WB_MEM = 2'b10;

	localparam [3:0] CSR_N   = 4'b0000;
	localparam [3:0] CSR_RW  = 4'b0001;
	localparam [3:0] CSR_RS  = 4'b0010;
	localparam [3:0] CSR_RC  = 4'b0100;
	localparam [3:0] CSR_RWI = 4'b1001;
	localparam [3:0] CSR_RSI = 4'b1010;
	localparam [3:0] CSR_RCI = 4'b1100;

	localparam [4:0] MD_NONE   = 5'b00000;
	localparam [4:0] MD_MUL    = 5'b00001;
	localparam [4:0] MD_MULH   = 5'b00010;
	localparam [4:0] MD_MULHSU = 5'b00100;
	localparam [4:0] MD_MULHU  = 5'b01000;
	localparam [4:0] MD_DIV    = 5'b10001;
	localparam [4:0] MD_DIVU   = 5'b10100;
	localparam [4:0] MD_REM    = 5'b10010;
	localparam [4:0] MD_REMU   = 5'b11000;

	localparam [6:0] OPC_LOAD   = 7'b0000011;
	localparam [6:0] OPC_FENCE  = 7'b0001111;
	localparam [6:0] OPC_OP_IMM = 7'b0010011;
	localparam [6:0] OPC_AUIPC  = 7'b0010111;
	localparam [6:0] OPC_STORE  = 7'b0100011;
	localparam [6:0] OPC_OP     = 7'b0110011;
	localparam [6:0] OPC_LUI    = 7'b0110111;
	localparam [6:0] OPC_BRANCH = 7'b1100011;
	localparam [6:0] OPC_JALR   = 7'b1100111;
	localparam [6:0] OPC_JAL    = 7'b1101111;
	localparam [6:0] OPC_SYSTEM = 7'b1110011;

	wire [6:0] opcode = dec_inst[6:0];
	wire [2:0] funct3 = dec_inst[14:12];
	wire [6:0] funct7 = dec_inst[31:25];

	function automatic valid_load_funct3;
		input [2:0] f3;
		begin
			case (f3)
			3'b000, 3'b001, 3'b010, 3'b100, 3'b101:
				valid_load_funct3 = 1'b1;
			default:
				valid_load_funct3 = 1'b0;
			endcase
		end
	endfunction

	function automatic valid_store_funct3;
		input [2:0] f3;
		begin
			case (f3)
			3'b000, 3'b001, 3'b010:
				valid_store_funct3 = 1'b1;
			default:
				valid_store_funct3 = 1'b0;
			endcase
		end
	endfunction

	function automatic valid_branch_funct3;
		input [2:0] f3;
		begin
			case (f3)
			3'b000, 3'b001, 3'b100, 3'b101, 3'b110, 3'b111:
				valid_branch_funct3 = 1'b1;
			default:
				valid_branch_funct3 = 1'b0;
			endcase
		end
	endfunction

	function automatic valid_op_imm;
		input [2:0] f3;
		input [6:0] f7;
		begin
			case (f3)
			3'b000, 3'b010, 3'b011, 3'b100, 3'b110, 3'b111:
				valid_op_imm = 1'b1;
			3'b001:
				valid_op_imm = f7 == 7'b0000000;
			3'b101:
				valid_op_imm = f7 == 7'b0000000 || f7 == 7'b0100000;
			default:
				valid_op_imm = 1'b0;
			endcase
		end
	endfunction

	function automatic valid_op;
		input [2:0] f3;
		input [6:0] f7;
		begin
			valid_op = f7 == 7'b0000001 ||
				(f7 == 7'b0000000) ||
				(f7 == 7'b0100000 && (f3 == 3'b000 || f3 == 3'b101));
		end
	endfunction

	function automatic valid_csr_funct3;
		input [2:0] f3;
		begin
			case (f3)
			3'b001, 3'b010, 3'b011, 3'b101, 3'b110, 3'b111:
				valid_csr_funct3 = 1'b1;
			default:
				valid_csr_funct3 = 1'b0;
			endcase
		end
	endfunction

	function automatic [3:0] load_mem_type;
		input [2:0] f3;
		begin
			case (f3)
			3'b000: load_mem_type = MEM_LB;
			3'b001: load_mem_type = MEM_LH;
			3'b010: load_mem_type = MEM_LW;
			3'b100: load_mem_type = MEM_LBU;
			3'b101: load_mem_type = MEM_LHU;
			default: load_mem_type = MEM_XXX;
			endcase
		end
	endfunction

	function automatic [3:0] store_mem_type;
		input [2:0] f3;
		begin
			case (f3)
			3'b000: store_mem_type = MEM_SB;
			3'b001: store_mem_type = MEM_SH;
			3'b010: store_mem_type = MEM_SW;
			default: store_mem_type = MEM_XXX;
			endcase
		end
	endfunction

	function automatic [8:0] branch_type;
		input [2:0] f3;
		begin
			case (f3)
			3'b000: branch_type = J_EQ;
			3'b001: branch_type = J_NE;
			3'b100: branch_type = J_LT;
			3'b101: branch_type = J_GE;
			3'b110: branch_type = J_LTU;
			3'b111: branch_type = J_GEU;
			default: branch_type = J_XXX;
			endcase
		end
	endfunction

	function automatic [9:0] branch_alu_op;
		input [2:0] f3;
		begin
			branch_alu_op =
				(f3 == 3'b110 || f3 == 3'b111) ? ALU_SLTU : ALU_SUB;
		end
	endfunction

	function automatic [9:0] op_imm_alu_op;
		input [2:0] f3;
		input [6:0] f7;
		begin
			case (f3)
			3'b010: op_imm_alu_op = ALU_SLT;
			3'b011: op_imm_alu_op = ALU_SLTU;
			3'b100: op_imm_alu_op = ALU_XOR;
			3'b110: op_imm_alu_op = ALU_OR;
			3'b111: op_imm_alu_op = ALU_AND;
			3'b001: op_imm_alu_op = ALU_SLL;
			3'b101: op_imm_alu_op = f7 == 7'b0100000 ? ALU_SRA : ALU_SRL;
			default: op_imm_alu_op = ALU_ADD;
			endcase
		end
	endfunction

	function automatic [9:0] op_alu_op;
		input [2:0] f3;
		input [6:0] f7;
		begin
			case (f3)
			3'b000: op_alu_op = f7 == 7'b0100000 ? ALU_SUB : ALU_ADD;
			3'b001: op_alu_op = ALU_SLL;
			3'b010: op_alu_op = ALU_SLT;
			3'b011: op_alu_op = ALU_SLTU;
			3'b100: op_alu_op = ALU_XOR;
			3'b101: op_alu_op = f7 == 7'b0100000 ? ALU_SRA : ALU_SRL;
			3'b110: op_alu_op = ALU_OR;
			default: op_alu_op = ALU_AND;
			endcase
		end
	endfunction

	function automatic [4:0] muldiv_op;
		input [2:0] f3;
		begin
			case (f3)
			3'b000: muldiv_op = MD_MUL;
			3'b001: muldiv_op = MD_MULH;
			3'b010: muldiv_op = MD_MULHSU;
			3'b011: muldiv_op = MD_MULHU;
			3'b100: muldiv_op = MD_DIV;
			3'b101: muldiv_op = MD_DIVU;
			3'b110: muldiv_op = MD_REM;
			default: muldiv_op = MD_REMU;
			endcase
		end
	endfunction

	function automatic [3:0] csr_type;
		input [2:0] f3;
		begin
			case (f3)
			3'b001: csr_type = CSR_RW;
			3'b010: csr_type = CSR_RS;
			3'b011: csr_type = CSR_RC;
			3'b101: csr_type = CSR_RWI;
			3'b110: csr_type = CSR_RSI;
			default: csr_type = CSR_RCI;
			endcase
		end
	endfunction

	function automatic [9:0] csr_alu_op;
		input [2:0] f3;
		begin
			case (f3)
			3'b010, 3'b110: csr_alu_op = ALU_OR;
			3'b011, 3'b111: csr_alu_op = ALU_AND;
			default: csr_alu_op = ALU_ADD;
			endcase
		end
	endfunction

	task automatic expect_common_no_mem_no_csr;
		begin
			assert(dec_mem_type == MEM_XXX);
			assert(dec_csr_type == CSR_N);
			assert(dec_muldiv_op == MD_NONE);
			assert(!dec_fencei);
		end
	endtask

	task automatic expect_common_alu_wb;
		begin
			assert(dec_wb_type == WB_ALU);
			assert(dec_wb_wen);
		end
	endtask

	always @(posedge clock) begin
		if (opcode == OPC_LOAD && valid_load_funct3(funct3)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_alu_op == ALU_ADD);
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_IMM);
			assert(dec_j_type == J_XXX);
			assert(dec_mem_type == load_mem_type(funct3));
			assert(dec_wb_type == WB_MEM);
			assert(dec_wb_wen);
			assert(dec_csr_type == CSR_N);
			assert(dec_muldiv_op == MD_NONE);
			assert(!dec_fencei);
		end

		if (opcode == OPC_STORE && valid_store_funct3(funct3)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_S);
			assert(dec_alu_op == ALU_ADD);
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_IMM);
			assert(dec_j_type == J_XXX);
			assert(dec_mem_type == store_mem_type(funct3));
			assert(dec_wb_type == WB_ALU);
			assert(!dec_wb_wen);
			assert(dec_csr_type == CSR_N);
			assert(dec_muldiv_op == MD_NONE);
			assert(!dec_fencei);
		end

		if (opcode == OPC_BRANCH && valid_branch_funct3(funct3)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_B);
			assert(dec_alu_op == branch_alu_op(funct3));
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_REG);
			assert(dec_j_type == branch_type(funct3));
			assert(dec_mem_type == MEM_XXX);
			assert(dec_wb_type == WB_ALU);
			assert(!dec_wb_wen);
			assert(dec_csr_type == CSR_N);
			assert(dec_muldiv_op == MD_NONE);
			assert(!dec_fencei);
		end

		if (opcode == OPC_JAL) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_J);
			assert(dec_alu_op == ALU_ADD);
			assert(dec_a_sel == ASEL_PC);
			assert(dec_b_sel == BSEL_FOUR);
			assert(dec_j_type == J_JAL);
			expect_common_no_mem_no_csr();
			expect_common_alu_wb();
		end

		if (opcode == OPC_JALR && funct3 == 3'b000) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_alu_op == ALU_ADD);
			assert(dec_a_sel == ASEL_PC);
			assert(dec_b_sel == BSEL_FOUR);
			assert(dec_j_type == J_JALR);
			expect_common_no_mem_no_csr();
			expect_common_alu_wb();
		end

		if (opcode == OPC_LUI || opcode == OPC_AUIPC) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_U);
			assert(dec_alu_op == ALU_ADD);
			assert(dec_a_sel == (opcode == OPC_AUIPC ? ASEL_PC : ASEL_Z));
			assert(dec_b_sel == BSEL_IMM);
			assert(dec_j_type == J_XXX);
			expect_common_no_mem_no_csr();
			expect_common_alu_wb();
		end

		if (opcode == OPC_OP_IMM && valid_op_imm(funct3, funct7)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_alu_op == op_imm_alu_op(funct3, funct7));
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_IMM);
			assert(dec_j_type == J_XXX);
			expect_common_no_mem_no_csr();
			expect_common_alu_wb();
		end

		if (opcode == OPC_OP && valid_op(funct3, funct7)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_REG);
			assert(dec_j_type == J_XXX);
			assert(dec_mem_type == MEM_XXX);
			assert(dec_wb_type == WB_ALU);
			assert(dec_wb_wen);
			assert(dec_csr_type == CSR_N);
			assert(!dec_fencei);
			if (funct7 == 7'b0000001) begin
				assert(dec_alu_op == ALU_ADD);
				assert(dec_muldiv_op == muldiv_op(funct3));
			end else begin
				assert(dec_alu_op == op_alu_op(funct3, funct7));
				assert(dec_muldiv_op == MD_NONE);
			end
		end

		if (opcode == OPC_SYSTEM && valid_csr_funct3(funct3)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_alu_op == csr_alu_op(funct3));
			assert(dec_a_sel == (funct3[2] ? ASEL_CSRIMM : ASEL_REG));
			assert(dec_b_sel == BSEL_CSR);
			assert(dec_j_type == J_XXX);
			assert(dec_mem_type == MEM_XXX);
			assert(dec_wb_wen);
			assert(dec_csr_type == csr_type(funct3));
			assert(dec_muldiv_op == MD_NONE);
			assert(!dec_fencei);
		end

		if (opcode == OPC_FENCE && (funct3 == 3'b000 || funct3 == 3'b001)) begin
			assert(!dec_illegal);
			assert(dec_imm_type == IMM_I);
			assert(dec_a_sel == ASEL_REG);
			assert(dec_b_sel == BSEL_REG);
			assert(dec_j_type == J_XXX);
			assert(dec_mem_type == MEM_XXX);
			assert(dec_wb_type == WB_ALU);
			assert(!dec_wb_wen);
			assert(dec_csr_type == CSR_N);
			assert(dec_muldiv_op == MD_NONE);
			assert(dec_fencei == (funct3 == 3'b001));
		end

		if (opcode == OPC_LOAD && !valid_load_funct3(funct3))
			assert(dec_illegal);
		if (opcode == OPC_STORE && !valid_store_funct3(funct3))
			assert(dec_illegal);
		if (opcode == OPC_BRANCH && !valid_branch_funct3(funct3))
			assert(dec_illegal);
		if (opcode == OPC_JALR && funct3 != 3'b000)
			assert(dec_illegal);
		if (opcode == OPC_OP_IMM && !valid_op_imm(funct3, funct7))
			assert(dec_illegal);
		if (opcode == OPC_OP && !valid_op(funct3, funct7))
			assert(dec_illegal);
		if (opcode == OPC_SYSTEM && funct3 == 3'b100)
			assert(dec_illegal);
		if (opcode == OPC_FENCE && !(funct3 == 3'b000 || funct3 == 3'b001))
			assert(dec_illegal);
	end

	wire [2:0] rvc_funct3 = rvc_inst[15:13];
	wire [1:0] rvc_quad = rvc_inst[1:0];
	wire [4:0] rvc_rd = rvc_inst[11:7];
	wire [4:0] rvc_rs2 = rvc_inst[6:2];
	wire [4:0] rvc_rs1p = {2'b01, rvc_inst[9:7]};
	wire [4:0] rvc_rs2p = {2'b01, rvc_inst[4:2]};
	wire [11:0] rvc_addi_imm = {{7{rvc_inst[12]}}, rvc_inst[6:2]};
	wire [11:0] rvc_lw_imm =
		{5'b00000, rvc_inst[5], rvc_inst[12:10], rvc_inst[6], 2'b00};
	wire [11:0] rvc_lwsp_imm =
		{4'b0000, rvc_inst[3:2], rvc_inst[12], rvc_inst[6:4], 2'b00};
	wire [11:0] rvc_addi4spn_imm =
		{2'b00, rvc_inst[10:7], rvc_inst[12:11],
		 rvc_inst[5], rvc_inst[6], 2'b00};
	wire [11:0] rvc_addi16sp_imm =
		{{3{rvc_inst[12]}}, rvc_inst[4:3], rvc_inst[5],
		 rvc_inst[2], rvc_inst[6], 4'b0000};
	wire [31:0] rvc_lui_imm =
		{{15{rvc_inst[12]}}, rvc_inst[6:2], 12'b0};
	wire rvc_nzimm = rvc_inst[12] | (|rvc_inst[6:2]);
	wire rvc_arith_illegal =
		(rvc_inst[12] & ~rvc_inst[11]) | (&rvc_inst[12:10]);

	always @(posedge clock) begin
		if (rvc_quad == 2'b11) begin
			assert(rvc_illegal);
			assert(rvc_out == {16'h0000, rvc_inst});
		end

		if (rvc_quad == 2'b00 && rvc_funct3 == 3'b000) begin
			assert(rvc_illegal == !(|rvc_inst[12:5]));
			if (|rvc_inst[12:5]) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rs2p);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == 5'd2);
				assert(rvc_out[31:20] == rvc_addi4spn_imm);
			end
		end

		if (rvc_quad == 2'b00 && rvc_funct3 == 3'b010) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_LOAD);
			assert(rvc_out[11:7] == rvc_rs2p);
			assert(rvc_out[14:12] == 3'b010);
			assert(rvc_out[19:15] == rvc_rs1p);
			assert(rvc_out[31:20] == rvc_lw_imm);
		end

		if (rvc_quad == 2'b00 && rvc_funct3 == 3'b110) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_STORE);
			assert(rvc_out[14:12] == 3'b010);
			assert(rvc_out[19:15] == rvc_rs1p);
			assert(rvc_out[24:20] == rvc_rs2p);
			assert({rvc_out[31:25], rvc_out[11:7]} == rvc_lw_imm);
		end

		if (rvc_quad == 2'b00 &&
		    (rvc_funct3 == 3'b001 || rvc_funct3 == 3'b011 ||
		     rvc_funct3 == 3'b100 || rvc_funct3 == 3'b101 ||
		     rvc_funct3 == 3'b111)) begin
			assert(rvc_illegal);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b000) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_OP_IMM);
			assert(rvc_out[11:7] == rvc_rd);
			assert(rvc_out[14:12] == 3'b000);
			assert(rvc_out[19:15] == rvc_rd);
			assert(rvc_out[31:20] == rvc_addi_imm);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b001) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_JAL);
			assert(rvc_out[11:7] == 5'd1);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b010) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_OP_IMM);
			assert(rvc_out[11:7] == rvc_rd);
			assert(rvc_out[14:12] == 3'b000);
			assert(rvc_out[19:15] == 5'd0);
			assert(rvc_out[31:20] == rvc_addi_imm);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b011) begin
			assert(rvc_illegal == !rvc_nzimm);
			if (rvc_nzimm && (rvc_rd == 5'd0 || rvc_rd == 5'd2)) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == rvc_rd);
				assert(rvc_out[31:20] == rvc_addi16sp_imm);
			end
			if (rvc_nzimm && rvc_rd != 5'd0 && rvc_rd != 5'd2) begin
				assert(rvc_out[6:0] == OPC_LUI);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[31:12] == rvc_lui_imm[31:12]);
			end
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b100) begin
			assert(rvc_illegal == rvc_arith_illegal);
			if (!rvc_arith_illegal && rvc_inst[11:10] == 2'b00) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rs1p);
				assert(rvc_out[14:12] == 3'b101);
				assert(rvc_out[19:15] == rvc_rs1p);
				assert(rvc_out[24:20] == rvc_inst[6:2]);
				assert(rvc_out[31:25] == 7'b0000000);
			end
			if (!rvc_arith_illegal && rvc_inst[11:10] == 2'b01) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rs1p);
				assert(rvc_out[14:12] == 3'b101);
				assert(rvc_out[19:15] == rvc_rs1p);
				assert(rvc_out[24:20] == rvc_inst[6:2]);
				assert(rvc_out[31:25] == 7'b0100000);
			end
			if (!rvc_arith_illegal && rvc_inst[11:10] == 2'b10) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rs1p);
				assert(rvc_out[14:12] == 3'b111);
				assert(rvc_out[19:15] == rvc_rs1p);
				assert(rvc_out[31:20] == rvc_addi_imm);
			end
			if (!rvc_arith_illegal && rvc_inst[11:10] == 2'b11) begin
				assert(rvc_out[6:0] == OPC_OP);
				assert(rvc_out[11:7] == rvc_rs1p);
				assert(rvc_out[19:15] == rvc_rs1p);
				assert(rvc_out[24:20] == rvc_rs2p);
				assert(rvc_out[31:25] ==
					(rvc_inst[6:5] == 2'b00 ? 7'b0100000 : 7'b0000000));
				case (rvc_inst[6:5])
				2'b00: assert(rvc_out[14:12] == 3'b000);
				2'b01: assert(rvc_out[14:12] == 3'b100);
				2'b10: assert(rvc_out[14:12] == 3'b110);
				2'b11: assert(rvc_out[14:12] == 3'b111);
				endcase
			end
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b101) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_JAL);
			assert(rvc_out[11:7] == 5'd0);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b110) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_BRANCH);
			assert(rvc_out[14:12] == 3'b000);
			assert(rvc_out[19:15] == rvc_rs1p);
			assert(rvc_out[24:20] == 5'd0);
		end

		if (rvc_quad == 2'b01 && rvc_funct3 == 3'b111) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_BRANCH);
			assert(rvc_out[14:12] == 3'b001);
			assert(rvc_out[19:15] == rvc_rs1p);
			assert(rvc_out[24:20] == 5'd0);
		end

		if (rvc_quad == 2'b10 && rvc_funct3 == 3'b000) begin
			assert(rvc_illegal == rvc_inst[12]);
			if (!rvc_inst[12]) begin
				assert(rvc_out[6:0] == OPC_OP_IMM);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[14:12] == 3'b001);
				assert(rvc_out[19:15] == rvc_rd);
				assert(rvc_out[24:20] == rvc_inst[6:2]);
				assert(rvc_out[31:25] == 7'b0000000);
			end
		end

		if (rvc_quad == 2'b10 && rvc_funct3 == 3'b010) begin
			assert(rvc_illegal == (rvc_rd == 5'd0));
			if (rvc_rd != 5'd0) begin
				assert(rvc_out[6:0] == OPC_LOAD);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[14:12] == 3'b010);
				assert(rvc_out[19:15] == 5'd2);
				assert(rvc_out[31:20] == rvc_lwsp_imm);
			end
		end

		if (rvc_quad == 2'b10 && rvc_funct3 == 3'b100) begin
			assert(rvc_illegal == (rvc_inst[12:2] == 11'h000));
			if (!rvc_inst[12] && rvc_rs2 != 5'd0) begin
				assert(rvc_out[6:0] == OPC_OP);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == 5'd0);
				assert(rvc_out[24:20] == rvc_rs2);
				assert(rvc_out[31:25] == 7'b0000000);
			end
			if (!rvc_inst[12] && rvc_rs2 == 5'd0 && rvc_rd != 5'd0) begin
				assert(rvc_out[6:0] == OPC_JALR);
				assert(rvc_out[11:7] == 5'd0);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == rvc_rd);
				assert(rvc_out[31:20] == 12'h000);
			end
			if (rvc_inst[12] && rvc_rs2 != 5'd0) begin
				assert(rvc_out[6:0] == OPC_OP);
				assert(rvc_out[11:7] == rvc_rd);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == rvc_rd);
				assert(rvc_out[24:20] == rvc_rs2);
				assert(rvc_out[31:25] == 7'b0000000);
			end
			if (rvc_inst[12] && rvc_rs2 == 5'd0 && rvc_rd != 5'd0) begin
				assert(rvc_out[6:0] == OPC_JALR);
				assert(rvc_out[11:7] == 5'd1);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == rvc_rd);
				assert(rvc_out[31:20] == 12'h000);
			end
			if (rvc_inst[12] && rvc_rs2 == 5'd0 && rvc_rd == 5'd0) begin
				assert(!rvc_illegal);
				assert(rvc_out[6:0] == OPC_SYSTEM);
				assert(rvc_out[11:7] == 5'd0);
				assert(rvc_out[14:12] == 3'b000);
				assert(rvc_out[19:15] == 5'd0);
				assert(rvc_out[31:20] == 12'h001);
			end
		end

		if (rvc_quad == 2'b10 && rvc_funct3 == 3'b110) begin
			assert(!rvc_illegal);
			assert(rvc_out[6:0] == OPC_STORE);
			assert(rvc_out[14:12] == 3'b010);
			assert(rvc_out[19:15] == 5'd2);
			assert(rvc_out[24:20] == rvc_rs2);
			assert(rvc_out[31:28] == 4'h0);
			assert(rvc_out[27:26] == rvc_inst[8:7]);
			assert(rvc_out[25] == rvc_inst[12]);
			assert(rvc_out[11:9] == rvc_inst[11:9]);
			assert(rvc_out[8:7] == 2'b00);
		end

		if (rvc_quad == 2'b10 &&
		    (rvc_funct3 == 3'b001 || rvc_funct3 == 3'b011 ||
		     rvc_funct3 == 3'b101 || rvc_funct3 == 3'b111)) begin
			assert(rvc_illegal);
		end
	end

	always @(posedge clock) begin
		cover(opcode == OPC_LOAD && valid_load_funct3(funct3));
		cover(opcode == OPC_STORE && valid_store_funct3(funct3));
		cover(opcode == OPC_BRANCH && valid_branch_funct3(funct3));
		cover(opcode == OPC_OP && funct7 == 7'b0000001);
		cover(opcode == OPC_SYSTEM && valid_csr_funct3(funct3));
		cover(rvc_quad == 2'b00 && rvc_funct3 == 3'b010);
		cover(rvc_quad == 2'b01 && rvc_funct3 == 3'b101);
		cover(rvc_quad == 2'b01 && rvc_funct3 == 3'b011 && rvc_nzimm);
		cover(rvc_quad == 2'b01 && rvc_funct3 == 3'b100 &&
			!rvc_arith_illegal && rvc_inst[11:10] == 2'b11);
		cover(rvc_quad == 2'b10 && rvc_funct3 == 3'b100 &&
			rvc_inst[12] && rvc_rs2 == 5'd0 && rvc_rd == 5'd0);
		cover(rvc_quad == 2'b10 && rvc_funct3 == 3'b010 && rvc_rd != 5'd0);
	end
endmodule
