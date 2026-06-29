`ifndef CL1_FORMAL_INSN_WFI
`define CL1_FORMAL_INSN_WFI(_insn) ((_insn) == 32'h10500073)
`endif

module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
	`RVFI_BUS_OUTPUTS
);

	(* keep *) `rvformal_rand_reg ext_irq;
	(* keep *) `rvformal_rand_reg sft_irq;
	(* keep *) `rvformal_rand_reg tmr_irq;

`ifdef CL1_USE_NATIVE_BUS
	// ---- Native bus interface (Cl1Top) ----

	// ibus signals
	(* keep *) wire        ibus_req_valid;
	(* keep *) wire [31:0] ibus_req_bits_addr;
	(* keep *) wire [31:0] ibus_req_bits_data;
	(* keep *) wire        ibus_req_bits_wen;
	(* keep *) wire [3:0]  ibus_req_bits_mask;
	(* keep *) wire        ibus_req_bits_cache;
	(* keep *) wire [1:0]  ibus_req_bits_size;
	(* keep *) wire        ibus_req_ready;
	(* keep *) wire        ibus_rsp_ready;
	(* keep *) wire        ibus_rsp_valid;
	(* keep *) wire [31:0] ibus_rsp_bits_data;
	(* keep *) wire        ibus_rsp_bits_err;

	// dbus signals
	(* keep *) wire        dbus_req_valid;
	(* keep *) wire [31:0] dbus_req_bits_addr;
	(* keep *) wire [31:0] dbus_req_bits_data;
	(* keep *) wire        dbus_req_bits_wen;
	(* keep *) wire [3:0]  dbus_req_bits_mask;
	(* keep *) wire        dbus_req_bits_cache;
	(* keep *) wire [1:0]  dbus_req_bits_size;
	(* keep *) wire        dbus_req_ready;
	(* keep *) wire        dbus_rsp_ready;
	(* keep *) wire        dbus_rsp_valid;
	(* keep *) wire [31:0] dbus_rsp_bits_data;
	(* keep *) wire        dbus_rsp_bits_err;

	// Native bus dummy slaves
	native_bus_dummy_slave ibus_slave (
		.clock          (clock              ),
		.reset          (reset              ),
		.req_valid      (ibus_req_valid     ),
		.req_ready      (ibus_req_ready     ),
		.rsp_valid      (ibus_rsp_valid     ),
		.rsp_ready      (ibus_rsp_ready     ),
		.rsp_bits_data  (ibus_rsp_bits_data ),
		.rsp_bits_err   (ibus_rsp_bits_err  )
	);

	native_bus_dummy_slave dbus_slave (
		.clock          (clock              ),
		.reset          (reset              ),
		.req_valid      (dbus_req_valid     ),
		.req_ready      (dbus_req_ready     ),
		.rsp_valid      (dbus_rsp_valid     ),
		.rsp_ready      (dbus_rsp_ready     ),
		.rsp_bits_data  (dbus_rsp_bits_data ),
		.rsp_bits_err   (dbus_rsp_bits_err  )
	);

	Cl1Top uut (
		.clock                      (clock              ),
		.reset                      (!reset             ),

		// Randomized interrupts, debug tied off
		.io_ext_irq                 (ext_irq            ),
		.io_sft_irq                 (sft_irq            ),
		.io_tmr_irq                 (tmr_irq            ),
		.io_dbg_req_i               (1'b0               ),

		// ibus
		.io_ibus_req_valid          (ibus_req_valid      ),
		.io_ibus_req_ready          (ibus_req_ready      ),
		.io_ibus_req_bits_addr      (ibus_req_bits_addr  ),
		.io_ibus_req_bits_data      (ibus_req_bits_data  ),
		.io_ibus_req_bits_wen       (ibus_req_bits_wen   ),
		.io_ibus_req_bits_mask      (ibus_req_bits_mask  ),
		.io_ibus_req_bits_cache     (ibus_req_bits_cache ),
		.io_ibus_req_bits_size      (ibus_req_bits_size  ),
		.io_ibus_rsp_ready          (ibus_rsp_ready      ),
		.io_ibus_rsp_valid          (ibus_rsp_valid      ),
		.io_ibus_rsp_bits_data      (ibus_rsp_bits_data  ),
		.io_ibus_rsp_bits_err       (ibus_rsp_bits_err   ),

		// dbus
		.io_dbus_req_valid          (dbus_req_valid      ),
		.io_dbus_req_ready          (dbus_req_ready      ),
		.io_dbus_req_bits_addr      (dbus_req_bits_addr  ),
		.io_dbus_req_bits_data      (dbus_req_bits_data  ),
		.io_dbus_req_bits_wen       (dbus_req_bits_wen   ),
		.io_dbus_req_bits_mask      (dbus_req_bits_mask  ),
		.io_dbus_req_bits_cache     (dbus_req_bits_cache ),
		.io_dbus_req_bits_size      (dbus_req_bits_size  ),
		.io_dbus_rsp_ready          (dbus_rsp_ready      ),
		.io_dbus_rsp_valid          (dbus_rsp_valid      ),
		.io_dbus_rsp_bits_data      (dbus_rsp_bits_data  ),
		.io_dbus_rsp_bits_err       (dbus_rsp_bits_err   ),

		// RVFI
		`RVFI_CONN
	);

`else
	// ---- AXI4 interface (Cl1Top_AXI) ----
	localparam AXI_DATA_WIDTH = 32;
	localparam AXI_ADDRESS_WIDTH = 32;
	localparam AXI_ID_WIDTH = 5;
	localparam AXI_AWUSER_WIDTH = 1;
	localparam AXI_WUSER_WIDTH = 1;
	localparam AXI_BUSER_WIDTH = 1;
	localparam AXI_ARUSER_WIDTH = 1;
	localparam AXI_RUSER_WIDTH = 1;

	// AXI4 AR channel (read address)
	(* keep *) wire        ar_valid;
	(* keep *) wire [31:0] ar_addr;
	(* keep *) wire [AXI_ID_WIDTH-1:0] ar_id;
	(* keep *) wire [7:0]  ar_len;
	(* keep *) wire [2:0]  ar_size;
	(* keep *) wire [1:0]  ar_burst;
	(* keep *) wire        ar_lock;
	(* keep *) wire [3:0]  ar_cache;
	(* keep *) wire [2:0]  ar_prot;
	(* keep *) wire        ar_ready;

	// AXI4 R channel (read data)
	(* keep *) wire        r_ready;
	(* keep *) wire        r_valid;
	(* keep *) wire [31:0] r_data;
	(* keep *) wire [1:0]  r_resp;
	(* keep *) wire        r_last;
	(* keep *) wire [AXI_ID_WIDTH-1:0] r_id;

	// AXI4 AW channel (write address)
	(* keep *) wire        aw_valid;
	(* keep *) wire [31:0] aw_addr;
	(* keep *) wire [AXI_ID_WIDTH-1:0] aw_id;
	(* keep *) wire [7:0]  aw_len;
	(* keep *) wire [2:0]  aw_size;
	(* keep *) wire [1:0]  aw_burst;
	(* keep *) wire        aw_lock;
	(* keep *) wire [3:0]  aw_cache;
	(* keep *) wire [2:0]  aw_prot;
	(* keep *) wire        aw_ready;

	// AXI4 W channel (write data)
	(* keep *) wire        w_valid;
	(* keep *) wire [31:0] w_data;
	(* keep *) wire [3:0]  w_strb;
	(* keep *) wire        w_last;
	(* keep *) wire        w_ready;

	// AXI4 B channel (write response)
	(* keep *) wire        b_ready;
	(* keep *) wire        b_valid;
	(* keep *) wire [1:0]  b_resp;
	(* keep *) wire [AXI_ID_WIDTH-1:0] b_id;

	// AXI4 Dummy Slave
	axi4_dummy_slave #(
		.ID_WIDTH      (AXI_ID_WIDTH)
	) axi_slave (
		.clock          (clock   ),
		.reset          (reset   ),

		// AR
		.ar_valid       (ar_valid),
		.ar_ready       (ar_ready),
		.ar_id          (ar_id   ),
		.ar_len         (ar_len  ),
		.ar_size        (ar_size ),
		.ar_prot        (ar_prot ),

		// R
		.r_valid        (r_valid ),
		.r_ready        (r_ready ),
		.r_data         (r_data  ),
		.r_resp         (r_resp  ),
		.r_last         (r_last  ),
		.r_id           (r_id    ),

		// AW
		.aw_valid       (aw_valid),
		.aw_ready       (aw_ready),
		.aw_id          (aw_id   ),
		.aw_len         (aw_len  ),

		// W
		.w_valid        (w_valid ),
		.w_ready        (w_ready ),
		.w_last         (w_last  ),

		// B
		.b_valid        (b_valid ),
		.b_ready        (b_ready ),
		.b_resp         (b_resp  ),
		.b_id           (b_id    )
	);

`ifdef RISCV_FORMAL_BUS
	rvfi_bus_axi4_observer_write #(
		.AXI_DATA_WIDTH      (AXI_DATA_WIDTH),
		.AXI_ADDRESS_WIDTH   (AXI_ADDRESS_WIDTH),
		.AXI_ID_WIDTH        (AXI_ID_WIDTH),
		.AXI_AWUSER_WIDTH    (AXI_AWUSER_WIDTH),
		.AXI_WUSER_WIDTH     (AXI_WUSER_WIDTH),
		.AXI_BUSER_WIDTH     (AXI_BUSER_WIDTH),
		.IGNORE_PROT_DATA_INSN(0),
		.DEPTH               (8)
	) axi_write_observer (
		.clock       (clock   ),
		.reset       (reset   ),
		.axi_awid    (aw_id   ),
		.axi_awaddr  (aw_addr ),
		.axi_awregion(4'b0000 ),
		.axi_awlen   (aw_len  ),
		.axi_awsize  (aw_size ),
		.axi_awburst (aw_burst),
		.axi_awlock  (aw_lock ),
		.axi_awcache (aw_cache),
		.axi_awprot  (aw_prot ),
		.axi_awqos   (4'b0000 ),
		.axi_awuser  (1'b0    ),
		.axi_awvalid (aw_valid),
		.axi_awready (aw_ready),
		.axi_wdata   (w_data  ),
		.axi_wstrb   (w_strb  ),
		.axi_wlast   (w_last  ),
		.axi_wuser   (1'b0    ),
		.axi_wvalid  (w_valid ),
		.axi_wready  (w_ready ),
		.axi_bid     (b_id    ),
		.axi_bresp   (b_resp  ),
		.axi_buser   (1'b0    ),
		.axi_bvalid  (b_valid ),
		.axi_bready  (b_ready )
		`RVFI_BUS_CHANNEL_CONN(0)
	);

	rvfi_bus_axi4_observer_read #(
		.AXI_DATA_WIDTH      (AXI_DATA_WIDTH),
		.AXI_ADDRESS_WIDTH   (AXI_ADDRESS_WIDTH),
		.AXI_ID_WIDTH        (AXI_ID_WIDTH),
		.AXI_ARUSER_WIDTH    (AXI_ARUSER_WIDTH),
		.AXI_RUSER_WIDTH     (AXI_RUSER_WIDTH),
		.IGNORE_PROT_DATA_INSN(0),
		.DEPTH               (8)
	) axi_read_observer (
		.clock       (clock   ),
		.reset       (reset   ),
		.axi_arid    (ar_id   ),
		.axi_araddr  (ar_addr ),
		.axi_arregion(4'b0000 ),
		.axi_arlen   (ar_len  ),
		.axi_arsize  (ar_size ),
		.axi_arburst (ar_burst),
		.axi_arlock  (ar_lock ),
		.axi_arcache (ar_cache),
		.axi_arprot  (ar_prot ),
		.axi_arqos   (4'b0000 ),
		.axi_aruser  (1'b0    ),
		.axi_arvalid (ar_valid),
		.axi_arready (ar_ready),
		.axi_rid     (r_id    ),
		.axi_rdata   (r_data  ),
		.axi_rresp   (r_resp  ),
		.axi_rlast   (r_last  ),
		.axi_ruser   (1'b0    ),
		.axi_rvalid  (r_valid ),
		.axi_rready  (r_ready )
		`RVFI_BUS_CHANNEL_CONN(1)
	);
`endif

`ifdef CL1_USE_AXI_CACHE_DUT
	Cl1Top_AXI_CACHE uut (
`else
	Cl1Top_AXI uut (
`endif
		.clock                      (clock   ),
		.reset                      (!reset  ),

		// Randomized interrupts, debug tied off
		.io_ext_irq                 (ext_irq ),
		.io_sft_irq                 (sft_irq ),
		.io_tmr_irq                 (tmr_irq ),
		.io_dbg_req_i               (1'b0    ),
`ifdef CL1_USE_AXI_CACHE_DUT
		.io_boot_addr               (32'h80000000),
`endif

		// AXI4 AR
		.io_master_ar_valid         (ar_valid),
		.io_master_ar_ready         (ar_ready),
		.io_master_ar_bits_araddr   (ar_addr ),
		.io_master_ar_bits_arid     (ar_id   ),
		.io_master_ar_bits_arlen    (ar_len  ),
		.io_master_ar_bits_arsize   (ar_size ),
		.io_master_ar_bits_arburst  (ar_burst),
		.io_master_ar_bits_arlock   (ar_lock ),
		.io_master_ar_bits_arcache  (ar_cache),
		.io_master_ar_bits_arprot   (ar_prot ),

		// AXI4 R
		.io_master_r_ready          (r_ready ),
		.io_master_r_valid          (r_valid ),
		.io_master_r_bits_rdata     (r_data  ),
		.io_master_r_bits_rresp     (r_resp  ),
		.io_master_r_bits_rlast     (r_last  ),
		.io_master_r_bits_rid       (r_id    ),

		// AXI4 AW
		.io_master_aw_valid         (aw_valid),
		.io_master_aw_ready         (aw_ready),
		.io_master_aw_bits_awaddr   (aw_addr ),
		.io_master_aw_bits_awid     (aw_id   ),
		.io_master_aw_bits_awlen    (aw_len  ),
		.io_master_aw_bits_awsize   (aw_size ),
		.io_master_aw_bits_awburst  (aw_burst),
		.io_master_aw_bits_awlock   (aw_lock ),
		.io_master_aw_bits_awcache  (aw_cache),
		.io_master_aw_bits_awprot   (aw_prot ),

		// AXI4 W
		.io_master_w_valid          (w_valid ),
		.io_master_w_ready          (w_ready ),
		.io_master_w_bits_wdata     (w_data  ),
		.io_master_w_bits_wstrb     (w_strb  ),
		.io_master_w_bits_wlast     (w_last  ),

		// AXI4 B
		.io_master_b_ready          (b_ready ),
		.io_master_b_valid          (b_valid ),
		.io_master_b_bits_bresp     (b_resp  ),
		.io_master_b_bits_bid       (b_id    ),

		// RVFI
		`RVFI_CONN
	);

`endif

	always @* begin
		// Debug Mode is disabled for formal runs via
		// `chisel3.assume(!dbg_flush)` in Cl1Top.scala (on the internal
		// signal `core.dm.io.dbg_flush`). That single assume implies
		// dbg_mode_r=0, step_req_r=0, ebreakm=0 for every reachable cycle,
		// so no additional debug-related wrapper-side assumes are needed.
`ifndef RISCV_FORMAL_INTERRUPT
		// Default no-interrupt environment. The interrupt and progress checks
		// define RISCV_FORMAL_INTERRUPT to let the solver drive the irq lines
		// and pick an arbitrary initial mstatus.MIE.
		assume (ext_irq == 1'b0);
		assume (sft_irq == 1'b0);
		assume (tmr_irq == 1'b0);
`else
`endif
`ifdef RISCV_FORMAL_INTERRUPT_PROGRESS_ENV
		// Interrupt-progress checks allow arbitrary interrupts before the
		// progress window, then quiesce them so liveness cannot be satisfied
		// or defeated solely by a permanent external interrupt stream.
		if (cl1_formal_cycle >= CL1_FORMAL_INTERRUPT_QUIESCE_CYCLE) begin
			assume (ext_irq == 1'b0);
			assume (sft_irq == 1'b0);
			assume (tmr_irq == 1'b0);
		end
`endif
`ifdef RISCV_FORMAL_DEADLOCK_ENV
		// Deadlock checks use arbitrary memory contents with bounded response
		// latency. Main progress checks can enable non-OKAY responses to prove
		// fault progress. WFI is excluded from successful instruction fetches
		// because it is an architectural wait.
`ifdef CL1_USE_NATIVE_BUS
		if (ibus_rsp_valid && !ibus_rsp_bits_err)
			assume (!`CL1_FORMAL_INSN_WFI(ibus_rsp_bits_data));
`endif
`endif
`ifdef CL1_FORMAL_ASSUME_ALIGNED_32I
		// Software contract: compressed instructions may start at any
		// halfword, but 32-bit instructions are kept 32-bit aligned.
		if (!reset && rvfi_valid[0] && rvfi_insn[1:0] == 2'b11)
			assume (rvfi_pc_rdata[1] == 1'b0);
`endif

	end

`ifdef RISCV_FORMAL_INTERRUPT_PROGRESS_ENV
	reg [31:0] cl1_formal_cycle = 0;
	localparam integer CL1_FORMAL_INTERRUPT_QUIESCE_CYCLE =
`ifdef RISCV_FORMAL_TRIG_CYCLE
		`RISCV_FORMAL_TRIG_CYCLE
`else
		((`RISCV_FORMAL_CHECK_CYCLE > 8) ? 8 : `RISCV_FORMAL_CHECK_CYCLE)
`endif
	;

	always @(posedge clock) begin
		if (reset)
			cl1_formal_cycle <= 0;
		else
			cl1_formal_cycle <= cl1_formal_cycle + 1'b1;
	end
`endif

`ifdef RISCV_FORMAL_BUS
`ifdef CL1_USE_NATIVE_BUS
	assign rvfi_bus_valid = '0;
	assign rvfi_bus_insn  = '0;
	assign rvfi_bus_data  = '0;
	assign rvfi_bus_fault = '0;
	assign rvfi_bus_addr  = '0;
	assign rvfi_bus_rmask = '0;
	assign rvfi_bus_wmask = '0;
	assign rvfi_bus_rdata = '0;
	assign rvfi_bus_wdata = '0;
`endif
`endif

endmodule

// Native bus dummy slave for formal verification (used with Cl1Top)
// Simple req/rsp handshake: accepts requests, returns stable non-deterministic
// responses with bounded latency.
module native_bus_dummy_slave (
	input         clock,
	input         reset,

	input         req_valid,
	output        req_ready,

	output        rsp_valid,
	input         rsp_ready,
	output [31:0] rsp_bits_data,
	output        rsp_bits_err
);

	reg [1:0] rsp_pending = 0;
	reg [31:0] rsp_data_q0 = 0;
	reg [31:0] rsp_data_q1 = 0;
	reg        rsp_err_q0 = 0;
	reg        rsp_err_q1 = 0;

	localparam [2:0] RSP_DELAY_MAX = 3'd4;
	`rvformal_rand_reg [31:0] rsp_data_nd;
	`rvformal_rand_reg rsp_delay_nd;
`ifdef CL1_NATIVE_FAULT_FORMAL_MEM
	`rvformal_rand_reg rsp_err_nd;
	wire rsp_err_next = rsp_err_nd;
`else
	wire rsp_err_next = 1'b0;
`endif
	//wire rsp_delay = 0;

	reg [2:0] rsp_delay_cnt = 0;
	wire rsp_delay = rsp_delay_nd && (rsp_delay_cnt < RSP_DELAY_MAX);

	wire req_fire = req_valid && req_ready;
	wire rsp_fire = rsp_valid && rsp_ready;

	assign req_ready     = (rsp_pending < 2) && !reset;
	assign rsp_valid     = (rsp_pending != 0) && !reset && !rsp_delay;
	assign rsp_bits_data = rsp_data_q0;
	assign rsp_bits_err  = rsp_err_q0;

	always @(posedge clock) begin
		if (reset) begin
			rsp_pending   <= 0;
			rsp_data_q0   <= 0;
			rsp_data_q1   <= 0;
			rsp_err_q0    <= 0;
			rsp_err_q1    <= 0;
			rsp_delay_cnt <= 0;
		end else begin
			case ({req_fire, rsp_fire})
				2'b10: begin
					if (rsp_pending == 0) begin
						rsp_data_q0 <= rsp_data_nd;
						rsp_err_q0  <= rsp_err_next;
					end else begin
						rsp_data_q1 <= rsp_data_nd;
						rsp_err_q1  <= rsp_err_next;
					end
					rsp_pending <= rsp_pending + 1'b1;
				end
				2'b01: begin
					if (rsp_pending == 2) begin
						rsp_data_q0 <= rsp_data_q1;
						rsp_err_q0  <= rsp_err_q1;
					end
					rsp_pending <= rsp_pending - 1'b1;
				end
				2'b11: begin
					if (rsp_pending == 1) begin
						rsp_data_q0 <= rsp_data_nd;
						rsp_err_q0  <= rsp_err_next;
					end else begin
						rsp_data_q0 <= rsp_data_q1;
						rsp_err_q0  <= rsp_err_q1;
						rsp_data_q1 <= rsp_data_nd;
						rsp_err_q1  <= rsp_err_next;
					end
				end
				default: rsp_pending <= rsp_pending;
			endcase
			if (rsp_delay)
				rsp_delay_cnt <= rsp_delay_cnt + 1'b1;
			else
				rsp_delay_cnt <= 0;
		end
	end
endmodule

// AXI4 Dummy Slave for formal verification
// Modeled after Rocket's tilelink_ad_dummy:
//   - Tracks pending read/write transactions
//   - Only asserts response valid when a request is pending
//   - Properly handles burst transfers (arlen/awlen)
//   - Returns stable non-deterministic data with bounded response latency
module axi4_dummy_slave #(
	parameter ID_WIDTH = 5
) (
	input         clock,
	input         reset,

	// AR - read address
	input         ar_valid,
	output        ar_ready,
	input  [ID_WIDTH-1:0] ar_id,
	input  [7:0]  ar_len,
	input  [2:0]  ar_size,
	input  [2:0]  ar_prot,

	// R - read data
	output        r_valid,
	input         r_ready,
	output [31:0] r_data,
	output [1:0]  r_resp,
	output        r_last,
	output [ID_WIDTH-1:0] r_id,

	// AW - write address
	input         aw_valid,
	output        aw_ready,
	input  [ID_WIDTH-1:0] aw_id,
	input  [7:0]  aw_len,

	// W - write data
	input         w_valid,
	output        w_ready,
	input         w_last,

	// B - write response
	output        b_valid,
	input         b_ready,
	output [1:0]  b_resp,
	output [ID_WIDTH-1:0] b_id
);

	localparam [2:0] AXI_DELAY_MAX = 3'd4;

	// ---- Read channel state machine ----
	reg        rd_busy = 0;
	reg [ID_WIDTH-1:0] rd_id;
	reg [7:0]  rd_len;
	reg [7:0]  rd_cnt;
	reg [31:0] rd_data = 0;
	reg        rd_instr = 0;
	reg        rd_rsp_valid = 0;

	`rvformal_rand_reg [31:0] rd_data_nd;
	`rvformal_rand_reg [2:0] ar_ready_delay_nd;
	`rvformal_rand_reg [2:0] rd_delay_nd;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
	`rvformal_rand_reg rd_fault_nd;
	reg rd_fault = 0;
`endif
	reg [2:0] ar_ready_delay_cnt = 0;
	reg [2:0] rd_delay_cnt = 0;
	reg ar_ready_delay_sampled = 0;
	reg rd_delay_sampled = 0;
	wire ar_ready_can_accept = !rd_busy && !reset;
	wire [2:0] ar_ready_delay_next =
		(ar_ready_delay_nd > AXI_DELAY_MAX) ? AXI_DELAY_MAX : ar_ready_delay_nd;
	wire [2:0] rd_delay_next =
		(rd_delay_nd > AXI_DELAY_MAX) ? AXI_DELAY_MAX : rd_delay_nd;
`ifdef CL1_AXI_FAST_FORMAL_MEM
	wire ar_ready_delay = 1'b0;
	wire rd_delay = 1'b0;
`else
`ifdef CL1_AXI_STRESS_BACKPRESSURE
	wire ar_ready_delay = ar_valid && ar_ready_can_accept &&
		(ar_ready_delay_sampled ? (ar_ready_delay_cnt != 0) :
					   (ar_ready_delay_next != 0));
	wire rd_delay = rd_busy && !rd_rsp_valid &&
		(rd_delay_sampled ? (rd_delay_cnt != 0) :
				     (rd_delay_next != 0));
`else
	wire ar_ready_delay = 1'b0;
	wire rd_delay = 1'b0;
`endif
`endif

	wire rd_last = (rd_cnt == rd_len);

	assign ar_ready = ar_ready_can_accept && !ar_ready_delay;
	assign r_valid  = rd_rsp_valid && !reset;
	assign r_data   = rd_data;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
	assign r_resp   = rd_fault ? 2'b10 : 2'b00;  // SLVERR or OKAY
`else
	assign r_resp   = 2'b00;
`endif
	assign r_last   = rd_last;
	assign r_id     = rd_id;

	always @* begin
		assert (!(ar_valid && ar_ready && rd_busy));
		assert (!rd_rsp_valid || rd_busy);
		if (r_valid)
			assert (rd_busy && r_id == rd_id);
	end

`ifdef RISCV_FORMAL_DEADLOCK_ENV
	always @* begin
		if (r_valid && rd_instr && r_resp == 2'b00)
			assume (!`CL1_FORMAL_INSN_WFI(r_data));
	end
`endif

	always @(posedge clock) begin
		if (reset) begin
			rd_busy      <= 0;
			rd_data      <= 0;
			rd_instr     <= 0;
			rd_rsp_valid <= 0;
			ar_ready_delay_cnt <= 0;
			rd_delay_cnt <= 0;
			ar_ready_delay_sampled <= 0;
			rd_delay_sampled <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
			rd_fault     <= 0;
`endif
		end else begin
			// Accept new read request
			if (ar_ready && ar_valid) begin
				rd_busy  <= 1;
				rd_id    <= ar_id;
				rd_len   <= ar_len;
				rd_cnt   <= 0;
				rd_data  <= rd_data_nd;
				rd_instr <= ar_prot[2];
				rd_rsp_valid <= 0;
				rd_delay_sampled <= 0;
				rd_delay_cnt <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
				rd_fault <= rd_fault_nd;
`endif
			end

			if (rd_busy && !rd_rsp_valid && !rd_delay) begin
				rd_rsp_valid <= 1'b1;
			end

			// Deliver read data beat
			if (r_valid && r_ready) begin
				if (rd_last) begin
					rd_busy      <= 0;
					rd_instr     <= 0;
					rd_rsp_valid <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
					rd_fault <= 0;
`endif
				end else begin
					rd_cnt       <= rd_cnt + 1;
					rd_data      <= rd_data_nd;
					rd_rsp_valid <= 0;
					rd_delay_sampled <= 0;
					rd_delay_cnt <= 0;
				end
			end

			if (!rd_busy || rd_rsp_valid || !rd_delay) begin
				rd_delay_sampled <= 0;
				rd_delay_cnt <= 0;
			end else if (!rd_delay_sampled) begin
				rd_delay_sampled <= 1'b1;
				rd_delay_cnt <= rd_delay_next - 1'b1;
			end else begin
				rd_delay_cnt <= rd_delay_cnt - 1'b1;
			end

			if (ar_ready && ar_valid) begin
				ar_ready_delay_sampled <= 0;
				ar_ready_delay_cnt <= 0;
			end else if (!ar_valid || !ar_ready_can_accept) begin
				ar_ready_delay_sampled <= 0;
				ar_ready_delay_cnt <= 0;
			end else if (!ar_ready_delay_sampled) begin
				ar_ready_delay_sampled <= 1'b1;
				ar_ready_delay_cnt <= ar_ready_delay_next - 1'b1;
			end else if (ar_ready_delay_cnt != 0) begin
				ar_ready_delay_cnt <= ar_ready_delay_cnt - 1'b1;
			end
		end
	end

	// ---- Write channel state machine ----
	reg        wr_addr_busy = 0;
	reg [ID_WIDTH-1:0] wr_id;
	reg [7:0]  wr_len;
	reg [7:0]  wr_cnt;
	reg        wr_resp_pending = 0;
	reg        wr_resp_valid = 0;

	`rvformal_rand_reg [2:0] aw_ready_delay_nd;
	`rvformal_rand_reg [2:0] w_ready_delay_nd;
	`rvformal_rand_reg [2:0] wr_delay_nd;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
	`rvformal_rand_reg wr_fault_nd;
	reg wr_fault = 0;
`endif
	reg [2:0] aw_ready_delay_cnt = 0;
	reg [2:0] w_ready_delay_cnt = 0;
	reg [2:0] wr_delay_cnt = 0;
	reg aw_ready_delay_sampled = 0;
	reg w_ready_delay_sampled = 0;
	reg wr_delay_sampled = 0;
	wire aw_ready_can_accept = !wr_addr_busy && !wr_resp_pending && !reset;
	wire w_ready_can_accept = wr_addr_busy && !reset;
	wire [2:0] aw_ready_delay_next =
		(aw_ready_delay_nd > AXI_DELAY_MAX) ? AXI_DELAY_MAX : aw_ready_delay_nd;
	wire [2:0] w_ready_delay_next =
		(w_ready_delay_nd > AXI_DELAY_MAX) ? AXI_DELAY_MAX : w_ready_delay_nd;
	wire [2:0] wr_delay_next =
		(wr_delay_nd > AXI_DELAY_MAX) ? AXI_DELAY_MAX : wr_delay_nd;
`ifdef CL1_AXI_FAST_FORMAL_MEM
	wire aw_ready_delay = 1'b0;
	wire w_ready_delay = 1'b0;
	wire wr_delay = 1'b0;
`else
`ifdef CL1_AXI_STRESS_BACKPRESSURE
	wire aw_ready_delay = aw_valid && aw_ready_can_accept &&
		(aw_ready_delay_sampled ? (aw_ready_delay_cnt != 0) :
					   (aw_ready_delay_next != 0));
	wire w_ready_delay = w_valid && w_ready_can_accept &&
		(w_ready_delay_sampled ? (w_ready_delay_cnt != 0) :
					 (w_ready_delay_next != 0));
	wire wr_delay = wr_resp_pending && !wr_resp_valid &&
		(wr_delay_sampled ? (wr_delay_cnt != 0) :
				     (wr_delay_next != 0));
`else
	wire aw_ready_delay = 1'b0;
	wire w_ready_delay = 1'b0;
	wire wr_delay = 1'b0;
`endif
`endif

	assign aw_ready = aw_ready_can_accept && !aw_ready_delay;
	assign w_ready  = w_ready_can_accept && !w_ready_delay;
	assign b_valid  = wr_resp_valid && !reset;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
	assign b_resp   = wr_fault ? 2'b10 : 2'b00;  // SLVERR or OKAY
`else
	assign b_resp   = 2'b00;
`endif
	assign b_id     = wr_id;
	wire wr_expected_last = (wr_cnt == wr_len);

	always @* begin
		assert (!(aw_valid && aw_ready && (wr_addr_busy || wr_resp_pending)));
		assert (!(w_valid && w_ready && !wr_addr_busy));
		assert (!wr_resp_pending || !wr_addr_busy);
		assert (!wr_resp_valid || wr_resp_pending);
		if (w_valid && w_ready)
			assert (w_last == wr_expected_last);
		if (b_valid)
			assert (wr_resp_pending && b_id == wr_id);
	end

	always @(posedge clock) begin
		if (reset) begin
			wr_addr_busy    <= 0;
			wr_len          <= 0;
			wr_cnt          <= 0;
			wr_resp_pending <= 0;
			wr_resp_valid   <= 0;
			aw_ready_delay_cnt <= 0;
			w_ready_delay_cnt  <= 0;
			wr_delay_cnt    <= 0;
			aw_ready_delay_sampled <= 0;
			w_ready_delay_sampled  <= 0;
			wr_delay_sampled <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
			wr_fault        <= 0;
`endif
		end else begin
			// Accept write address
			if (aw_ready && aw_valid) begin
				wr_addr_busy <= 1;
				wr_id        <= aw_id;
				wr_len       <= aw_len;
				wr_cnt       <= 0;
				w_ready_delay_sampled <= 0;
				w_ready_delay_cnt <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
				wr_fault     <= wr_fault_nd;
`endif
			end

			// Accept write data until wlast
			if (w_ready && w_valid) begin
				if (w_last) begin
					wr_addr_busy    <= 0;
					wr_resp_pending <= 1;
					wr_resp_valid   <= 0;
					wr_delay_sampled <= 0;
					wr_delay_cnt <= 0;
				end else begin
					wr_cnt <= wr_cnt + 1;
					w_ready_delay_sampled <= 0;
					w_ready_delay_cnt <= 0;
				end
			end

			if (wr_resp_pending && !wr_resp_valid && !wr_delay)
				wr_resp_valid <= 1'b1;

			// Write response handshake
			if (b_valid && b_ready) begin
				wr_resp_pending <= 0;
				wr_resp_valid   <= 0;
				wr_delay_sampled <= 0;
				wr_delay_cnt <= 0;
`ifdef CL1_AXI_FAULT_FORMAL_MEM
				wr_fault        <= 0;
`endif
			end

			if (!wr_resp_pending || wr_resp_valid || !wr_delay) begin
				wr_delay_sampled <= 0;
				wr_delay_cnt <= 0;
			end else if (!wr_delay_sampled) begin
				wr_delay_sampled <= 1'b1;
				wr_delay_cnt <= wr_delay_next - 1'b1;
			end else begin
				wr_delay_cnt <= wr_delay_cnt - 1'b1;
			end

			if (aw_ready && aw_valid) begin
				aw_ready_delay_sampled <= 0;
				aw_ready_delay_cnt <= 0;
			end else if (!aw_valid || !aw_ready_can_accept) begin
				aw_ready_delay_sampled <= 0;
				aw_ready_delay_cnt <= 0;
			end else if (!aw_ready_delay_sampled) begin
				aw_ready_delay_sampled <= 1'b1;
				aw_ready_delay_cnt <= aw_ready_delay_next - 1'b1;
			end else if (aw_ready_delay_cnt != 0) begin
				aw_ready_delay_cnt <= aw_ready_delay_cnt - 1'b1;
			end

			if (w_ready && w_valid) begin
				w_ready_delay_sampled <= 0;
				w_ready_delay_cnt <= 0;
			end else if (!w_valid || !w_ready_can_accept) begin
				w_ready_delay_sampled <= 0;
				w_ready_delay_cnt <= 0;
			end else if (!w_ready_delay_sampled) begin
				w_ready_delay_sampled <= 1'b1;
				w_ready_delay_cnt <= w_ready_delay_next - 1'b1;
			end else if (w_ready_delay_cnt != 0) begin
				w_ready_delay_cnt <= w_ready_delay_cnt - 1'b1;
			end
		end
	end

`ifdef CL1_AXI_COVER_ENV
	reg seen_axi_ar_delay = 0;
	reg seen_axi_aw_delay = 0;
	reg seen_axi_w_delay  = 0;
	reg seen_axi_r_delay  = 0;
	reg seen_axi_b_delay  = 0;
	reg seen_axi_read_txn = 0;
	reg seen_axi_write_txn = 0;

	always @(posedge clock) begin
		if (reset) begin
			seen_axi_ar_delay   <= 1'b0;
			seen_axi_aw_delay   <= 1'b0;
			seen_axi_w_delay    <= 1'b0;
			seen_axi_r_delay    <= 1'b0;
			seen_axi_b_delay    <= 1'b0;
			seen_axi_read_txn   <= 1'b0;
			seen_axi_write_txn  <= 1'b0;
		end else begin
			seen_axi_ar_delay   <= seen_axi_ar_delay || ar_ready_delay;
			seen_axi_aw_delay   <= seen_axi_aw_delay || aw_ready_delay;
			seen_axi_w_delay    <= seen_axi_w_delay  || w_ready_delay;
			seen_axi_r_delay    <= seen_axi_r_delay  || (rd_busy && rd_delay);
			seen_axi_b_delay    <= seen_axi_b_delay  || (wr_resp_pending && wr_delay);
			seen_axi_read_txn   <= seen_axi_read_txn || (r_valid && r_ready);
			seen_axi_write_txn  <= seen_axi_write_txn || (b_valid && b_ready);
		end
	end

	always @* if (!reset) begin
		cover (seen_axi_ar_delay);
		cover (seen_axi_aw_delay);
		cover (seen_axi_w_delay);
		cover (seen_axi_r_delay);
		cover (seen_axi_b_delay);
		cover (seen_axi_read_txn && seen_axi_write_txn &&
		       seen_axi_ar_delay && seen_axi_aw_delay && seen_axi_w_delay &&
		       seen_axi_r_delay && seen_axi_b_delay);
	end
`endif
endmodule
