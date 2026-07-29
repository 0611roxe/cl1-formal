module cache_check #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer STRB_WIDTH = DATA_WIDTH / 8,
  parameter integer ID_WIDTH = 2,
  parameter integer AXI_LEN_WIDTH = 8,
  parameter integer MAX_BURST_LEN = 3,
  parameter integer LINE_ALIGN_LSB = 4
) (
  input  wire                      clock,
  input  wire                      reset,

  input  wire                      ic_req_valid,
  input  wire                      ic_req_ready,
  input  wire [ADDR_WIDTH-1:0]     ic_req_addr,
  input  wire                      ic_req_cache,
  input  wire                      ic_rsp_valid,
  input  wire                      ic_rsp_ready,
  input  wire [DATA_WIDTH-1:0]     ic_rsp_data,
  input  wire                      ic_rsp_err,

  input  wire                      dc_req_valid,
  input  wire                      dc_req_ready,
  input  wire [ADDR_WIDTH-1:0]     dc_req_addr,
  input  wire [DATA_WIDTH-1:0]     dc_req_data,
  input  wire                      dc_req_wen,
  input  wire [STRB_WIDTH-1:0]     dc_req_mask,
  input  wire                      dc_req_cache,
  input  wire [1:0]                dc_req_size,
  input  wire                      dc_rsp_valid,
  input  wire                      dc_rsp_ready,
  input  wire [DATA_WIDTH-1:0]     dc_rsp_data,
  input  wire                      dc_rsp_err,

  input  wire                      aw_valid,
  output wire                      aw_ready,
  input  wire [ADDR_WIDTH-1:0]     aw_addr,
  input  wire [ID_WIDTH-1:0]       aw_id,
  input  wire [AXI_LEN_WIDTH-1:0]  aw_len,
  input  wire [2:0]                aw_size,
  input  wire [1:0]                aw_burst,

  input  wire                      w_valid,
  output wire                      w_ready,
  input  wire [DATA_WIDTH-1:0]     w_data,
  input  wire [STRB_WIDTH-1:0]     w_strb,
  input  wire                      w_last,

  output wire                      b_valid,
  input  wire                      b_ready,
  output wire [1:0]                b_resp,
  output wire [ID_WIDTH-1:0]       b_id,

  input  wire                      ar_valid,
  output wire                      ar_ready,
  input  wire [ADDR_WIDTH-1:0]     ar_addr,
  input  wire [ID_WIDTH-1:0]       ar_id,
  input  wire [AXI_LEN_WIDTH-1:0]  ar_len,
  input  wire [2:0]                ar_size,
  input  wire [1:0]                ar_burst,
  input  wire [2:0]                ar_prot,

  output wire                      r_valid,
  input  wire                      r_ready,
  output wire [1:0]                r_resp,
  output wire [DATA_WIDTH-1:0]     r_data,
  output wire                      r_last,
  output wire [ID_WIDTH-1:0]       r_id
);
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

  localparam integer LINE_BYTES = (1 << LINE_ALIGN_LSB);
  localparam integer WORD_OFFSET_LSB = $clog2(STRB_WIDTH);
  localparam integer LINE_WORDS = LINE_BYTES / STRB_WIDTH;
  localparam integer LINE_WORD_INDEX_WIDTH = LINE_ALIGN_LSB - WORD_OFFSET_LSB;

  (* anyconst *) reg [ADDR_WIDTH-LINE_ALIGN_LSB-1:0] watch_line_any;
  (* anyconst *) reg bp_data_side_any;
  (* anyconst *) reg bp_stall_hit_any;

  wire [ADDR_WIDTH-1:0] watch_line_addr = {watch_line_any, {LINE_ALIGN_LSB{1'b0}}};
  wire ic_req_fire = ic_req_valid && ic_req_ready;
  wire ic_rsp_fire = ic_rsp_valid && ic_rsp_ready;
  wire dc_req_fire = dc_req_valid && dc_req_ready;
  wire dc_rsp_fire = dc_rsp_valid && dc_rsp_ready;

  wire aw_fire;
  wire w_fire;
  wire b_fire;
  wire ar_fire;
  wire r_fire;

  wire        wr_addr_busy;
  wire        wr_resp_pending;
  wire [ID_WIDTH-1:0]      wr_id;
  wire [ADDR_WIDTH-1:0]    wr_addr;
  wire [AXI_LEN_WIDTH-1:0] wr_len;
  wire [AXI_LEN_WIDTH-1:0] wr_cnt;

  wire        rd_busy;
  wire [ID_WIDTH-1:0]      rd_id;
  wire [ADDR_WIDTH-1:0]    rd_addr;
  wire [AXI_LEN_WIDTH-1:0] rd_len;
  wire [AXI_LEN_WIDTH-1:0] rd_cnt;

  wire [1:0] aw_wait_cnt;
  wire [1:0] w_wait_cnt;
  wire [1:0] ar_wait_cnt;
  wire [1:0] b_wait_cnt;
  wire [1:0] r_wait_cnt;
  wire       aw_blocked;
  wire       w_blocked;
  wire       ar_blocked;
  wire       b_blocked;
  wire       r_blocked;

  reg        dc_pending;
  reg [ADDR_WIDTH-1:0] dc_pending_addr;
  reg [DATA_WIDTH-1:0] dc_pending_data;
  reg [STRB_WIDTH-1:0] dc_pending_mask;
  reg        dc_pending_wen;
  reg        dc_pending_cache;
  reg        dc_turnover_check_pending;
  reg [ADDR_WIDTH-1:0] dc_turnover_addr;
  reg [DATA_WIDTH-1:0] dc_turnover_data;
  reg [STRB_WIDTH-1:0] dc_turnover_mask;
  reg        dc_turnover_wen;
  reg        dc_turnover_cache;

  reg        ic_pending;
  reg [ADDR_WIDTH-1:0] ic_pending_addr;
  reg        rd_instr;

  reg [DATA_WIDTH-1:0] mem_line_data [0:LINE_WORDS-1];
  reg [DATA_WIDTH-1:0] icache_line_data [0:LINE_WORDS-1];
  reg [DATA_WIDTH-1:0] dcache_line_data [0:LINE_WORDS-1];
  reg [LINE_WORDS-1:0] icache_line_known;
  reg [LINE_WORDS-1:0] dcache_line_known;
  reg [LINE_WORDS-1:0] dcache_line_dirty;
  reg                  seen_ic_req;
  reg                  seen_ic_rsp;
  reg                  seen_dc_load;
  reg                  seen_dc_store;
  reg                  seen_watch_line_load;
  reg                  seen_watch_line_store;
  reg                  seen_watch_line_refill;
  reg                  seen_watch_ic_refill;
  reg                  seen_watch_dc_refill;
  reg                  seen_watch_ic_refill_rsp;
  reg                  seen_watch_dc_refill_rsp;
  reg                  seen_watch_partial_store;
  reg [ADDR_WIDTH-1:0] seen_watch_partial_store_addr;
  reg                  seen_watch_partial_store_load;
  reg                  seen_watch_line_writeback;
  reg                  seen_dc_turnover;
  reg                  seen_ic_rsp_stall;
  reg                  seen_ic_refill_stall;
  reg                  seen_ic_hit_stall;
  reg                  seen_ic_refill_resume;
  reg                  seen_ic_hit_resume;
  reg                  seen_dc_rsp_stall;
  reg                  seen_dc_refill_stall;
  reg                  seen_dc_hit_stall;
  reg                  seen_dc_refill_resume;
  reg                  seen_dc_hit_resume;
  reg                  seen_axi_read;
  reg                  seen_axi_write;
  reg                  seen_aw_backpressure;
  reg                  seen_w_backpressure;
  reg                  seen_ar_backpressure;
  reg                  seen_b_delay;
  reg                  seen_r_delay;

  `CACHE_FORMAL_SEED_WORD(cf_seed_word, 16'hcace)
  `CACHE_FORMAL_MERGE_MASK(cf_merge_mask)

  function automatic [0:0] is_watch_line(input [ADDR_WIDTH-1:0] addr);
    begin
      is_watch_line = addr[ADDR_WIDTH-1:LINE_ALIGN_LSB] == watch_line_any;
    end
  endfunction

  function automatic [LINE_WORD_INDEX_WIDTH-1:0] line_word_index(input [ADDR_WIDTH-1:0] addr);
    begin
      line_word_index = addr[LINE_ALIGN_LSB-1:WORD_OFFSET_LSB];
    end
  endfunction

  function automatic [ADDR_WIDTH-1:0] watch_word_addr(input integer word_index);
    begin
      watch_word_addr = watch_line_addr + (word_index * STRB_WIDTH);
    end
  endfunction

  function automatic [DATA_WIDTH-1:0] read_word(input [ADDR_WIDTH-1:0] addr);
    begin
      if (is_watch_line(addr))
        read_word = mem_line_data[line_word_index(addr)];
      else
        read_word = cf_seed_word(addr);
    end
  endfunction

  function automatic [0:0] same_word(
    input [ADDR_WIDTH-1:0] lhs,
    input [ADDR_WIDTH-1:0] rhs
  );
    begin
      same_word = lhs[ADDR_WIDTH-1:WORD_OFFSET_LSB] ==
                  rhs[ADDR_WIDTH-1:WORD_OFFSET_LSB];
    end
  endfunction

  wire [DATA_WIDTH-1:0] axi_read_data = read_word(rd_addr);

`ifdef CACHE_FORMAL_TURNOVER
  always @* begin
    if (!reset) begin
      assume (!ic_req_valid);
      assume (dc_req_valid);
      assume (dc_req_addr == watch_line_addr);
      assume (dc_req_cache);
      assume (!dc_req_wen);
      assume (dc_req_mask == {STRB_WIDTH{1'b1}});
      assume (dc_req_size == 2'b10);
      assume (dc_rsp_ready);
      assume (!force_aw_wait_any);
      assume (!force_w_wait_any);
      assume (!force_ar_wait_any);
      assume (!force_b_wait_any);
      assume (!force_r_wait_any);
    end
  end
`endif

`ifdef CACHE_FORMAL_BACKPRESSURE
  always @* begin
    if (!reset) begin
      assume (!force_aw_wait_any);
      assume (!force_w_wait_any);
      assume (!force_ar_wait_any);
      assume (!force_b_wait_any);
      assume (!force_r_wait_any);

      if (bp_data_side_any) begin
        assume (!ic_req_valid);
        assume (ic_rsp_ready);
        assume (dc_req_valid);
        assume (dc_req_addr == watch_line_addr);
        assume (dc_req_cache);
        assume (!dc_req_wen);
        assume (dc_req_mask == {STRB_WIDTH{1'b1}});
        assume (dc_req_size == 2'b10);
        if (bp_stall_hit_any && !seen_dc_load)
          assume (dc_rsp_ready);
        else if (!seen_dc_rsp_stall)
          assume (!dc_rsp_ready);
        else
          assume (dc_rsp_ready);
      end else begin
        assume (ic_req_valid);
        assume (ic_req_addr == watch_line_addr);
        assume (ic_req_cache);
        assume (!dc_req_valid);
        assume (dc_rsp_ready);
        if (bp_stall_hit_any && !seen_ic_rsp)
          assume (ic_rsp_ready);
        else if (!seen_ic_rsp_stall)
          assume (!ic_rsp_ready);
        else
          assume (ic_rsp_ready);
      end
    end
  end
`endif

`ifdef CACHE_FORMAL_DATA_SANITY
  always @* begin
    if (!reset) begin
      assume (!ic_req_valid);
      assume (ic_rsp_ready);
      assume (dc_rsp_ready);
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
      if (dc_pending)
        assume (!dc_req_valid || dc_rsp_fire);
      else
        assume (dc_req_valid);
    end
  end
`endif

  cache_axi_single_outstanding_model #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(AXI_LEN_WIDTH),
    .BEAT_BYTES(STRB_WIDTH)
  ) axi_mem (
    .clock        (clock),
    .reset        (reset),
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
    .wr_addr_busy (wr_addr_busy),
    .wr_resp_pending(wr_resp_pending),
    .wr_id        (wr_id),
    .wr_addr      (wr_addr),
    .wr_len       (wr_len),
    .wr_cnt       (wr_cnt),
    .rd_busy      (rd_busy),
    .rd_id        (rd_id),
    .rd_addr      (rd_addr),
    .rd_len       (rd_len),
    .rd_cnt       (rd_cnt),
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

  cache_req_rsp_contract #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REQUEST_ASSUME_MODE(1),
    .RESPONSE_ASSUME_MODE(0),
    .CHECK_RESPONSE_ORDER(1),
    .MAX_LEN(0)
  ) ic_req_contract (
    .clock    (clock),
    .reset    (reset),
    .req_valid(ic_req_valid),
    .req_ready(ic_req_ready),
    .req_addr (ic_req_addr),
    .req_data ({DATA_WIDTH{1'b0}}),
    .req_wen  (1'b0),
    .req_mask ({STRB_WIDTH{1'b1}}),
    .req_len  (4'h0),
    .req_size (2'b10),
    .req_last (1'b1),
    .rsp_valid(ic_rsp_valid),
    .rsp_ready(ic_rsp_ready),
    .rsp_data (ic_rsp_data),
    .rsp_err  (ic_rsp_err),
    .rsp_last (1'b1)
  );

  cache_req_rsp_contract #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .REQUEST_ASSUME_MODE(1),
    .RESPONSE_ASSUME_MODE(0),
    .CHECK_RESPONSE_ORDER(1),
    .MAX_LEN(0)
  ) dc_req_contract (
    .clock    (clock),
    .reset    (reset),
    .req_valid(dc_req_valid),
    .req_ready(dc_req_ready),
    .req_addr (dc_req_addr),
    .req_data (dc_req_data),
    .req_wen  (dc_req_wen),
    .req_mask (dc_req_mask),
    .req_len  (4'h0),
    .req_size (dc_req_size),
    .req_last (1'b1),
    .rsp_valid(dc_rsp_valid),
    .rsp_ready(dc_rsp_ready),
    .rsp_data (dc_rsp_data),
    .rsp_err  (dc_rsp_err),
    .rsp_last (1'b1)
  );

  cache_axi_master_contract #(
    .ADDR_WIDTH(ADDR_WIDTH),
    .DATA_WIDTH(DATA_WIDTH),
    .STRB_WIDTH(STRB_WIDTH),
    .ID_WIDTH(ID_WIDTH),
    .LEN_WIDTH(AXI_LEN_WIDTH),
    .MAX_BURST_LEN(MAX_BURST_LEN),
    .LINE_ALIGN_LSB(LINE_ALIGN_LSB)
  ) axi_contract (
    .clock   (clock),
    .reset   (reset),
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
    if (reset) begin
      assume (!ic_req_valid);
      assume (!dc_req_valid);
    end

    if (ic_req_valid) begin
      assume (ic_req_addr[1:0] == 2'b00);
      assume (ic_req_cache);
    end

    if (dc_req_valid) begin
      assume (dc_req_size <= 2'b10);
      if (dc_req_size == 2'b01)
        assume (dc_req_addr[0] == 1'b0);
      if (dc_req_size == 2'b10)
        assume (dc_req_addr[1:0] == 2'b00);
      if (is_watch_line(dc_req_addr))
        assume (dc_req_cache);
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

  always @(posedge clock) begin
    integer word_index;
    if (reset) begin
      ic_pending <= 1'b0;
      ic_pending_addr <= {ADDR_WIDTH{1'b0}};
      rd_instr <= 1'b0;
      dc_pending <= 1'b0;
      dc_pending_addr <= {ADDR_WIDTH{1'b0}};
      dc_pending_data <= {DATA_WIDTH{1'b0}};
      dc_pending_mask <= {STRB_WIDTH{1'b0}};
      dc_pending_wen <= 1'b0;
      dc_pending_cache <= 1'b0;
      dc_turnover_check_pending <= 1'b0;
      dc_turnover_addr <= {ADDR_WIDTH{1'b0}};
      dc_turnover_data <= {DATA_WIDTH{1'b0}};
      dc_turnover_mask <= {STRB_WIDTH{1'b0}};
      dc_turnover_wen <= 1'b0;
      dc_turnover_cache <= 1'b0;
      for (word_index = 0; word_index < LINE_WORDS; word_index = word_index + 1) begin
        mem_line_data[word_index] <= cf_seed_word(watch_word_addr(word_index));
        icache_line_data[word_index] <= cf_seed_word(watch_word_addr(word_index));
        dcache_line_data[word_index] <= cf_seed_word(watch_word_addr(word_index));
      end
      icache_line_known <= {LINE_WORDS{1'b1}};
      dcache_line_known <= {LINE_WORDS{1'b1}};
      dcache_line_dirty <= {LINE_WORDS{1'b0}};
      seen_ic_req <= 1'b0;
      seen_ic_rsp <= 1'b0;
      seen_dc_load <= 1'b0;
      seen_dc_store <= 1'b0;
      seen_watch_line_load <= 1'b0;
      seen_watch_line_store <= 1'b0;
      seen_watch_line_refill <= 1'b0;
      seen_watch_ic_refill <= 1'b0;
      seen_watch_dc_refill <= 1'b0;
      seen_watch_ic_refill_rsp <= 1'b0;
      seen_watch_dc_refill_rsp <= 1'b0;
      seen_watch_partial_store <= 1'b0;
      seen_watch_partial_store_addr <= {ADDR_WIDTH{1'b0}};
      seen_watch_partial_store_load <= 1'b0;
      seen_watch_line_writeback <= 1'b0;
      seen_dc_turnover <= 1'b0;
      seen_ic_rsp_stall <= 1'b0;
      seen_ic_refill_stall <= 1'b0;
      seen_ic_hit_stall <= 1'b0;
      seen_ic_refill_resume <= 1'b0;
      seen_ic_hit_resume <= 1'b0;
      seen_dc_rsp_stall <= 1'b0;
      seen_dc_refill_stall <= 1'b0;
      seen_dc_hit_stall <= 1'b0;
      seen_dc_refill_resume <= 1'b0;
      seen_dc_hit_resume <= 1'b0;
      seen_axi_read <= 1'b0;
      seen_axi_write <= 1'b0;
      seen_aw_backpressure <= 1'b0;
      seen_w_backpressure <= 1'b0;
      seen_ar_backpressure <= 1'b0;
      seen_b_delay <= 1'b0;
      seen_r_delay <= 1'b0;
    end else begin
      if (ic_rsp_fire)
        ic_pending <= 1'b0;
      if (ic_req_fire) begin
        ic_pending <= 1'b1;
        ic_pending_addr <= ic_req_addr;
      end

      if (ar_fire)
        rd_instr <= ar_prot[2];
      else if (r_fire && r_last)
        rd_instr <= 1'b0;

      if (aw_fire && is_watch_line(aw_addr) && aw_len == LINE_WORDS - 1)
        assert (|dcache_line_dirty);

      // A dirty cached copy must be written back before the same DCache line
      // can be refilled. ICache refills remain independent until fence.i.
      if (ar_fire && !ar_prot[2] && is_watch_line(ar_addr))
        assert (!(|dcache_line_dirty));

      if (dc_turnover_check_pending) begin
        assert (dc_pending);
        assert (dc_pending_addr == dc_turnover_addr);
        assert (dc_pending_data == dc_turnover_data);
        assert (dc_pending_mask == dc_turnover_mask);
        assert (dc_pending_wen == dc_turnover_wen);
        assert (dc_pending_cache == dc_turnover_cache);
      end

      dc_turnover_check_pending <= dc_req_fire && dc_rsp_fire;
      if (dc_req_fire && dc_rsp_fire) begin
        dc_turnover_addr <= dc_req_addr;
        dc_turnover_data <= dc_req_data;
        dc_turnover_mask <= dc_req_mask;
        dc_turnover_wen <= dc_req_wen;
        dc_turnover_cache <= dc_req_cache;
      end

      if (dc_rsp_fire)
        dc_pending <= 1'b0;

      // CL1 may retire the old response and accept the next request in the
      // same cycle. The new request must remain pending in that case.
      if (dc_req_fire) begin
        dc_pending <= 1'b1;
        dc_pending_addr <= dc_req_addr;
        dc_pending_data <= dc_req_data;
        dc_pending_mask <= dc_req_mask;
        dc_pending_wen <= dc_req_wen;
        dc_pending_cache <= dc_req_cache;
      end

      if (dc_rsp_fire) begin
        if (dc_pending_cache && is_watch_line(dc_pending_addr)) begin
          if (dc_pending_wen) begin
            dcache_line_data[line_word_index(dc_pending_addr)] <=
              cf_merge_mask(dcache_line_data[line_word_index(dc_pending_addr)], dc_pending_data, dc_pending_mask);
            dcache_line_known[line_word_index(dc_pending_addr)] <= 1'b1;
            dcache_line_dirty[line_word_index(dc_pending_addr)] <= 1'b1;
            seen_watch_line_store <= 1'b1;
            if (dc_pending_mask != {STRB_WIDTH{1'b1}}) begin
              seen_watch_partial_store <= 1'b1;
              seen_watch_partial_store_addr <= dc_pending_addr;
            end
          end else if (dcache_line_known[line_word_index(dc_pending_addr)]) begin
            assert (cf_merge_mask({DATA_WIDTH{1'b0}}, dc_rsp_data, dc_pending_mask) ==
                    cf_merge_mask({DATA_WIDTH{1'b0}},
                                  dcache_line_data[line_word_index(dc_pending_addr)],
                                  dc_pending_mask));
            seen_watch_line_load <= 1'b1;
            if (seen_watch_partial_store && same_word(dc_pending_addr, seen_watch_partial_store_addr))
              seen_watch_partial_store_load <= 1'b1;
            if (seen_watch_dc_refill)
              seen_watch_dc_refill_rsp <= 1'b1;
          end
        end
      end

      if (w_fire && is_watch_line(wr_addr)) begin
        if (wr_len == LINE_WORDS - 1) begin
          assert (w_strb == {STRB_WIDTH{1'b1}});
          if (dcache_line_known[line_word_index(wr_addr)])
            assert (w_data == dcache_line_data[line_word_index(wr_addr)]);
        end
        mem_line_data[line_word_index(wr_addr)] <=
          cf_merge_mask(mem_line_data[line_word_index(wr_addr)], w_data, w_strb);
        if (wr_len == LINE_WORDS - 1 && w_last) begin
          dcache_line_dirty <= {LINE_WORDS{1'b0}};
          seen_watch_line_writeback <= 1'b1;
        end
      end

      if (r_fire && is_watch_line(rd_addr)) begin
        if (rd_instr) begin
          icache_line_data[line_word_index(rd_addr)] <= r_data;
          icache_line_known[line_word_index(rd_addr)] <= 1'b1;
          seen_watch_ic_refill <= 1'b1;
        end else begin
          if (dc_rsp_fire && dc_pending_wen &&
              same_word(rd_addr, dc_pending_addr))
            dcache_line_data[line_word_index(rd_addr)] <=
              cf_merge_mask(r_data, dc_pending_data, dc_pending_mask);
          else
            dcache_line_data[line_word_index(rd_addr)] <= r_data;
          dcache_line_known[line_word_index(rd_addr)] <= 1'b1;
          dcache_line_dirty[line_word_index(rd_addr)] <=
            dc_rsp_fire && dc_pending_wen && same_word(rd_addr, dc_pending_addr);
          seen_watch_dc_refill <= 1'b1;
        end
      end

      if (ic_rsp_fire && is_watch_line(ic_pending_addr) &&
          icache_line_known[line_word_index(ic_pending_addr)]) begin
        if (r_fire && rd_instr && same_word(rd_addr, ic_pending_addr))
          assert (ic_rsp_data == r_data);
        else
          assert (ic_rsp_data == icache_line_data[line_word_index(ic_pending_addr)]);
        if (seen_watch_ic_refill)
          seen_watch_ic_refill_rsp <= 1'b1;
      end

      if (ic_req_fire)
        seen_ic_req <= 1'b1;
      if (ic_rsp_fire)
        seen_ic_rsp <= 1'b1;
      if (dc_rsp_fire && !dc_pending_wen)
        seen_dc_load <= 1'b1;
      if (dc_rsp_fire && dc_pending_wen)
        seen_dc_store <= 1'b1;
      if (ar_fire)
        seen_axi_read <= 1'b1;
      if (r_fire && is_watch_line(rd_addr))
        seen_watch_line_refill <= 1'b1;
      if (dc_req_fire && dc_rsp_fire)
        seen_dc_turnover <= 1'b1;
      if (ic_rsp_valid && !ic_rsp_ready) begin
        seen_ic_rsp_stall <= 1'b1;
        if (r_valid)
          seen_ic_refill_stall <= 1'b1;
        else
          seen_ic_hit_stall <= 1'b1;
      end
      if (ic_rsp_fire && seen_ic_refill_stall)
        seen_ic_refill_resume <= 1'b1;
      if (ic_rsp_fire && seen_ic_hit_stall)
        seen_ic_hit_resume <= 1'b1;
      if (dc_rsp_valid && !dc_rsp_ready) begin
        seen_dc_rsp_stall <= 1'b1;
        if (r_valid)
          seen_dc_refill_stall <= 1'b1;
        else
          seen_dc_hit_stall <= 1'b1;
      end
      if (dc_rsp_fire && seen_dc_refill_stall)
        seen_dc_refill_resume <= 1'b1;
      if (dc_rsp_fire && seen_dc_hit_stall)
        seen_dc_hit_resume <= 1'b1;
      if (w_fire && w_last)
        seen_axi_write <= 1'b1;
      if (aw_blocked)
        seen_aw_backpressure <= 1'b1;
      if (w_blocked)
        seen_w_backpressure <= 1'b1;
      if (ar_blocked)
        seen_ar_backpressure <= 1'b1;
      if (b_blocked)
        seen_b_delay <= 1'b1;
      if (r_blocked)
        seen_r_delay <= 1'b1;
    end
  end

  always @(posedge clock) begin
    if (!reset) begin
      assert (!ic_rsp_err);
      assert (!dc_rsp_err);
      if (ic_rsp_valid)
        assert (ic_pending);
      if (dc_rsp_valid)
        assert (dc_pending);
    end
  end

`ifdef CACHE_FORMAL_COVER
  always @(posedge clock) begin
    if (!reset) begin
`ifdef CACHE_FORMAL_TURNOVER
      cover (seen_dc_turnover);
`elsif CACHE_FORMAL_DATA_SANITY
      cover (seen_watch_partial_store_load);
      cover (seen_watch_line_writeback);
`elsif CACHE_FORMAL_BACKPRESSURE
      cover (seen_ic_refill_stall && seen_ic_refill_resume);
      cover (seen_ic_hit_stall && seen_ic_hit_resume);
      cover (seen_dc_refill_stall && seen_dc_refill_resume);
      cover (seen_dc_hit_stall && seen_dc_hit_resume);
`else
      cover (seen_ic_req && seen_ic_rsp);
      cover (seen_dc_load && seen_dc_store);
      cover (seen_axi_read && seen_axi_write);
      cover (seen_watch_line_load);
      cover (seen_watch_line_store);
      cover (seen_watch_line_refill);
      cover (seen_watch_ic_refill_rsp);
      cover (seen_watch_dc_refill_rsp);
      cover (seen_watch_partial_store_load);
      cover (seen_dc_turnover);
      cover (seen_aw_backpressure);
      cover (seen_w_backpressure);
      cover (seen_ar_backpressure);
      cover (seen_b_delay);
      cover (seen_r_delay);
`endif
    end
  end
`endif
endmodule
