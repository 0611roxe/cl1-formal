module cl1_alu_check(input clock);
	(* anyseq *) reg [31:0] alu_a;
	(* anyseq *) reg [31:0] alu_b;
	(* anyseq *) reg [9:0]  alu_op;

	wire [31:0] alu_res;
	wire        alu_eq;
	wire        alu_lt;

	Cl1ALU dut (
		.io_misc_req_a(alu_a),
		.io_misc_req_b(alu_b),
		.io_misc_req_op(alu_op),
		.io_misc_req_res(alu_res),
		.io_misc_req_eq(alu_eq),
		.io_misc_req_lt(alu_lt)
	);

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

	wire [4:0] shamt = alu_b[4:0];
	wire signed [31:0] alu_a_signed = alu_a;
	wire signed [31:0] alu_b_signed = alu_b;
	wire [31:0] expected_sra = alu_a_signed >>> shamt;

	function automatic legal_onehot_op;
		input [9:0] op;
		begin
			case (op)
			ALU_ADD, ALU_SUB, ALU_AND, ALU_OR, ALU_XOR,
			ALU_SLL, ALU_SLT, ALU_SLTU, ALU_SRL, ALU_SRA:
				legal_onehot_op = 1'b1;
			default:
				legal_onehot_op = 1'b0;
			endcase
		end
	endfunction

	function automatic [31:0] expected_result;
		input [31:0] a;
		input [31:0] b;
		input [9:0]  op;
		begin
			case (op)
			ALU_ADD:  expected_result = a + b;
			ALU_SUB:  expected_result = a - b;
			ALU_AND:  expected_result = a & b;
			ALU_OR:   expected_result = a | b;
			ALU_XOR:  expected_result = a ^ b;
			ALU_SLL:  expected_result = a << b[4:0];
			ALU_SLT:  expected_result = {31'b0, $signed(a) < $signed(b)};
			ALU_SLTU: expected_result = {31'b0, a < b};
			ALU_SRL:  expected_result = a >> b[4:0];
			ALU_SRA:  expected_result = $signed(a) >>> b[4:0];
			default:   expected_result = 32'h0;
			endcase
		end
	endfunction

	always @(posedge clock) begin
		assert(alu_eq == (alu_a == alu_b));

		if (alu_op == ALU_SUB || alu_op == ALU_SLT)
			assert(alu_lt == (alu_a_signed < alu_b_signed));

		if (alu_op == ALU_SLTU)
			assert(alu_lt == (alu_a < alu_b));

		if (legal_onehot_op(alu_op))
			assert(alu_res == expected_result(alu_a, alu_b, alu_op));
	end

	always @(posedge clock) begin
		cover(alu_op == ALU_ADD);
		cover(alu_op == ALU_SUB);
		cover(alu_op == ALU_SLT && alu_a_signed < alu_b_signed);
		cover(alu_op == ALU_SLTU && alu_a < alu_b);
		cover(alu_op == ALU_SLL && shamt != 5'd0);
		cover(alu_op == ALU_SRA && alu_a[31] && shamt != 5'd0);
	end
endmodule
