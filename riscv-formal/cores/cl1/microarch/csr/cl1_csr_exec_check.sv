module cl1_csr_exec_check (
	input clock, reset, check,
	`RVFI_INPUTS
);
endmodule

module cl1_csr_exec_bound_check (
	input         clock,
	input         dut_reset_n,
	input         io_ext_irq,
	input         io_sft_irq,
	input         io_tmr_irq,
	input         rvfi_valid,
	input [31:0]  rvfi_insn,
	input         rvfi_trap,
	input         rvfi_intr,
	input [31:0]  rvfi_rs1_rdata,
	input [4:0]   rvfi_rd_addr,
	input [31:0]  rvfi_rd_wdata,
	input [31:0]  rvfi_pc_rdata,
	input [31:0]  rvfi_pc_wdata,
	input         rvfi_mem_fault,
	input [31:0]  rvfi_mem_addr,
	input [3:0]   rvfi_mem_fault_rmask,
	input [3:0]   rvfi_mem_fault_wmask,
	input [31:0]  rvfi_csr_mstatus_rdata,
	input [31:0]  rvfi_csr_mie_rdata,
	input [31:0]  rvfi_csr_mip_rdata,
	input [31:0]  rvfi_csr_mepc_rdata,
	input [31:0]  rvfi_csr_mcause_rdata,
	input [31:0]  rvfi_csr_mtval_rdata,
	input [31:0]  rvfi_csr_mtvec_rdata,
	input [31:0]  rvfi_csr_mscratch_rdata,
	input [31:0]  rvfi_csr_misa_rdata,
	input         trap_req_bore,
	input         intr_taken_bore,
	input         mret_taken_bore,
	input [5:0]   excp_flush_ofst_bore,
	input [31:0]  cur_excp_mtvec_bore,
	input [31:0]  cur_mstatus_bore,
	input [31:0]  cur_mie_bore,
	input [31:0]  cur_mip_bore,
	input [31:0]  cur_mepc_bore,
	input [31:0]  cur_mcause_bore,
	input [31:0]  cur_mtval_bore,
	input [31:0]  cur_mtvec_bore,
	input [31:0]  cur_mscratch_bore,
	input [31:0]  cur_misa_bore,
	input         cmt_epc_en_bore,
	input         cmt_cause_en_bore,
	input         cmt_tval_en_bore,
	input         cmt_status_en_bore,
	input         cmt_mret_en_bore,
	input [31:0]  cmt_epc_n_bore,
	input [31:0]  cmt_cause_n_bore,
	input [31:0]  cmt_tval_n_bore
);
	localparam [31:0] MISA_VALUE = 32'h40001104;
	localparam [31:0] MVENDORID_VALUE = 32'h00000000;
	localparam [31:0] MARCHID_VALUE = 32'h00000005;
	localparam [31:0] MIMPID_VALUE = 32'h00000000;
	localparam [31:0] MHARTID_VALUE = 32'h00000000;
	localparam [31:0] MCONFIGPTR_VALUE = 32'h00000000;
	localparam [31:0] MSTATUSH_VALUE = 32'h00000000;

	wire formal_reset = !dut_reset_n;

	wire csr_insn = rvfi_valid && rvfi_insn[6:0] == 7'h73 && rvfi_insn[14:12] != 3'b000;
	wire [2:0] csr_funct3 = rvfi_insn[14:12];
	wire [11:0] csr_addr = rvfi_insn[31:20];
	wire [31:0] csr_arg = rvfi_insn[14] ? {27'h0, rvfi_insn[19:15]} : rvfi_rs1_rdata;
	wire csr_writes =
		csr_funct3[1:0] == 2'b01 ||
		(csr_funct3[1:0] != 2'b00 && rvfi_insn[19:15] != 5'h0);
	wire csr_commit_write;

	wire take_exception = trap_req_bore;
	wire take_interrupt = intr_taken_bore;
	wire take_mret = mret_taken_bore;
	wire fault_exception = take_exception && rvfi_valid && rvfi_trap && rvfi_mem_fault;

	reg        exp_meip;
	reg        exp_mtip;
	reg        exp_msip;
	reg        exp_meie;
	reg        exp_mtie;
	reg        exp_msie;
	reg        exp_mstatus_mie;
	reg        exp_mpie;
	reg [31:0] exp_mtvec;
	reg [31:0] exp_mepc;
	reg [31:0] exp_mcause;
	reg [31:0] exp_mtval;
	reg [31:0] exp_mscratch;

	reg        next_meip;
	reg        next_mtip;
	reg        next_msip;
	reg        next_meie;
	reg        next_mtie;
	reg        next_msie;
	reg        next_mstatus_mie;
	reg        next_mpie;
	reg [31:0] next_mtvec;
	reg [31:0] next_mepc;
	reg [31:0] next_mcause;
	reg [31:0] next_mtval;
	reg [31:0] next_mscratch;

	wire [31:0] exp_mip = {20'h0, exp_meip, 3'h0, exp_mtip, 3'h0, exp_msip, 3'h0};
	wire [31:0] exp_mie = {20'h0, exp_meie, 3'h0, exp_mtie, 3'h0, exp_msie, 3'h0};
	wire [31:0] exp_mstatus = {24'h18, exp_mpie, 3'h0, exp_mstatus_mie, 3'h0};
	wire [31:0] old_mip = {20'h0, old_meip, 3'h0, old_mtip, 3'h0, old_msip, 3'h0};
	wire [31:0] old_mie = {20'h0, old_meie, 3'h0, old_mtie, 3'h0, old_msie, 3'h0};
	wire [31:0] old_mstatus = {24'h18, old_mpie, 3'h0, old_mstatus_mie, 3'h0};

	reg [31:0] last_resume_pc;
	reg        have_last_resume_pc;

	reg        irq_taken_pending;
	reg [31:0] irq_taken_cause;
	reg [31:0] irq_taken_mtvec;
	reg [31:0] irq_taken_mepc;

	reg        old_meip;
	reg        old_mtip;
	reg        old_msip;
	reg        old_meie;
	reg        old_mtie;
	reg        old_msie;
	reg        old_mstatus_mie;
	reg        old_mpie;
	reg [31:0] old_mtvec;
	reg [31:0] old_mepc;
	reg [31:0] old_mcause;
	reg [31:0] old_mtval;
	reg [31:0] old_mscratch;

	reg        next_have_last_resume_pc;
	reg [31:0] next_last_resume_pc;
	reg        next_irq_taken_pending;
	reg [31:0] next_irq_taken_cause;
	reg [31:0] next_irq_taken_mtvec;
	reg [31:0] next_irq_taken_mepc;

	function [31:0] csr_write_value;
		input [31:0] old_value;
		input [31:0] arg;
		input [2:0] funct3;
		begin
			case (funct3[1:0])
			2'b01: csr_write_value = arg;
			2'b10: csr_write_value = old_value | arg;
			2'b11: csr_write_value = old_value & ~arg;
			default: csr_write_value = old_value;
			endcase
		end
	endfunction

	function [31:0] irq_cause;
		input ext;
		input sft;
		input tmr;
		input meie;
		input msie;
		input mtie;
		begin
			if (ext && meie)
				irq_cause = 32'h8000000B;
			else if (sft && msie)
				irq_cause = 32'h80000003;
			else if (tmr && mtie)
				irq_cause = 32'h80000007;
			else
				irq_cause = 32'h00000000;
		end
	endfunction

	function [31:0] fault_cause;
		input [3:0] fault_rmask;
		input [3:0] fault_wmask;
		begin
			if (|fault_wmask)
				fault_cause = 32'h00000007;
			else if (|fault_rmask)
				fault_cause = 32'h00000005;
			else
				fault_cause = 32'h00000001;
		end
	endfunction

	function [31:0] fault_tval;
		input [3:0] fault_rmask;
		input [3:0] fault_wmask;
		input [31:0] mem_addr;
		input [31:0] pc;
		begin
			fault_tval = (|fault_rmask || |fault_wmask) ? mem_addr : pc;
		end
	endfunction

	function csr_is_machine_readable;
		input [11:0] addr;
		begin
			csr_is_machine_readable =
				addr == 12'h300 || addr == 12'h301 || addr == 12'h304 ||
				addr == 12'h305 || addr == 12'h310 || addr == 12'h340 ||
				addr == 12'h341 || addr == 12'h342 || addr == 12'h343 ||
				addr == 12'h344 || addr == 12'hB00 || addr == 12'hB02 ||
				addr == 12'hB80 || addr == 12'hB82 || addr == 12'hF11 ||
				addr == 12'hF12 || addr == 12'hF13 || addr == 12'hF14 ||
				addr == 12'hF15;
		end
	endfunction

	function csr_is_read_only;
		input [11:0] addr;
		begin
			csr_is_read_only =
				addr == 12'hF11 || addr == 12'hF12 || addr == 12'hF13 ||
				addr == 12'hF14 || addr == 12'hF15;
		end
	endfunction

	function csr_is_counter;
		input [11:0] addr;
		begin
			csr_is_counter =
				addr == 12'hB00 || addr == 12'hB02 ||
				addr == 12'hB80 || addr == 12'hB82;
		end
	endfunction

	function csr_has_retire_rdata_model;
		input [11:0] addr;
		begin
			csr_has_retire_rdata_model =
				addr == 12'h301 || addr == 12'h310 || addr == 12'hF11 ||
				addr == 12'hF12 || addr == 12'hF13 || addr == 12'hF14 ||
				addr == 12'hF15;
		end
	endfunction

	reg [31:0] csr_old_value;
	always @* begin
		case (csr_addr)
		12'h300: csr_old_value = exp_mstatus;
		12'h301: csr_old_value = MISA_VALUE;
		12'h304: csr_old_value = exp_mie;
		12'h305: csr_old_value = exp_mtvec;
		12'h310: csr_old_value = MSTATUSH_VALUE;
		12'h340: csr_old_value = exp_mscratch;
		12'h341: csr_old_value = exp_mepc;
		12'h342: csr_old_value = exp_mcause;
		12'h343: csr_old_value = exp_mtval;
		12'h344: csr_old_value = exp_mip;
		12'hF11: csr_old_value = MVENDORID_VALUE;
		12'hF12: csr_old_value = MARCHID_VALUE;
		12'hF13: csr_old_value = MIMPID_VALUE;
		12'hF14: csr_old_value = MHARTID_VALUE;
		12'hF15: csr_old_value = MCONFIGPTR_VALUE;
		default: csr_old_value = 32'h00000000;
		endcase
	end

	reg [31:0] csr_retire_old_value;
	always @* begin
		case (csr_addr)
		12'h300: csr_retire_old_value = old_mstatus;
		12'h301: csr_retire_old_value = MISA_VALUE;
		12'h304: csr_retire_old_value = old_mie;
		12'h305: csr_retire_old_value = old_mtvec;
		12'h310: csr_retire_old_value = MSTATUSH_VALUE;
		12'h340: csr_retire_old_value = old_mscratch;
		12'h341: csr_retire_old_value = old_mepc;
		12'h342: csr_retire_old_value = old_mcause;
		12'h343: csr_retire_old_value = old_mtval;
		12'h344: csr_retire_old_value = old_mip;
		12'hF11: csr_retire_old_value = MVENDORID_VALUE;
		12'hF12: csr_retire_old_value = MARCHID_VALUE;
		12'hF13: csr_retire_old_value = MIMPID_VALUE;
		12'hF14: csr_retire_old_value = MHARTID_VALUE;
		12'hF15: csr_retire_old_value = MCONFIGPTR_VALUE;
		default: csr_retire_old_value = 32'h00000000;
		endcase
	end

	wire csr_model_illegal =
		csr_insn && (!csr_is_machine_readable(csr_addr) ||
		(csr_writes && csr_is_read_only(csr_addr)));
	wire csr_model_legal = csr_insn && !csr_model_illegal;
	assign csr_commit_write = csr_model_legal && csr_writes && !rvfi_trap;

	wire [31:0] csr_next_value = csr_write_value(csr_old_value, csr_arg, csr_funct3);
	wire [31:0] csr_retire_next_value = csr_write_value(csr_retire_old_value, csr_arg, csr_funct3);
	wire retire_resume_current = rvfi_valid && !rvfi_trap;
	wire have_resume_pc_current = have_last_resume_pc || retire_resume_current;
	wire [31:0] resume_pc_current = retire_resume_current ? rvfi_pc_wdata : last_resume_pc;
	wire [31:0] irq_cause_now =
		irq_cause(io_ext_irq, io_sft_irq, io_tmr_irq, exp_meie, exp_msie, exp_mtie);
	wire [31:0] irq_expected_cause = irq_cause_now;
	wire [31:0] irq_expected_mtvec = exp_mtvec;
	wire [31:0] irq_expected_mepc =
		have_resume_pc_current ? resume_pc_current : 32'h00000000;
	wire irq_expected_have_mepc = have_resume_pc_current;

	always @* begin
		next_meip = io_ext_irq;
		next_mtip = io_tmr_irq;
		next_msip = io_sft_irq;
		next_meie = exp_meie;
		next_mtie = exp_mtie;
		next_msie = exp_msie;
		next_mstatus_mie = exp_mstatus_mie;
		next_mpie = exp_mpie;
		next_mtvec = exp_mtvec;
		next_mepc = exp_mepc;
		next_mcause = exp_mcause;
		next_mtval = exp_mtval;
		next_mscratch = exp_mscratch;

		next_have_last_resume_pc = have_last_resume_pc;
		next_last_resume_pc = last_resume_pc;
		next_irq_taken_pending = irq_taken_pending;
		next_irq_taken_cause = irq_taken_cause;
		next_irq_taken_mtvec = irq_taken_mtvec;
		next_irq_taken_mepc = irq_taken_mepc;

		if (take_exception) begin
			next_mstatus_mie = 1'b0;
			next_mpie = exp_mstatus_mie;
			if (fault_exception) begin
				next_mepc = rvfi_pc_rdata & 32'hFFFFFFFE;
				next_mcause = fault_cause(rvfi_mem_fault_rmask, rvfi_mem_fault_wmask);
				next_mtval =
					fault_tval(rvfi_mem_fault_rmask, rvfi_mem_fault_wmask, rvfi_mem_addr, rvfi_pc_rdata);
			end else begin
				next_mepc = cmt_epc_n_bore & 32'hFFFFFFFE;
				next_mcause = cmt_cause_n_bore;
				next_mtval = cmt_tval_n_bore;
			end
		end else if (take_interrupt) begin
			next_mstatus_mie = 1'b0;
			next_mpie = exp_mstatus_mie;
			next_mepc = irq_expected_mepc & 32'hFFFFFFFE;
			next_mcause = irq_expected_cause;
			next_mtval = 32'h00000000;
			next_irq_taken_pending = 1'b1;
			next_irq_taken_cause = irq_expected_cause;
			next_irq_taken_mtvec = irq_expected_mtvec;
			next_irq_taken_mepc = irq_expected_mepc & 32'hFFFFFFFE;
		end else if (take_mret) begin
			next_mstatus_mie = exp_mpie;
			next_mpie = 1'b1;
		end

		if (csr_commit_write && !take_exception && !take_interrupt && !take_mret) begin
			case (csr_addr)
			12'h300: begin
				next_mstatus_mie = csr_next_value[3];
				next_mpie = csr_next_value[7];
			end
			12'h304: begin
				next_meie = csr_next_value[11];
				next_mtie = csr_next_value[7];
				next_msie = csr_next_value[3];
			end
			12'h305: next_mtvec = csr_next_value & 32'hFFFFFFFD;
			12'h340: next_mscratch = csr_next_value;
			12'h341: next_mepc = csr_next_value & 32'hFFFFFFFE;
			12'h342: next_mcause = csr_next_value;
			12'h343: next_mtval = csr_next_value;
			default: begin
			end
			endcase
		end

		if (retire_resume_current) begin
			next_last_resume_pc = rvfi_pc_wdata;
			next_have_last_resume_pc = 1'b1;
		end

		if (rvfi_valid && rvfi_intr)
			next_irq_taken_pending = 1'b0;
	end

	always @(posedge clock or posedge formal_reset) begin
		if (formal_reset) begin
			exp_meip <= 1'b0;
			exp_mtip <= 1'b0;
			exp_msip <= 1'b0;
			exp_meie <= 1'b0;
			exp_mtie <= 1'b0;
			exp_msie <= 1'b0;
			exp_mstatus_mie <= 1'b0;
			exp_mpie <= 1'b0;
			exp_mtvec <= 32'h20000000;
			exp_mepc <= 32'h00000000;
			exp_mcause <= 32'h00000000;
			exp_mtval <= 32'h00000000;
			exp_mscratch <= 32'h00000000;
			last_resume_pc <= 32'h00000000;
			have_last_resume_pc <= 1'b0;
			irq_taken_pending <= 1'b0;
			irq_taken_cause <= 32'h00000000;
			irq_taken_mtvec <= 32'h00000000;
			irq_taken_mepc <= 32'h00000000;
			old_meip <= 1'b0;
			old_mtip <= 1'b0;
			old_msip <= 1'b0;
			old_meie <= 1'b0;
			old_mtie <= 1'b0;
			old_msie <= 1'b0;
			old_mstatus_mie <= 1'b0;
			old_mpie <= 1'b0;
			old_mtvec <= 32'h20000000;
			old_mepc <= 32'h00000000;
			old_mcause <= 32'h00000000;
			old_mtval <= 32'h00000000;
			old_mscratch <= 32'h00000000;
		end else begin
			old_meip <= exp_meip;
			old_mtip <= exp_mtip;
			old_msip <= exp_msip;
			old_meie <= exp_meie;
			old_mtie <= exp_mtie;
			old_msie <= exp_msie;
			old_mstatus_mie <= exp_mstatus_mie;
			old_mpie <= exp_mpie;
			old_mtvec <= exp_mtvec;
			old_mepc <= exp_mepc;
			old_mcause <= exp_mcause;
			old_mtval <= exp_mtval;
			old_mscratch <= exp_mscratch;
			exp_meip <= next_meip;
			exp_mtip <= next_mtip;
			exp_msip <= next_msip;
			exp_meie <= next_meie;
			exp_mtie <= next_mtie;
			exp_msie <= next_msie;
			exp_mstatus_mie <= next_mstatus_mie;
			exp_mpie <= next_mpie;
			exp_mtvec <= next_mtvec;
			exp_mepc <= next_mepc;
			exp_mcause <= next_mcause;
			exp_mtval <= next_mtval;
			exp_mscratch <= next_mscratch;
			last_resume_pc <= next_last_resume_pc;
			have_last_resume_pc <= next_have_last_resume_pc;
			irq_taken_pending <= next_irq_taken_pending;
			irq_taken_cause <= next_irq_taken_cause;
			irq_taken_mtvec <= next_irq_taken_mtvec;
			irq_taken_mepc <= next_irq_taken_mepc;
		end
	end

	reg past_valid = 1'b0;
	always @(posedge clock or posedge formal_reset) begin
		if (formal_reset)
			past_valid <= 1'b0;
		else
			past_valid <= 1'b1;
	end

	wire [31:0] irq_vector_pc =
		{irq_taken_mtvec[31:2], 2'b00} +
		(irq_taken_mtvec[0] ? {26'h0, irq_taken_cause[3:0], 2'b00} : 32'h00000000);

	always @* begin
		if (past_valid && !formal_reset) begin
			assert(cur_mstatus_bore == exp_mstatus);
			assert(cur_mie_bore == exp_mie);
			assert(cur_mip_bore == exp_mip);
			assert(cur_mepc_bore == exp_mepc);
			assert(cur_mcause_bore == exp_mcause);
			assert(cur_mtval_bore == exp_mtval);
			assert(cur_mtvec_bore == exp_mtvec);
			assert(cur_mscratch_bore == exp_mscratch);
			assert(cur_misa_bore == MISA_VALUE);
			assert(cur_excp_mtvec_bore == exp_mtvec);

			assert(rvfi_csr_mstatus_rdata == cur_mstatus_bore);
			assert(rvfi_csr_mie_rdata == cur_mie_bore);
			assert(rvfi_csr_mip_rdata == cur_mip_bore);
			assert(rvfi_csr_mepc_rdata == cur_mepc_bore);
			assert(rvfi_csr_mcause_rdata == cur_mcause_bore);
			assert(rvfi_csr_mtval_rdata == cur_mtval_bore);
			assert(rvfi_csr_mtvec_rdata == cur_mtvec_bore);
			assert(rvfi_csr_mscratch_rdata == cur_mscratch_bore);
			assert(rvfi_csr_misa_rdata == cur_misa_bore);

			if (take_exception) begin
				assert(cmt_epc_en_bore);
				assert(cmt_status_en_bore);
				assert(cmt_cause_en_bore);
				assert(cmt_tval_en_bore);
				assert(!intr_taken_bore);
			end

			if (take_interrupt) begin
				assert(cmt_epc_en_bore);
				assert(cmt_status_en_bore);
				assert(cmt_cause_en_bore);
				assert(cmt_tval_en_bore);
				assert(!trap_req_bore);
				assert(exp_mstatus_mie);
				assert(irq_expected_cause[31]);
				assert(cmt_cause_n_bore == irq_expected_cause);
				assert(cmt_tval_n_bore == 32'h00000000);
				if (irq_expected_have_mepc)
					assert((cmt_epc_n_bore & 32'hFFFFFFFE) == (irq_expected_mepc & 32'hFFFFFFFE));
			end

			if (take_mret)
				assert(cmt_mret_en_bore);

			if (fault_exception) begin
				assert((cmt_epc_n_bore & 32'hFFFFFFFE) == (rvfi_pc_rdata & 32'hFFFFFFFE));
				assert(cmt_cause_n_bore == fault_cause(rvfi_mem_fault_rmask, rvfi_mem_fault_wmask));
				assert(cmt_tval_n_bore ==
					fault_tval(rvfi_mem_fault_rmask, rvfi_mem_fault_wmask, rvfi_mem_addr, rvfi_pc_rdata));
			end

			if (rvfi_valid && rvfi_intr && irq_taken_pending) begin
				assert(cur_mepc_bore == irq_taken_mepc);
				assert(cur_mcause_bore == irq_taken_cause);
				assert(rvfi_pc_rdata == irq_vector_pc);
			end

			if (rvfi_valid && csr_insn) begin
				if (csr_model_illegal) begin
					assert(rvfi_trap);
				end else begin
					assert(!rvfi_trap);
					if (rvfi_rd_addr != 5'h0 && csr_has_retire_rdata_model(csr_addr))
						assert(rvfi_rd_wdata == csr_retire_old_value);
				end

				if (csr_model_legal && csr_writes && !csr_is_counter(csr_addr) &&
						!take_exception && !take_interrupt && !take_mret) begin
					case (csr_addr)
					12'h300: assert(cur_mstatus_bore == {24'h18, csr_retire_next_value[7], 3'h0, csr_retire_next_value[3], 3'h0});
					12'h304: assert(cur_mie_bore == {20'h0, csr_retire_next_value[11], 3'h0, csr_retire_next_value[7], 3'h0, csr_retire_next_value[3], 3'h0});
					12'h305: assert(cur_mtvec_bore == (csr_retire_next_value & 32'hFFFFFFFD));
					12'h340: assert(cur_mscratch_bore == csr_retire_next_value);
					12'h341: assert(cur_mepc_bore == (csr_retire_next_value & 32'hFFFFFFFE));
					12'h342: assert(cur_mcause_bore == csr_retire_next_value);
					12'h343: assert(cur_mtval_bore == csr_retire_next_value);
					default: begin
					end
					endcase
				end
			end
		end
	end

	always @* begin
		if (past_valid && !formal_reset) begin
			cover(csr_commit_write && csr_addr == 12'h300);
			cover(csr_commit_write && csr_addr == 12'h304);
			cover(csr_commit_write && csr_addr == 12'h305 && csr_next_value[0]);
			cover(csr_commit_write && csr_addr == 12'h340);
			cover(csr_commit_write && csr_addr == 12'h341);
			cover(csr_commit_write && csr_addr == 12'h342);
			cover(csr_commit_write && csr_addr == 12'h343);
			cover(rvfi_valid && csr_insn && !rvfi_trap && csr_addr == 12'hF12);
			cover(take_interrupt);
			cover(fault_exception);
			cover(take_mret);
		end
	end
endmodule

module cl1_csr_info_counter_check (
	input         clock,
	input         reset,
	input [11:0]  io_rdAddr,
	input [31:0]  io_rdValue,
	input [11:0]  io_wrAddr,
	input [31:0]  io_wrValue,
	input         io_wen,
	input         io_wb_commit
);
	localparam [31:0] MVENDORID_VALUE = 32'h00000000;
	localparam [31:0] MARCHID_VALUE = 32'h00000005;
	localparam [31:0] MIMPID_VALUE = 32'h00000000;
	localparam [31:0] MHARTID_VALUE = 32'h00000000;
	localparam [31:0] MCONFIGPTR_VALUE = 32'h00000000;
	localparam [31:0] MSTATUSH_VALUE = 32'h00000000;

	reg past_valid;
	reg [31:0] exp_mcycle;
	reg [31:0] exp_mcycleh;
	reg [31:0] exp_minstret;
	reg [31:0] exp_minstreth;

	wire write_mcycle = io_wen && io_wrAddr == 12'hB00;
	wire write_minstret = io_wen && io_wrAddr == 12'hB02;
	wire write_mcycleh = io_wen && io_wrAddr == 12'hB80;
	wire write_minstreth = io_wen && io_wrAddr == 12'hB82;

	always @(posedge clock or posedge reset) begin
		if (reset) begin
			past_valid <= 1'b0;
			exp_mcycle <= 32'h00000000;
			exp_mcycleh <= 32'h00000000;
			exp_minstret <= 32'h00000000;
			exp_minstreth <= 32'h00000000;
		end else begin
			past_valid <= 1'b1;

			exp_mcycle <= write_mcycle ? io_wrValue : exp_mcycle + 32'h1;
			if (write_mcycleh || (!write_mcycle && (&exp_mcycle))) begin
				exp_mcycleh <= write_mcycleh ? io_wrValue : exp_mcycleh + 32'h1;
			end

			if (write_minstret || io_wb_commit) begin
				exp_minstret <= write_minstret ? io_wrValue : exp_minstret + 32'h1;
			end
			if (write_minstreth || (io_wb_commit && !write_minstret && (&exp_minstret))) begin
				exp_minstreth <= write_minstreth ? io_wrValue : exp_minstreth + 32'h1;
			end
		end
	end

	always @* begin
		if (past_valid && !reset) begin
			case (io_rdAddr)
			12'hB00: assert(io_rdValue == exp_mcycle);
			12'hB02: assert(io_rdValue == exp_minstret);
			12'hB80: assert(io_rdValue == exp_mcycleh);
			12'hB82: assert(io_rdValue == exp_minstreth);
			12'h310: assert(io_rdValue == MSTATUSH_VALUE);
			12'hF11: assert(io_rdValue == MVENDORID_VALUE);
			12'hF12: assert(io_rdValue == MARCHID_VALUE);
			12'hF13: assert(io_rdValue == MIMPID_VALUE);
			12'hF14: assert(io_rdValue == MHARTID_VALUE);
			12'hF15: assert(io_rdValue == MCONFIGPTR_VALUE);
			default: begin
			end
			endcase
		end
	end

	always @* begin
		if (past_valid && !reset) begin
			cover(io_rdAddr == 12'hF12 && io_rdValue == MARCHID_VALUE);
			cover(io_rdAddr == 12'hB00);
			cover(write_mcycle);
			cover(io_wb_commit);
		end
	end
endmodule

module cl1_csr_core_wire_check (
	input        clock,
	input        reset,
	input        csr_excp_meie,
	input        csr_excp_msie,
	input        csr_excp_mtie,
	input        csr_excp_mie,
	input [31:0] csr_excp_mepc,
	input [31:0] csr_excp_mcause,
	input [31:0] csr_excp_mtvec,
	input [31:0] cur_mstatus_bore,
	input [31:0] cur_mie_bore,
	input [31:0] cur_mepc_bore,
	input [31:0] cur_mcause_bore,
	input [31:0] cur_mtvec_bore
);
	always @* begin
		if (!reset) begin
			assert(csr_excp_meie == cur_mie_bore[11]);
			assert(csr_excp_msie == cur_mie_bore[3]);
			assert(csr_excp_mtie == cur_mie_bore[7]);
			assert(csr_excp_mie == cur_mstatus_bore[3]);
			assert(csr_excp_mepc == cur_mepc_bore);
			assert(csr_excp_mcause == cur_mcause_bore);
			assert(csr_excp_mtvec == cur_mtvec_bore);
		end
	end
endmodule

bind Cl1Core cl1_csr_core_wire_check cl1_csr_core_wire_check_i (
	.clock(clock),
	.reset(reset),
	.csr_excp_meie(_csr_io_excp_intf_meie),
	.csr_excp_msie(_csr_io_excp_intf_msie),
	.csr_excp_mtie(_csr_io_excp_intf_mtie),
	.csr_excp_mie(_csr_io_excp_intf_mie),
	.csr_excp_mepc(_csr_io_excp_intf_mepc),
	.csr_excp_mcause(_csr_io_excp_intf_mcause),
	.csr_excp_mtvec(_csr_io_excp_intf_mtvec),
	.cur_mstatus_bore(cur_mstatus_bore),
	.cur_mie_bore(cur_mie_bore),
	.cur_mepc_bore(cur_mepc_bore),
	.cur_mcause_bore(cur_mcause_bore),
	.cur_mtvec_bore(cur_mtvec_bore)
);

bind Cl1CSR cl1_csr_info_counter_check cl1_csr_info_counter_check_i (
	.clock(clock),
	.reset(reset),
	.io_rdAddr(io_rdAddr),
	.io_rdValue(io_rdValue),
	.io_wrAddr(io_wrAddr),
	.io_wrValue(io_wrValue),
	.io_wen(io_wen),
	.io_wb_commit(io_wb_commit)
);

bind Cl1Top_AXI_CACHE cl1_csr_exec_bound_check cl1_csr_exec_bound_check_i (
	.clock(clock),
	.dut_reset_n(reset),
	.io_ext_irq(io_ext_irq),
	.io_sft_irq(io_sft_irq),
	.io_tmr_irq(io_tmr_irq),
	.rvfi_valid(rvfi_valid),
	.rvfi_insn(rvfi_insn),
	.rvfi_trap(rvfi_trap),
	.rvfi_intr(rvfi_intr),
	.rvfi_rs1_rdata(rvfi_rs1_rdata),
	.rvfi_rd_addr(rvfi_rd_addr),
	.rvfi_rd_wdata(rvfi_rd_wdata),
	.rvfi_pc_rdata(rvfi_pc_rdata),
	.rvfi_pc_wdata(rvfi_pc_wdata),
	.rvfi_mem_fault(rvfi_mem_fault),
	.rvfi_mem_addr(rvfi_mem_addr),
	.rvfi_mem_fault_rmask(rvfi_mem_fault_rmask),
	.rvfi_mem_fault_wmask(rvfi_mem_fault_wmask),
	.rvfi_csr_mstatus_rdata(rvfi_csr_mstatus_rdata),
	.rvfi_csr_mie_rdata(rvfi_csr_mie_rdata),
	.rvfi_csr_mip_rdata(rvfi_csr_mip_rdata),
	.rvfi_csr_mepc_rdata(rvfi_csr_mepc_rdata),
	.rvfi_csr_mcause_rdata(rvfi_csr_mcause_rdata),
	.rvfi_csr_mtval_rdata(rvfi_csr_mtval_rdata),
	.rvfi_csr_mtvec_rdata(rvfi_csr_mtvec_rdata),
	.rvfi_csr_mscratch_rdata(rvfi_csr_mscratch_rdata),
	.rvfi_csr_misa_rdata(rvfi_csr_misa_rdata),
	.trap_req_bore(_core_trap_req_bore),
	.intr_taken_bore(_core_intr_taken_bore),
	.mret_taken_bore(_core_mret_taken_bore),
	.excp_flush_ofst_bore(_core_excp_flush_ofst_bore),
	.cur_excp_mtvec_bore(_core_cur_excp_mtvec_bore),
	.cur_mstatus_bore(_core_cur_mstatus_bore),
	.cur_mie_bore(_core_cur_mie_bore),
	.cur_mip_bore(_core_cur_mip_bore),
	.cur_mepc_bore(_core_cur_mepc_bore),
	.cur_mcause_bore(_core_cur_mcause_bore),
	.cur_mtval_bore(_core_cur_mtval_bore),
	.cur_mtvec_bore(_core_cur_mtvec_bore),
	.cur_mscratch_bore(_core_cur_mscratch_bore),
	.cur_misa_bore(_core_cur_misa_bore),
	.cmt_epc_en_bore(_core_cmt_epc_en_bore),
	.cmt_cause_en_bore(_core_cmt_cause_en_bore),
	.cmt_tval_en_bore(_core_cmt_tval_en_bore),
	.cmt_status_en_bore(_core_cmt_status_en_bore),
	.cmt_mret_en_bore(_core_cmt_mret_en_bore),
	.cmt_epc_n_bore(_core_cmt_epc_n_bore),
	.cmt_cause_n_bore(_core_cmt_cause_n_bore),
	.cmt_tval_n_bore(_core_cmt_tval_n_bore)
);
