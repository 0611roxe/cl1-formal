`ifdef MDU_REAL_DIVREM_SIGNED_FULL
`define MDU_REAL_DIVREM_FULL
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_DIVREM_UNSIGNED_FULL
`define MDU_REAL_DIVREM_FULL
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_FULL_MUL_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_BOOTH_RECODE_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_SCALED_STEP_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_DIV_STEP_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_DIV_QUOTIENT_RECODE_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_PROTOCOL_CHECK
`define MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_STRICT_MUL_CHECK
`define MDU_REAL_MUL_REFERENCE_ONLY
`endif
`ifdef MDU_REAL_SCALED_RANGE_CHECK
`define MDU_REAL_MUL_REFERENCE_ONLY
`endif
`ifdef MDU_REAL_SCALED_EQUIV_CHECK
`define MDU_REAL_MUL_REFERENCE_ONLY
`endif
`ifdef MDU_REAL_DIV_INVARIANT_CHECK
`define MDU_REAL_DIV_REFERENCE_ONLY
`endif
`ifdef MDU_REAL_DIV_RANGE_CHECK
`define MDU_REAL_DIV_REFERENCE_ONLY
`endif

`ifndef MDU_REAL_SPECIALIZED_FULL
module cl1_mdu_real_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire reset = !past_valid;

	(* anyseq *) reg [31:0] any_rs1;
	(* anyseq *) reg [31:0] any_rs2;
	(* anyseq *) reg [3:0]  any_op;

	reg        issued = 1'b0;
	reg        active = 1'b0;
	reg        done = 1'b0;
	reg [5:0]  wait_count = 6'h0;
	reg [31:0] tracked_rs1 = 32'h0;
	reg [31:0] tracked_rs2 = 32'h0;
	reg [3:0]  tracked_op = 4'h0;
	reg        tracked_is_div = 1'b0;

	wire issue_now = !reset && !issued;

`ifdef MDU_REAL_MUL
	localparam        CHECK_IS_DIV = 1'b0;
	localparam [3:0]  CHECK_OP = 4'b0001;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b0;
	localparam [5:0]  MAX_LATENCY = 6'd22;
`elsif MDU_REAL_MULH
	localparam        CHECK_IS_DIV = 1'b0;
	localparam [3:0]  CHECK_OP = 4'b0010;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b0;
	localparam [5:0]  MAX_LATENCY = 6'd22;
`elsif MDU_REAL_MULHSU
	localparam        CHECK_IS_DIV = 1'b0;
	localparam [3:0]  CHECK_OP = 4'b0100;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b0;
	localparam [5:0]  MAX_LATENCY = 6'd22;
`elsif MDU_REAL_MULHU
	localparam        CHECK_IS_DIV = 1'b0;
	localparam [3:0]  CHECK_OP = 4'b1000;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b0;
	localparam [5:0]  MAX_LATENCY = 6'd22;
`elsif MDU_REAL_DIV
	localparam        CHECK_IS_DIV = 1'b1;
	localparam [3:0]  CHECK_OP = 4'b0001;
	localparam        CHECK_SIGNED_DIV = 1'b1;
	localparam        CHECK_NORMAL_DIV = 1'b1;
	localparam [5:0]  MAX_LATENCY = 6'd40;
`elsif MDU_REAL_REM
	localparam        CHECK_IS_DIV = 1'b1;
	localparam [3:0]  CHECK_OP = 4'b0010;
	localparam        CHECK_SIGNED_DIV = 1'b1;
	localparam        CHECK_NORMAL_DIV = 1'b1;
	localparam [5:0]  MAX_LATENCY = 6'd40;
`elsif MDU_REAL_DIVU
	localparam        CHECK_IS_DIV = 1'b1;
	localparam [3:0]  CHECK_OP = 4'b0100;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b1;
	localparam [5:0]  MAX_LATENCY = 6'd40;
`elsif MDU_REAL_REMU
	localparam        CHECK_IS_DIV = 1'b1;
	localparam [3:0]  CHECK_OP = 4'b1000;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b1;
	localparam [5:0]  MAX_LATENCY = 6'd40;
`elsif MDU_REAL_SPECIAL_COVER
	localparam        CHECK_IS_DIV = 1'b1;
	localparam [3:0]  CHECK_OP = 4'b0001;
	localparam        CHECK_SIGNED_DIV = 1'b0;
	localparam        CHECK_NORMAL_DIV = 1'b0;
	localparam [5:0]  MAX_LATENCY = 6'd40;
`else
	initial assert(1'b0);
`endif

	wire        io_in_valid;
	wire [31:0] io_in_bits_rs1;
	wire [31:0] io_in_bits_rs2;
	wire [3:0]  io_in_bits_op;
	wire        io_in_bits_is_div;
	wire        io_in_bits_flush = 1'b0;
	wire        io_out_ready = 1'b1;

	assign io_in_valid = issue_now;
	assign io_in_bits_rs1 = (issued && !done) ? tracked_rs1 : any_rs1;
	assign io_in_bits_rs2 = (issued && !done) ? tracked_rs2 : any_rs2;

`ifdef MDU_REAL_SPECIAL_COVER
	assign io_in_bits_op = any_op;
	assign io_in_bits_is_div = 1'b1;
`else
	assign io_in_bits_op = CHECK_OP;
	assign io_in_bits_is_div = CHECK_IS_DIV;
`endif

	wire [34:0] io_alu_req_op1;
	wire [34:0] io_alu_req_op2;
	wire        io_alu_req_sub;
	wire [34:0] io_alu_req_rslt =
		io_alu_req_op1 + ({35{io_alu_req_sub}} ^ io_alu_req_op2)
		+ {34'h0, io_alu_req_sub};
	wire        io_out_valid;
	wire [31:0] io_out_bits;

	CL1MDULp dut (
		.clock(clock),
		.reset(reset),
		.io_in_valid(io_in_valid),
		.io_in_bits_rs1(io_in_bits_rs1),
		.io_in_bits_rs2(io_in_bits_rs2),
		.io_in_bits_op(io_in_bits_op),
		.io_in_bits_is_div(io_in_bits_is_div),
		.io_in_bits_flush(io_in_bits_flush),
		.io_alu_req_op1(io_alu_req_op1),
		.io_alu_req_op2(io_alu_req_op2),
		.io_alu_req_sub(io_alu_req_sub),
		.io_alu_req_rslt(io_alu_req_rslt),
		.io_out_ready(io_out_ready),
		.io_out_valid(io_out_valid),
		.io_out_bits(io_out_bits)
	);

	function automatic legal_mdu_op;
		input [3:0] op;
		begin
			case (op)
			4'b0001, 4'b0010, 4'b0100, 4'b1000:
				legal_mdu_op = 1'b1;
			default:
				legal_mdu_op = 1'b0;
			endcase
		end
	endfunction

	function automatic [31:0] expected_result;
		input [31:0] rs1;
		input [31:0] rs2;
		input [3:0]  op;
		input        is_div;
`ifdef MDU_REAL_SMALL_OPERANDS
		reg signed [16:0] s16_rs1;
		reg signed [16:0] s16_rs2;
		reg signed [16:0] s16_q;
		reg signed [16:0] s16_r;
		reg [16:0]        u16_rs1;
		reg [16:0]        u16_rs2;
		reg [16:0]        u16_q;
		reg [16:0]        u16_r;
		reg signed [33:0] prod_ss_small;
		reg signed [33:0] prod_su_small;
		reg [33:0]        prod_uu_small;
`elsif MDU_REAL_MUL_TINY_OPERANDS
		reg signed [8:0]  s8_rs1;
		reg signed [8:0]  s8_rs2;
		reg [8:0]         u8_rs1;
		reg [8:0]         u8_rs2;
		reg signed [17:0] prod_ss_tiny;
		reg signed [17:0] prod_su_tiny;
		reg [17:0]        prod_uu_tiny;
`elsif MDU_REAL_DIV_TINY_OPERANDS
		reg signed [8:0]  s8_rs1;
		reg signed [8:0]  s8_rs2;
		reg signed [8:0]  s8_q;
		reg signed [8:0]  s8_r;
		reg [8:0]         u8_rs1;
		reg [8:0]         u8_rs2;
		reg [8:0]         u8_q;
		reg [8:0]         u8_r;
`else
		reg signed [31:0] s_rs1;
		reg signed [31:0] s_rs2;
		reg signed [63:0] prod_ss;
		reg signed [63:0] prod_su;
		reg [63:0]        prod_uu;
`endif
		begin
`ifdef MDU_REAL_SMALL_OPERANDS
			s16_rs1 = {rs1[15], rs1[15:0]};
			s16_rs2 = {rs2[15], rs2[15:0]};
			u16_rs1 = {1'b0, rs1[15:0]};
			u16_rs2 = {1'b0, rs2[15:0]};
`ifdef MDU_REAL_MUL
			prod_ss_small = s16_rs1 * s16_rs2;
			expected_result = prod_ss_small[31:0];
