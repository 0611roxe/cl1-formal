module cl1_cache_control_ready_check #(
  parameter integer SPEC = 0
) (
  input wire clock
);
  localparam integer SPEC_ICACHE_INVALID_READY = 0;
  localparam integer SPEC_DCACHE_CLEAN_READY = 1;
  localparam integer SPEC_DCACHE_INVALID_READY = 2;

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

  cl1_cache_control_env env (
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

  localparam [1:0] S_WAIT_IDLE = 2'd0;
  localparam [1:0] S_SEND_REQ  = 2'd1;
  localparam [1:0] S_DONE      = 2'd2;

  reg [1:0] state;
  reg [9:0] age;
  reg [9:0] run_age;
  reg       seen_done;
  wire      selected_dx_fire =
              (SPEC == SPEC_ICACHE_INVALID_READY) ? (ic_dx_valid && ic_dx_ready) :
                                                     (dc_dx_valid && dc_dx_ready);

  always @(posedge clock) begin
    if (reset) begin
      ic_req_valid <= 1'b0;
      ic_req_addr <= 32'h0000_1000;
      ic_dx_valid <= 1'b0;
      ic_dx_invalid <= 1'b0;
      ic_dx_clean <= 1'b0;
      dc_req_valid <= 1'b0;
      dc_req_addr <= 32'h0000_1000;
      dc_req_data <= 32'h0;
      dc_req_wen <= 1'b0;
      dc_dx_valid <= 1'b0;
      dc_dx_invalid <= 1'b0;
      dc_dx_clean <= 1'b0;
      state <= S_WAIT_IDLE;
      age <= 10'd0;
      run_age <= 10'd0;
      seen_done <= 1'b0;
    end else begin
      if (!seen_done)
        run_age <= run_age + 10'd1;

      case (state)
        S_WAIT_IDLE: begin
          age <= 10'd0;
          if (icache_idle && dcache_idle)
            state <= S_SEND_REQ;
        end

        S_SEND_REQ: begin
          age <= age + 10'd1;
          if (SPEC == SPEC_ICACHE_INVALID_READY) begin
            ic_dx_valid <= 1'b1;
            ic_dx_invalid <= 1'b1;
            ic_dx_clean <= 1'b0;
            if (ic_dx_valid && ic_dx_ready) begin
              ic_dx_valid <= 1'b0;
              ic_dx_invalid <= 1'b0;
              state <= S_DONE;
              seen_done <= 1'b1;
            end
          end else if (SPEC == SPEC_DCACHE_CLEAN_READY) begin
            dc_dx_valid <= 1'b1;
            dc_dx_invalid <= 1'b0;
            dc_dx_clean <= 1'b1;
            if (dc_dx_valid && dc_dx_ready) begin
              dc_dx_valid <= 1'b0;
              dc_dx_clean <= 1'b0;
              state <= S_DONE;
              seen_done <= 1'b1;
            end
          end else begin
            dc_dx_valid <= 1'b1;
            dc_dx_invalid <= 1'b1;
            dc_dx_clean <= 1'b0;
            if (dc_dx_valid && dc_dx_ready) begin
              dc_dx_valid <= 1'b0;
              dc_dx_invalid <= 1'b0;
              state <= S_DONE;
              seen_done <= 1'b1;
            end
          end
        end

        default: begin
          ic_dx_valid <= 1'b0;
          dc_dx_valid <= 1'b0;
        end
      endcase
    end
  end

  always @(posedge clock) begin
    if (!reset) begin
      assert (!ic_rsp_err);
      assert (!dc_rsp_err);
      assert (!ic_req_valid);
      assert (!dc_req_valid);
      assert (!aw_valid);
      assert (!w_valid);
      assert (!ar_valid);

      if (ic_dx_ready)
        assert (ic_dx_valid && ic_dx_invalid && !ic_dx_clean);
      if (dc_dx_ready)
        assert (dc_dx_valid && (dc_dx_invalid || dc_dx_clean));

      if (state == S_SEND_REQ) begin
        if (SPEC == SPEC_ICACHE_INVALID_READY)
          assert (age < 10'd170);
        if (SPEC == SPEC_DCACHE_CLEAN_READY)
          assert (age < 10'd330);
        if (SPEC == SPEC_DCACHE_INVALID_READY)
          assert (age < 10'd480);
      end

      if (SPEC == SPEC_ICACHE_INVALID_READY)
        assert (seen_done || (run_age < 10'd360));
      if (SPEC == SPEC_DCACHE_CLEAN_READY)
        assert (seen_done || (run_age < 10'd520));
      if (SPEC == SPEC_DCACHE_INVALID_READY)
        assert (seen_done || (run_age < 10'd520));
    end
  end

`ifdef CACHE_FORMAL_COVER
  always @(posedge clock) begin
    if (!reset) begin
      cover (selected_dx_fire);
      cover (seen_done);
    end
  end
`endif
endmodule
