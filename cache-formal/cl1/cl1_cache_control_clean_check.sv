module cl1_cache_control_clean_check #(
  parameter integer SPEC = 0
) (
  input wire clock
);
  localparam integer SPEC_DCACHE_CLEAN_WRITEBACK = 0;
  localparam integer SPEC_DCACHE_CLEAN_TWICE = 1;

  reg        ic_req_valid;
  reg [31:0] ic_req_addr;
  reg        ic_dx_valid;
  reg        ic_dx_invalid;
  reg        ic_dx_clean;

  reg        dc_req_valid;
  reg [31:0] dc_req_addr;
  reg [31:0] dc_req_data;
  reg        dc_req_wen;
  reg        dc_dx_valid;
  reg        dc_dx_invalid;
  reg        dc_dx_clean;

  wire       reset;
  wire       ic_req_ready;
  wire       ic_rsp_valid;
  wire       ic_rsp_err;
  wire       ic_dx_ready;
  wire       icache_idle;
  wire       dc_req_ready;
  wire       dc_rsp_valid;
  wire       dc_rsp_err;
  wire       dc_dx_ready;
  wire       dcache_idle;
  wire       aw_valid;
  wire       aw_ready;
  wire [31:0] aw_addr;
  wire [7:0] aw_len;
  wire [2:0] aw_size;
  wire       w_valid;
  wire       w_ready;
  wire [31:0] w_data;
  wire [3:0] w_strb;
  wire       w_last;
  wire       ar_valid;
  wire       ar_ready;
  wire [31:0] ar_addr;
  wire       aw_fire;
  wire       w_fire;
  wire       ar_fire;
  wire       dc_writeback_valid;
  wire       dc_writeback_ready;
  wire       dc_writeback_from_clean;
  wire [31:0] dc_writeback_addr;
  wire [3:0] dc_writeback_mask;
  wire [3:0] dc_writeback_len;
  wire [1:0] dc_writeback_size;
  wire       dc_writeback_last;

  wire [31:0] line_addr = 32'h0000_1000;
  wire [31:0] store_data = 32'h1234_5678;
  wire        line_ar_fire = ar_fire && (ar_addr == line_addr);
  wire        clean_wb_fire = dc_writeback_valid &&
                              dc_writeback_ready &&
                              dc_writeback_from_clean;

  cl1_cache_control_env #(
    .QUIET_AXI(1)
  ) env (
    .clock(clock),
    .reset(reset),
    .ic_req_valid(ic_req_valid),
    .ic_req_addr(ic_req_addr),
    .ic_dx_valid(ic_dx_valid),
    .ic_dx_invalid(ic_dx_invalid),
    .ic_dx_clean(ic_dx_clean),
    .ic_req_ready(ic_req_ready),
    .ic_rsp_valid(ic_rsp_valid),
    .ic_rsp_err(ic_rsp_err),
    .ic_dx_ready(ic_dx_ready),
    .icache_idle(icache_idle),
    .dc_req_valid(dc_req_valid),
    .dc_req_addr(dc_req_addr),
    .dc_req_data(dc_req_data),
    .dc_req_wen(dc_req_wen),
    .dc_dx_valid(dc_dx_valid),
    .dc_dx_invalid(dc_dx_invalid),
    .dc_dx_clean(dc_dx_clean),
    .dc_req_ready(dc_req_ready),
    .dc_rsp_valid(dc_rsp_valid),
    .dc_rsp_err(dc_rsp_err),
    .dc_dx_ready(dc_dx_ready),
    .dcache_idle(dcache_idle),
    .aw_valid(aw_valid),
    .aw_ready(aw_ready),
    .aw_addr(aw_addr),
    .aw_len(aw_len),
    .aw_size(aw_size),
    .w_valid(w_valid),
    .w_ready(w_ready),
    .w_data(w_data),
    .w_strb(w_strb),
    .w_last(w_last),
    .ar_valid(ar_valid),
    .ar_ready(ar_ready),
    .ar_addr(ar_addr),
    .aw_fire(aw_fire),
    .w_fire(w_fire),
    .ar_fire(ar_fire),
    .dc_writeback_valid(dc_writeback_valid),
    .dc_writeback_ready(dc_writeback_ready),
    .dc_writeback_from_clean(dc_writeback_from_clean),
    .dc_writeback_addr(dc_writeback_addr),
    .dc_writeback_mask(dc_writeback_mask),
    .dc_writeback_len(dc_writeback_len),
    .dc_writeback_size(dc_writeback_size),
    .dc_writeback_last(dc_writeback_last)
  );

  localparam [3:0] S_WAIT_IDLE          = 4'd0;
  localparam [3:0] S_DC_STORE_REQ       = 4'd1;
  localparam [3:0] S_DC_WAIT_STORE      = 4'd2;
  localparam [3:0] S_DC_WAIT_STORE_IDLE = 4'd3;
  localparam [3:0] S_DC_SEND_CLEAN      = 4'd4;
  localparam [3:0] S_DC_WAIT_CLEAN_IDLE = 4'd5;
  localparam [3:0] S_DC_SEND_CLEAN_2    = 4'd6;
  localparam [3:0] S_DONE               = 4'd15;

  reg [3:0] state;
  reg [9:0] age;
  reg [9:0] run_age;
  reg       seen_done;
  reg       seen_store_line_ar;
  reg       seen_clean_writeback;
  reg [1:0] clean_writeback_beat;
  reg       clean_axi_write_active;
  reg [1:0] clean_axi_write_beat;
  reg       seen_clean_axi_aw;
  reg       seen_clean_axi_data;
  reg       seen_second_clean_req;

  always @(posedge clock) begin
    if (reset) begin
      ic_req_valid <= 1'b0;
      ic_req_addr <= line_addr;
      ic_dx_valid <= 1'b0;
      ic_dx_invalid <= 1'b0;
      ic_dx_clean <= 1'b0;
      dc_req_valid <= 1'b0;
      dc_req_addr <= line_addr;
      dc_req_data <= store_data;
      dc_req_wen <= 1'b0;
      dc_dx_valid <= 1'b0;
      dc_dx_invalid <= 1'b0;
      dc_dx_clean <= 1'b0;
      state <= S_WAIT_IDLE;
      age <= 10'd0;
      run_age <= 10'd0;
      seen_done <= 1'b0;
      seen_store_line_ar <= 1'b0;
      seen_clean_writeback <= 1'b0;
      clean_writeback_beat <= 2'd0;
      clean_axi_write_active <= 1'b0;
      clean_axi_write_beat <= 2'd0;
      seen_clean_axi_aw <= 1'b0;
      seen_clean_axi_data <= 1'b0;
      seen_second_clean_req <= 1'b0;
    end else begin
      if (state == S_WAIT_IDLE)
        run_age <= 10'd0;
      else if (!seen_done)
        run_age <= run_age + 10'd1;

      if ((state == S_DC_WAIT_STORE) && line_ar_fire)
        seen_store_line_ar <= 1'b1;

      if ((state == S_DC_SEND_CLEAN) && clean_wb_fire) begin
        seen_clean_writeback <= 1'b1;
        clean_writeback_beat <= clean_writeback_beat + 2'd1;
      end

      if ((state == S_DC_SEND_CLEAN) && aw_fire && (aw_addr == line_addr)) begin
        clean_axi_write_active <= 1'b1;
        clean_axi_write_beat <= 2'd0;
        seen_clean_axi_aw <= 1'b1;
      end

      if (clean_axi_write_active && w_fire) begin
        if (clean_axi_write_beat == 2'd0 && w_data == store_data && w_strb == 4'hf)
          seen_clean_axi_data <= 1'b1;
        if (w_last) begin
          clean_axi_write_active <= 1'b0;
          clean_axi_write_beat <= 2'd0;
        end else begin
          clean_axi_write_beat <= clean_axi_write_beat + 2'd1;
        end
      end

      case (state)
        S_WAIT_IDLE: begin
          age <= 10'd0;
          seen_store_line_ar <= 1'b0;
          seen_clean_writeback <= 1'b0;
          clean_writeback_beat <= 2'd0;
          clean_axi_write_active <= 1'b0;
          clean_axi_write_beat <= 2'd0;
          seen_clean_axi_aw <= 1'b0;
          seen_clean_axi_data <= 1'b0;
          seen_second_clean_req <= 1'b0;
          if (icache_idle && dcache_idle)
            state <= S_DC_STORE_REQ;
        end

        S_DC_STORE_REQ: begin
          age <= age + 10'd1;
          dc_req_valid <= 1'b1;
          dc_req_addr <= line_addr;
          dc_req_data <= store_data;
          dc_req_wen <= 1'b1;
          if (dc_req_valid && dc_req_ready) begin
            dc_req_valid <= 1'b0;
            state <= S_DC_WAIT_STORE;
          end
        end

        S_DC_WAIT_STORE: begin
          age <= age + 10'd1;
          if (dc_rsp_valid) begin
            state <= S_DC_WAIT_STORE_IDLE;
            age <= 10'd0;
          end
        end

        S_DC_WAIT_STORE_IDLE: begin
          age <= age + 10'd1;
          if (dcache_idle) begin
            state <= S_DC_SEND_CLEAN;
            age <= 10'd0;
          end
        end

        S_DC_SEND_CLEAN: begin
          age <= age + 10'd1;
          dc_dx_valid <= 1'b1;
          dc_dx_invalid <= 1'b0;
          dc_dx_clean <= 1'b1;
          if (dc_dx_valid && dc_dx_ready) begin
            dc_dx_valid <= 1'b0;
            dc_dx_clean <= 1'b0;
            if (SPEC == SPEC_DCACHE_CLEAN_TWICE) begin
              state <= S_DC_WAIT_CLEAN_IDLE;
              age <= 10'd0;
            end else begin
              state <= S_DONE;
              seen_done <= 1'b1;
            end
          end
        end

        S_DC_WAIT_CLEAN_IDLE: begin
          age <= age + 10'd1;
          if (dcache_idle) begin
            state <= S_DC_SEND_CLEAN_2;
            age <= 10'd0;
          end
        end

        S_DC_SEND_CLEAN_2: begin
          age <= age + 10'd1;
          dc_dx_valid <= 1'b1;
          dc_dx_invalid <= 1'b0;
          dc_dx_clean <= 1'b1;
          if (dc_dx_valid && dc_dx_ready) begin
            dc_dx_valid <= 1'b0;
            dc_dx_clean <= 1'b0;
            state <= S_DONE;
            seen_done <= 1'b1;
            seen_second_clean_req <= 1'b1;
          end
        end

        default: begin
          dc_req_valid <= 1'b0;
          dc_dx_valid <= 1'b0;
        end
      endcase
    end
  end

  always @(posedge clock) begin
    if (!reset) begin
      assert (!ic_rsp_err);
      assert (!dc_rsp_err);

      if (dc_dx_ready)
        assert (dc_dx_valid && dc_dx_clean && !dc_dx_invalid);

      if (state == S_DC_WAIT_STORE) begin
        assert (age < 10'd100);
        if (dc_rsp_valid)
          assert (seen_store_line_ar);
      end

      if (state == S_DC_WAIT_STORE_IDLE)
        assert (age < 10'd20);

      if (state == S_DC_SEND_CLEAN) begin
        assert (age < 10'd390);
        if (clean_wb_fire) begin
          assert (dc_writeback_addr[3:0] == 4'h0);
          assert (dc_writeback_mask == 4'hf);
          assert (dc_writeback_len == 4'h3);
          assert (dc_writeback_size == 2'h2);
          if (clean_writeback_beat == 2'd3)
            assert (dc_writeback_last);
          else
            assert (!dc_writeback_last);
        end
        if (dc_dx_valid && dc_dx_ready) begin
          assert (seen_clean_writeback);
          assert (seen_clean_axi_aw);
          assert (seen_clean_axi_data);
        end
      end

      if (state == S_DC_WAIT_CLEAN_IDLE)
        assert (age < 10'd20);

      if (state == S_DC_SEND_CLEAN_2) begin
        assert (age < 10'd330);
        assert (!dc_writeback_from_clean);
      end

      if (SPEC == SPEC_DCACHE_CLEAN_WRITEBACK)
        assert (seen_done || (run_age < 10'd520));
      if (SPEC == SPEC_DCACHE_CLEAN_TWICE)
        assert (seen_done || (run_age < 10'd850));
    end
  end

`ifdef CACHE_FORMAL_COVER
  always @(posedge clock) begin
    if (!reset) begin
      cover (state == S_DC_WAIT_STORE && seen_store_line_ar);
      cover (state == S_DC_SEND_CLEAN && seen_clean_writeback);
      cover (state == S_DC_SEND_CLEAN && seen_clean_axi_aw);
      cover (state == S_DC_SEND_CLEAN && seen_clean_axi_data);
      if (SPEC == SPEC_DCACHE_CLEAN_TWICE)
        cover (seen_second_clean_req);
      cover (seen_done);
    end
  end
`endif
endmodule
