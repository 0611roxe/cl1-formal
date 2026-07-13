module cl1_excp_ctrl_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg        io_ext_irq;
	(* anyseq *) reg        io_sft_irq;
	(* anyseq *) reg        io_tmr_irq;
	(* anyseq *) reg [31:0] io_next_pc;
	(* anyseq *) reg        io_dx_valid;
	(* anyseq *) reg        io_excp2Csr_meie;
	(* anyseq *) reg        io_excp2Csr_msie;
	(* anyseq *) reg        io_excp2Csr_mtie;
	(* anyseq *) reg        io_excp2Csr_mie;
	(* anyseq *) reg [31:0] io_excp2Csr_mepc;
	(* anyseq *) reg [31:0] io_excp2Csr_mcause;
	(* anyseq *) reg [31:0] io_excp2Csr_mtvec;
	(* anyseq *) reg        io_dbg2excp_ebrk_excp_en;
	(* anyseq *) reg        io_wb2Excp_cmt_ecall;
	(* anyseq *) reg        io_wb2Excp_cmt_mret;
	(* anyseq *) reg        io_wb2Excp_cmt_wfi;
	(* anyseq *) reg        io_wb2Excp_wb_valid;
	(* anyseq *) reg [31:0] io_wb2Excp_wb_pc;
	(* anyseq *) reg        io_wb2Excp_excp_valid;
	(* anyseq *) reg [7:0]  io_wb2Excp_excp_code;
	(* anyseq *) reg [31:0] io_wb2Excp_excp_tval;

	wire        io_flush;
	wire [31:0] io_flush_pc;
	wire [31:0] io_flush_ofst;
	wire        io_ifu_stall;
	wire        io_dxu_stall;
	wire        io_ifu_halt;
	wire        io_dxu_halt;
	wire        io_excp2Csr_ext_irq;
	wire        io_excp2Csr_sft_irq;
	wire        io_excp2Csr_tmr_irq;
	wire        io_excp2Csr_cmt_epc_en;
	wire [31:0] io_excp2Csr_cmt_epc_n;
	wire        io_excp2Csr_cmt_status_en;
	wire        io_excp2Csr_cmt_cause_en;
	wire [31:0] io_excp2Csr_cmt_cause_n;
	wire        io_excp2Csr_cmt_tval_en;
	wire [31:0] io_excp2Csr_cmt_tval_n;
	wire        io_excp2Csr_cmt_mret_en;
	wire        trap_req_bore;
	wire        intr_taken_bore;
	wire [31:0] excp_flush_pc_bore;
	wire [5:0]  excp_flush_ofst_bore;
	wire        cmt_epc_en_bore;
	wire        cmt_cause_en_bore;
	wire        cmt_tval_en_bore;
	wire        cmt_status_en_bore;
	wire [31:0] cmt_epc_n_bore;
	wire [31:0] cmt_cause_n_bore;
	wire [31:0] cmt_tval_n_bore;

	Cl1EXCP dut (
		.clock(clock),
		.reset(reset),
		.io_ext_irq(io_ext_irq),
		.io_sft_irq(io_sft_irq),
		.io_tmr_irq(io_tmr_irq),
		.io_flush(io_flush),
		.io_flush_pc(io_flush_pc),
		.io_flush_ofst(io_flush_ofst),
		.io_next_pc(io_next_pc),
		.io_dx_valid(io_dx_valid),
		.io_ifu_stall(io_ifu_stall),
		.io_dxu_stall(io_dxu_stall),
		.io_ifu_halt(io_ifu_halt),
		.io_dxu_halt(io_dxu_halt),
		.io_excp2Csr_ext_irq(io_excp2Csr_ext_irq),
		.io_excp2Csr_sft_irq(io_excp2Csr_sft_irq),
		.io_excp2Csr_tmr_irq(io_excp2Csr_tmr_irq),
		.io_excp2Csr_meie(io_excp2Csr_meie),
		.io_excp2Csr_msie(io_excp2Csr_msie),
		.io_excp2Csr_mtie(io_excp2Csr_mtie),
		.io_excp2Csr_mie(io_excp2Csr_mie),
		.io_excp2Csr_mepc(io_excp2Csr_mepc),
		.io_excp2Csr_mcause(io_excp2Csr_mcause),
		.io_excp2Csr_mtvec(io_excp2Csr_mtvec),
		.io_excp2Csr_cmt_epc_en(io_excp2Csr_cmt_epc_en),
		.io_excp2Csr_cmt_epc_n(io_excp2Csr_cmt_epc_n),
		.io_excp2Csr_cmt_status_en(io_excp2Csr_cmt_status_en),
		.io_excp2Csr_cmt_cause_en(io_excp2Csr_cmt_cause_en),
		.io_excp2Csr_cmt_cause_n(io_excp2Csr_cmt_cause_n),
		.io_excp2Csr_cmt_tval_en(io_excp2Csr_cmt_tval_en),
		.io_excp2Csr_cmt_tval_n(io_excp2Csr_cmt_tval_n),
		.io_excp2Csr_cmt_mret_en(io_excp2Csr_cmt_mret_en),
		.io_dbg2excp_ebrk_excp_en(io_dbg2excp_ebrk_excp_en),
		.io_wb2Excp_cmt_ecall(io_wb2Excp_cmt_ecall),
		.io_wb2Excp_cmt_mret(io_wb2Excp_cmt_mret),
		.io_wb2Excp_cmt_wfi(io_wb2Excp_cmt_wfi),
		.io_wb2Excp_wb_valid(io_wb2Excp_wb_valid),
		.io_wb2Excp_wb_pc(io_wb2Excp_wb_pc),
		.io_wb2Excp_excp_valid(io_wb2Excp_excp_valid),
		.io_wb2Excp_excp_code(io_wb2Excp_excp_code),
		.io_wb2Excp_excp_tval(io_wb2Excp_excp_tval),
		.trap_req_bore(trap_req_bore),
		.intr_taken_bore(intr_taken_bore),
		.excp_flush_pc_bore(excp_flush_pc_bore),
		.excp_flush_ofst_bore(excp_flush_ofst_bore),
		.cmt_epc_en_bore(cmt_epc_en_bore),
		.cmt_cause_en_bore(cmt_cause_en_bore),
		.cmt_tval_en_bore(cmt_tval_en_bore),
		.cmt_status_en_bore(cmt_status_en_bore),
		.cmt_epc_n_bore(cmt_epc_n_bore),
		.cmt_cause_n_bore(cmt_cause_n_bore),
		.cmt_tval_n_bore(cmt_tval_n_bore)
	);

	wire irq_mei = io_ext_irq & io_excp2Csr_meie;
	wire irq_msi = io_sft_irq & io_excp2Csr_msie;
	wire irq_mti = io_tmr_irq & io_excp2Csr_mtie;
	wire irq_req_raw = irq_mei | irq_msi | irq_mti;
	wire irq_req = irq_req_raw & io_excp2Csr_mie;
	wire excp_req = io_wb2Excp_cmt_ecall | io_dbg2excp_ebrk_excp_en |
		io_wb2Excp_excp_valid;
	wire dxwb_empty = !io_dx_valid & !io_wb2Excp_wb_valid;
	wire [31:0] expected_excp_cause =
		io_wb2Excp_excp_valid ? {24'h0, io_wb2Excp_excp_code} :
		io_dbg2excp_ebrk_excp_en ? 32'h00000003 :
		io_wb2Excp_cmt_ecall ? 32'h0000000B : 32'h00000000;
	wire [31:0] expected_irq_cause =
		irq_mei ? 32'h8000000B :
		irq_msi ? 32'h80000003 :
		irq_mti ? 32'h80000007 : 32'h00000000;

	always @* begin
		// Debug handling is outside this microarchitecture proof target.
		assume(!io_dbg2excp_ebrk_excp_en);

		// WB can only present one committed privileged/trap side effect at a time.
		assume(!(io_wb2Excp_cmt_ecall & io_wb2Excp_cmt_mret));
		assume(!(io_wb2Excp_cmt_ecall & io_wb2Excp_cmt_wfi));
		assume(!(io_wb2Excp_cmt_ecall & io_wb2Excp_excp_valid));
		assume(!(io_wb2Excp_cmt_mret & io_wb2Excp_cmt_wfi));
		assume(!(io_wb2Excp_cmt_mret & io_wb2Excp_excp_valid));
		assume(!(io_wb2Excp_cmt_wfi & io_wb2Excp_excp_valid));

		assume(!io_wb2Excp_cmt_ecall || io_wb2Excp_wb_valid);
		assume(!io_wb2Excp_cmt_mret || io_wb2Excp_wb_valid);
		assume(!io_wb2Excp_cmt_wfi || io_wb2Excp_wb_valid);
		assume(!io_wb2Excp_excp_valid || io_wb2Excp_wb_valid);
	end

	always @(posedge clock) begin
		if (!reset) begin
			assert(io_excp2Csr_ext_irq == io_ext_irq);
			assert(io_excp2Csr_sft_irq == io_sft_irq);
			assert(io_excp2Csr_tmr_irq == io_tmr_irq);

			assert(io_dxu_stall == excp_req);
			assert(trap_req_bore == excp_req);
			assert(io_excp2Csr_cmt_mret_en == io_wb2Excp_cmt_mret);

			assert(cmt_epc_en_bore == io_excp2Csr_cmt_epc_en);
			assert(cmt_cause_en_bore == io_excp2Csr_cmt_cause_en);
			assert(cmt_tval_en_bore == io_excp2Csr_cmt_tval_en);
			assert(cmt_status_en_bore == io_excp2Csr_cmt_status_en);
			assert(cmt_epc_n_bore == io_excp2Csr_cmt_epc_n);
			assert(cmt_cause_n_bore == io_excp2Csr_cmt_cause_n);
			assert(cmt_tval_n_bore == io_excp2Csr_cmt_tval_n);
			assert(excp_flush_pc_bore == io_flush_pc);
			assert({26'h0, excp_flush_ofst_bore} == io_flush_ofst);

			assert(io_excp2Csr_cmt_epc_en == io_excp2Csr_cmt_status_en);
			assert(io_excp2Csr_cmt_epc_en == io_excp2Csr_cmt_cause_en);
			assert(io_excp2Csr_cmt_epc_en == io_excp2Csr_cmt_tval_en);

			if (excp_req) begin
				assert(io_excp2Csr_cmt_epc_en);
				assert(io_excp2Csr_cmt_epc_n == io_wb2Excp_wb_pc);
				assert(io_excp2Csr_cmt_cause_n == expected_excp_cause);
				if (io_wb2Excp_excp_valid)
					assert(io_excp2Csr_cmt_tval_n == io_wb2Excp_excp_tval);
				else
					assert(io_excp2Csr_cmt_tval_n == 32'h0);
			end

			if (intr_taken_bore) begin
				assert(!excp_req);
				assert(irq_req);
				assert(dxwb_empty);
				assert(io_excp2Csr_cmt_epc_en);
				assert(io_excp2Csr_cmt_epc_n == io_next_pc);
				assert(io_excp2Csr_cmt_cause_n == expected_irq_cause);
				assert(io_excp2Csr_cmt_tval_n == 32'h0);
			end

			if (!excp_req && !intr_taken_bore)
				assert(!io_excp2Csr_cmt_epc_en);

			if (io_wb2Excp_cmt_wfi & !irq_req_raw) begin
				assert(io_ifu_halt);
				assert(io_dxu_halt);
			end
		end
	end

	always @(posedge clock) begin
		if (!reset) begin
			cover(excp_req);
			cover(io_wb2Excp_excp_valid);
			cover(io_wb2Excp_cmt_ecall);
			cover(io_wb2Excp_cmt_mret);
			cover(io_wb2Excp_cmt_wfi);
			cover(irq_req & !dxwb_empty);
			cover(intr_taken_bore);
			cover(io_flush);
		end
	end

endmodule
