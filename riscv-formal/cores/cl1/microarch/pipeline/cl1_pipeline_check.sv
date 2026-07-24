`ifdef CL1_PIPELINE_BASE
module cl1_pipeline_base(
	input  clock,
	output reset,
	output trap_req_bore,
	output intr_taken_bore
);
	reg past_valid = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;
	assign reset = !past_valid;

	(* anyseq *) reg        io_ext_irq;
	(* anyseq *) reg        io_sft_irq;
	(* anyseq *) reg        io_tmr_irq;
	(* anyseq *) reg        io_master_aw_ready;
	(* anyseq *) reg        io_master_w_ready;
	(* anyseq *) reg        io_master_b_valid;
	(* anyseq *) reg [1:0]  io_master_b_bits_bresp;
	(* anyseq *) reg        io_master_ar_ready;
	(* anyseq *) reg        io_master_r_valid;
	(* anyseq *) reg [1:0]  io_master_r_bits_rresp;
	(* anyseq *) reg [31:0] io_master_r_bits_rdata;
	(* anyseq *) reg        io_master_r_bits_rlast;

	Cl1Core dut (
		.clock(clock),
		.reset(reset),
		.io_dbg_req_i(1'b0),
		.io_ext_irq(io_ext_irq),
		.io_sft_irq(io_sft_irq),
		.io_tmr_irq(io_tmr_irq),
		.io_master_aw_ready(io_master_aw_ready),
		.io_master_w_ready(io_master_w_ready),
		.io_master_b_valid(io_master_b_valid),
		.io_master_b_bits_bresp(io_master_b_bits_bresp),
		.io_master_ar_ready(io_master_ar_ready),
		.io_master_r_valid(io_master_r_valid),
		.io_master_r_bits_rresp(io_master_r_bits_rresp),
		.io_master_r_bits_rdata(io_master_r_bits_rdata),
		.io_master_r_bits_rlast(io_master_r_bits_rlast),
		.trap_req_bore(trap_req_bore),
		.intr_taken_bore(intr_taken_bore)
	);
endmodule
`endif

`ifdef CL1_PIPELINE_POST
module cl1_pipeline_check(input clock);
	wire reset;
	wire trap_req_bore;
	wire intr_taken_bore;
	wire uarch_if_out_valid;
	wire uarch_if_out_ready;
	wire [115:0] uarch_if_out_payload;
	wire uarch_dx_in_valid;
	wire uarch_dx_in_ready;
	wire [115:0] uarch_dx_in_payload;
	wire uarch_dx_out_valid;
	wire uarch_dx_out_ready;
	wire [199:0] uarch_dx_out_payload;
	wire uarch_wb_in_valid;
	wire uarch_wb_in_ready;
	wire [199:0] uarch_wb_in_payload;
	wire uarch_irq_drain_stall;
	wire uarch_pipe_flush;

	cl1_pipeline_base dut (
		.clock(clock),
		.reset(reset),
		.trap_req_bore(trap_req_bore),
		.intr_taken_bore(intr_taken_bore),
		.uarch_if_out_valid(uarch_if_out_valid),
		.uarch_if_out_ready(uarch_if_out_ready),
		.uarch_if_out_payload(uarch_if_out_payload),
		.uarch_dx_in_valid(uarch_dx_in_valid),
		.uarch_dx_in_ready(uarch_dx_in_ready),
		.uarch_dx_in_payload(uarch_dx_in_payload),
		.uarch_dx_out_valid(uarch_dx_out_valid),
		.uarch_dx_out_ready(uarch_dx_out_ready),
		.uarch_dx_out_payload(uarch_dx_out_payload),
		.uarch_wb_in_valid(uarch_wb_in_valid),
		.uarch_wb_in_ready(uarch_wb_in_ready),
		.uarch_wb_in_payload(uarch_wb_in_payload),
		.uarch_irq_drain_stall(uarch_irq_drain_stall),
		.uarch_pipe_flush(uarch_pipe_flush)
	);

	reg past_valid = 1'b0;
	reg saw_busy_in_drain = 1'b0;
	always @(posedge clock)
		past_valid <= 1'b1;

	always @(posedge clock) begin
		if (reset || !uarch_irq_drain_stall || intr_taken_bore)
			saw_busy_in_drain <= 1'b0;
		else if (uarch_dx_in_valid | uarch_wb_in_valid)
			saw_busy_in_drain <= 1'b1;
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert(uarch_if_out_ready == uarch_dx_in_ready);
			assert(uarch_dx_out_ready == uarch_wb_in_ready);

			if (past_valid && !$past(reset)) begin
				// IF -> IDEX: flush clears valid, ready transfers one entry,
				// and backpressure holds valid and payload.
				if ($past(uarch_pipe_flush)) begin
					assert(!uarch_dx_in_valid);
				end else if ($past(uarch_dx_in_ready)) begin
					assert(uarch_dx_in_valid == $past(uarch_if_out_valid));
					if ($past(uarch_if_out_valid))
						assert(uarch_dx_in_payload ==
							$past(uarch_if_out_payload));
					else
						assert(uarch_dx_in_payload ==
							$past(uarch_dx_in_payload));
				end else begin
					assert(uarch_dx_in_valid == $past(uarch_dx_in_valid));
					assert(uarch_dx_in_payload == $past(uarch_dx_in_payload));
				end

				// IDEX -> WB: ready transfers one entry and backpressure
				// holds valid and payload.
				if ($past(uarch_wb_in_ready)) begin
					assert(uarch_wb_in_valid == $past(uarch_dx_out_valid));
					if ($past(uarch_dx_out_valid))
						assert(uarch_wb_in_payload ==
							$past(uarch_dx_out_payload));
					else
						assert(uarch_wb_in_payload ==
							$past(uarch_wb_in_payload));
				end else begin
					assert(uarch_wb_in_valid == $past(uarch_wb_in_valid));
					assert(uarch_wb_in_payload == $past(uarch_wb_in_payload));
				end
			end

			// Interrupt acceptance requires the real downstream pipeline
			// stages to be empty, independent of the EXCP input wiring.
			if (intr_taken_bore) begin
				assert(!uarch_dx_in_valid);
				assert(!uarch_wb_in_valid);
			end

			if (past_valid && $past(intr_taken_bore))
				assert(uarch_pipe_flush);

			if (past_valid && $past(trap_req_bore & !uarch_pipe_flush))
				assert(uarch_pipe_flush);
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(past_valid & $past(uarch_if_out_valid &
				uarch_if_out_ready) & uarch_dx_in_valid);
			cover(past_valid & $past(uarch_dx_out_valid &
				uarch_dx_out_ready) & uarch_wb_in_valid);
			cover(past_valid & $past(uarch_dx_out_valid &
				!uarch_dx_out_ready) & uarch_dx_out_valid);
			cover(past_valid & $past(uarch_pipe_flush &
				uarch_dx_in_valid) & !uarch_dx_in_valid);
			cover(uarch_irq_drain_stall &
				(uarch_dx_in_valid | uarch_wb_in_valid));
			cover(intr_taken_bore);
			cover(saw_busy_in_drain & uarch_irq_drain_stall &
				intr_taken_bore);
			cover(past_valid & $past(intr_taken_bore) & uarch_pipe_flush);
			cover(trap_req_bore);
		end
	end
endmodule
`endif
