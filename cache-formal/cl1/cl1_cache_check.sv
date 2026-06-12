module cl1_cache_check(input wire clock);

  reg reset = 1'b1;
  always @(posedge clock) reset <= 1'b0;
  initial assume (reset);

  (* anyseq *) reg        ic_req_valid_any;
  (* anyseq *) reg [31:0] ic_req_addr_any;
  (* anyseq *) reg        ic_req_cache_any;

  (* anyseq *) reg        dc_req_valid_any;
  (* anyseq *) reg [31:0] dc_req_addr_any;
  (* anyseq *) reg [31:0] dc_req_data_any;
  (* anyseq *) reg        dc_req_wen_any;
  (* anyseq *) reg        dc_req_cache_any;
  (* anyseq *) reg [1:0]  dc_req_size_any;

  wire [31:0] ic_req_addr = {ic_req_addr_any[31:2], 2'b00};
  wire [31:0] dc_req_addr = dc_req_addr_any;
  wire [3:0]  dc_req_mask = cf_mask_from_size(dc_req_addr[1:0], dc_req_size_any);
  wire        core_rsp_ready = 1'b1;

  wire        ic_req_ready;
  wire        ic_rsp_valid;
  wire [31:0] ic_rsp_data;
  wire        ic_rsp_err;

  wire        dc_req_ready;
  wire        dc_rsp_valid;
  wire [31:0] dc_rsp_data;
  wire        dc_rsp_err;

  wire        aw_valid;
  wire        aw_ready;
  wire [31:0] aw_addr;
  wire [1:0]  aw_id;
  wire [7:0]  aw_len;
  wire [2:0]  aw_size;
  wire [1:0]  aw_burst;

  wire        w_valid;
  wire        w_ready;
  wire [31:0] w_data;
  wire [3:0]  w_strb;
  wire        w_last;

  wire        b_valid;
  wire        b_ready;
  wire [1:0]  b_resp;
  wire [1:0]  b_id;

  wire        ar_valid;
  wire        ar_ready;
  wire [31:0] ar_addr;
  wire [1:0]  ar_id;
  wire [7:0]  ar_len;
  wire [2:0]  ar_size;
  wire [1:0]  ar_burst;

  wire        r_valid;
  wire        r_ready;
  wire [1:0]  r_resp;
  wire [31:0] r_data;
  wire        r_last;
  wire [1:0]  r_id;

  wire        dc_dirty_replace_valid;
  wire [31:0] dc_dirty_replace_addr;
  wire        dc_dirty_replace_way_dirty;
  wire        dc_read_req_valid;
  wire        dc_writeback_valid;
  wire        dc_writeback_ready;
  wire        dc_writeback_from_replace;
  wire        dc_writeback_from_clean;
  wire [31:0] dc_writeback_addr;
  wire [3:0]  dc_writeback_mask;
  wire [3:0]  dc_writeback_len;
  wire [1:0]  dc_writeback_size;
  wire        dc_writeback_last;

  wire        dc_writeback_fire = dc_writeback_valid && dc_writeback_ready;

  `CACHE_FORMAL_MASK_FROM_SIZE(cf_mask_from_size)

  Cl1CacheFormal dut (
    .clock                       (clock),
    .reset                       (reset),
    .io_icore_req_ready          (ic_req_ready),
    .io_icore_req_valid          (ic_req_valid_any),
    .io_icore_req_bits_addr      (ic_req_addr),
    .io_icore_req_bits_data      (32'h0),
    .io_icore_req_bits_wen       (1'b0),
    .io_icore_req_bits_mask      (4'hf),
    .io_icore_req_bits_cache     (ic_req_cache_any),
    .io_icore_req_bits_size      (2'b10),
    .io_icore_rsp_ready          (core_rsp_ready),
    .io_icore_rsp_valid          (ic_rsp_valid),
    .io_icore_rsp_bits_data      (ic_rsp_data),
    .io_icore_rsp_bits_err       (ic_rsp_err),

    .io_dcore_req_ready          (dc_req_ready),
    .io_dcore_req_valid          (dc_req_valid_any),
    .io_dcore_req_bits_addr      (dc_req_addr),
    .io_dcore_req_bits_data      (dc_req_data_any),
    .io_dcore_req_bits_wen       (dc_req_wen_any),
    .io_dcore_req_bits_mask      (dc_req_mask),
    .io_dcore_req_bits_cache     (dc_req_cache_any),
    .io_dcore_req_bits_size      (dc_req_size_any),
    .io_dcore_rsp_ready          (core_rsp_ready),
    .io_dcore_rsp_valid          (dc_rsp_valid),
    .io_dcore_rsp_bits_data      (dc_rsp_data),
    .io_dcore_rsp_bits_err       (dc_rsp_err),

    .io_idxReq_valid             (1'b0),
    .io_idxReq_bits_invalid      (1'b0),
    .io_idxReq_bits_clean        (1'b0),

    .io_ddxReq_valid             (1'b0),
    .io_ddxReq_bits_invalid      (1'b0),
    .io_ddxReq_bits_clean        (1'b0),

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

    .io_master_r_ready           (r_ready),
    .io_master_r_valid           (r_valid),
    .io_master_r_bits_rresp      (r_resp),
    .io_master_r_bits_rdata      (r_data),
    .io_master_r_bits_rlast      (r_last),
    .io_master_r_bits_rid        (r_id),

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

  cache_check #(
    .ADDR_WIDTH(32),
    .DATA_WIDTH(32),
    .STRB_WIDTH(4),
    .ID_WIDTH(2),
    .AXI_LEN_WIDTH(8),
    .MAX_BURST_LEN(3),
    .LINE_ALIGN_LSB(4)
  ) u_cache_check (
    .clock       (clock),
    .reset       (reset),
    .ic_req_valid(ic_req_valid_any),
    .ic_req_ready(ic_req_ready),
    .ic_req_addr (ic_req_addr),
    .ic_req_cache(ic_req_cache_any),
    .ic_rsp_valid(ic_rsp_valid),
    .ic_rsp_ready(core_rsp_ready),
    .ic_rsp_data (ic_rsp_data),
    .ic_rsp_err  (ic_rsp_err),

    .dc_req_valid(dc_req_valid_any),
    .dc_req_ready(dc_req_ready),
    .dc_req_addr (dc_req_addr),
    .dc_req_data (dc_req_data_any),
    .dc_req_wen  (dc_req_wen_any),
    .dc_req_mask (dc_req_mask),
    .dc_req_cache(dc_req_cache_any),
    .dc_req_size (dc_req_size_any),
    .dc_rsp_valid(dc_rsp_valid),
    .dc_rsp_ready(core_rsp_ready),
    .dc_rsp_data (dc_rsp_data),
    .dc_rsp_err  (dc_rsp_err),

    .aw_valid(aw_valid),
    .aw_ready(aw_ready),
    .aw_addr (aw_addr),
    .aw_id   (aw_id),
    .aw_len  (aw_len),
    .aw_size (aw_size),
    .aw_burst(aw_burst),

    .w_valid(w_valid),
    .w_ready(w_ready),
    .w_data (w_data),
    .w_strb (w_strb),
    .w_last (w_last),

    .b_valid(b_valid),
    .b_ready(b_ready),
    .b_resp (b_resp),
    .b_id   (b_id),

    .ar_valid(ar_valid),
    .ar_ready(ar_ready),
    .ar_addr (ar_addr),
    .ar_id   (ar_id),
    .ar_len  (ar_len),
    .ar_size (ar_size),
    .ar_burst(ar_burst),

    .r_valid(r_valid),
    .r_ready(r_ready),
    .r_resp (r_resp),
    .r_data (r_data),
    .r_last (r_last),
    .r_id   (r_id)
  );

  reg        dirty_replace_pending;
  reg [31:0] dirty_replace_addr;
  reg [1:0]  dirty_replace_wbeat;
  reg        seen_dirty_replace;
  reg        seen_dirty_replace_write;

  always @(posedge clock) begin
    if (reset) begin
      dirty_replace_pending <= 1'b0;
      dirty_replace_addr <= 32'h0;
      dirty_replace_wbeat <= 2'h0;
      seen_dirty_replace <= 1'b0;
      seen_dirty_replace_write <= 1'b0;
    end else begin
      if (dc_dirty_replace_valid) begin
        dirty_replace_pending <= 1'b1;
        dirty_replace_addr <= dc_dirty_replace_addr;
        dirty_replace_wbeat <= 2'h0;
        seen_dirty_replace <= 1'b1;
      end

      if (dc_writeback_fire && dc_writeback_from_replace) begin
        seen_dirty_replace_write <= 1'b1;
        if (dc_writeback_last) begin
          dirty_replace_pending <= 1'b0;
          dirty_replace_wbeat <= 2'h0;
        end else begin
          dirty_replace_wbeat <= dirty_replace_wbeat + 2'h1;
        end
      end
    end
  end

  always @(posedge clock) begin
    if (!reset) begin
      if (dc_dirty_replace_valid) begin
        assert (!dirty_replace_pending);
        assert (dc_dirty_replace_way_dirty);
        assert (dc_dirty_replace_addr[3:0] == 4'h0);
      end

      assert (!(dc_writeback_from_replace && dc_writeback_from_clean));

      if (dirty_replace_pending) begin
        assert (!dc_read_req_valid);
      end

      if (dc_writeback_valid && dc_writeback_from_replace) begin
        assert (dirty_replace_pending);
        assert (dc_writeback_addr == dirty_replace_addr);
        assert (dc_writeback_mask == 4'hf);
        assert (dc_writeback_len == 4'h3);
        assert (dc_writeback_size == 2'b10);
      end

      if (dc_writeback_fire && dc_writeback_from_replace) begin
        if (dc_writeback_last)
          assert (dirty_replace_wbeat == 2'h3);
        else
          assert (dirty_replace_wbeat != 2'h3);
      end
    end
  end

endmodule
