module cl1_csr_unit_check(input clock);
	reg past_valid = 1'b0;
	always @(posedge clock) begin
		past_valid <= 1'b1;
	end

	wire reset = !past_valid;

	(* anyseq *) reg [11:0] rd_addr;
	(* anyseq *) reg [11:0] wr_addr;
	(* anyseq *) reg [31:0] wr_value;
	(* anyseq *) reg        wr_en;
	(* anyseq *) reg        wb_commit;

	(* anyseq *) reg ext_irq;
	(* anyseq *) reg sft_irq;
	(* anyseq *) reg tmr_irq;

	(* anyseq *) reg        cmt_epc_en;
	(* anyseq *) reg [31:0] cmt_epc_n;
	(* anyseq *) reg        cmt_status_en;
	(* anyseq *) reg        cmt_cause_en;
	(* anyseq *) reg [31:0] cmt_cause_n;
	(* anyseq *) reg        cmt_tval_en;
	(* anyseq *) reg [31:0] cmt_tval_n;
	(* anyseq *) reg        cmt_mret_en;

	wire [31:0] rd_value;
	wire [31:0] dbg_dpc_r;
	wire        dbg_ebreakm_r;
	wire        dbg_step_r;
	wire        excp_meie;
	wire        excp_msie;
	wire        excp_mtie;
	wire        excp_mie;
	wire [31:0] excp_mepc;
	wire [31:0] excp_mcause;
	wire [31:0] excp_mtvec;
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

	Cl1CSR dut (
		.clock(clock),
		.reset(reset),
		.io_rdAddr(rd_addr),
		.io_rdValue(rd_value),
		.io_wrAddr(wr_addr),
		.io_wrValue(wr_value),
		.io_wen(wr_en),
		.io_dbg_intf_csr_update_en(1'b0),
		.io_dbg_intf_dpc_update(32'b0),
		.io_dbg_intf_dbg_cause(3'b0),
		.io_dbg_intf_dpc_r(dbg_dpc_r),
		.io_dbg_intf_ebreakm_r(dbg_ebreakm_r),
		.io_dbg_intf_step_r(dbg_step_r),
		.io_excp_intf_ext_irq(ext_irq),
		.io_excp_intf_sft_irq(sft_irq),
		.io_excp_intf_tmr_irq(tmr_irq),
		.io_excp_intf_meie(excp_meie),
		.io_excp_intf_msie(excp_msie),
		.io_excp_intf_mtie(excp_mtie),
		.io_excp_intf_mie(excp_mie),
		.io_excp_intf_mepc(excp_mepc),
		.io_excp_intf_mcause(excp_mcause),
		.io_excp_intf_mtvec(excp_mtvec),
		.io_excp_intf_cmt_epc_en(cmt_epc_en),
		.io_excp_intf_cmt_epc_n(cmt_epc_n),
		.io_excp_intf_cmt_status_en(cmt_status_en),
		.io_excp_intf_cmt_cause_en(cmt_cause_en),
		.io_excp_intf_cmt_cause_n(cmt_cause_n),
		.io_excp_intf_cmt_tval_en(cmt_tval_en),
		.io_excp_intf_cmt_tval_n(cmt_tval_n),
		.io_excp_intf_cmt_mret_en(cmt_mret_en),
		.io_wb_commit(wb_commit),
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

	wire rd_addr_checked =
		rd_addr == 12'h300 || rd_addr == 12'h301 || rd_addr == 12'h304 ||
		rd_addr == 12'h305 || rd_addr == 12'h310 || rd_addr == 12'h340 ||
		rd_addr == 12'h341 || rd_addr == 12'h342 || rd_addr == 12'h343 ||
		rd_addr == 12'h344 || rd_addr == 12'hB00 || rd_addr == 12'hB02 ||
		rd_addr == 12'hB80 || rd_addr == 12'hB82 || rd_addr == 12'hF11 ||
		rd_addr == 12'hF12 || rd_addr == 12'hF13 || rd_addr == 12'hF14 ||
		rd_addr == 12'hF15;

	always @* begin
		assume(rd_addr_checked);
	end

	localparam [31:0] MISA_VALUE = 32'h40001104;
	localparam [31:0] MVENDORID_VALUE = 32'h00000000;
	localparam [31:0] MARCHID_VALUE = 32'h00000005;
	localparam [31:0] MIMPID_VALUE = 32'h00000000;
	localparam [31:0] MHARTID_VALUE = 32'h00000000;
	localparam [31:0] MCONFIGPTR_VALUE = 32'h00000000;
	localparam [31:0] MSTATUSH_VALUE = 32'h00000000;

	reg        exp_meip;
	reg        exp_mtip;
	reg        exp_msip;
	reg        exp_meie;
	reg        exp_mtie;
	reg        exp_msie;
	reg        exp_mstatus_mie;
	reg        exp_mpie;
	reg [31:0] exp_mscratch;
	reg [31:0] exp_mtvec;
	reg [31:0] exp_mepc;
	reg [31:0] exp_mcause;
	reg [31:0] exp_mtval;
	reg [31:0] exp_mcycle;
	reg [31:0] exp_mcycleh;
	reg [31:0] exp_minstret;
	reg [31:0] exp_minstreth;

	wire csrw_mstatus = wr_en && wr_addr == 12'h300;
	wire write_mie = wr_en && wr_addr == 12'h304;
	wire write_mtvec = wr_en && wr_addr == 12'h305;
	wire write_mscratch = wr_en && wr_addr == 12'h340;
	wire write_mepc = wr_en && wr_addr == 12'h341;
	wire write_mcause = wr_en && wr_addr == 12'h342;
	wire write_mtval = wr_en && wr_addr == 12'h343;
	wire write_mcycle = wr_en && wr_addr == 12'hB00;
	wire write_minstret = wr_en && wr_addr == 12'hB02;
	wire write_mcycleh = wr_en && wr_addr == 12'hB80;
	wire write_minstreth = wr_en && wr_addr == 12'hB82;

	always @(posedge clock or posedge reset) begin
		if (reset) begin
			exp_meip <= 1'b0;
			exp_mtip <= 1'b0;
			exp_msip <= 1'b0;
			exp_meie <= 1'b0;
			exp_mtie <= 1'b0;
			exp_msie <= 1'b0;
			exp_mstatus_mie <= 1'b0;
			exp_mpie <= 1'b0;
			exp_mscratch <= 32'h00000000;
			exp_mtvec <= 32'h20000000;
			exp_mepc <= 32'h00000000;
			exp_mcause <= 32'h00000000;
			exp_mtval <= 32'h00000000;
			exp_mcycle <= 32'h00000000;
			exp_mcycleh <= 32'h00000000;
			exp_minstret <= 32'h00000000;
			exp_minstreth <= 32'h00000000;
		end else begin
			exp_meip <= ext_irq;
			exp_mtip <= tmr_irq;
			exp_msip <= sft_irq;

			if (write_mie) begin
				exp_meie <= wr_value[11];
				exp_mtie <= wr_value[7];
				exp_msie <= wr_value[3];
			end

			if (csrw_mstatus || cmt_status_en || cmt_mret_en) begin
				exp_mstatus_mie <=
					!cmt_status_en &&
					(cmt_mret_en ? exp_mpie : (csrw_mstatus && wr_value[3]));
				exp_mpie <= cmt_status_en ? exp_mstatus_mie :
					(cmt_mret_en || (csrw_mstatus && wr_value[7]));
			end

			if (write_mscratch) begin
				exp_mscratch <= wr_value;
			end

			if (write_mtvec) begin
				exp_mtvec <= wr_value & 32'hFFFFFFFD;
			end

			if (write_mepc || cmt_epc_en) begin
				exp_mepc <= (cmt_epc_en ? cmt_epc_n : wr_value) & 32'hFFFFFFFE;
			end

			if (write_mcause || cmt_cause_en) begin
				exp_mcause <= cmt_cause_en ? cmt_cause_n : wr_value;
			end

			if (write_mtval || cmt_tval_en) begin
				exp_mtval <= cmt_tval_en ? cmt_tval_n : wr_value;
			end

			exp_mcycle <= write_mcycle ? wr_value : exp_mcycle + 32'h1;
			if (write_mcycleh || (!write_mcycle && (&exp_mcycle))) begin
				exp_mcycleh <= write_mcycleh ? wr_value : exp_mcycleh + 32'h1;
			end

			if (write_minstret || wb_commit) begin
				exp_minstret <= write_minstret ? wr_value : exp_minstret + 32'h1;
			end
			if (write_minstreth || (wb_commit && !write_minstret && (&exp_minstret))) begin
				exp_minstreth <= write_minstreth ? wr_value : exp_minstreth + 32'h1;
			end
		end
	end

	wire [31:0] exp_mip = {20'h0, exp_meip, 3'h0, exp_mtip, 3'h0, exp_msip, 3'h0};
	wire [31:0] exp_mie = {20'h0, exp_meie, 3'h0, exp_mtie, 3'h0, exp_msie, 3'h0};
	wire [31:0] exp_mstatus = {24'h18, exp_mpie, 3'h0, exp_mstatus_mie, 3'h0};

	reg [31:0] exp_rd_value;
	always @* begin
		case (rd_addr)
		12'h300: exp_rd_value = exp_mstatus;
		12'h301: exp_rd_value = MISA_VALUE;
		12'h304: exp_rd_value = exp_mie;
		12'h305: exp_rd_value = exp_mtvec;
		12'h310: exp_rd_value = MSTATUSH_VALUE;
		12'h340: exp_rd_value = exp_mscratch;
		12'h341: exp_rd_value = exp_mepc;
		12'h342: exp_rd_value = exp_mcause;
		12'h343: exp_rd_value = exp_mtval;
		12'h344: exp_rd_value = exp_mip;
		12'hB00: exp_rd_value = exp_mcycle;
		12'hB02: exp_rd_value = exp_minstret;
		12'hB80: exp_rd_value = exp_mcycleh;
		12'hB82: exp_rd_value = exp_minstreth;
		12'hF11: exp_rd_value = MVENDORID_VALUE;
		12'hF12: exp_rd_value = MARCHID_VALUE;
		12'hF13: exp_rd_value = MIMPID_VALUE;
		12'hF14: exp_rd_value = MHARTID_VALUE;
		12'hF15: exp_rd_value = MCONFIGPTR_VALUE;
		default: exp_rd_value = 32'h00000000;
		endcase
	end

	always @* begin
		if (past_valid && !reset) begin
			assert(rd_value == exp_rd_value);

			assert(excp_meie == exp_meie);
			assert(excp_msie == exp_msie);
			assert(excp_mtie == exp_mtie);
			assert(excp_mie == exp_mstatus_mie);
			assert(excp_mepc == exp_mepc);
			assert(excp_mcause == exp_mcause);
			assert(excp_mtvec == exp_mtvec);

			assert(cur_excp_mtvec == exp_mtvec);
			assert(cur_mstatus == exp_mstatus);
			assert(cur_mie == exp_mie);
			assert(cur_mip == exp_mip);
			assert(cur_mepc == exp_mepc);
			assert(cur_mcause == exp_mcause);
			assert(cur_mtval == exp_mtval);
			assert(cur_mtvec == exp_mtvec);
			assert(cur_mscratch == exp_mscratch);
			assert(cur_misa == MISA_VALUE);
		end
	end
endmodule
