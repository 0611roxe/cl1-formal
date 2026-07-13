module cl1_mdu_altops_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	wire reset = !past_valid;

	(* anyseq *) reg        io_in_valid;
	(* anyseq *) reg [31:0] io_in_bits_rs1;
	(* anyseq *) reg [31:0] io_in_bits_rs2;
	(* anyseq *) reg [3:0]  io_in_bits_op;
	(* anyseq *) reg        io_in_bits_is_div;
	(* anyseq *) reg        io_in_bits_flush;
	(* anyseq *) reg        io_out_ready;

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

	function automatic [31:0] altops_mask;
		input       is_div;
		input [3:0] op;
		begin
			if (!is_div) begin
				case (op)
				4'b0001: altops_mask = 32'h5876063e;
				4'b0010: altops_mask = 32'hf6583fb7;
				4'b0100: altops_mask = 32'hecfbe137;
				default: altops_mask = 32'h949ce5e8;
				endcase
			end else begin
				case (op)
				4'b0001: altops_mask = 32'h7f8529ec;
				4'b0010: altops_mask = 32'h8da68fa5;
				4'b0100: altops_mask = 32'h10e8fd70;
				default: altops_mask = 32'h3138d0e1;
				endcase
			end
		end
	endfunction

	function automatic [31:0] altops_result;
		input [31:0] rs1;
		input [31:0] rs2;
		input [3:0]  op;
		input        is_div;
		reg [31:0] base;
		begin
			base = (is_div || (!is_div && op[2])) ? rs1 - rs2 : rs1 + rs2;
			altops_result = base ^ altops_mask(is_div, op);
		end
	endfunction

	wire legal_req = legal_mdu_op(io_in_bits_op);
	wire div_by_zero_req =
		io_in_valid && !io_in_bits_flush && io_in_bits_is_div
		&& legal_req && io_in_bits_rs2 == 32'h0;

	reg        active = 1'b0;
	reg [31:0] tracked_rs1 = 32'h0;
	reg [31:0] tracked_rs2 = 32'h0;
	reg [3:0]  tracked_op = 4'h0;
	reg        tracked_is_div = 1'b0;

	wire active_done = active && io_out_valid && io_out_ready;
	wire start_req =
		!active && io_in_valid && !io_in_bits_flush && legal_req
		&& !(io_in_bits_is_div && io_in_bits_rs2 == 32'h0);

	always @(posedge clock) begin
		if (reset || io_in_bits_flush) begin
			active <= 1'b0;
			tracked_rs1 <= 32'h0;
			tracked_rs2 <= 32'h0;
			tracked_op <= 4'h0;
			tracked_is_div <= 1'b0;
		end else begin
			if (start_req) begin
				active <= !active_done;
				tracked_rs1 <= io_in_bits_rs1;
				tracked_rs2 <= io_in_bits_rs2;
				tracked_op <= io_in_bits_op;
				tracked_is_div <= io_in_bits_is_div;
			end else if (active_done) begin
				active <= 1'b0;
			end
		end
	end

	always @* begin
		assume(!io_in_valid || legal_req);
		assume(!io_in_valid || !io_in_bits_is_div || io_in_bits_rs2 == 32'h0);
		if (active) begin
			assume(!io_in_bits_flush);
			assume(io_in_bits_rs1 == tracked_rs1);
			assume(io_in_bits_rs2 == tracked_rs2);
			assume(io_in_bits_op == tracked_op);
			assume(io_in_bits_is_div == tracked_is_div);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			if (active && io_out_valid)
				assert(io_out_bits == altops_result(tracked_rs1,
					tracked_rs2, tracked_op, tracked_is_div));

			if (div_by_zero_req && !active) begin
				assert(io_out_valid);
				assert(io_out_bits == altops_result(io_in_bits_rs1,
					io_in_bits_rs2, io_in_bits_op, io_in_bits_is_div));
			end

			if ($past(active && io_out_valid && !io_out_ready && !io_in_bits_flush)) begin
				assert(io_out_valid);
				assert(active);
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(start_req && !io_in_bits_is_div);
			cover(div_by_zero_req && !active);
			cover(active && io_out_valid && io_out_ready && !tracked_is_div);
			cover(active && io_out_valid && !io_out_ready);
		end
	end
endmodule
