module cl1_cache_control_env #(
  parameter integer QUIET_AXI = 0
) (
  input wire clock,

  output wire reset,

  input  wire        ic_req_valid,
  input  wire [31:0] ic_req_addr,
  input  wire        ic_dx_valid,
  input  wire        ic_dx_invalid,
  input  wire        ic_dx_clean,
  output wire        ic_req_ready,
  output wire        ic_rsp_valid,
  output wire        ic_rsp_err,
  output wire        ic_dx_ready,
  output wire        icache_idle,

  input  wire        dc_req_valid,
  input  wire [31:0] dc_req_addr,
  input  wire [31:0] dc_req_data,
  input  wire        dc_req_wen,
  input  wire        dc_dx_valid,
  input  wire        dc_dx_invalid,
  input  wire        dc_dx_clean,
  output wire        dc_req_ready,
  output wire        dc_rsp_valid,
  output wire        dc_rsp_err,
  output wire        dc_dx_ready,
  output wire        dcache_idle,

  output wire        aw_valid,
  output wire        aw_ready,
  output wire [31:0] aw_addr,
  output wire [7:0]  aw_len,
  output wire [2:0]  aw_size,
  output wire        w_valid,
  output wire        w_ready,
  output wire [31:0] w_data,
  output wire [3:0]  w_strb,
  output wire        w_last,
  output wire        ar_valid,
  output wire        ar_ready,
  output wire [31:0] ar_addr,
  output wire        aw_fire,
  output wire        w_fire,
  output wire        ar_fire,

  output wire        dc_writeback_valid,
  output wire        dc_writeback_ready,
  output wire        dc_writeback_from_clean,
  output wire [31:0] dc_writeback_addr,
  output wire [3:0]  dc_writeback_mask,
  output wire [3:0]  dc_writeback_len,
  output wire [1:0]  dc_writeback_size,
  output wire        dc_writeback_last
);
  reg reset_r = 1'b1;
  always @(posedge clock) reset_r <= 1'b0;
  initial assume (reset_r);
  assign reset = reset_r;

  `CACHE_FORMAL_SEED_WORD(cf_seed_word, 16'hcace)

  wire [31:0] ic_rsp_data;
  wire [31:0] dc_rsp_data;

  wire [1:0]  aw_id;
  wire [1:0]  aw_burst;

  wire        b_valid;
  wire        b_ready;
  wire [1:0]  b_resp;
  wire [1:0]  b_id;

  wire [1:0]  ar_id;
  wire [7:0]  ar_len;
  wire [2:0]  ar_size;
  wire [1:0]  ar_burst;
  wire [2:0]  ar_prot;

  wire        r_valid;
  wire        r_ready;
  wire [1:0]  r_resp;
  wire [31:0] r_data;
  wire        r_last;
  wire [1:0]  r_id;

  wire        b_fire;
  wire        r_fire;
  wire [1:0]  aw_wait_cnt;
  wire [1:0]  w_wait_cnt;
  wire [1:0]  ar_wait_cnt;
  wire [1:0]  b_wait_cnt;
  wire [1:0]  r_wait_cnt;
  wire        aw_blocked;
  wire        w_blocked;
  wire        ar_blocked;
  wire        b_blocked;
  wire        r_blocked;

  wire        dc_dirty_replace_valid;
  wire [31:0] dc_dirty_replace_addr;
  wire        dc_dirty_replace_way_dirty;
  wire        dc_read_req_valid;
  wire        dc_writeback_from_replace;

  (* anyseq *) reg aw_ready_any;
  (* anyseq *) reg w_ready_any;
  (* anyseq *) reg ar_ready_any;
  (* anyseq *) reg b_delay_any;
  (* anyseq *) reg r_delay_any;
  (* anyseq *) reg force_aw_wait_any;
  (* anyseq *) reg force_w_wait_any;
  (* anyseq *) reg force_ar_wait_any;
  (* anyseq *) reg force_b_wait_any;
  (* anyseq *) reg force_r_wait_any;

  wire [31:0] axi_read_data = cf_seed_word(ar_addr);
  wire        core_rsp_ready = 1'b1;

  Cl1CacheFormal dut (
    .clock                       (clock),
    .reset                       (reset_r),

    .io_icore_req_ready          (ic_req_ready),
    .io_icore_req_valid          (ic_req_valid),
    .io_icore_req_bits_addr      (ic_req_addr),
    .io_icore_req_bits_data      (32'h0),
    .io_icore_req_bits_wen       (1'b0),
    .io_icore_req_bits_mask      (4'hf),
    .io_icore_req_bits_cache     (1'b1),
    .io_icore_req_bits_size      (2'b10),
    .io_icore_rsp_ready          (core_rsp_ready),
    .io_icore_rsp_valid          (ic_rsp_valid),
    .io_icore_rsp_bits_data      (ic_rsp_data),
    .io_icore_rsp_bits_err       (ic_rsp_err),

    .io_dcore_req_ready          (dc_req_ready),
    .io_dcore_req_valid          (dc_req_valid),
    .io_dcore_req_bits_addr      (dc_req_addr),
    .io_dcore_req_bits_data      (dc_req_data),
    .io_dcore_req_bits_wen       (dc_req_wen),
    .io_dcore_req_bits_mask      (4'hf),
    .io_dcore_req_bits_cache     (1'b1),
    .io_dcore_req_bits_size      (2'b10),
    .io_dcore_rsp_ready          (core_rsp_ready),
    .io_dcore_rsp_valid          (dc_rsp_valid),
    .io_dcore_rsp_bits_data      (dc_rsp_data),
    .io_dcore_rsp_bits_err       (dc_rsp_err),

    .io_idxReq_ready             (ic_dx_ready),
    .io_idxReq_valid             (ic_dx_valid),
    .io_idxReq_bits_invalid      (ic_dx_invalid),
    .io_idxReq_bits_clean        (ic_dx_clean),

    .io_ddxReq_ready             (dc_dx_ready),
    .io_ddxReq_valid             (dc_dx_valid),
    .io_ddxReq_bits_invalid      (dc_dx_invalid),
    .io_ddxReq_bits_clean        (dc_dx_clean),

    .io_master_aw_ready          (aw_ready),
    .io_master_aw_valid          (aw_valid),
    .io_master_aw_bits_awaddr    (aw_addr),
    .io_master_aw_bits_awid      (aw_id),
    .io_master_aw_bits_awlen     (aw_len),
    .io_master_aw_bits_awsize    (aw_size),
    .io_master_aw_bits_awburst   (aw_burst),

    .io_master_w_ready           (w_ready),
    .io_master_w_valid           (w_valid),
    .io_master_w_bits_wdata      (w_data),
    .io_master_w_bits_wstrb      (w_strb),
    .io_master_w_bits_wlast      (w_last),

    .io_master_b_ready           (b_ready),
    .io_master_b_valid           (b_valid),
    .io_master_b_bits_bresp      (b_resp),
    .io_master_b_bits_bid        (b_id),

    .io_master_ar_ready          (ar_ready),
    .io_master_ar_valid          (ar_valid),
    .io_master_ar_bits_araddr    (ar_addr),
    .io_master_ar_bits_arid      (ar_id),
    .io_master_ar_bits_arlen     (ar_len),
    .io_master_ar_bits_arsize    (ar_size),
    .io_master_ar_bits_arburst   (ar_burst),
    .io_master_ar_bits_arprot    (ar_prot),

    .io_master_r_ready           (r_ready),
    .io_master_r_valid           (r_valid),
    .io_master_r_bits_rresp      (r_resp),
    .io_master_r_bits_rdata      (r_data),
    .io_master_r_bits_rlast      (r_last),
    .io_master_r_bits_rid        (r_id),

    .io_icache_idle              (icache_idle),
    .io_dcache_idle              (dcache_idle),

    .io_dcacheWriteback_dirty_replace_valid     (dc_dirty_replace_valid),
    .io_dcacheWriteback_dirty_replace_addr      (dc_dirty_replace_addr),
    .io_dcacheWriteback_dirty_replace_way_dirty (dc_dirty_replace_way_dirty),
    .io_dcacheWriteback_read_req_valid          (dc_read_req_valid),
    .io_dcacheWriteback_writeback_valid         (dc_writeback_valid),
    .io_dcacheWriteback_writeback_ready         (dc_writeback_ready),
    .io_dcacheWriteback_writeback_from_replace  (dc_writeback_from_replace),
    .io_dcacheWriteback_writeback_from_clean    (dc_writeback_from_clean),
    .io_dcacheWriteback_writeback_addr          (dc_writeback_addr),
    .io_dcacheWriteback_writeback_mask          (dc_writeback_mask),
    .io_dcacheWriteback_writeback_len           (dc_writeback_len),
    .io_dcacheWriteback_writeback_size          (dc_writeback_size),
    .io_dcacheWriteback_writeback_last          (dc_writeback_last)
  );

  cache_axi_single_outstanding_model #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .STRB_WIDTH(4),
    .ID_WIDTH(2),
    .LEN_WIDTH(8),
    .BEAT_BYTES(4)
  ) axi_mem (
    .clock        (clock),
    .reset        (reset_r),
    .aw_valid     (aw_valid),
    .aw_ready     (aw_ready),
    .aw_addr      (aw_addr),
    .aw_id        (aw_id),
    .aw_len       (aw_len),
    .w_valid      (w_valid),
    .w_ready      (w_ready),
    .w_last       (w_last),
    .b_valid      (b_valid),
    .b_ready      (b_ready),
    .b_resp       (b_resp),
    .b_id         (b_id),
    .ar_valid     (ar_valid),
    .ar_ready     (ar_ready),
    .ar_addr      (ar_addr),
    .ar_id        (ar_id),
    .ar_len       (ar_len),
    .r_valid      (r_valid),
    .r_ready      (r_ready),
    .r_resp       (r_resp),
    .r_data       (r_data),
    .r_last       (r_last),
    .r_id         (r_id),
    .read_data    (axi_read_data),
    .aw_ready_any (aw_ready_any),
    .w_ready_any  (w_ready_any),
    .ar_ready_any (ar_ready_any),
    .b_delay_any  (b_delay_any),
    .r_delay_any  (r_delay_any),
    .force_aw_wait(force_aw_wait_any),
    .force_w_wait (force_w_wait_any),
    .force_ar_wait(force_ar_wait_any),
    .force_b_wait (force_b_wait_any),
    .force_r_wait (force_r_wait_any),
    .aw_fire      (aw_fire),
    .w_fire       (w_fire),
    .b_fire       (b_fire),
    .ar_fire      (ar_fire),
    .r_fire       (r_fire),
    .wr_addr_busy (),
    .wr_resp_pending(),
    .wr_id        (),
    .wr_addr      (),
    .wr_len       (),
    .wr_cnt       (),
    .rd_busy      (),
    .rd_id        (),
    .rd_addr      (),
    .rd_len       (),
    .rd_cnt       (),
    .aw_blocked   (aw_blocked),
    .w_blocked    (w_blocked),
    .ar_blocked   (ar_blocked),
    .b_blocked    (b_blocked),
    .r_blocked    (r_blocked),
    .aw_wait_cnt  (aw_wait_cnt),
    .w_wait_cnt   (w_wait_cnt),
    .ar_wait_cnt  (ar_wait_cnt),
    .b_wait_cnt   (b_wait_cnt),
    .r_wait_cnt   (r_wait_cnt)
  );

  cache_axi_master_contract #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .STRB_WIDTH(4),
    .ID_WIDTH(2),
    .LEN_WIDTH(8),
    .MAX_BURST_LEN(3),
    .LINE_ALIGN_LSB(4)
  ) axi_contract (
    .clock   (clock),
    .reset   (reset_r),
    .aw_valid(aw_valid),
    .aw_ready(aw_ready),
    .aw_addr (aw_addr),
    .aw_id   (aw_id),
    .aw_len  (aw_len),
    .aw_size (aw_size),
    .aw_burst(aw_burst),
    .w_valid (w_valid),
    .w_ready (w_ready),
    .w_data  (w_data),
    .w_strb  (w_strb),
    .w_last  (w_last),
    .b_valid (b_valid),
    .b_ready (b_ready),
    .ar_valid(ar_valid),
    .ar_ready(ar_ready),
    .ar_addr (ar_addr),
    .ar_id   (ar_id),
    .ar_len  (ar_len),
    .ar_size (ar_size),
    .ar_burst(ar_burst),
    .ar_prot (ar_prot),
    .r_valid (r_valid),
    .r_ready (r_ready),
    .r_last  (r_last)
  );

  always @* begin
    if (QUIET_AXI) begin
      assume (aw_ready_any);
      assume (w_ready_any);
      assume (ar_ready_any);
      assume (!b_delay_any);
      assume (!r_delay_any);
      assume (!force_aw_wait_any);
      assume (!force_w_wait_any);
      assume (!force_ar_wait_any);
      assume (!force_b_wait_any);
      assume (!force_r_wait_any);
    end

    if (aw_wait_cnt == 2'h2) begin
      assume (aw_ready_any);
      assume (!force_aw_wait_any);
    end
    if (w_wait_cnt == 2'h2) begin
      assume (w_ready_any);
      assume (!force_w_wait_any);
    end
    if (ar_wait_cnt == 2'h2) begin
      assume (ar_ready_any);
      assume (!force_ar_wait_any);
    end
    if (b_wait_cnt == 2'h2) begin
      assume (!b_delay_any);
      assume (!force_b_wait_any);
    end
    if (r_wait_cnt == 2'h2) begin
      assume (!r_delay_any);
      assume (!force_r_wait_any);
    end
  end
endmodule
