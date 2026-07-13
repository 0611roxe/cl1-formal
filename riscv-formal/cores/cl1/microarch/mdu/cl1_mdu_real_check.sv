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
