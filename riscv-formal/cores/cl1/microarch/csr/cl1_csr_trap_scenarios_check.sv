module cl1_csr_trap_scenarios_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	reg [4:0] cycle = 5'h0;
	always @(posedge clock) begin
		if (reset)
			cycle <= 5'h0;
		else
			cycle <= cycle + 5'h1;
	end

	localparam [2:0] SC_IRQ_DIRECT      = 3'd0;
	localparam [2:0] SC_IRQ_VECTOR      = 3'd1;
	localparam [2:0] SC_EXCEPTION       = 3'd2;
	localparam [2:0] SC_EXCP_OVER_IRQ   = 3'd3;
	localparam [2:0] SC_MRET            = 3'd4;
	localparam [2:0] SC_IRQ_BLOCKED     = 3'd5;
	localparam [2:0] SC_IRQ_DRAIN       = 3'd6;

	(* anyconst *) reg [2:0]  scenario;
	(* anyconst *) reg [31:0] sym_wb_pc;
	(* anyconst *) reg [31:0] sym_next_pc;
	(* anyconst *) reg [31:0] sym_mtvec_base;
	(* anyconst *) reg [31:0] sym_mret_mepc;
	(* anyconst *) reg [31:0] sym_excp_tval;
	(* anyconst *) reg [7:0]  sym_excp_code;
	(* anyconst *) reg        sym_irq_ext_pending;
	(* anyconst *) reg        sym_irq_sft_pending;
	(* anyconst *) reg        sym_irq_tmr_pending;
	(* anyconst *) reg        sym_irq_ext_enable;
	(* anyconst *) reg        sym_irq_sft_enable;
	(* anyconst *) reg        sym_irq_tmr_enable;
	(* anyconst *) reg        sym_irq_global_enable;
	(* anyconst *) reg        sym_drain_dx_busy;
	(* anyconst *) reg        sym_drain_wb_busy;
	(* anyconst *) reg        sym_drain_second_dx_busy;
	(* anyconst *) reg        sym_drain_second_wb_busy;
	(* anyconst *) reg        sym_drain_vector_mode;
	(* anyconst *) reg        sym_excp_valid_req;
	(* anyconst *) reg        sym_ecall_req;
	(* anyconst *) reg        sym_ebrk_req;
	(* anyconst *) reg        sym_pre_trap_mpie;
	(* anyconst *) reg        sym_exception_pre_mie;
	(* anyconst *) reg        sym_mret_pre_mie;
	(* anyconst *) reg        sym_mret_pre_mpie;

	localparam [31:0] MCAUSE_MSI = 32'h80000003;
	localparam [31:0] MCAUSE_MTI = 32'h80000007;
	localparam [31:0] MCAUSE_MEI = 32'h8000000B;

	wire irq_immediate_scenario =
		scenario == SC_IRQ_DIRECT ||
		scenario == SC_IRQ_VECTOR;
	wire irq_trap_scenario =
		irq_immediate_scenario ||
		scenario == SC_IRQ_DRAIN;
	wire irq_event_scenario =
		irq_trap_scenario ||
		scenario == SC_EXCP_OVER_IRQ ||
		scenario == SC_IRQ_BLOCKED;
	wire raw_irq_pending_exists =
		sym_irq_ext_pending ||
		sym_irq_sft_pending ||
		sym_irq_tmr_pending;
	wire enabled_irq_exists =
		(sym_irq_ext_pending && sym_irq_ext_enable) ||
		(sym_irq_sft_pending && sym_irq_sft_enable) ||
		(sym_irq_tmr_pending && sym_irq_tmr_enable);
	wire exception_scenario =
		scenario == SC_EXCEPTION ||
		scenario == SC_EXCP_OVER_IRQ;
	wire exception_source_exists =
		sym_excp_valid_req ||
		sym_ecall_req ||
		sym_ebrk_req;
	wire drain_first_busy =
		sym_drain_dx_busy ||
		sym_drain_wb_busy;
	wire drain_second_busy =
		sym_drain_second_dx_busy ||
		sym_drain_second_wb_busy;

	wire setup_mstatus_mie =
		(scenario == SC_MRET) ? sym_mret_pre_mie :
		(scenario == SC_EXCEPTION) ? sym_exception_pre_mie :
		(scenario == SC_IRQ_BLOCKED) ? sym_irq_global_enable :
		1'b1;
	wire setup_mstatus_mpie =
		(scenario == SC_MRET) ? sym_mret_pre_mpie : sym_pre_trap_mpie;
	wire [31:0] setup_mstatus =
		{24'h0, setup_mstatus_mpie, 3'h0, setup_mstatus_mie, 3'h0};
	wire [31:0] setup_mie =
		{20'h0, sym_irq_ext_enable, 3'h0, sym_irq_tmr_enable, 3'h0,
		 sym_irq_sft_enable, 3'h0};
	wire [31:0] setup_mtvec =
		(sym_mtvec_base & 32'hFFFFFFFC) |
		((scenario == SC_IRQ_VECTOR || (scenario == SC_IRQ_DRAIN && sym_drain_vector_mode))
		 ? 32'h00000001 : 32'h00000000);

	always @* begin
		assume(scenario <= SC_IRQ_DRAIN);
		assume(sym_wb_pc[0] == 1'b0);
		assume(sym_next_pc[0] == 1'b0);
		assume(sym_mret_mepc[0] == 1'b0);
		assume(sym_mtvec_base[1:0] == 2'b00);
		if (irq_trap_scenario || scenario == SC_EXCP_OVER_IRQ)
			assume(enabled_irq_exists);
		if (scenario == SC_IRQ_BLOCKED) begin
			assume(raw_irq_pending_exists);
			assume(!(sym_irq_global_enable && enabled_irq_exists));
		end
		if (scenario == SC_IRQ_DRAIN)
			assume(drain_first_busy);
		if (exception_scenario)
			assume(exception_source_exists);
	end

	reg [11:0] csr_rd_addr;
	reg [11:0] csr_wr_addr;
	reg [31:0] csr_wr_value;
	reg        csr_wen;

	reg        ext_irq;
	reg        sft_irq;
	reg        tmr_irq;
	reg        dx_valid;
	reg        wb_valid;
	reg [31:0] wb_pc;
	reg [31:0] next_pc;
	reg        dbg_ebrk_excp_en;
	reg        cmt_ecall;
	reg        cmt_mret;
	reg        cmt_wfi;
	reg        excp_valid;
	reg [7:0]  excp_code;
	reg [31:0] excp_tval;

	always @* begin
		csr_rd_addr = 12'h300;
		csr_wr_addr = 12'h000;
		csr_wr_value = 32'h00000000;
		csr_wen = 1'b0;

		ext_irq = 1'b0;
		sft_irq = 1'b0;
		tmr_irq = 1'b0;
		dx_valid = 1'b0;
		wb_valid = 1'b0;
		wb_pc = sym_wb_pc;
		next_pc = sym_next_pc;
		dbg_ebrk_excp_en = 1'b0;
		cmt_ecall = 1'b0;
		cmt_mret = 1'b0;
		cmt_wfi = 1'b0;
		excp_valid = 1'b0;
		excp_code = sym_excp_code;
		excp_tval = sym_excp_tval;

		case (cycle)
		5'd1: begin
			csr_wen = 1'b1;
			csr_wr_addr = 12'h300;
			csr_wr_value = setup_mstatus;
		end
		5'd2: begin
			csr_wen = 1'b1;
			if (scenario == SC_MRET) begin
				csr_wr_addr = 12'h341;
				csr_wr_value = sym_mret_mepc;
			end else begin
				csr_wr_addr = 12'h304;
				csr_wr_value = setup_mie;
			end
		end
		5'd3: begin
			if (scenario != SC_MRET) begin
				csr_wen = 1'b1;
				csr_wr_addr = 12'h305;
				csr_wr_value = setup_mtvec;
			end
		end
		default: begin
		end
		endcase

		if ((cycle == 5'd4 || cycle == 5'd5 || cycle == 5'd6)
				&& irq_event_scenario) begin
			ext_irq = sym_irq_ext_pending;
			sft_irq = sym_irq_sft_pending;
			tmr_irq = sym_irq_tmr_pending;
		end

		if (scenario == SC_IRQ_DRAIN && cycle == 5'd4) begin
			dx_valid = sym_drain_dx_busy;
			wb_valid = sym_drain_wb_busy;
		end
		if (scenario == SC_IRQ_DRAIN && cycle == 5'd5) begin
			dx_valid = sym_drain_second_dx_busy;
			wb_valid = sym_drain_second_wb_busy;
		end

		if (cycle == 5'd4) begin
			if (exception_scenario) begin
				wb_valid = 1'b1;
				excp_valid = sym_excp_valid_req;
				cmt_ecall = sym_ecall_req;
				dbg_ebrk_excp_en = sym_ebrk_req;
			end
			if (scenario == SC_MRET) begin
				wb_valid = 1'b1;
				cmt_mret = 1'b1;
			end
		end
	end

	function [31:0] expected_irq_cause;
		input ext_pending;
		input sft_pending;
		input tmr_pending;
		input ext_enable;
		input sft_enable;
		input tmr_enable;
		begin
			if (ext_pending && ext_enable)
				expected_irq_cause = MCAUSE_MEI;
			else if (sft_pending && sft_enable)
				expected_irq_cause = MCAUSE_MSI;
			else if (tmr_pending && tmr_enable)
				expected_irq_cause = MCAUSE_MTI;
			else
				expected_irq_cause = 32'h00000000;
		end
	endfunction

	wire [31:0] exp_irq_cause =
		expected_irq_cause(
			sym_irq_ext_pending, sym_irq_sft_pending, sym_irq_tmr_pending,
			sym_irq_ext_enable, sym_irq_sft_enable, sym_irq_tmr_enable);
	wire [31:0] exp_irq_ofst = {26'h0, exp_irq_cause[3:0], 2'b00};
	wire [31:0] exp_irq_drain_ofst =
		sym_drain_vector_mode ? exp_irq_ofst : 32'h00000000;
	wire [31:0] exp_mip =
		{20'h0, sym_irq_ext_pending, 3'h0, sym_irq_tmr_pending, 3'h0,
		 sym_irq_sft_pending, 3'h0};
	wire [31:0] exp_mtvec_base = sym_mtvec_base & 32'hFFFFFFFC;
	wire [31:0] exp_wb_epc = sym_wb_pc & 32'hFFFFFFFE;
	wire [31:0] exp_next_epc = sym_next_pc & 32'hFFFFFFFE;
	wire [31:0] exp_mret_pc = sym_mret_mepc & 32'hFFFFFFFE;
	wire [31:0] exp_excp_cause =
		sym_excp_valid_req ? {24'h0, sym_excp_code} :
		sym_ebrk_req ? 32'h00000003 :
		sym_ecall_req ? 32'h0000000B :
		32'h00000000;
	wire [31:0] exp_excp_tval =
		sym_excp_valid_req ? sym_excp_tval : 32'h00000000;

	wire [31:0] csr_rd_value;
	wire [31:0] dbg_dpc_r;
	wire        dbg_ebreakm_r;
	wire        dbg_step_r;
	wire        csr_meie;
	wire        csr_msie;
	wire        csr_mtie;
	wire        csr_mie;
	wire [31:0] csr_mepc;
	wire [31:0] csr_mcause;
	wire [31:0] csr_mtvec;
	wire [31:0] cur_excp_mtvec;
	wire [31:0] cur_mstatus;
	wire [31:0] cur_mie;
	wire [31:0] cur_mip;
	wire [31:0] cur_mepc;
	wire [31:0] cur_mcause;
	wire [31:0] cur_mtval;
	wire [31:0] cur_mtvec;
	wire [31:0] cur_mscratch;
	wire [31:0] cur_misa;

	wire        excp_flush;
	wire [31:0] excp_flush_pc;
	wire [31:0] excp_flush_ofst;
	wire        ifu_stall;
	wire        dxu_stall;
	wire        ifu_halt;
	wire        dxu_halt;
	wire        excp2csr_ext_irq;
	wire        excp2csr_sft_irq;
	wire        excp2csr_tmr_irq;
	wire        excp_cmt_epc_en;
	wire [31:0] excp_cmt_epc_n;
	wire        excp_cmt_status_en;
	wire        excp_cmt_cause_en;
	wire [31:0] excp_cmt_cause_n;
	wire        excp_cmt_tval_en;
	wire [31:0] excp_cmt_tval_n;
	wire        excp_cmt_mret_en;
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

	Cl1CSR csr (
		.clock(clock),
		.reset(reset),
		.io_rdAddr(csr_rd_addr),
		.io_rdValue(csr_rd_value),
		.io_wrAddr(csr_wr_addr),
		.io_wrValue(csr_wr_value),
		.io_wen(csr_wen),
		.io_dbg_intf_csr_update_en(1'b0),
		.io_dbg_intf_dpc_update(32'h00000000),
		.io_dbg_intf_dbg_cause(3'h0),
		.io_dbg_intf_dpc_r(dbg_dpc_r),
		.io_dbg_intf_ebreakm_r(dbg_ebreakm_r),
		.io_dbg_intf_step_r(dbg_step_r),
		.io_excp_intf_ext_irq(excp2csr_ext_irq),
		.io_excp_intf_sft_irq(excp2csr_sft_irq),
		.io_excp_intf_tmr_irq(excp2csr_tmr_irq),
		.io_excp_intf_meie(csr_meie),
		.io_excp_intf_msie(csr_msie),
		.io_excp_intf_mtie(csr_mtie),
		.io_excp_intf_mie(csr_mie),
		.io_excp_intf_mepc(csr_mepc),
		.io_excp_intf_mcause(csr_mcause),
		.io_excp_intf_mtvec(csr_mtvec),
		.io_excp_intf_cmt_epc_en(excp_cmt_epc_en),
		.io_excp_intf_cmt_epc_n(excp_cmt_epc_n),
		.io_excp_intf_cmt_status_en(excp_cmt_status_en),
		.io_excp_intf_cmt_cause_en(excp_cmt_cause_en),
		.io_excp_intf_cmt_cause_n(excp_cmt_cause_n),
		.io_excp_intf_cmt_tval_en(excp_cmt_tval_en),
		.io_excp_intf_cmt_tval_n(excp_cmt_tval_n),
		.io_excp_intf_cmt_mret_en(excp_cmt_mret_en),
		.cur_excp_mtvec_bore(cur_excp_mtvec),
		.cur_mstatus_bore(cur_mstatus),
		.cur_mie_bore(cur_mie),
		.cur_mip_bore(cur_mip),
		.cur_mepc_bore(cur_mepc),
		.cur_mcause_bore(cur_mcause),
		.cur_mtval_bore(cur_mtval),
		.cur_mtvec_bore(cur_mtvec),
		.cur_mscratch_bore(cur_mscratch),
		.cur_misa_bore(cur_misa)
	);

	Cl1EXCP excp (
		.clock(clock),
		.reset(reset),
		.io_ext_irq(ext_irq),
		.io_sft_irq(sft_irq),
		.io_tmr_irq(tmr_irq),
		.io_flush(excp_flush),
		.io_flush_pc(excp_flush_pc),
		.io_flush_ofst(excp_flush_ofst),
		.io_next_pc(next_pc),
		.io_dx_valid(dx_valid),
		.io_ifu_stall(ifu_stall),
		.io_dxu_stall(dxu_stall),
		.io_ifu_halt(ifu_halt),
		.io_dxu_halt(dxu_halt),
		.io_excp2Csr_ext_irq(excp2csr_ext_irq),
		.io_excp2Csr_sft_irq(excp2csr_sft_irq),
		.io_excp2Csr_tmr_irq(excp2csr_tmr_irq),
		.io_excp2Csr_meie(csr_meie),
		.io_excp2Csr_msie(csr_msie),
		.io_excp2Csr_mtie(csr_mtie),
		.io_excp2Csr_mie(csr_mie),
		.io_excp2Csr_mepc(csr_mepc),
		.io_excp2Csr_mcause(csr_mcause),
		.io_excp2Csr_mtvec(csr_mtvec),
		.io_excp2Csr_cmt_epc_en(excp_cmt_epc_en),
		.io_excp2Csr_cmt_epc_n(excp_cmt_epc_n),
		.io_excp2Csr_cmt_status_en(excp_cmt_status_en),
		.io_excp2Csr_cmt_cause_en(excp_cmt_cause_en),
		.io_excp2Csr_cmt_cause_n(excp_cmt_cause_n),
		.io_excp2Csr_cmt_tval_en(excp_cmt_tval_en),
		.io_excp2Csr_cmt_tval_n(excp_cmt_tval_n),
		.io_excp2Csr_cmt_mret_en(excp_cmt_mret_en),
		.io_dbg2excp_ebrk_excp_en(dbg_ebrk_excp_en),
		.io_wb2Excp_cmt_ecall(cmt_ecall),
		.io_wb2Excp_cmt_mret(cmt_mret),
		.io_wb2Excp_cmt_wfi(cmt_wfi),
		.io_wb2Excp_wb_valid(wb_valid),
		.io_wb2Excp_wb_pc(wb_pc),
		.io_wb2Excp_excp_valid(excp_valid),
		.io_wb2Excp_excp_code(excp_code),
		.io_wb2Excp_excp_tval(excp_tval),
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

	always @* begin
		if (past_valid && !reset) begin
			assert(cur_excp_mtvec == cur_mtvec);
			assert(csr_mepc == cur_mepc);
			assert(csr_mcause == cur_mcause);
			assert(csr_mtvec == cur_mtvec);
			assert(csr_mie == cur_mstatus[3]);
			assert(csr_meie == cur_mie[11]);
			assert(csr_msie == cur_mie[3]);
			assert(csr_mtie == cur_mie[7]);

			if (cycle == 5'd5 && irq_immediate_scenario) begin
				assert(intr_taken_bore);
				assert(!trap_req_bore);
				assert(excp_cmt_epc_en);
				assert(excp_cmt_status_en);
				assert(excp_cmt_cause_en);
				assert(excp_cmt_tval_en);
				assert(cmt_epc_en_bore);
				assert(cmt_status_en_bore);
				assert(cmt_cause_en_bore);
				assert(cmt_tval_en_bore);
				assert(excp_cmt_epc_n == exp_next_epc);
				assert(cmt_epc_n_bore == exp_next_epc);
				assert(excp_cmt_cause_n == exp_irq_cause);
				assert(cmt_cause_n_bore == exp_irq_cause);
				assert(excp_cmt_tval_n == 32'h00000000);
				assert(cmt_tval_n_bore == 32'h00000000);
			end

			if (cycle == 5'd6 && irq_immediate_scenario) begin
				assert(cur_mepc == exp_next_epc);
				assert(cur_mcause == exp_irq_cause);
				assert(cur_mtval == 32'h00000000);
				assert(cur_mstatus[3] == 1'b0);
				assert(cur_mstatus[7] == 1'b1);
				assert(excp_flush);
				assert(excp_flush_pc == exp_mtvec_base);
				assert(excp_flush_pc_bore == exp_mtvec_base);
			end

			if (cycle == 5'd6 && scenario == SC_IRQ_DIRECT) begin
				assert(excp_flush_ofst == 32'h00000000);
				assert(excp_flush_ofst_bore == 6'h00);
			end

			if (cycle == 5'd6 && scenario == SC_IRQ_VECTOR) begin
				assert(excp_flush_ofst == exp_irq_ofst);
				assert(excp_flush_ofst_bore == exp_irq_ofst[5:0]);
			end

			if ((cycle == 5'd4 || cycle == 5'd5 || cycle == 5'd6)
					&& scenario == SC_IRQ_BLOCKED) begin
				assert(!trap_req_bore);
				assert(!intr_taken_bore);
				assert(!excp_cmt_epc_en);
				assert(!excp_cmt_status_en);
				assert(!excp_cmt_cause_en);
				assert(!excp_cmt_tval_en);
				assert(!excp_flush);
			end

			if (cycle == 5'd5 && scenario == SC_IRQ_BLOCKED) begin
				assert(cur_mip == exp_mip);
				assert(cur_mepc == 32'h00000000);
				assert(cur_mcause == 32'h00000000);
				assert(cur_mtval == 32'h00000000);
			end

			if (cycle == 5'd5 && scenario == SC_IRQ_DRAIN) begin
				assert(ifu_stall);
				assert(!trap_req_bore);
				if (drain_second_busy) begin
					assert(!intr_taken_bore);
					assert(!excp_cmt_epc_en);
					assert(!excp_cmt_status_en);
					assert(!excp_cmt_cause_en);
					assert(!excp_cmt_tval_en);
					assert(!excp_flush);
				end else begin
					assert(intr_taken_bore);
					assert(excp_cmt_epc_en);
					assert(excp_cmt_status_en);
					assert(excp_cmt_cause_en);
					assert(excp_cmt_tval_en);
					assert(excp_cmt_epc_n == exp_next_epc);
					assert(excp_cmt_cause_n == exp_irq_cause);
					assert(excp_cmt_tval_n == 32'h00000000);
					assert(!excp_flush);
				end
			end

			if (cycle == 5'd6 && scenario == SC_IRQ_DRAIN) begin
				assert(!trap_req_bore);
				if (drain_second_busy) begin
					assert(intr_taken_bore);
					assert(excp_cmt_epc_en);
					assert(excp_cmt_status_en);
					assert(excp_cmt_cause_en);
					assert(excp_cmt_tval_en);
					assert(excp_cmt_epc_n == exp_next_epc);
					assert(excp_cmt_cause_n == exp_irq_cause);
					assert(excp_cmt_tval_n == 32'h00000000);
					assert(!excp_flush);
				end else begin
					assert(!intr_taken_bore);
					assert(!excp_cmt_epc_en);
					assert(!excp_cmt_status_en);
					assert(!excp_cmt_cause_en);
					assert(!excp_cmt_tval_en);
					assert(excp_flush);
					assert(excp_flush_pc == exp_mtvec_base);
					assert(excp_flush_pc_bore == exp_mtvec_base);
					assert(excp_flush_ofst == exp_irq_drain_ofst);
					assert(excp_flush_ofst_bore == exp_irq_drain_ofst[5:0]);
				end
			end

			if (cycle == 5'd7 && scenario == SC_IRQ_DRAIN) begin
				assert(cur_mepc == exp_next_epc);
				assert(cur_mcause == exp_irq_cause);
				assert(cur_mtval == 32'h00000000);
				assert(cur_mstatus[3] == 1'b0);
				assert(cur_mstatus[7] == 1'b1);
				if (drain_second_busy) begin
					assert(excp_flush);
					assert(excp_flush_pc == exp_mtvec_base);
					assert(excp_flush_pc_bore == exp_mtvec_base);
					assert(excp_flush_ofst == exp_irq_drain_ofst);
					assert(excp_flush_ofst_bore == exp_irq_drain_ofst[5:0]);
				end
			end

			if (cycle == 5'd4 && scenario == SC_EXCEPTION) begin
				assert(trap_req_bore);
				assert(!intr_taken_bore);
				assert(excp_cmt_epc_en);
				assert(excp_cmt_status_en);
				assert(excp_cmt_cause_en);
				assert(excp_cmt_tval_en);
				assert(cmt_epc_en_bore);
				assert(cmt_status_en_bore);
				assert(cmt_cause_en_bore);
				assert(cmt_tval_en_bore);
				assert(excp_cmt_epc_n == exp_wb_epc);
				assert(cmt_epc_n_bore == exp_wb_epc);
				assert(excp_cmt_cause_n == exp_excp_cause);
				assert(cmt_cause_n_bore == exp_excp_cause);
				assert(excp_cmt_tval_n == exp_excp_tval);
				assert(cmt_tval_n_bore == exp_excp_tval);
			end

			if (cycle == 5'd5 && scenario == SC_EXCEPTION) begin
				assert(cur_mepc == exp_wb_epc);
				assert(cur_mcause == exp_excp_cause);
				assert(cur_mtval == exp_excp_tval);
				assert(cur_mstatus[3] == 1'b0);
				assert(cur_mstatus[7] == sym_exception_pre_mie);
				assert(excp_flush);
				assert(excp_flush_pc == exp_mtvec_base);
				assert(excp_flush_pc_bore == exp_mtvec_base);
				assert(excp_flush_ofst == 32'h00000000);
				assert(excp_flush_ofst_bore == 6'h00);
			end

			if (cycle == 5'd4 && scenario == SC_EXCP_OVER_IRQ) begin
				assert(trap_req_bore);
				assert(!intr_taken_bore);
				assert(excp_cmt_epc_en);
				assert(excp_cmt_status_en);
				assert(excp_cmt_cause_en);
				assert(excp_cmt_tval_en);
				assert(cmt_epc_en_bore);
				assert(cmt_status_en_bore);
				assert(cmt_cause_en_bore);
				assert(cmt_tval_en_bore);
				assert(excp_cmt_epc_n == exp_wb_epc);
				assert(cmt_epc_n_bore == exp_wb_epc);
				assert(excp_cmt_cause_n == exp_excp_cause);
				assert(cmt_cause_n_bore == exp_excp_cause);
				assert(excp_cmt_tval_n == exp_excp_tval);
				assert(cmt_tval_n_bore == exp_excp_tval);
			end

			if (cycle == 5'd5 && scenario == SC_EXCP_OVER_IRQ) begin
				assert(cur_mepc == exp_wb_epc);
				assert(cur_mcause == exp_excp_cause);
				assert(cur_mtval == exp_excp_tval);
				assert(cur_mstatus[3] == 1'b0);
				assert(cur_mstatus[7] == 1'b1);
				assert(excp_flush);
				assert(excp_flush_pc == exp_mtvec_base);
				assert(excp_flush_pc_bore == exp_mtvec_base);
				assert(excp_flush_ofst == 32'h00000000);
				assert(excp_flush_ofst_bore == 6'h00);
			end

			if (cycle == 5'd4 && scenario == SC_MRET) begin
				assert(!trap_req_bore);
				assert(!intr_taken_bore);
				assert(!excp_cmt_epc_en);
				assert(!excp_cmt_status_en);
				assert(!excp_cmt_cause_en);
				assert(!excp_cmt_tval_en);
				assert(excp_cmt_mret_en);
				assert(excp_flush);
				assert(excp_flush_pc == exp_mret_pc);
				assert(excp_flush_pc_bore == exp_mret_pc);
				assert(excp_flush_ofst == 32'h00000000);
				assert(excp_flush_ofst_bore == 6'h00);
			end

			if (cycle == 5'd5 && scenario == SC_MRET) begin
				assert(cur_mstatus[3] == sym_mret_pre_mpie);
				assert(cur_mstatus[7] == 1'b1);
			end
		end
	end
endmodule