`elsif MDU_REAL_MULH
			prod_ss_small = s16_rs1 * s16_rs2;
			expected_result = {32{prod_ss_small[31]}};
`elsif MDU_REAL_MULHSU
			prod_su_small = s16_rs1 * $signed({1'b0, rs2[15:0]});
			expected_result = {32{prod_su_small[31]}};
`elsif MDU_REAL_MULHU
			prod_uu_small = u16_rs1 * u16_rs2;
			expected_result = 32'h0;
`elsif MDU_REAL_DIV
			s16_q = s16_rs1 / s16_rs2;
			expected_result = {{15{s16_q[16]}}, s16_q};
`elsif MDU_REAL_REM
			s16_r = s16_rs1 % s16_rs2;
			expected_result = {{15{s16_r[16]}}, s16_r};
`elsif MDU_REAL_DIVU
			u16_q = u16_rs1 / u16_rs2;
			expected_result = {15'h0, u16_q};
`elsif MDU_REAL_REMU
			u16_r = u16_rs1 % u16_rs2;
			expected_result = {15'h0, u16_r};
`else
			expected_result = 32'h0;
`endif
`else
`ifdef MDU_REAL_MUL_TINY_OPERANDS
			s8_rs1 = {rs1[7], rs1[7:0]};
			s8_rs2 = {rs2[7], rs2[7:0]};
			u8_rs1 = {1'b0, rs1[7:0]};
			u8_rs2 = {1'b0, rs2[7:0]};
`ifdef MDU_REAL_MUL
			prod_ss_tiny = s8_rs1 * s8_rs2;
			expected_result = {{14{prod_ss_tiny[17]}}, prod_ss_tiny};
`elsif MDU_REAL_MULH
			prod_ss_tiny = s8_rs1 * s8_rs2;
			expected_result = {32{prod_ss_tiny[17]}};
`elsif MDU_REAL_MULHSU
			prod_su_tiny = s8_rs1 * $signed({1'b0, rs2[7:0]});
			expected_result = {32{prod_su_tiny[17]}};
`elsif MDU_REAL_MULHU
			prod_uu_tiny = u8_rs1 * u8_rs2;
			expected_result = 32'h0;
`else
			expected_result = 32'h0;
`endif
`elsif MDU_REAL_DIV_TINY_OPERANDS
			s8_rs1 = {rs1[7], rs1[7:0]};
			s8_rs2 = {rs2[7], rs2[7:0]};
			u8_rs1 = {1'b0, rs1[7:0]};
			u8_rs2 = {1'b0, rs2[7:0]};
`ifdef MDU_REAL_DIV
			s8_q = s8_rs1 / s8_rs2;
			expected_result = {{23{s8_q[8]}}, s8_q};
`elsif MDU_REAL_REM
			s8_r = s8_rs1 % s8_rs2;
			expected_result = {{23{s8_r[8]}}, s8_r};
`elsif MDU_REAL_DIVU
			u8_q = u8_rs1 / u8_rs2;
			expected_result = {23'h0, u8_q};
`elsif MDU_REAL_REMU
			u8_r = u8_rs1 % u8_rs2;
			expected_result = {23'h0, u8_r};
`else
			expected_result = 32'h0;
`endif
`else
`ifdef MDU_REAL_MUL
			prod_uu = {32'h0, rs1} * {32'h0, rs2};
			expected_result = prod_uu[31:0];
`elsif MDU_REAL_MULH
			s_rs1 = rs1;
			s_rs2 = rs2;
			prod_ss = $signed({{32{rs1[31]}}, rs1})
				* $signed({{32{rs2[31]}}, rs2});
			expected_result = prod_ss[63:32];
`elsif MDU_REAL_MULHSU
			prod_su = $signed({{32{rs1[31]}}, rs1})
				* $signed({32'h0, rs2});
			expected_result = prod_su[63:32];
`elsif MDU_REAL_MULHU
			prod_uu = {32'h0, rs1} * {32'h0, rs2};
			expected_result = prod_uu[63:32];
`elsif MDU_REAL_DIV
			s_rs1 = rs1;
			s_rs2 = rs2;
			expected_result = s_rs1 / s_rs2;
`elsif MDU_REAL_REM
			s_rs1 = rs1;
			s_rs2 = rs2;
			expected_result = s_rs1 % s_rs2;
`elsif MDU_REAL_DIVU
			expected_result = rs1 / rs2;
`elsif MDU_REAL_REMU
			expected_result = rs1 % rs2;
`else
			expected_result = 32'h0;
`endif
`endif
`endif
		end
	endfunction

	wire [31:0] expected_out =
		expected_result(tracked_rs1, tracked_rs2, tracked_op, tracked_is_div);

	// CL1_MDU_ASSUMPTIONS_BEGIN interface
	always @* begin
`ifdef MDU_REAL_SPECIAL_COVER
		assume(legal_mdu_op(io_in_bits_op));
`else
`ifdef MDU_REAL_MUL_TINY_OPERANDS
		if (!CHECK_IS_DIV) begin
			if (CHECK_OP == 4'b0100) begin
				assume(io_in_bits_rs1[31:7] == {25{io_in_bits_rs1[7]}});
				assume(io_in_bits_rs2[31:8] == 24'h0);
			end else if (CHECK_OP == 4'b1000) begin
				assume(io_in_bits_rs1[31:8] == 24'h0);
				assume(io_in_bits_rs2[31:8] == 24'h0);
			end else begin
				assume(io_in_bits_rs1[31:7] == {25{io_in_bits_rs1[7]}});
				assume(io_in_bits_rs2[31:7] == {25{io_in_bits_rs2[7]}});
			end
		end
`endif
`ifdef MDU_REAL_SMALL_OPERANDS
		if (!CHECK_IS_DIV) begin
			if (CHECK_OP == 4'b0100) begin
				assume(io_in_bits_rs1[31:15] == {17{io_in_bits_rs1[15]}});
				assume(io_in_bits_rs2[31:16] == 16'h0);
			end else if (CHECK_OP == 4'b1000) begin
				assume(io_in_bits_rs1[31:16] == 16'h0);
				assume(io_in_bits_rs2[31:16] == 16'h0);
			end else begin
				assume(io_in_bits_rs1[31:15] == {17{io_in_bits_rs1[15]}});
				assume(io_in_bits_rs2[31:15] == {17{io_in_bits_rs2[15]}});
			end
		end
`endif
`ifdef MDU_REAL_DIV_TINY_OPERANDS
		if (CHECK_NORMAL_DIV) begin
			assume(io_in_bits_rs2 != 32'h0);
			if (CHECK_SIGNED_DIV) begin
				assume(io_in_bits_rs1[31:7] == {25{io_in_bits_rs1[7]}});
				assume(io_in_bits_rs2[31:7] == {25{io_in_bits_rs2[7]}});
			end else begin
				assume(io_in_bits_rs1[31:8] == 24'h0);
				assume(io_in_bits_rs2[31:8] == 24'h0);
			end
		end
`endif
		if (CHECK_NORMAL_DIV) begin
`ifndef MDU_REAL_DIV_TINY_OPERANDS
			assume(io_in_bits_rs2 != 32'h0);
			if (CHECK_SIGNED_DIV) begin
				assume(io_in_bits_rs1[31:15] == {17{io_in_bits_rs1[15]}});
				assume(io_in_bits_rs2[31:15] == {17{io_in_bits_rs2[15]}});
			end else begin
				assume(io_in_bits_rs1[31:16] == 16'h0);
				assume(io_in_bits_rs2[31:16] == 16'h0);
			end
`endif
		end
`endif
	end
	// CL1_MDU_ASSUMPTIONS_END interface

	always @(posedge clock) begin
		if (reset) begin
			issued <= 1'b0;
			active <= 1'b0;
			done <= 1'b0;
			wait_count <= 6'h0;
			tracked_rs1 <= 32'h0;
			tracked_rs2 <= 32'h0;
			tracked_op <= 4'h0;
			tracked_is_div <= 1'b0;
		end else begin
			if (issue_now) begin
				issued <= 1'b1;
				active <= !io_out_valid;
				done <= io_out_valid;
				wait_count <= 6'h0;
				tracked_rs1 <= io_in_bits_rs1;
				tracked_rs2 <= io_in_bits_rs2;
				tracked_op <= io_in_bits_op;
				tracked_is_div <= io_in_bits_is_div;
			end else if (active && io_out_valid) begin
				active <= 1'b0;
				done <= 1'b1;
			end else if (active) begin
				wait_count <= wait_count + 6'h1;
			end
		end
	end

`ifndef MDU_REAL_SPECIAL_COVER
	always @(posedge clock) begin
		if (!reset) begin
			if (active && io_out_valid)
				assert(io_out_bits == expected_out);
			if (active && wait_count == MAX_LATENCY)
				assert(io_out_valid);
		end
	end
`endif

`ifdef MDU_REAL_SPECIAL_COVER
	always @(posedge clock) begin
		if (!reset) begin
			cover(issue_now && io_in_bits_op == 4'b0001
				&& io_in_bits_rs2 == 32'h0
				&& io_out_valid && io_out_bits == 32'hFFFF_FFFF);
			cover(issue_now && io_in_bits_op == 4'b0010
				&& io_in_bits_rs2 == 32'h0
				&& io_out_valid && io_out_bits == io_in_bits_rs1);
			cover(active && io_out_valid && tracked_op == 4'b0001
				&& tracked_rs1 == 32'h8000_0000
				&& tracked_rs2 == 32'hFFFF_FFFF
				&& io_out_bits == 32'h8000_0000);
			cover(active && io_out_valid && tracked_op == 4'b0010
				&& tracked_rs1 == 32'h8000_0000
				&& tracked_rs2 == 32'hFFFF_FFFF
				&& io_out_bits == 32'h0);
		end
	end
`else
	always @(posedge clock) begin
		if (!reset) begin
			cover(issue_now);
			cover(active && io_out_valid && io_out_bits == expected_out);
		end
	end
`endif
endmodule
`else
`ifdef MDU_REAL_PROTOCOL_CHECK
module cl1_mdu_real_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire reset = !past_valid;

	(* anyseq *) reg [31:0] any_rs1;
	(* anyseq *) reg [31:0] any_rs2;
	(* anyseq *) reg [1:0]  any_op_select;
	(* anyseq *) reg        any_is_div;
	(* anyseq *) reg        any_start;
	(* anyseq *) reg        any_flush;
	(* anyseq *) reg        any_out_ready;

	reg        active = 1'b0;
	reg        cooldown = 1'b0;
	reg [31:0] tracked_rs1 = 32'h0;
	reg [31:0] tracked_rs2 = 32'h0;
	reg [3:0]  tracked_op = 4'h0;
	reg        tracked_is_div = 1'b0;
	reg        tracked_normal = 1'b0;
	reg [5:0]  active_age = 6'h0;
	reg [1:0]  accepted_count = 2'h0;
	reg [1:0]  response_count = 2'h0;
	reg [1:0]  cancelled_count = 2'h0;
	reg [1:0]  normal_response_count = 2'h0;

	function automatic [3:0] legal_op;
		input [1:0] select;
		begin
			case (select)
			2'b00: legal_op = 4'b0001;
			2'b01: legal_op = 4'b0010;
			2'b10: legal_op = 4'b0100;
			default: legal_op = 4'b1000;
			endcase
		end
	endfunction

`ifdef MDU_REAL_PROTOCOL_PROGRESS
	wire source_start = accepted_count == 2'h0;
	wire source_flush = 1'b0;
	wire source_out_ready = 1'b1;
	wire can_start = !active && !cooldown && accepted_count == 2'h0;
`else
	wire source_start = any_start;
	wire source_flush = any_flush;
	wire source_out_ready = any_out_ready;
	wire can_start = !active && !cooldown && accepted_count < 2'h2;
`endif

	wire start_now = !reset && can_start && source_start;
	wire [3:0] start_op = legal_op(any_op_select);
	wire io_in_bits_flush = (active || start_now) && source_flush;
	wire io_in_valid = (active || start_now) && !io_in_bits_flush;
	wire [31:0] io_in_bits_rs1 = active ? tracked_rs1 :
		start_now ? any_rs1 : 32'h0;
	wire [31:0] io_in_bits_rs2 = active ? tracked_rs2 :
		start_now ? any_rs2 : 32'h1;
	wire [3:0] io_in_bits_op = active ? tracked_op :
		start_now ? start_op : 4'b0001;
	wire io_in_bits_is_div = active ? tracked_is_div :
		start_now ? any_is_div : 1'b0;
	wire io_out_ready = source_out_ready;
	wire request_special = io_in_bits_is_div && io_in_bits_rs2 == 32'h0;

	wire [34:0] io_alu_req_op1;
	wire [34:0] io_alu_req_op2;
	wire        io_alu_req_sub;
	wire [34:0] io_alu_req_rslt =
		io_alu_req_op1 + ({35{io_alu_req_sub}} ^ io_alu_req_op2)
		+ {34'h0, io_alu_req_sub};
	wire        io_out_valid;
	wire [31:0] io_out_bits;

	CL1MDULp dut (
		.clock(clock),
		.reset(reset),
		.io_in_valid(io_in_valid),
		.io_in_bits_rs1(io_in_bits_rs1),
		.io_in_bits_rs2(io_in_bits_rs2),
		.io_in_bits_op(io_in_bits_op),
		.io_in_bits_is_div(io_in_bits_is_div),
		.io_in_bits_flush(io_in_bits_flush),
		.io_alu_req_op1(io_alu_req_op1),
		.io_alu_req_op2(io_alu_req_op2),
		.io_alu_req_sub(io_alu_req_sub),
		.io_alu_req_rslt(io_alu_req_rslt),
		.io_out_ready(io_out_ready),
		.io_out_valid(io_out_valid),
		.io_out_bits(io_out_bits)
	);

	wire response_fire = io_out_valid && io_out_ready && !io_in_bits_flush;
	wire accepted_start = start_now && !io_in_bits_flush;
	wire cancel_active = active && io_in_bits_flush;

	always @(posedge clock) begin
		if (reset) begin
			active <= 1'b0;
			cooldown <= 1'b0;
			tracked_rs1 <= 32'h0;
			tracked_rs2 <= 32'h0;
			tracked_op <= 4'h0;
			tracked_is_div <= 1'b0;
			tracked_normal <= 1'b0;
			active_age <= 6'h0;
			accepted_count <= 2'h0;
			response_count <= 2'h0;
			cancelled_count <= 2'h0;
			normal_response_count <= 2'h0;
		end else begin
			cooldown <= io_in_bits_flush;

			if (active) begin
				if (cancel_active) begin
					active <= 1'b0;
					active_age <= 6'h0;
					cancelled_count <= cancelled_count + 2'h1;
				end else if (response_fire) begin
					active <= 1'b0;
					active_age <= 6'h0;
					response_count <= response_count + 2'h1;
					if (tracked_normal)
						normal_response_count <= normal_response_count + 2'h1;
				end else begin
					active_age <= active_age + 6'h1;
				end
			end else if (accepted_start) begin
				accepted_count <= accepted_count + 2'h1;
				tracked_rs1 <= io_in_bits_rs1;
				tracked_rs2 <= io_in_bits_rs2;
				tracked_op <= io_in_bits_op;
				tracked_is_div <= io_in_bits_is_div;
				tracked_normal <= !request_special;
				active_age <= 6'h0;
				if (response_fire) begin
					response_count <= response_count + 2'h1;
				end else begin
					active <= 1'b1;
				end
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert({1'b0, accepted_count} ==
				{1'b0, response_count} + {1'b0, cancelled_count}
				+ {2'b00, active});
			assert(response_count <= accepted_count);
			assert(cancelled_count <= accepted_count);

			if (io_out_valid && !io_in_bits_flush)
				assert(active || start_now);
			if (cooldown)
				assert(!io_out_valid);
			if (past_valid && !$past(reset) &&
					$past(io_out_valid && !io_out_ready &&
					!io_in_bits_flush) && !io_in_bits_flush) begin
				assert(io_out_valid);
				assert(io_out_bits == $past(io_out_bits));
			end
`ifdef MDU_REAL_PROTOCOL_PROGRESS
			if (active && active_age == 6'd42)
				assert(io_out_valid);
`endif
		end
	end

`ifdef MDU_REAL_PROTOCOL_COVER
	always @(posedge clock) begin
		if (!reset) begin
			cover(accepted_start && !request_special && !io_in_bits_is_div);
			cover(accepted_start && !request_special && io_in_bits_is_div);
			cover(accepted_start && request_special && io_out_valid &&
				!io_out_ready);
			cover(active && io_out_valid && !io_out_ready);
			cover(cancel_active);
			cover(cooldown && !io_out_valid);
			cover(response_count == 2'h2);
			cover(normal_response_count == 2'h2);
		end
	end
`endif
endmodule
`elsif MDU_REAL_DIV_QUOTIENT_RECODE_CHECK
module cl1_mdu_real_check(input clock);
	(* anyseq *) reg [31:0] any_quotient_digits;
	(* anyseq *) reg [31:0] any_dividend;

	function automatic signed [33:0] reconstruct_quotient;
		input [31:0] digits;
		reg signed [33:0] coefficient;
		integer digit;
		begin
			coefficient = digits[31] ? -34'sd1 : 34'sd1;
			for (digit = 31; digit >= 0; digit = digit - 1)
				coefficient = (coefficient <<< 1)
				+ (digits[digit] ? 34'sd1 : -34'sd1);
			reconstruct_quotient = coefficient;
		end
	endfunction

	function automatic signed [65:0] reconstruct_dividend;
		input [31:0] value;
		input signed_mode;
		reg signed [65:0] prefix;
		integer bit_index;
		begin
			prefix = signed_mode && value[31] ? -66'sd1 : 66'sd0;
			for (bit_index = 31; bit_index >= 0; bit_index = bit_index - 1)
				prefix = (prefix <<< 1) + value[bit_index];
			reconstruct_dividend = prefix;
		end
	endfunction

	wire signed [33:0] reconstructed_quotient =
		reconstruct_quotient(any_quotient_digits);
	wire [32:0] encoded_quotient = {any_quotient_digits, 1'b1};
	wire signed [33:0] expected_quotient =
		{encoded_quotient[32], encoded_quotient};
	wire signed [65:0] reconstructed_signed_dividend =
		reconstruct_dividend(any_dividend, 1'b1);
	wire signed [65:0] reconstructed_unsigned_dividend =
		reconstruct_dividend(any_dividend, 1'b0);

	always @(posedge clock) begin
		assert(reconstructed_quotient == expected_quotient);
		assert(reconstructed_signed_dividend
			== {{34{any_dividend[31]}}, any_dividend});
		assert(reconstructed_unsigned_dividend == {34'h0, any_dividend});
	end
endmodule
`elsif MDU_REAL_DIV_STEP_CHECK
module cl1_mdu_real_check(input clock);
	(* anyseq *) reg [31:0] any_dividend;
	(* anyseq *) reg [31:0] any_divisor;
	(* anyseq *) reg [32:0] any_remainder;
	(* anyseq *) reg any_dividend_bit;
	(* anyseq *) reg signed [65:0] any_prefix;
	(* anyseq *) reg signed [65:0] any_qd;

`ifdef MDU_REAL_DIV_STEP_SIGNED
	localparam CHECK_SIGNED = 1'b1;
`else
	localparam CHECK_SIGNED = 1'b0;
`endif

	wire dividend_sign = CHECK_SIGNED && any_dividend[31];
	wire divisor_sign = CHECK_SIGNED && any_divisor[31];
	wire signed [32:0] divisor = {divisor_sign, any_divisor};
	wire [32:0] divisor_magnitude = divisor[32]
		? (~divisor + 33'h1) : divisor;
	wire signed [33:0] divisor_bound = {1'b0, divisor_magnitude};
	wire signed [33:0] remainder_wide =
		{any_remainder[32], any_remainder};
	wire remainder_in_range = remainder_wide >= -divisor_bound
		&& remainder_wide < divisor_bound;

	wire body_quotient_bit = any_remainder[32] ^ ~divisor_sign;
	wire signed [32:0] shifted_remainder =
		{any_remainder[31:0], any_dividend_bit};
	wire signed [32:0] next_remainder = shifted_remainder
		+ (body_quotient_bit ? -divisor : divisor);
	wire signed [33:0] next_remainder_wide =
		{next_remainder[32], next_remainder};
	wire next_remainder_in_range = next_remainder_wide >= -divisor_bound
		&& next_remainder_wide < divisor_bound;

	wire initial_subtract = dividend_sign ^ ~divisor_sign;
	wire signed [32:0] initial_prefix = dividend_sign ? -33'sd1 : 33'sd0;
	wire signed [32:0] initial_remainder = initial_prefix
		+ (initial_subtract ? -divisor : divisor);
	wire signed [33:0] initial_remainder_wide =
		{initial_remainder[32], initial_remainder};
	wire initial_remainder_in_range =
		initial_remainder_wide >= -divisor_bound
		&& initial_remainder_wide < divisor_bound;

	wire correction_subtract = any_remainder[32] ^ divisor_sign;
	wire signed [32:0] check_sum = $signed(any_remainder) + divisor;
	wire correction_needed =
		(any_remainder[32] ^ dividend_sign) && (|any_remainder)
		|| $signed(any_remainder) == divisor || check_sum == 33'sh0;
	wire signed [32:0] corrected_remainder = correction_subtract
		? ($signed(any_remainder) + divisor)
		: ($signed(any_remainder) - divisor);
	wire signed [32:0] final_remainder = correction_needed
		? corrected_remainder : $signed(any_remainder);
	wire [32:0] final_remainder_magnitude = final_remainder[32]
		? (~final_remainder + 33'h1) : final_remainder;
	wire final_remainder_in_range = final_remainder_magnitude
		< divisor_magnitude;
	wire final_remainder_sign_ok = !CHECK_SIGNED || final_remainder == 33'sh0
		|| final_remainder[32] == dividend_sign;

	wire signed [65:0] divisor_wide = {{33{divisor[32]}}, divisor};
	wire signed [65:0] remainder_identity =
		{{33{any_remainder[32]}}, any_remainder};
	wire signed [65:0] next_remainder_identity =
		{{33{next_remainder[32]}}, next_remainder};
	wire signed [65:0] prefix_next = (any_prefix <<< 1)
		+ {{65{1'b0}}, any_dividend_bit};
	wire signed [65:0] qd_next = (any_qd <<< 1)
		+ (body_quotient_bit ? divisor_wide : -divisor_wide);
	wire signed [65:0] qd_corrected = any_qd
		+ (correction_subtract ? -divisor_wide : divisor_wide);
	wire signed [65:0] corrected_remainder_identity =
		{{33{corrected_remainder[32]}}, corrected_remainder};
	wire signed [65:0] initial_prefix_identity =
		{{33{initial_prefix[32]}}, initial_prefix};
	wire signed [65:0] initial_remainder_identity =
		{{33{initial_remainder[32]}}, initial_remainder};
	wire signed [65:0] initial_qd_identity = initial_subtract
		? divisor_wide : -divisor_wide;

	// CL1_STRICT_ASSUMPTIONS_BEGIN div_step
	always @* begin
		assume(any_divisor != 32'h0);
		assume(remainder_in_range);
		assume(any_prefix == any_qd + remainder_identity);
	end
	// CL1_STRICT_ASSUMPTIONS_END div_step

	always @(posedge clock) begin
		assert(initial_remainder_in_range);
		assert(initial_prefix_identity
			== initial_qd_identity + initial_remainder_identity);
		assert(next_remainder_in_range);
		assert(prefix_next == qd_next + next_remainder_identity);
		assert(any_prefix == qd_corrected + corrected_remainder_identity);
		assert(final_remainder_in_range);
		assert(final_remainder_sign_ok);
	end
endmodule
`elsif MDU_REAL_SCALED_STEP_CHECK
module cl1_mdu_real_check(input clock);
	(* anyseq *) reg [4:0] any_stage;
	(* anyseq *) reg [2:0] any_booth_code;
	(* anyseq *) reg [31:0] any_multiplicand;
	(* anyseq *) reg [65:0] any_product;

	wire [5:0] shift_amount = {any_stage, 1'b0};
	wire booth_zero = any_booth_code == 3'b000
		|| any_booth_code == 3'b111;
	wire booth_two = any_booth_code == 3'b011
		|| any_booth_code == 3'b100;
`ifdef MDU_REAL_SCALED_RHS_SIGNED
	wire signed [65:0] base_multiplicand =
		{{34{any_multiplicand[31]}}, any_multiplicand};
	wire signed [34:0] scaled_base =
		{{3{any_multiplicand[31]}}, any_multiplicand};
`else
	wire signed [65:0] base_multiplicand = {34'h0, any_multiplicand};
	wire signed [34:0] scaled_base = {3'h0, any_multiplicand};
`endif
	wire signed [65:0] shifted_multiplicand =
		base_multiplicand <<< shift_amount;
	wire signed [65:0] unscaled_magnitude = booth_two
		? (shifted_multiplicand <<< 1) : shifted_multiplicand;
	wire signed [65:0] unscaled_partial = booth_zero
		? 66'sh0 : any_booth_code[2] ? -unscaled_magnitude
		: unscaled_magnitude;
	wire signed [65:0] product_next = $signed(any_product)
		+ unscaled_partial;
	wire signed [65:0] product_shifted = $signed(any_product)
		>>> shift_amount;
	wire signed [34:0] scaled_product = product_shifted[34:0];
	wire signed [34:0] scaled_magnitude = booth_two
		? (scaled_base <<< 1) : scaled_base;
	wire signed [34:0] scaled_partial = booth_zero
		? 35'sh0 : any_booth_code[2] ? -scaled_magnitude
		: scaled_magnitude;
	wire signed [35:0] scaled_sum_ext =
		$signed({scaled_product[34], scaled_product})
		+ $signed({scaled_partial[34], scaled_partial});
	wire signed [34:0] scaled_sum = scaled_sum_ext[34:0];
	wire signed [34:0] scaled_next = scaled_sum >>> 2;
	wire signed [65:0] product_next_shifted = product_next
		>>> (shift_amount + 6'd2);
	wire signed [65:0] product_final_shifted = product_next >>> 6'd32;

	// CL1_STRICT_ASSUMPTIONS_BEGIN scaled_step
	always @* begin
		assume(any_stage <= 5'd16);
		assume(product_shifted[65:35] == {31{product_shifted[34]}});
		assume(any_stage == 5'd16 || scaled_sum_ext[35] == scaled_sum_ext[34]);
	end
	// CL1_STRICT_ASSUMPTIONS_END scaled_step

	always @(posedge clock) begin
		if (any_stage < 5'd16) begin
			assert(product_next_shifted[65:35]
				== {31{product_next_shifted[34]}});
			assert(scaled_next == product_next_shifted[34:0]);
		end else begin
			assert(product_final_shifted[65:35]
				== {31{product_final_shifted[34]}});
			assert(scaled_sum[31:0] == product_final_shifted[31:0]);
		end
	end
endmodule
`elsif MDU_REAL_BOOTH_RECODE_CHECK
module cl1_mdu_real_check(input clock);
	(* anyseq *) reg [31:0] any_multiplier;

	function automatic signed [34:0] reconstruct_multiplier;
		input [31:0] value;
		reg signed [34:0] scan;
		reg signed [34:0] weight;
		reg signed [34:0] digit_value;
		reg signed [34:0] sum;
		integer digit;
		begin
`ifdef MDU_REAL_RECODE_SIGNED
			scan = {{2{value[31]}}, value, 1'b0};
`else
			scan = {2'b00, value, 1'b0};
`endif
			weight = 35'h1;
			sum = 35'h0;
			for (digit = 0; digit < 17; digit = digit + 1) begin
				case (scan[2:0])
						3'b001, 3'b010: digit_value = weight;
					3'b011: digit_value = weight <<< 1;
					3'b100: digit_value = -(weight <<< 1);
					3'b101, 3'b110: digit_value = -weight;
					default: digit_value = 35'h0;
				endcase
				sum = sum + digit_value;
				scan = scan >>> 2;
				weight = weight <<< 2;
			end
			reconstruct_multiplier = sum;
		end
	endfunction

	wire [34:0] reconstructed = reconstruct_multiplier(any_multiplier);
`ifdef MDU_REAL_RECODE_SIGNED
	wire [34:0] expected_multiplier = {{3{any_multiplier[31]}}, any_multiplier};
`else
	wire [34:0] expected_multiplier = {3'h0, any_multiplier};
`endif

	always @(posedge clock)
		assert(reconstructed == expected_multiplier);

	always @(posedge clock)
		cover(reconstructed == expected_multiplier);
endmodule
`elsif MDU_REAL_FULL_MUL_CHECK
module cl1_mdu_real_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire reset = !past_valid;
	(* anyseq *) reg [31:0] any_rs1;
	(* anyseq *) reg [31:0] any_rs2;
	// CL1_STRICT_ASSUMPTIONS_BEGIN mul_partitions
`ifdef MDU_REAL_MUL_RS1_NEG
	always @* assume(any_rs1[31]);
`elsif MDU_REAL_MUL_RS1_POS
	always @* assume(!any_rs1[31]);
`endif
`ifdef MDU_REAL_MUL_RS2_NEG
	always @* assume(any_rs2[31]);
`elsif MDU_REAL_MUL_RS2_POS
	always @* assume(!any_rs2[31]);
`endif
	// CL1_STRICT_ASSUMPTIONS_END mul_partitions
	reg issued = 1'b0;
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
	reg dut_done = 1'b0;
	reg [5:0] wait_count = 6'h0;
	reg [31:0] dut_result = 32'h0;
`endif
	reg ref_done = 1'b0;
	reg [4:0] ref_count = 5'h0;
	reg [31:0] tracked_rs1 = 32'h0;
	reg [31:0] tracked_rs2 = 32'h0;
	reg signed [34:0] ref_multiplier = 35'h0;
	reg [65:0] ref_multiplicand = 66'h0;
	reg [65:0] ref_product = 66'h0;
	reg [65:0] ref_result = 66'h0;
	reg [34:0] ref_scaled_product = 35'h0;
	reg [31:0] ref_high_result = 32'h0;
`ifdef MDU_REAL_STRICT_MUL_CHECK
	reg [65:0] strict_binary_product = 66'h0;
`endif

	wire issue_now = !reset && !issued;
	wire [31:0] operand_rs1 = issued ? tracked_rs1 : any_rs1;
	wire [31:0] operand_rs2 = issued ? tracked_rs2 : any_rs2;

`ifdef MDU_REAL_MUL
	localparam [3:0] CHECK_OP = 4'b0001;
	localparam RESULT_HIGH = 1'b0;
	localparam LHS_SIGNED = 1'b1;
	localparam RHS_SIGNED = 1'b1;
`elsif MDU_REAL_MULH
	localparam [3:0] CHECK_OP = 4'b0010;
	localparam RESULT_HIGH = 1'b1;
	localparam LHS_SIGNED = 1'b1;
	localparam RHS_SIGNED = 1'b1;
`elsif MDU_REAL_MULHSU
	localparam [3:0] CHECK_OP = 4'b0100;
	localparam RESULT_HIGH = 1'b1;
	localparam LHS_SIGNED = 1'b1;
	localparam RHS_SIGNED = 1'b0;
`else
	localparam [3:0] CHECK_OP = 4'b1000;
	localparam RESULT_HIGH = 1'b1;
	localparam LHS_SIGNED = 1'b0;
	localparam RHS_SIGNED = 1'b0;
`endif

	wire [2:0] ref_booth_code = ref_multiplier[2:0];
	wire ref_booth_zero = ref_booth_code == 3'b000
		|| ref_booth_code == 3'b111;
	wire ref_booth_two = ref_booth_code == 3'b011
		|| ref_booth_code == 3'b100;
	wire [65:0] ref_booth_magnitude = ref_booth_two
		? (ref_multiplicand << 1) : ref_multiplicand;
	wire [65:0] ref_partial = ref_booth_zero
		? 66'h0
		: ref_booth_code[2]
		? (~ref_booth_magnitude + 66'h1) : ref_booth_magnitude;
	wire [65:0] ref_product_next = ref_product + ref_partial;
	wire [34:0] ref_base_operand = RHS_SIGNED
		? {{3{tracked_rs2[31]}}, tracked_rs2}
		: {3'h0, tracked_rs2};
	wire [34:0] ref_booth_operand = ref_booth_zero
		? 35'h0
		: ref_booth_two ? (ref_base_operand << 1) : ref_base_operand;
	wire [34:0] ref_scaled_partial = ref_booth_code[2]
		? (~ref_booth_operand + 35'h1) : ref_booth_operand;
	wire [34:0] ref_scaled_next = ref_scaled_product + ref_scaled_partial;
	wire signed [35:0] ref_scaled_sum_ext =
		$signed({ref_scaled_product[34], ref_scaled_product})
		+ $signed({ref_scaled_partial[34], ref_scaled_partial});
`ifdef MDU_REAL_SCALED_EQUIV_CHECK
	wire [5:0] ref_scale_shift = {ref_count, 1'b0};
	wire signed [65:0] ref_product_scaled_view =
		$signed(ref_product) >>> ref_scale_shift;
`endif

`ifdef MDU_REAL_STRICT_MUL_CHECK
	wire [5:0] strict_multiplier_shift = {ref_count, 1'b0};
	wire [65:0] strict_base_multiplicand = RHS_SIGNED
		? {{34{tracked_rs2[31]}}, tracked_rs2}
		: {34'h0, tracked_rs2};
	wire [65:0] strict_shifted_multiplicand =
		strict_base_multiplicand << strict_multiplier_shift;
	wire [32:0] strict_multiplier_bits = {1'b0, tracked_rs1}
		>> strict_multiplier_shift;
	wire [5:0] strict_previous_shift = ref_count == 5'h0
		? 6'h0 : strict_multiplier_shift - 6'h1;
	wire [32:0] strict_previous_bits = {1'b0, tracked_rs1}
		>> strict_previous_shift;
	wire strict_previous_bit = ref_count == 5'h0
		? 1'b0 : strict_previous_bits[0];
	wire [65:0] strict_even_partial = strict_multiplier_bits[0]
		? strict_shifted_multiplicand : 66'h0;
	wire [65:0] strict_odd_partial = strict_multiplier_bits[1]
		? (strict_shifted_multiplicand << 1) : 66'h0;
	wire [65:0] strict_binary_next = strict_binary_product
		+ strict_even_partial + strict_odd_partial;
	wire [65:0] strict_current_correction = strict_previous_bit
		? strict_shifted_multiplicand : 66'h0;
	wire [65:0] strict_next_correction = strict_multiplier_bits[1]
		? (strict_shifted_multiplicand << 2) : 66'h0;
	wire [65:0] strict_final_product = strict_binary_product
		- (LHS_SIGNED && tracked_rs1[31]
		? strict_shifted_multiplicand : 66'h0);
`endif

`ifndef MDU_REAL_MUL_REFERENCE_ONLY
	wire [31:0] expected_result = RESULT_HIGH
		? ref_high_result : ref_result[31:0];
	wire [34:0] alu_op1;
	wire [34:0] alu_op2;
	wire alu_sub;
	wire [34:0] alu_result = alu_op1
		+ ({35{alu_sub}} ^ alu_op2) + {34'h0, alu_sub};
	wire out_valid;
	wire [31:0] out_bits;

	CL1MDULp dut (
		.clock(clock),
		.reset(reset),
		.io_in_valid(issue_now),
		.io_in_bits_rs1(operand_rs1),
		.io_in_bits_rs2(operand_rs2),
		.io_in_bits_op(CHECK_OP),
		.io_in_bits_is_div(1'b0),
		.io_in_bits_flush(1'b0),
		.io_alu_req_op1(alu_op1),
		.io_alu_req_op2(alu_op2),
		.io_alu_req_sub(alu_sub),
		.io_alu_req_rslt(alu_result),
		.io_out_ready(1'b1),
		.io_out_valid(out_valid),
		.io_out_bits(out_bits)
		);
`endif

	always @(posedge clock) begin
		if (reset) begin
			issued <= 1'b0;
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
			dut_done <= 1'b0;
			wait_count <= 6'h0;
			dut_result <= 32'h0;
`endif
			ref_done <= 1'b0;
			ref_count <= 5'h0;
			tracked_rs1 <= 32'h0;
			tracked_rs2 <= 32'h0;
			ref_multiplier <= 35'h0;
			ref_multiplicand <= 66'h0;
			ref_product <= 66'h0;
			ref_result <= 66'h0;
			ref_scaled_product <= 35'h0;
			ref_high_result <= 32'h0;
`ifdef MDU_REAL_STRICT_MUL_CHECK
			strict_binary_product <= 66'h0;
`endif
		end else begin
			if (issue_now) begin
				issued <= 1'b1;
				tracked_rs1 <= operand_rs1;
				tracked_rs2 <= operand_rs2;
				ref_multiplier <= {
					{2{LHS_SIGNED && operand_rs1[31]}}, operand_rs1, 1'b0};
				ref_multiplicand <= RHS_SIGNED
					? {{34{operand_rs2[31]}}, operand_rs2}
					: {34'h0, operand_rs2};
				ref_product <= 66'h0;
				ref_scaled_product <= 35'h0;
				ref_count <= 5'h0;
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
				wait_count <= 6'h0;
`endif
`ifdef MDU_REAL_STRICT_MUL_CHECK
				strict_binary_product <= 66'h0;
`endif
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
			end else if (issued && !dut_done) begin
				wait_count <= wait_count + 6'h1;
`endif
			end
			if (issued && !ref_done) begin
				ref_product <= ref_product_next;
				ref_scaled_product <= $signed(ref_scaled_next) >>> 2;
				ref_multiplier <= $signed(ref_multiplier) >>> 2;
				ref_multiplicand <= ref_multiplicand << 2;
`ifdef MDU_REAL_STRICT_MUL_CHECK
				if (ref_count < 5'd16)
					strict_binary_product <= strict_binary_next;
`endif
				if (ref_count == 5'd16) begin
					ref_done <= 1'b1;
					ref_result <= ref_product_next;
					ref_high_result <= ref_scaled_next[31:0];
				end else begin
					ref_count <= ref_count + 5'h1;
				end
			end
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
			if (!dut_done && out_valid) begin
				dut_done <= 1'b1;
				dut_result <= out_bits;
			end
`endif
		end
	end

	always @(posedge clock) begin
		if (!reset && issued) begin
`ifdef MDU_REAL_SCALED_RANGE_CHECK
			if (!ref_done && ref_count < 5'd16)
				assert(ref_scaled_sum_ext[35] == ref_scaled_sum_ext[34]);
`elsif MDU_REAL_SCALED_EQUIV_CHECK
			if (!ref_done) begin
				assert(ref_product_scaled_view[65:35]
					== {31{ref_product_scaled_view[34]}});
				assert(ref_scaled_product == ref_product_scaled_view[34:0]);
			end
			if (ref_done)
				assert(ref_high_result == ref_result[63:32]);
`else
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
			if (!dut_done && wait_count == 6'd22)
				assert(out_valid);
			if (RESULT_HIGH && !ref_done) begin
				assert(alu_op1 == ref_scaled_product);
				assert(alu_op2 == ref_booth_operand);
				assert(alu_sub == ref_booth_code[2]);
			end
`endif

`endif
		end
	end

`ifdef MDU_REAL_STRICT_MUL_CHECK
	always @(posedge clock) begin
		if (!reset && issued && !ref_done) begin
			assert(ref_product
				== strict_binary_product - strict_current_correction
				&& (ref_count < 5'd16
				? ref_product_next
				== strict_binary_next - strict_next_correction
				: ref_product_next == strict_final_product));
		end
		if (!reset && ref_done)
			assert(ref_result == strict_final_product);
	end
`else
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
	genvar result_bit;
	generate
		for (result_bit = 0; result_bit < 32; result_bit = result_bit + 1) begin : g_result_bit
			always @(posedge clock) begin
				if (!reset && issued && dut_done && ref_done)
					assert(dut_result[result_bit] == expected_result[result_bit]);
			end
		end
	endgenerate
`endif
`endif

	always @(posedge clock) begin
		if (!reset) begin
			cover(issue_now);
`ifdef MDU_REAL_STRICT_COMPLETION_COVER
			cover(ref_done && ref_result == strict_final_product);
`endif
`ifndef MDU_REAL_MUL_REFERENCE_ONLY
			cover(dut_done && ref_done && dut_result == expected_result);
`endif
		end
	end
endmodule
`else
module cl1_mdu_real_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire reset = !past_valid;
	(* anyseq *) reg [31:0] any_rs1;
	(* anyseq *) reg [31:0] any_rs2;

	// CL1_STRICT_ASSUMPTIONS_BEGIN div_partitions
`ifdef MDU_REAL_DIV_RS1_NEG
	always @* assume(any_rs1[31]);
`elsif MDU_REAL_DIV_RS1_POS
	always @* assume(!any_rs1[31]);
`endif
`ifdef MDU_REAL_DIV_RS2_NEG
	always @* assume(any_rs2[31]);
`elsif MDU_REAL_DIV_RS2_POS
	always @* assume(!any_rs2[31]);
`endif
`ifdef MDU_REAL_DIV_RS2_BIT30_ONE
	always @* assume(any_rs2[30]);
`elsif MDU_REAL_DIV_RS2_BIT30_ZERO
	always @* assume(!any_rs2[30]);
`endif
	// CL1_STRICT_ASSUMPTIONS_END div_partitions
	reg issued = 1'b0;
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
	reg q_done = 1'b0;
	reg r_done = 1'b0;
	reg [5:0] wait_count = 6'h0;
	reg [31:0] q_result = 32'h0;
	reg [31:0] r_result = 32'h0;
`endif
	reg [31:0] tracked_rs1 = 32'h0;
	reg [31:0] tracked_rs2 = 32'h0;
	reg ref_done = 1'b0;
	reg [2:0] ref_state = 3'h0;
	reg [5:0] ref_count = 6'h0;
	reg [65:0] ref_share = 66'h0;
	reg [31:0] ref_q_result = 32'h0;
	reg [31:0] ref_r_result = 32'h0;
`ifdef MDU_REAL_DIV_INVARIANT_CHECK
	reg signed [65:0] inv_prefix = 66'sh0;
	reg signed [65:0] inv_coefficient = 66'sh0;
	reg signed [65:0] inv_qd = 66'sh0;
	reg signed [32:0] inv_expected_remainder = 33'sh0;
`endif

	wire issue_now = !reset && !issued;
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
	wire pair_done = q_done && r_done;
`endif
	wire [31:0] operand_rs1 = issued ? tracked_rs1 : any_rs1;
	wire [31:0] operand_rs2 = issued ? tracked_rs2 : any_rs2;

`ifdef MDU_REAL_DIVREM_SIGNED_FULL
	localparam [3:0] QUOT_OP = 4'b0001;
	localparam [3:0] REM_OP = 4'b0010;
	localparam CHECK_SIGNED = 1'b1;
`else
	localparam [3:0] QUOT_OP = 4'b0100;
	localparam [3:0] REM_OP = 4'b1000;
	localparam CHECK_SIGNED = 1'b0;
`endif

`ifndef MDU_REAL_DIV_REFERENCE_ONLY
	wire [34:0] q_alu_op1;
	wire [34:0] q_alu_op2;
	wire q_alu_sub;
	wire [32:0] q_alu_result_low = q_alu_op1[32:0]
		+ ({33{q_alu_sub}} ^ q_alu_op2[32:0]) + {32'h0, q_alu_sub};
	wire [34:0] q_alu_result = {2'h0, q_alu_result_low};
	wire q_out_valid;
	wire [31:0] q_out_bits;

	wire [34:0] r_alu_op1;
	wire [34:0] r_alu_op2;
	wire r_alu_sub;
	wire [32:0] r_alu_result_low = r_alu_op1[32:0]
		+ ({33{r_alu_sub}} ^ r_alu_op2[32:0]) + {32'h0, r_alu_sub};
	wire [34:0] r_alu_result = {2'h0, r_alu_result_low};
	wire r_out_valid;
	wire [31:0] r_out_bits;

	CL1MDULp quotient_dut (
		.clock(clock),
		.reset(reset),
		.io_in_valid(issue_now),
		.io_in_bits_rs1(operand_rs1),
		.io_in_bits_rs2(operand_rs2),
		.io_in_bits_op(QUOT_OP),
		.io_in_bits_is_div(1'b1),
		.io_in_bits_flush(1'b0),
		.io_alu_req_op1(q_alu_op1),
		.io_alu_req_op2(q_alu_op2),
		.io_alu_req_sub(q_alu_sub),
		.io_alu_req_rslt(q_alu_result),
		.io_out_ready(1'b1),
		.io_out_valid(q_out_valid),
		.io_out_bits(q_out_bits)
		);

	CL1MDULp remainder_dut (
		.clock(clock),
		.reset(reset),
		.io_in_valid(issue_now),
		.io_in_bits_rs1(operand_rs1),
		.io_in_bits_rs2(operand_rs2),
		.io_in_bits_op(REM_OP),
		.io_in_bits_is_div(1'b1),
		.io_in_bits_flush(1'b0),
		.io_alu_req_op1(r_alu_op1),
		.io_alu_req_op2(r_alu_op2),
		.io_alu_req_sub(r_alu_sub),
		.io_alu_req_rslt(r_alu_result),
		.io_out_ready(1'b1),
		.io_out_valid(r_out_valid),
		.io_out_bits(r_out_bits)
		);

	wire q_available = q_done || q_out_valid;
	wire r_available = r_done || r_out_valid;
`endif
	wire signed_overflow = tracked_rs1 == 32'h8000_0000
		&& tracked_rs2 == 32'hFFFF_FFFF;
	wire normal_division = tracked_rs2 != 32'h0
		&& !(CHECK_SIGNED && signed_overflow);
	wire issue_signed_overflow = operand_rs1 == 32'h8000_0000
		&& operand_rs2 == 32'hFFFF_FFFF;
	wire issue_normal_division = operand_rs2 != 32'h0
		&& !(CHECK_SIGNED && issue_signed_overflow);
	wire ref_exec = ref_state == 3'h1;
	wire ref_check_remainder = ref_state == 3'h2;
	wire ref_correct_quotient = ref_state == 3'h3;
	wire ref_correct_remainder = ref_state == 3'h4;
	wire ref_cycle_zero = ref_exec && ref_count == 6'h0;
	wire ref_cycle_body = ref_exec && ref_count != 6'h0;
	wire ref_last_cycle = ref_count == 6'd32;
	wire ref_rs1_sign = CHECK_SIGNED && tracked_rs1[31];
	wire ref_rs2_sign = CHECK_SIGNED && tracked_rs2[31];
	wire [32:0] ref_divisor = {ref_rs2_sign, tracked_rs2};
	wire [32:0] ref_remainder = ref_share[65:33];
	wire [32:0] ref_quotient = ref_share[32:0];
	wire ref_correct_quotient_sub = ref_remainder[32] ^ ref_rs2_sign;
	wire [34:0] ref_alu_op1 = ref_cycle_zero
		? {2'h0, {33{ref_rs1_sign}}}
		: ref_cycle_body ? {2'h0, ref_share[64:32]}
		: (ref_check_remainder || ref_correct_remainder)
		? {2'h0, ref_remainder}
		: ref_correct_quotient ? {2'h0, ref_quotient} : 35'h0;
	wire [34:0] ref_alu_op2 = ref_correct_quotient
		? 35'h1 : {2'h0, ref_divisor};
	wire ref_alu_sub = ref_cycle_zero
		? (ref_rs1_sign ^ ~ref_rs2_sign)
		: ref_cycle_body ? ref_share[0]
		: ref_correct_quotient ? ref_correct_quotient_sub
		: ref_correct_remainder ? ~ref_correct_quotient_sub : 1'b0;
	wire [32:0] ref_div_result = ref_alu_op1[32:0]
		+ ({33{ref_alu_sub}} ^ ref_alu_op2[32:0]) + {32'h0, ref_alu_sub};
	wire ref_current_quotient = ref_div_result[32] ^ ~ref_rs2_sign;
	wire ref_result_needs_correction =
		(ref_remainder[32] ^ ref_rs1_sign) && (|ref_remainder)
		|| ref_remainder == ref_divisor || ref_div_result == 33'h0;

`ifdef MDU_REAL_DIV_INVARIANT_CHECK
	wire signed [65:0] inv_divisor = {{33{ref_divisor[32]}}, ref_divisor};
	wire signed [65:0] inv_remainder = {{33{ref_remainder[32]}}, ref_remainder};
	wire signed [65:0] inv_div_result = {{33{ref_div_result[32]}}, ref_div_result};
	wire signed [65:0] inv_initial_prefix = ref_rs1_sign ? -66'sd1 : 66'sd0;
	wire signed [65:0] inv_initial_coefficient = ref_alu_sub
		? 66'sd1 : -66'sd1;
	wire signed [65:0] inv_initial_qd = ref_alu_sub
		? inv_divisor : -inv_divisor;
	wire [5:0] inv_dividend_index = 6'd32 - ref_count;
	wire inv_next_dividend_bit = tracked_rs1[inv_dividend_index];
	wire signed [65:0] inv_prefix_next = (inv_prefix <<< 1)
		+ {{65{1'b0}}, inv_next_dividend_bit};
	wire signed [65:0] inv_coefficient_next = (inv_coefficient <<< 1)
		+ (ref_share[0] ? 66'sd1 : -66'sd1);
	wire signed [65:0] inv_qd_next = (inv_qd <<< 1)
		+ (ref_share[0] ? inv_divisor : -inv_divisor);
	wire signed [65:0] inv_correction_delta = ref_alu_sub
		? -66'sd1 : 66'sd1;
	wire signed [65:0] inv_coefficient_corrected = inv_coefficient
		+ inv_correction_delta;
	wire signed [65:0] inv_qd_corrected = inv_qd
		+ (ref_alu_sub ? -inv_divisor : inv_divisor);
	wire signed [65:0] inv_dividend = CHECK_SIGNED
		? {{34{tracked_rs1[31]}}, tracked_rs1}
		: {34'h0, tracked_rs1};
`endif

`ifdef MDU_REAL_DIV_RANGE_CHECK
	wire [32:0] inv_divisor_magnitude_wide = ref_divisor[32]
		? (~ref_divisor + 33'h1) : ref_divisor;
	wire signed [33:0] inv_current_remainder_wide =
		{ref_remainder[32], ref_remainder};
	wire signed [33:0] inv_divisor_bound =
		{1'b0, inv_divisor_magnitude_wide};
	wire inv_current_remainder_in_range =
		inv_current_remainder_wide >= -inv_divisor_bound
		&& inv_current_remainder_wide < inv_divisor_bound;
	wire inv_body_digit_matches = ref_share[0]
		== (ref_remainder[32] ^ ~ref_rs2_sign);
	wire [31:0] inv_divisor_magnitude = CHECK_SIGNED && tracked_rs2[31]
		? (~tracked_rs2 + 32'h1) : tracked_rs2;
	wire [31:0] inv_remainder_magnitude = CHECK_SIGNED && ref_r_result[31]
		? (~ref_r_result + 32'h1) : ref_r_result;
	wire inv_remainder_in_range = inv_remainder_magnitude
		< inv_divisor_magnitude;
	wire inv_remainder_sign_ok = !CHECK_SIGNED || ref_r_result == 32'h0
		|| ref_r_result[31] == tracked_rs1[31];
	wire inv_quotient_sign_ok = !CHECK_SIGNED || ref_q_result == 32'h0
		|| ref_q_result[31] == (tracked_rs1[31] ^ tracked_rs2[31]);
`endif

	always @(posedge clock) begin
		if (reset) begin
			issued <= 1'b0;
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
			q_done <= 1'b0;
			r_done <= 1'b0;
			wait_count <= 6'h0;
			q_result <= 32'h0;
			r_result <= 32'h0;
`endif
			tracked_rs1 <= 32'h0;
			tracked_rs2 <= 32'h0;
			ref_done <= 1'b0;
			ref_state <= 3'h0;
			ref_count <= 6'h0;
			ref_share <= 66'h0;
			ref_q_result <= 32'h0;
			ref_r_result <= 32'h0;
`ifdef MDU_REAL_DIV_INVARIANT_CHECK
			inv_prefix <= 66'sh0;
			inv_coefficient <= 66'sh0;
			inv_qd <= 66'sh0;
			inv_expected_remainder <= 33'sh0;
`endif
		end else begin
			if (issue_now) begin
				issued <= 1'b1;
				tracked_rs1 <= operand_rs1;
				tracked_rs2 <= operand_rs2;
				ref_state <= issue_normal_division ? 3'h1 : 3'h0;
				ref_share <= 66'h0;
				ref_count <= 6'h0;
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
				wait_count <= 6'h0;
`endif
			end
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
			else if (issued && !pair_done) begin
				wait_count <= wait_count + 6'h1;
			end
			if (!q_done && q_out_valid) begin
				q_done <= 1'b1;
				q_result <= q_out_bits;
			end
			if (!r_done && r_out_valid) begin
				r_done <= 1'b1;
				r_result <= r_out_bits;
			end
`endif
			if (ref_exec) begin
				ref_share <= ref_cycle_zero
					? {ref_div_result, tracked_rs1, ref_current_quotient}
					: {ref_div_result, ref_share[31:0],
					ref_last_cycle || ref_current_quotient};
				if (ref_last_cycle) begin
					ref_state <= 3'h2;
				end else begin
					ref_count <= ref_count + 6'h1;
				end
			end else if (ref_check_remainder) begin
				if (ref_result_needs_correction) begin
					ref_state <= 3'h3;
				end else begin
					ref_state <= 3'h0;
					ref_done <= 1'b1;
					ref_q_result <= ref_quotient[31:0];
					ref_r_result <= ref_remainder[31:0];
				end
			end else if (ref_correct_quotient) begin
				ref_share <= {ref_remainder, ref_div_result};
				ref_state <= 3'h4;
			end else if (ref_correct_remainder) begin
				ref_state <= 3'h0;
				ref_done <= 1'b1;
				ref_q_result <= ref_quotient[31:0];
				ref_r_result <= ref_div_result[31:0];
			end
`ifdef MDU_REAL_DIV_INVARIANT_CHECK
			if (ref_exec && ref_cycle_zero) begin
				inv_prefix <= inv_initial_prefix;
				inv_coefficient <= inv_initial_coefficient;
				inv_qd <= inv_initial_qd;
			end else if (ref_exec && ref_cycle_body) begin
				inv_prefix <= inv_prefix_next;
				inv_coefficient <= inv_coefficient_next;
				inv_qd <= inv_qd_next;
			end else if (ref_correct_quotient) begin
				inv_coefficient <= inv_coefficient_corrected;
				inv_qd <= inv_qd_corrected;
			end
			if (ref_check_remainder && !ref_result_needs_correction)
				inv_expected_remainder <= ref_remainder;
			else if (ref_correct_remainder)
				inv_expected_remainder <= ref_div_result;
`endif
		end
	end

	always @(posedge clock) begin
		if (!reset && issued) begin
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
			if (!pair_done && wait_count == 6'd40)
				assert(q_available && r_available);
			if (ref_state != 3'h0) begin
				assert(q_alu_op1 == ref_alu_op1);
				assert(q_alu_op2 == ref_alu_op2);
				assert(q_alu_sub == ref_alu_sub);
				assert(r_alu_op1 == ref_alu_op1);
				assert(r_alu_op2 == ref_alu_op2);
				assert(r_alu_sub == ref_alu_sub);
			end
`endif
		end
	end

`ifndef MDU_REAL_DIV_REFERENCE_ONLY
	genvar result_bit;
	generate
		for (result_bit = 0; result_bit < 32; result_bit = result_bit + 1) begin : g_result_bit
			always @(posedge clock) begin
				if (!reset && pair_done && normal_division && ref_done)
					assert(q_result[result_bit] == ref_q_result[result_bit]);
				if (!reset && pair_done && normal_division && ref_done)
					assert(r_result[result_bit] == ref_r_result[result_bit]);
			end
		end
	endgenerate
`endif

`ifdef MDU_REAL_DIV_INVARIANT_CHECK
	always @(posedge clock) begin
		if (!reset && normal_division) begin
			assert((!ref_cycle_zero
				|| inv_initial_prefix == inv_initial_qd + inv_div_result)
				&& (!ref_cycle_body
				|| (inv_prefix == inv_qd + inv_remainder
				&& inv_prefix_next == inv_qd_next + inv_div_result))
				&& (!ref_check_remainder
				|| (inv_prefix == inv_dividend
				&& inv_prefix == inv_qd + inv_remainder
				&& ref_quotient == inv_coefficient[32:0]))
				&& (!ref_correct_quotient
				|| (inv_prefix == inv_dividend
				&& inv_prefix == inv_qd + inv_remainder
				&& ref_quotient == inv_coefficient[32:0]
				&& ref_div_result == inv_coefficient_corrected[32:0]))
				&& (!ref_correct_remainder
				|| (inv_prefix == inv_dividend
				&& ref_quotient == inv_coefficient[32:0]
				&& inv_prefix == inv_qd + inv_div_result))
				&& (!ref_done
				|| (ref_q_result == inv_coefficient[31:0]
				&& ref_r_result == inv_expected_remainder[31:0])));
		end
	end
`endif

`ifdef MDU_REAL_DIV_RANGE_CHECK
	always @(posedge clock) begin
		if (!reset && normal_division) begin
			assert((!ref_cycle_body
				|| (inv_current_remainder_in_range
				&& inv_body_digit_matches))
				&& (!(ref_check_remainder || ref_correct_quotient)
				|| inv_current_remainder_in_range)
				&& (!ref_done
				|| (inv_remainder_in_range
				&& inv_remainder_sign_ok
				&& inv_quotient_sign_ok)));
		end
	end
`endif

`ifndef MDU_REAL_DIV_REFERENCE_ONLY
	genvar special_bit;
	generate
		for (special_bit = 0; special_bit < 32; special_bit = special_bit + 1) begin : g_special_bit
			always @(posedge clock) begin
				if (!reset && pair_done && tracked_rs2 == 32'h0) begin
					assert(q_result[special_bit] == 1'b1);
					assert(r_result[special_bit] == tracked_rs1[special_bit]);
				end
				if (!reset && pair_done && CHECK_SIGNED && signed_overflow) begin
					assert(q_result[special_bit] == (special_bit == 31));
					assert(r_result[special_bit] == 1'b0);
				end
			end
		end
	endgenerate
`endif

	always @(posedge clock) begin
		if (!reset) begin
			cover(issue_now);
`ifdef MDU_REAL_STRICT_COMPLETION_COVER
			cover(ref_done && normal_division);
`endif
`ifndef MDU_REAL_DIV_REFERENCE_ONLY
			cover(q_done && r_done && tracked_rs2 != 32'h0);
			cover(q_done && r_done && tracked_rs2 == 32'h0);
`ifdef MDU_REAL_DIVREM_SIGNED_FULL
			cover(q_done && r_done && signed_overflow);
`endif
`endif
		end
	end
endmodule
`endif
`endif

`ifdef MDU_REAL_DIVREM_FULL
`undef MDU_REAL_DIVREM_FULL
`endif
`ifdef MDU_REAL_SPECIALIZED_FULL
`undef MDU_REAL_SPECIALIZED_FULL
`endif
`ifdef MDU_REAL_DIV_REFERENCE_ONLY
`undef MDU_REAL_DIV_REFERENCE_ONLY
`endif
`ifdef MDU_REAL_MUL_REFERENCE_ONLY
`undef MDU_REAL_MUL_REFERENCE_ONLY
`endif
