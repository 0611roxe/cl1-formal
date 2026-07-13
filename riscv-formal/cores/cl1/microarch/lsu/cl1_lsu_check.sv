module cl1_lsu_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_in_req_valid;
	(* anyseq *) reg [3:0]  io_in_req_bits_memType;
	(* anyseq *) reg [31:0] io_in_req_bits_addr;
	(* anyseq *) reg [31:0] io_in_req_bits_wdata;
	(* anyseq *) reg        io_in_resp_ready;
	(* anyseq *) reg        io_out_req_ready;
	(* anyseq *) reg        io_out_rsp_valid;
	(* anyseq *) reg [31:0] io_out_rsp_bits_data;
	(* anyseq *) reg        io_out_rsp_bits_err;

	wire        io_in_req_ready;
	wire        io_in_resp_valid;
	wire [31:0] io_in_resp_bits_rdata;
	wire [3:0]  io_in_resp_bits_err;
	wire        io_memNotOutStanding;
	wire        io_out_req_valid;
	wire [31:0] io_out_req_bits_addr;
	wire [31:0] io_out_req_bits_data;
	wire        io_out_req_bits_wen;
	wire [3:0]  io_out_req_bits_mask;
	wire        io_out_req_bits_cache;
	wire [1:0]  io_out_req_bits_size;
	wire        io_out_rsp_ready;

	Cl1LSU dut (
		.clock(clock),
		.reset(reset),
		.io_in_req_ready(io_in_req_ready),
		.io_in_req_valid(io_in_req_valid),
		.io_in_req_bits_memType(io_in_req_bits_memType),
		.io_in_req_bits_addr(io_in_req_bits_addr),
		.io_in_req_bits_wdata(io_in_req_bits_wdata),
		.io_in_resp_ready(io_in_resp_ready),
		.io_in_resp_valid(io_in_resp_valid),
		.io_in_resp_bits_rdata(io_in_resp_bits_rdata),
		.io_in_resp_bits_err(io_in_resp_bits_err),
		.io_memNotOutStanding(io_memNotOutStanding),
		.io_out_req_ready(io_out_req_ready),
		.io_out_req_valid(io_out_req_valid),
		.io_out_req_bits_addr(io_out_req_bits_addr),
		.io_out_req_bits_data(io_out_req_bits_data),
		.io_out_req_bits_wen(io_out_req_bits_wen),
		.io_out_req_bits_mask(io_out_req_bits_mask),
		.io_out_req_bits_cache(io_out_req_bits_cache),
		.io_out_req_bits_size(io_out_req_bits_size),
		.io_out_rsp_ready(io_out_rsp_ready),
		.io_out_rsp_valid(io_out_rsp_valid),
		.io_out_rsp_bits_data(io_out_rsp_bits_data),
		.io_out_rsp_bits_err(io_out_rsp_bits_err)
	);

	localparam [3:0] MEM_LB  = 4'h2;
	localparam [3:0] MEM_LBU = 4'h3;
	localparam [3:0] MEM_LH  = 4'h4;
	localparam [3:0] MEM_LHU = 4'h5;
	localparam [3:0] MEM_LW  = 4'h6;
	localparam [3:0] MEM_SB  = 4'hA;
	localparam [3:0] MEM_SH  = 4'hC;
	localparam [3:0] MEM_SW  = 4'hE;

	function legal_lsu_mem_type;
		input [3:0] mem_type;
		begin
			case (mem_type)
			MEM_LB, MEM_LBU, MEM_LH, MEM_LHU, MEM_LW,
			MEM_SB, MEM_SH, MEM_SW: legal_lsu_mem_type = 1'b1;
			default: legal_lsu_mem_type = 1'b0;
			endcase
		end
	endfunction

	function [3:0] expected_mask;
		input [1:0] addr_lsb;
		input [3:0] mem_type;
		begin
			case ({addr_lsb, mem_type[2:1]})
			4'b0001: expected_mask = 4'b0001;
			4'b0101: expected_mask = 4'b0010;
			4'b1001: expected_mask = 4'b0100;
			4'b1101: expected_mask = 4'b1000;
			4'b0010: expected_mask = 4'b0011;
			4'b1010: expected_mask = 4'b1100;
			4'b0011: expected_mask = 4'b1111;
			default: expected_mask = 4'b0000;
			endcase
		end
	endfunction

	function [1:0] expected_size;
		input [3:0] mem_type;
		begin
			case (mem_type[2:1])
			2'b01: expected_size = 2'h0;
			2'b10: expected_size = 2'h1;
			2'b11: expected_size = 2'h2;
			default: expected_size = 2'h0;
			endcase
		end
	endfunction

	function [31:0] expected_wdata;
		input [3:0]  mask;
		input [31:0] wdata;
		begin
			case (mask)
			4'b1111: expected_wdata = wdata;
			4'b1100: expected_wdata = {wdata[15:0], 16'h0};
			4'b0011: expected_wdata = wdata;
			4'b1000: expected_wdata = {wdata[7:0], 24'h0};
			4'b0100: expected_wdata = {8'h0, wdata[7:0], 16'h0};
			4'b0010: expected_wdata = {16'h0, wdata[7:0], 8'h0};
			4'b0001: expected_wdata = wdata;
			default: expected_wdata = 32'h0;
			endcase
		end
	endfunction

	function [7:0] select_byte;
		input [3:0]  mask;
		input [31:0] rdata;
		begin
			case (mask)
			4'b0001: select_byte = rdata[7:0];
			4'b0010: select_byte = rdata[15:8];
			4'b0100: select_byte = rdata[23:16];
			4'b1000: select_byte = rdata[31:24];
			default: select_byte = 8'h00;
			endcase
		end
	endfunction

	function [15:0] select_half;
		input [3:0]  mask;
		input [31:0] rdata;
		begin
			select_half = mask[1:0] == 2'b11 ? rdata[15:0] : rdata[31:16];
		end
	endfunction

	function [31:0] expected_rdata;
		input [3:0]  mem_type;
		input [3:0]  mask;
		input [31:0] rdata;
		reg [7:0] one_byte;
		reg [15:0] two_bytes;
		begin
			one_byte = select_byte(mask, rdata);
			two_bytes = select_half(mask, rdata);
			case (mem_type[2:0])
			3'b010: expected_rdata = {{24{one_byte[7]}}, one_byte};
			3'b011: expected_rdata = {24'h0, one_byte};
			3'b100: expected_rdata = {{16{two_bytes[15]}}, two_bytes};
			3'b101: expected_rdata = {16'h0, two_bytes};
			3'b110: expected_rdata = rdata;
			default: expected_rdata = 32'h0;
			endcase
		end
	endfunction

	function expected_cacheable;
		input [31:0] addr;
		begin
			expected_cacheable = addr[31] & (addr < 32'h81000000);
		end
	endfunction

	wire in_req_fire = io_in_req_valid & io_in_req_ready;
	wire in_resp_fire = io_in_resp_valid & io_in_resp_ready;
	wire out_req_fire = io_out_req_valid & io_out_req_ready;
	wire out_rsp_fire = io_out_rsp_valid & io_out_rsp_ready;
	wire [3:0] req_mask = expected_mask(io_in_req_bits_addr[1:0],
		io_in_req_bits_memType);

	reg outstanding = 1'b0;
	reg [3:0] tracked_mem_type = 4'h0;
	reg [3:0] tracked_mask = 4'h0;

	always @(posedge clock) begin
		if (reset) begin
			outstanding <= 1'b0;
			tracked_mem_type <= 4'h0;
			tracked_mask <= 4'h0;
		end else begin
			if (in_req_fire) begin
				tracked_mem_type <= io_in_req_bits_memType;
				tracked_mask <= req_mask;
			end

			if (out_req_fire | out_rsp_fire)
				outstanding <= out_req_fire | !out_rsp_fire;
		end
	end

	always @* begin
		assume(!io_in_req_valid || legal_lsu_mem_type(io_in_req_bits_memType));
	end

	always @(posedge clock) begin
		if (past_valid && !$past(reset)) begin
			if ($past(io_in_req_valid & !io_in_req_ready)) begin
				assume(io_in_req_valid);
				assume(io_in_req_bits_memType == $past(io_in_req_bits_memType));
				assume(io_in_req_bits_addr == $past(io_in_req_bits_addr));
				assume(io_in_req_bits_wdata == $past(io_in_req_bits_wdata));
			end

			if ($past(io_out_rsp_valid & !io_out_rsp_ready)) begin
				assume(io_out_rsp_valid);
				assume(io_out_rsp_bits_data == $past(io_out_rsp_bits_data));
				assume(io_out_rsp_bits_err == $past(io_out_rsp_bits_err));
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert(out_req_fire == in_req_fire);
			if (io_out_req_valid) begin
				assert(io_in_req_valid);
				assert(io_out_req_bits_addr == io_in_req_bits_addr);
				assert(io_out_req_bits_wen == io_in_req_bits_memType[3]);
				assert(io_out_req_bits_mask == req_mask);
				assert(io_out_req_bits_size == expected_size(io_in_req_bits_memType));
				assert(io_out_req_bits_data == expected_wdata(req_mask,
					io_in_req_bits_wdata));
				assert(io_out_req_bits_cache == expected_cacheable(io_in_req_bits_addr));
			end

			if (outstanding & !out_rsp_fire)
				assert(!out_req_fire);

			assert(io_memNotOutStanding == (!outstanding | out_rsp_fire));

			if (io_in_resp_valid) begin
				assert(io_out_rsp_valid);
				assert(outstanding);
				assert(io_in_resp_bits_err == {3'b000, io_out_rsp_bits_err});
				assert(io_in_resp_bits_rdata == expected_rdata(tracked_mem_type,
					tracked_mask, io_out_rsp_bits_data));
			end

			if (out_rsp_fire & !io_in_resp_valid)
				assert(!outstanding);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(in_req_fire);
			cover(out_req_fire);
			cover(io_out_req_valid & !io_out_req_ready);
			cover(io_in_resp_valid);
			cover(out_rsp_fire);
			cover(io_in_req_valid & io_in_req_bits_memType == MEM_LB);
			cover(io_in_req_valid & io_in_req_bits_memType == MEM_LHU);
			cover(io_in_req_valid & io_in_req_bits_memType == MEM_SW);
			cover(outstanding & out_rsp_fire & out_req_fire);
		end
	end

endmodule
