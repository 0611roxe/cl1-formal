module cl1_csr_trap_model_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg [11:0] csr_rd_addr;
	(* anyseq *) reg [11:0] csr_wr_addr;
	(* anyseq *) reg [31:0] csr_wr_value;
	(* anyseq *) reg        csr_wen;

	(* anyseq *) reg        ext_irq;
	(* anyseq *) reg        sft_irq;
	(* anyseq *) reg        tmr_irq;
	(* anyseq *) reg [31:0] next_pc;
	(* anyseq *) reg        dx_valid;
	(* anyseq *) reg        cmt_ecall;
	(* anyseq *) reg        cmt_mret;
	(* anyseq *) reg        cmt_wfi;
	(* anyseq *) reg        wb_valid;
	(* anyseq *) reg [31:0] wb_pc;
	(* anyseq *) reg        excp_valid;
	(* anyseq *) reg [7:0]  excp_code;
	(* anyseq *) reg [31:0] excp_tval;

	localparam [1:0] ST_IDLE       = 2'h0;
	localparam [1:0] ST_IRQ_DRAIN  = 2'h1;
	localparam [1:0] ST_IRQ_FLUSH  = 2'h2;
	localparam [1:0] ST_EXCP_FLUSH = 2'h3;

	localparam [31:0] MISA_VALUE = 32'h40001104;

	reg        ref_meip;
	reg        ref_mtip;
	reg        ref_msip;
	reg        ref_meie;
	reg        ref_mtie;
	reg        ref_msie;
	reg        ref_mstatus_mie;
	reg        ref_mpie;
	reg [31:0] ref_mscratch;
	reg [31:0] ref_mtvec;
	reg [31:0] ref_mepc;
	reg [31:0] ref_mcause;
	reg [31:0] ref_mtval;
	reg [31:0] ref_mcycle;
	reg [31:0] ref_mcycleh;
	reg [31:0] ref_minstret;
	reg [31:0] ref_minstreth;
	reg [1:0]  ref_excp_state;
	reg        ref_wfi_halt_req;

	wire [31:0] ref_mip =
		{20'h0, ref_meip, 3'h0, ref_mtip, 3'h0, ref_msip, 3'h0};
	wire [31:0] ref_mie =
		{20'h0, ref_meie, 3'h0, ref_mtie, 3'h0, ref_msie, 3'h0};
	wire [31:0] ref_mstatus =
		{24'h18, ref_mpie, 3'h0, ref_mstatus_mie, 3'h0};

	wire ref_irq_mei_req = ext_irq & ref_meie;
	wire ref_irq_msi_req = sft_irq & ref_msie;
	wire ref_irq_mti_req = tmr_irq & ref_mtie;
	wire ref_irq_req_raw = ref_irq_mei_req | ref_irq_msi_req | ref_irq_mti_req;
	wire ref_irq_req = ref_irq_req_raw & ref_mstatus_mie;
	wire ref_excp_req = cmt_ecall | excp_valid;
	wire ref_dxwb_empty = ~dx_valid & ~wb_valid;
	wire ref_irq_drain_take = ref_irq_req & ref_dxwb_empty;

	wire ref_st_idle = ref_excp_state == ST_IDLE;
	wire ref_st_irq_drain = ref_excp_state == ST_IRQ_DRAIN;
	wire ref_st_irq_flush = ref_excp_state == ST_IRQ_FLUSH;
	wire ref_st_excp_flush = ref_excp_state == ST_EXCP_FLUSH;
	wire ref_irq_csr_save_en = ref_st_irq_drain & ref_irq_drain_take;
	wire ref_trap_csr_save_en = ref_irq_csr_save_en | ref_excp_req;
	wire ref_trap_take_flush = ref_st_irq_flush | ref_st_excp_flush;

	wire [31:0] ref_irq_cause =
		ref_irq_mei_req ? 32'h8000000B :
		ref_irq_msi_req ? 32'h80000003 :
		ref_irq_mti_req ? 32'h80000007 :
		32'h00000000;
	wire [31:0] ref_excp_cause =
		excp_valid ? {24'h0, excp_code} :
		cmt_ecall ? 32'h0000000B :
		32'h00000000;
	wire [31:0] ref_cmt_epc_n = ref_excp_req ? wb_pc : next_pc;
	wire [31:0] ref_cmt_cause_n = ref_excp_req ? ref_excp_cause : ref_irq_cause;
	wire [31:0] ref_cmt_tval_n = excp_valid ? excp_tval : 32'h00000000;
	wire [5:0] ref_trap_flush_ofst =
		(ref_mtvec[1:0] == 2'h1 && ref_st_irq_flush) ?
			{ref_mcause[3:0], 2'b00} : 6'h00;
	wire [31:0] ref_flush_pc =
		ref_trap_take_flush ? {ref_mtvec[31:2], 2'b00} : ref_mepc;
	wire ref_wfi_halt_req_n = cmt_wfi & ~ref_irq_req_raw;
	wire ref_halt = ref_wfi_halt_req | ref_wfi_halt_req_n;

	wire ref_state_update =
		ref_st_idle
			? (ref_excp_req | ref_irq_req)
			: (ref_st_excp_flush |
			   (ref_st_irq_drain ? (ref_excp_req | ref_dxwb_empty) : ref_st_irq_flush));

	reg [1:0] ref_excp_state_n;
	always @* begin
		ref_excp_state_n = ref_excp_state;
		if (ref_state_update) begin
			if (ref_st_idle) begin
				if (ref_excp_req)
					ref_excp_state_n = ST_EXCP_FLUSH;
				else if (ref_irq_req)
					ref_excp_state_n = ST_IRQ_DRAIN;
			end else if (ref_st_excp_flush | ~ref_st_irq_drain) begin
				ref_excp_state_n = ST_IDLE;
			end else if (ref_excp_req) begin
				ref_excp_state_n = ST_EXCP_FLUSH;
			end else if (ref_irq_drain_take) begin
				ref_excp_state_n = ST_IRQ_FLUSH;
			end else if (~ref_irq_req & ref_dxwb_empty) begin
				ref_excp_state_n = ST_IDLE;
			end
		end
	end

	wire write_mstatus = csr_wen && csr_wr_addr == 12'h300;
	wire write_mie = csr_wen && csr_wr_addr == 12'h304;
	wire write_mtvec = csr_wen && csr_wr_addr == 12'h305;
	wire write_mscratch = csr_wen && csr_wr_addr == 12'h340;
	wire write_mepc = csr_wen && csr_wr_addr == 12'h341;
	wire write_mcause = csr_wen && csr_wr_addr == 12'h342;
	wire write_mtval = csr_wen && csr_wr_addr == 12'h343;
	wire write_mcycle = csr_wen && csr_wr_addr == 12'hB00;
	wire write_minstret = csr_wen && csr_wr_addr == 12'hB02;
	wire write_mcycleh = csr_wen && csr_wr_addr == 12'hB80;
	wire write_minstreth = csr_wen && csr_wr_addr == 12'hB82;
	always @(posedge clock or posedge reset) begin
		if (reset) begin
			ref_meip <= 1'b0;
			ref_mtip <= 1'b0;
			ref_msip <= 1'b0;
			ref_meie <= 1'b0;
			ref_mtie <= 1'b0;
			ref_msie <= 1'b0;
			ref_mstatus_mie <= 1'b0;
			ref_mpie <= 1'b0;
			ref_mscratch <= 32'h00000000;
			ref_mtvec <= 32'h20000000;
			ref_mepc <= 32'h00000000;
			ref_mcause <= 32'h00000000;
			ref_mtval <= 32'h00000000;
			ref_mcycle <= 32'h00000000;
			ref_mcycleh <= 32'h00000000;
			ref_minstret <= 32'h00000000;
			ref_minstreth <= 32'h00000000;
			ref_excp_state <= ST_IDLE;
			ref_wfi_halt_req <= 1'b0;
		end else begin
			ref_meip <= ext_irq;
			ref_mtip <= tmr_irq;
			ref_msip <= sft_irq;

			if (write_mie) begin
				ref_meie <= csr_wr_value[11];
				ref_mtie <= csr_wr_value[7];
				ref_msie <= csr_wr_value[3];
			end

			if (write_mstatus || ref_trap_csr_save_en || cmt_mret) begin
				ref_mstatus_mie <=
					!ref_trap_csr_save_en &&
					(cmt_mret ? ref_mpie : (write_mstatus && csr_wr_value[3]));
				ref_mpie <= ref_trap_csr_save_en ?
					ref_mstatus_mie : (cmt_mret || (write_mstatus && csr_wr_value[7]));
			end

			if (write_mscratch)
				ref_mscratch <= csr_wr_value;
			if (write_mtvec)
				ref_mtvec <= csr_wr_value & 32'hFFFFFFFD;
			if (write_mepc || ref_trap_csr_save_en)
				ref_mepc <= (ref_trap_csr_save_en ? ref_cmt_epc_n : csr_wr_value)
					& 32'hFFFFFFFE;
			if (write_mcause || ref_trap_csr_save_en)
				ref_mcause <= ref_trap_csr_save_en ? ref_cmt_cause_n : csr_wr_value;
			if (write_mtval || ref_trap_csr_save_en)
				ref_mtval <= ref_trap_csr_save_en ? ref_cmt_tval_n : csr_wr_value;

			ref_mcycle <= write_mcycle ? csr_wr_value : ref_mcycle + 32'h1;
			if (write_mcycleh || (!write_mcycle && (&ref_mcycle)))
				ref_mcycleh <= write_mcycleh ? csr_wr_value : ref_mcycleh + 32'h1;
			if (write_minstret)
				ref_minstret <= csr_wr_value;
			if (write_minstreth)
				ref_minstreth <= csr_wr_value;

			ref_excp_state <= ref_excp_state_n;
			if (cmt_wfi | ref_irq_req_raw)
				ref_wfi_halt_req <= ref_wfi_halt_req_n;
		end
	end

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
		.io_dbg2excp_ebrk_excp_en(1'b0),
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
			assert(csr_meie == ref_meie);
			assert(csr_msie == ref_msie);
			assert(csr_mtie == ref_mtie);
			assert(csr_mie == ref_mstatus_mie);
			assert(csr_mepc == ref_mepc);
			assert(csr_mcause == ref_mcause);
			assert(csr_mtvec == ref_mtvec);
			assert(cur_excp_mtvec == ref_mtvec);
			assert(cur_mstatus == ref_mstatus);
			assert(cur_mie == ref_mie);
			assert(cur_mip == ref_mip);
			assert(cur_mepc == ref_mepc);
			assert(cur_mcause == ref_mcause);
			assert(cur_mtval == ref_mtval);
			assert(cur_mtvec == ref_mtvec);
			assert(cur_mscratch == ref_mscratch);
			assert(cur_misa == MISA_VALUE);

			assert(excp2csr_ext_irq == ext_irq);
			assert(excp2csr_sft_irq == sft_irq);
			assert(excp2csr_tmr_irq == tmr_irq);
			assert(excp_cmt_epc_en == ref_trap_csr_save_en);
			assert(excp_cmt_status_en == ref_trap_csr_save_en);
			assert(excp_cmt_cause_en == ref_trap_csr_save_en);
			assert(excp_cmt_tval_en == ref_trap_csr_save_en);
			assert(excp_cmt_epc_n == ref_cmt_epc_n);
			assert(excp_cmt_cause_n == ref_cmt_cause_n);
			assert(excp_cmt_tval_n == ref_cmt_tval_n);
			assert(excp_cmt_mret_en == cmt_mret);

			assert(excp_flush == (ref_trap_take_flush | cmt_mret));
			assert(excp_flush_pc == ref_flush_pc);
			assert(excp_flush_ofst == {26'h0, ref_trap_flush_ofst});
			assert(ifu_stall == ref_st_irq_drain);
			assert(dxu_stall == ref_excp_req);
			assert(ifu_halt == ref_halt);
			assert(dxu_halt == ref_halt);

			assert(trap_req_bore == ref_excp_req);
			assert(intr_taken_bore == ref_irq_csr_save_en);
			assert(excp_flush_pc_bore == ref_flush_pc);
			assert(excp_flush_ofst_bore == ref_trap_flush_ofst);
			assert(cmt_epc_en_bore == ref_trap_csr_save_en);
			assert(cmt_cause_en_bore == ref_trap_csr_save_en);
			assert(cmt_tval_en_bore == ref_trap_csr_save_en);
			assert(cmt_status_en_bore == ref_trap_csr_save_en);
			assert(cmt_epc_n_bore == ref_cmt_epc_n);
			assert(cmt_cause_n_bore == ref_cmt_cause_n);
			assert(cmt_tval_n_bore == ref_cmt_tval_n);
		end
	end
endmodule
