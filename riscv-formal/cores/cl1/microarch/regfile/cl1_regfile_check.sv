module cl1_regfile_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg [4:0]  io_readAddrA;
	(* anyseq *) reg [4:0]  io_readAddrB;
	(* anyseq *) reg        io_wen;
	(* anyseq *) reg [4:0]  io_writeAddr;
	(* anyseq *) reg [31:0] io_writeData;

	wire [31:0] io_readDataA;
	wire [31:0] io_readDataB;
	wire [31:0] io_x1_val;

	Cl1RegFile dut (
		.clock(clock),
		.io_readAddrA(io_readAddrA),
		.io_readAddrB(io_readAddrB),
		.io_readDataA(io_readDataA),
		.io_readDataB(io_readDataB),
		.io_wen(io_wen),
		.io_writeAddr(io_writeAddr),
		.io_writeData(io_writeData),
		.io_x1_val(io_x1_val)
	);

	always @(posedge clock) begin
		if (!reset) begin
			if (io_readAddrA == 5'h0)
				assert(io_readDataA == 32'h0);
			if (io_readAddrB == 5'h0)
				assert(io_readDataB == 32'h0);

			if (io_readAddrA == io_readAddrB)
				assert(io_readDataA == io_readDataB);

			if (io_readAddrA == 5'h1)
				assert(io_readDataA == io_x1_val);
			if (io_readAddrB == 5'h1)
				assert(io_readDataB == io_x1_val);

			if (past_valid && !$past(reset)) begin
				if ($past(io_wen && io_writeAddr != 5'h0) &&
						io_readAddrA == $past(io_writeAddr))
					assert(io_readDataA == $past(io_writeData));
				if ($past(io_wen && io_writeAddr != 5'h0) &&
						io_readAddrB == $past(io_writeAddr))
					assert(io_readDataB == $past(io_writeData));
				if ($past(io_wen && io_writeAddr == 5'h1))
					assert(io_x1_val == $past(io_writeData));

				if ($past(io_wen && io_writeAddr == 5'h0)) begin
					if (io_readAddrA == 5'h0)
						assert(io_readDataA == 32'h0);
					if (io_readAddrB == 5'h0)
						assert(io_readDataB == 32'h0);
				end
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(io_readAddrA == 5'h0 && io_readDataA == 32'h0);
			cover(io_readAddrB == 5'h0 && io_readDataB == 32'h0);
			cover(io_wen && io_writeAddr == 5'h0);
			cover(io_wen && io_writeAddr == 5'h1);
			cover(io_wen && io_writeAddr != 5'h0 && io_writeAddr != 5'h1);
			cover(past_valid && $past(io_wen && io_writeAddr != 5'h0) &&
				io_readAddrA == $past(io_writeAddr));
			cover(io_readAddrA == io_readAddrB && io_readAddrA != 5'h0);
			cover(io_readAddrA == 5'h1 && io_readDataA == io_x1_val);
		end
	end

endmodule
