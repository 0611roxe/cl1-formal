module testbench (
	input clk,

	input         mem_ready,
	output        mem_valid,
	output        mem_instr,
	output [31:0] mem_addr,
	output [31:0] mem_wdata,
	output [3:0]  mem_wstrb,
	input  [31:0] mem_rdata,

);
	reg resetn = 0;

	always @(posedge clk)
		resetn <= 1;

	`RVFI_WIRES

	// AXI4 AR
	wire        ar_valid;
	wire [31:0] ar_addr;
	rand reg    ar_ready;

	// AXI4 R
	wire        r_ready;
	rand reg        r_valid;
	rand reg [31:0] r_data;
	rand reg [1:0]  r_resp;
	rand reg        r_last;
	rand reg [3:0]  r_id;

	// AXI4 AW
	wire        aw_valid;
	rand reg    aw_ready;

	// AXI4 W
	wire        w_valid;
	rand reg    w_ready;

	// AXI4 B
	wire        b_ready;
	rand reg        b_valid;
	rand reg [1:0]  b_resp;
	rand reg [3:0]  b_id;

	Cl1Top uut (
		.clock                      (clk     ),
		.reset                      (!resetn ),

		.io_ext_irq                 (1'b0    ),
		.io_sft_irq                 (1'b0    ),
		.io_tmr_irq                 (1'b0    ),
		.io_dbg_req_i               (1'b0    ),

		.io_master_ar_valid         (ar_valid),
		.io_master_ar_ready         (ar_ready),
		.io_master_ar_bits_araddr   (ar_addr ),
		.io_master_ar_bits_arid     (),
		.io_master_ar_bits_arlen    (),
		.io_master_ar_bits_arsize   (),
		.io_master_ar_bits_arburst  (),
		.io_master_ar_bits_arlock   (),
		.io_master_ar_bits_arcache  (),
		.io_master_ar_bits_arprot   (),

		.io_master_r_ready          (r_ready ),
		.io_master_r_valid          (r_valid ),
		.io_master_r_bits_rdata     (r_data  ),
		.io_master_r_bits_rresp     (r_resp  ),
		.io_master_r_bits_rlast     (r_last  ),
		.io_master_r_bits_rid       (r_id    ),

		.io_master_aw_valid         (aw_valid),
		.io_master_aw_ready         (aw_ready),
		.io_master_aw_bits_awaddr   (),
		.io_master_aw_bits_awid     (),
		.io_master_aw_bits_awlen    (),
		.io_master_aw_bits_awsize   (),
		.io_master_aw_bits_awburst  (),
		.io_master_aw_bits_awlock   (),
		.io_master_aw_bits_awcache  (),
		.io_master_aw_bits_awprot   (),

		.io_master_w_valid          (w_valid ),
		.io_master_w_ready          (w_ready ),
		.io_master_w_bits_wdata     (),
		.io_master_w_bits_wstrb     (),
		.io_master_w_bits_wlast     (),

		.io_master_b_ready          (b_ready ),
		.io_master_b_valid          (b_valid ),
		.io_master_b_bits_bresp     (b_resp  ),
		.io_master_b_bits_bid       (b_id    ),

		`RVFI_CONN
	);

	(* keep *) wire                                spec_valid;
	(* keep *) wire                                spec_trap;
	(* keep *) wire [                       4 : 0] spec_rs1_addr;
	(* keep *) wire [                       4 : 0] spec_rs2_addr;
	(* keep *) wire [                       4 : 0] spec_rd_addr;
	(* keep *) wire [`RISCV_FORMAL_XLEN   - 1 : 0] spec_rd_wdata;
	(* keep *) wire [`RISCV_FORMAL_XLEN   - 1 : 0] spec_pc_wdata;
	(* keep *) wire [`RISCV_FORMAL_XLEN   - 1 : 0] spec_mem_addr;
	(* keep *) wire [`RISCV_FORMAL_XLEN/8 - 1 : 0] spec_mem_rmask;
	(* keep *) wire [`RISCV_FORMAL_XLEN/8 - 1 : 0] spec_mem_wmask;
	(* keep *) wire [`RISCV_FORMAL_XLEN   - 1 : 0] spec_mem_wdata;

	rvfi_isa_rv32imc isa_spec (
		.rvfi_valid    (rvfi_valid    ),
		.rvfi_insn     (rvfi_insn     ),
		.rvfi_pc_rdata (rvfi_pc_rdata ),
		.rvfi_rs1_rdata(rvfi_rs1_rdata),
		.rvfi_rs2_rdata(rvfi_rs2_rdata),
		.rvfi_mem_rdata(rvfi_mem_rdata),

		.spec_valid    (spec_valid    ),
		.spec_trap     (spec_trap     ),
		.spec_rs1_addr (spec_rs1_addr ),
		.spec_rs2_addr (spec_rs2_addr ),
		.spec_rd_addr  (spec_rd_addr  ),
		.spec_rd_wdata (spec_rd_wdata ),
		.spec_pc_wdata (spec_pc_wdata ),
		.spec_mem_addr (spec_mem_addr ),
		.spec_mem_rmask(spec_mem_rmask),
		.spec_mem_wmask(spec_mem_wmask),
		.spec_mem_wdata(spec_mem_wdata)
	);

	always @* begin
		if (resetn && rvfi_valid && !rvfi_trap) begin
			assert(spec_valid && !spec_trap);
		end
	end
endmodule
