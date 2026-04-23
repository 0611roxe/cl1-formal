module rvfi_wrapper (
	input         clock,
	input         reset,
	`RVFI_OUTPUTS
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

	// AXI4 AR channel (read address)
	(* keep *) wire        ar_valid;
	(* keep *) wire [31:0] ar_addr;
	(* keep *) wire [3:0]  ar_id;
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
	(* keep *) wire [3:0]  r_id;

	// AXI4 AW channel (write address)
	(* keep *) wire        aw_valid;
	(* keep *) wire [31:0] aw_addr;
	(* keep *) wire [3:0]  aw_id;
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
	(* keep *) wire [3:0]  b_id;

	// AXI4 Dummy Slave
	axi4_dummy_slave axi_slave (
		.clock          (clock   ),
		.reset          (reset   ),

		// AR
		.ar_valid       (ar_valid),
		.ar_ready       (ar_ready),
		.ar_id          (ar_id   ),
		.ar_len         (ar_len  ),
		.ar_size        (ar_size ),

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

	Cl1Top_AXI uut (
		.clock                      (clock   ),
		.reset                      (!reset  ),

		// Randomized interrupts, debug tied off
		.io_ext_irq                 (ext_irq ),
		.io_sft_irq                 (sft_irq ),
		.io_tmr_irq                 (tmr_irq ),
		.io_dbg_req_i               (1'b0    ),

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
		// Default (no-interrupt) environment for the CSR / priv_insn /
		// trap_handler checks. The interrupt check defines
		// RISCV_FORMAL_INTERRUPT to let the solver drive the irq lines
		// and pick an arbitrary initial mstatus.MIE.
		assume (ext_irq == 1'b0);
		assume (sft_irq == 1'b0);
		assume (tmr_irq == 1'b0);
		if (reset) begin
			assume (uut.core.csr.mstatus_mie == 1'b0);
			assume (uut.intr_pending == 1'b0);
		end
`else
		if (reset) begin
			assume (uut.intr_pending == 1'b0);
		end
`endif
`ifdef RISCV_FORMAL_DEADLOCK_ENV
		// The following assumptions ensure that when the environment quiesces, 
		// the core can still retire instructions that are not interrupts (i.e.,
		// with rvfi_intr=0), so that the deadlock check can observe a valid RVFI
		// trace up to the point of deadlock.		
`ifdef CL1_USE_NATIVE_BUS
		assume (ibus_rsp_bits_data == 32'h00000013);
		assume (ibus_rsp_bits_err  == 1'b0);
		assume (dbus_rsp_bits_err  == 1'b0);
`else
		assume (r_data == 32'h00000013);
		assume (r_resp == 2'b00);
		assume (b_resp == 2'b00);
`endif
`endif
	end

endmodule

// Native bus dummy slave for formal verification (used with Cl1Top)
// Simple req/rsp handshake: accepts requests, returns non-deterministic data
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

	`rvformal_rand_reg [31:0] rsp_data_nd;
	// `rvformal_rand_reg rsp_delay;
	wire rsp_delay = 0;

	wire req_fire = req_valid && req_ready;
	wire rsp_fire = rsp_valid && rsp_ready;

	assign req_ready     = (rsp_pending < 2) && !reset;
	assign rsp_valid     = (rsp_pending != 0) && !reset && !rsp_delay;
	assign rsp_bits_data = rsp_data_nd;
	assign rsp_bits_err  = 1'b0;

	always @(posedge clock) begin
		if (reset) begin
			rsp_pending <= 0;
		end else begin
			case ({req_fire, rsp_fire})
				2'b10: rsp_pending <= rsp_pending + 1'b1;
				2'b01: rsp_pending <= rsp_pending - 1'b1;
				default: rsp_pending <= rsp_pending;
			endcase
		end
	end
endmodule

// AXI4 Dummy Slave for formal verification
// Modeled after Rocket's tilelink_ad_dummy:
//   - Tracks pending read/write transactions
//   - Only asserts response valid when a request is pending
//   - Properly handles burst transfers (arlen/awlen)
//   - Returns OKAY response, non-deterministic data
module axi4_dummy_slave (
	input         clock,
	input         reset,

	// AR - read address
	input         ar_valid,
	output        ar_ready,
	input  [3:0]  ar_id,
	input  [7:0]  ar_len,
	input  [2:0]  ar_size,

	// R - read data
	output        r_valid,
	input         r_ready,
	output [31:0] r_data,
	output [1:0]  r_resp,
	output        r_last,
	output [3:0]  r_id,

	// AW - write address
	input         aw_valid,
	output        aw_ready,
	input  [3:0]  aw_id,
	input  [7:0]  aw_len,

	// W - write data
	input         w_valid,
	output        w_ready,
	input         w_last,

	// B - write response
	output        b_valid,
	input         b_ready,
	output [1:0]  b_resp,
	output [3:0]  b_id
);

	// ---- Read channel state machine ----
	reg        rd_busy = 0;
	reg [3:0]  rd_id;
	reg [7:0]  rd_len;
	reg [7:0]  rd_cnt;

	`rvformal_rand_reg [31:0] rd_data_nd;

	wire rd_last = (rd_cnt == rd_len);

	assign ar_ready = !rd_busy && !reset;
	assign r_valid  = rd_busy && !reset;
	assign r_data   = rd_data_nd;
	assign r_resp   = 2'b00;  // OKAY
	assign r_last   = rd_last;
	assign r_id     = rd_id;

	always @(posedge clock) begin
		if (reset) begin
			rd_busy <= 0;
		end else begin
			// Accept new read request
			if (ar_ready && ar_valid) begin
				rd_busy <= 1;
				rd_id   <= ar_id;
				rd_len  <= ar_len;
				rd_cnt  <= 0;
			end

			// Deliver read data beat
			if (r_valid && r_ready) begin
				if (rd_last)
					rd_busy <= 0;
				else
					rd_cnt <= rd_cnt + 1;
			end
		end
	end

	// ---- Write channel state machine ----
	reg        wr_addr_busy = 0;
	reg        wr_data_done = 0;
	reg [3:0]  wr_id;
	reg        wr_resp_pending = 0;

	`rvformal_rand_reg wr_delay;

	assign aw_ready = !wr_addr_busy && !wr_resp_pending && !reset;
	assign w_ready  = wr_addr_busy && !reset;
	assign b_valid  = wr_resp_pending && !reset && !wr_delay;
	assign b_resp   = 2'b00;  // OKAY
	assign b_id     = wr_id;

	always @(posedge clock) begin
		if (reset) begin
			wr_addr_busy   <= 0;
			wr_data_done   <= 0;
			wr_resp_pending <= 0;
		end else begin
			// Accept write address
			if (aw_ready && aw_valid) begin
				wr_addr_busy <= 1;
				wr_id        <= aw_id;
			end

			// Accept write data until wlast
			if (w_ready && w_valid && w_last) begin
				wr_addr_busy    <= 0;
				wr_resp_pending <= 1;
			end

			// Write response handshake
			if (b_valid && b_ready) begin
				wr_resp_pending <= 0;
			end
		end
	end
endmodule
