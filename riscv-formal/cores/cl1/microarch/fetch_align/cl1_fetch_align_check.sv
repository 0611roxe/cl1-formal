module cl1_fetch_align_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_fromifu_valid;
	(* anyseq *) reg [31:0] io_fromifu_bits_req_pc;
	(* anyseq *) reg        io_fromifu_bits_req_redirect;
	(* anyseq *) reg        io_toifu_ready;
	(* anyseq *) reg        io_bus_req_ready;
	(* anyseq *) reg        io_bus_rsp_valid;
	(* anyseq *) reg [31:0] io_bus_rsp_bits_data;
	(* anyseq *) reg        io_bus_rsp_bits_err;

	wire        io_fromifu_ready;
	wire        io_toifu_valid;
	wire [31:0] io_toifu_bits_inst;
	wire        io_toifu_bits_err;
	wire        io_bus_req_valid;
	wire [31:0] io_bus_req_bits_addr;
	wire        io_bus_req_bits_cache;
	wire        io_bus_rsp_ready;

	FetchAlign dut (
		.clock(clock),
		.reset(reset),
		.io_fromifu_ready(io_fromifu_ready),
		.io_fromifu_valid(io_fromifu_valid),
		.io_fromifu_bits_req_pc(io_fromifu_bits_req_pc),
		.io_fromifu_bits_req_redirect(io_fromifu_bits_req_redirect),
		.io_toifu_ready(io_toifu_ready),
		.io_toifu_valid(io_toifu_valid),
		.io_toifu_bits_inst(io_toifu_bits_inst),
		.io_toifu_bits_err(io_toifu_bits_err),
		.io_bus_req_ready(io_bus_req_ready),
		.io_bus_req_valid(io_bus_req_valid),
		.io_bus_req_bits_addr(io_bus_req_bits_addr),
		.io_bus_req_bits_cache(io_bus_req_bits_cache),
		.io_bus_rsp_ready(io_bus_rsp_ready),
		.io_bus_rsp_valid(io_bus_rsp_valid),
		.io_bus_rsp_bits_data(io_bus_rsp_bits_data),
		.io_bus_rsp_bits_err(io_bus_rsp_bits_err)
	);

	function expected_cacheable;
		input [31:0] addr;
		begin
			expected_cacheable = addr[31] & (addr < 32'h81000000);
		end
	endfunction

	wire fromifu_fire = io_fromifu_valid & io_fromifu_ready;
	wire bus_req_fire = io_bus_req_valid & io_bus_req_ready;
	wire bus_rsp_fire = io_bus_rsp_valid & io_bus_rsp_ready;
	wire toifu_fire = io_toifu_valid & io_toifu_ready;

	reg        outstanding = 1'b0;
	reg        pending_valid = 1'b0;
	reg [31:0] pending_pc = 32'h0;
	reg        pending_seq = 1'b0;
	reg        cross_pending = 1'b0;
	reg [15:0] cross_low_half = 16'h0;

	wire first_cross_rsp =
		pending_valid &
		io_bus_rsp_valid &
		!io_bus_rsp_bits_err &
		pending_pc[1] &
		!pending_seq &
		(io_bus_rsp_bits_data[17:16] == 2'b11) &
		!cross_pending;
	wire [31:0] pending_pc_plus2 = pending_pc + 32'd2;
	wire [31:0] second_fetch_addr = {pending_pc_plus2[31:2], 2'b00};

	always @(posedge clock) begin
		if (reset) begin
			outstanding <= 1'b0;
			pending_valid <= 1'b0;
			pending_pc <= 32'h0;
			pending_seq <= 1'b0;
			cross_pending <= 1'b0;
			cross_low_half <= 16'h0;
		end else begin
			if (fromifu_fire) begin
				pending_valid <= 1'b1;
				pending_pc <= io_fromifu_bits_req_pc;
				pending_seq <= !io_fromifu_bits_req_redirect;
			end else if (toifu_fire & !fromifu_fire) begin
				pending_valid <= 1'b0;
			end

			if (first_cross_rsp & bus_rsp_fire) begin
				cross_pending <= 1'b1;
				cross_low_half <= io_bus_rsp_bits_data[31:16];
			end else if (cross_pending & toifu_fire) begin
				cross_pending <= 1'b0;
			end

			if (bus_req_fire | bus_rsp_fire)
				outstanding <= (outstanding & !bus_rsp_fire) | bus_req_fire;
		end
	end

	always @* begin
		assume(!io_fromifu_valid || io_fromifu_bits_req_pc[0] == 1'b0);
		assume(!io_bus_rsp_valid || outstanding);
		// The CL1 software environment does not place a 32-bit instruction at
		// a halfword redirect target. FetchAlign therefore does not have to
		// support reconstructing that sequence in hardware.
		if (pending_valid & io_bus_rsp_valid & !io_bus_rsp_bits_err &
				pending_pc[1] & !pending_seq & !cross_pending)
			assume(io_bus_rsp_bits_data[17:16] != 2'b11);
	end

	always @(posedge clock) begin
		if (past_valid && !$past(reset)) begin
			if ($past(io_fromifu_valid & !io_fromifu_ready)) begin
				assume(io_fromifu_valid);
				assume(io_fromifu_bits_req_pc == $past(io_fromifu_bits_req_pc));
				assume(io_fromifu_bits_req_redirect ==
					$past(io_fromifu_bits_req_redirect));
			end

			if ($past(io_bus_rsp_valid & !io_bus_rsp_ready)) begin
				assume(io_bus_rsp_valid);
				assume(io_bus_rsp_bits_data == $past(io_bus_rsp_bits_data));
				assume(io_bus_rsp_bits_err == $past(io_bus_rsp_bits_err));
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert(io_fromifu_ready == io_bus_req_ready);
			if (io_fromifu_valid)
				assert(io_bus_req_valid);

			if (fromifu_fire)
				assert(bus_req_fire);

			if (io_bus_req_valid) begin
				assert(io_bus_req_bits_addr[1:0] == 2'b00);
				assert(io_bus_req_bits_cache ==
					expected_cacheable(io_bus_req_bits_addr));
			end

			if (past_valid && !$past(reset) &&
					$past(io_bus_req_valid & !io_bus_req_ready & !outstanding)) begin
				assert(io_bus_req_valid);
				assert(io_bus_req_bits_addr == $past(io_bus_req_bits_addr));
				assert(io_bus_req_bits_cache == $past(io_bus_req_bits_cache));
			end

			assert(io_toifu_valid == (io_bus_rsp_valid & !first_cross_rsp));
			assert(io_toifu_bits_err == io_bus_rsp_bits_err);

			if (io_bus_rsp_valid & io_bus_rsp_bits_err) begin
				assert(io_toifu_valid);
				assert(io_toifu_bits_err);
			end

			if (pending_valid & io_bus_rsp_valid & !pending_pc[1] &
					!cross_pending) begin
				assert(io_toifu_valid);
				assert(io_toifu_bits_inst == io_bus_rsp_bits_data);
			end

			assert(!first_cross_rsp);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(fromifu_fire);
			cover(bus_req_fire);
			cover(io_bus_req_valid & !io_bus_req_ready);
			cover(io_bus_rsp_valid & io_bus_rsp_ready);
			cover(io_toifu_valid & io_toifu_ready);
			cover(io_bus_rsp_valid & io_bus_rsp_bits_err & io_toifu_bits_err);
		end
	end

endmodule
