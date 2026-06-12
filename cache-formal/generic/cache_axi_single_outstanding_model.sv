module cache_axi_single_outstanding_model #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer STRB_WIDTH = DATA_WIDTH / 8,
  parameter integer ID_WIDTH = 2,
  parameter integer LEN_WIDTH = 8,
  parameter integer BEAT_BYTES = STRB_WIDTH
) (
  input  wire                  clock,
  input  wire                  reset,

  input  wire                  aw_valid,
  output wire                  aw_ready,
  input  wire [ADDR_WIDTH-1:0] aw_addr,
  input  wire [ID_WIDTH-1:0]   aw_id,
  input  wire [LEN_WIDTH-1:0]  aw_len,

  input  wire                  w_valid,
  output wire                  w_ready,
  input  wire                  w_last,

  output wire                  b_valid,
  input  wire                  b_ready,
  output wire [1:0]            b_resp,
  output wire [ID_WIDTH-1:0]   b_id,

  input  wire                  ar_valid,
  output wire                  ar_ready,
  input  wire [ADDR_WIDTH-1:0] ar_addr,
  input  wire [ID_WIDTH-1:0]   ar_id,
  input  wire [LEN_WIDTH-1:0]  ar_len,

  output wire                  r_valid,
  input  wire                  r_ready,
  output wire [1:0]            r_resp,
  output wire [DATA_WIDTH-1:0] r_data,
  output wire                  r_last,
  output wire [ID_WIDTH-1:0]   r_id,
  input  wire [DATA_WIDTH-1:0] read_data,

  input  wire                  aw_ready_any,
  input  wire                  w_ready_any,
  input  wire                  ar_ready_any,
  input  wire                  b_delay_any,
  input  wire                  r_delay_any,
  input  wire                  force_aw_wait,
  input  wire                  force_w_wait,
  input  wire                  force_ar_wait,
  input  wire                  force_b_wait,
  input  wire                  force_r_wait,

  output wire                  aw_fire,
  output wire                  w_fire,
  output wire                  b_fire,
  output wire                  ar_fire,
  output wire                  r_fire,

  output reg                   wr_addr_busy,
  output reg                   wr_resp_pending,
  output reg  [ID_WIDTH-1:0]   wr_id,
  output reg  [ADDR_WIDTH-1:0] wr_addr,
  output reg  [LEN_WIDTH-1:0]  wr_len,
  output reg  [LEN_WIDTH-1:0]  wr_cnt,

  output reg                   rd_busy,
  output reg  [ID_WIDTH-1:0]   rd_id,
  output reg  [ADDR_WIDTH-1:0] rd_addr,
  output reg  [LEN_WIDTH-1:0]  rd_len,
  output reg  [LEN_WIDTH-1:0]  rd_cnt,

  output wire                  aw_blocked,
  output wire                  w_blocked,
  output wire                  ar_blocked,
  output wire                  b_blocked,
  output wire                  r_blocked,

  output reg  [1:0]            aw_wait_cnt,
  output reg  [1:0]            w_wait_cnt,
  output reg  [1:0]            ar_wait_cnt,
  output reg  [1:0]            b_wait_cnt,
  output reg  [1:0]            r_wait_cnt
);
  assign aw_ready = !reset && aw_ready_any && !force_aw_wait && !wr_addr_busy && !wr_resp_pending;
  assign w_ready  = !reset && w_ready_any && !force_w_wait && wr_addr_busy;
  assign ar_ready = !reset && ar_ready_any && !force_ar_wait && !rd_busy;

  assign b_valid = !reset && wr_resp_pending && !b_delay_any && !force_b_wait;
  assign b_resp  = 2'b00;
  assign b_id    = wr_id;

  assign r_valid = !reset && rd_busy && !r_delay_any && !force_r_wait;
  assign r_resp  = 2'b00;
  assign r_data  = read_data;
  assign r_last  = rd_cnt == rd_len;
  assign r_id    = rd_id;

  assign aw_fire = aw_valid && aw_ready;
  assign w_fire  = w_valid && w_ready;
  assign b_fire  = b_valid && b_ready;
  assign ar_fire = ar_valid && ar_ready;
  assign r_fire  = r_valid && r_ready;

  assign aw_blocked = aw_valid && !aw_ready && !wr_addr_busy;
  assign w_blocked  = w_valid && !w_ready && wr_addr_busy;
  assign ar_blocked = ar_valid && !ar_ready && !rd_busy;
  assign b_blocked  = wr_resp_pending && !b_valid;
  assign r_blocked  = rd_busy && !r_valid;

  always @(posedge clock) begin
    if (reset) begin
      wr_addr_busy <= 1'b0;
      wr_resp_pending <= 1'b0;
      wr_id <= {ID_WIDTH{1'b0}};
      wr_addr <= {ADDR_WIDTH{1'b0}};
      wr_len <= {LEN_WIDTH{1'b0}};
      wr_cnt <= {LEN_WIDTH{1'b0}};
      rd_busy <= 1'b0;
      rd_id <= {ID_WIDTH{1'b0}};
      rd_addr <= {ADDR_WIDTH{1'b0}};
      rd_len <= {LEN_WIDTH{1'b0}};
      rd_cnt <= {LEN_WIDTH{1'b0}};
      aw_wait_cnt <= 2'h0;
      w_wait_cnt <= 2'h0;
      ar_wait_cnt <= 2'h0;
      b_wait_cnt <= 2'h0;
      r_wait_cnt <= 2'h0;
    end else begin
      if (aw_blocked)
        aw_wait_cnt <= aw_wait_cnt + 2'h1;
      else
        aw_wait_cnt <= 2'h0;
      if (w_blocked)
        w_wait_cnt <= w_wait_cnt + 2'h1;
      else
        w_wait_cnt <= 2'h0;
      if (ar_blocked)
        ar_wait_cnt <= ar_wait_cnt + 2'h1;
      else
        ar_wait_cnt <= 2'h0;
      if (b_blocked)
        b_wait_cnt <= b_wait_cnt + 2'h1;
      else
        b_wait_cnt <= 2'h0;
      if (r_blocked)
        r_wait_cnt <= r_wait_cnt + 2'h1;
      else
        r_wait_cnt <= 2'h0;

      if (aw_fire) begin
        wr_addr_busy <= 1'b1;
        wr_id <= aw_id;
        wr_addr <= aw_addr;
        wr_len <= aw_len;
        wr_cnt <= {LEN_WIDTH{1'b0}};
      end

      if (w_fire) begin
        if (w_last) begin
          wr_addr_busy <= 1'b0;
          wr_resp_pending <= 1'b1;
        end else begin
          wr_cnt <= wr_cnt + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
          wr_addr <= wr_addr + BEAT_BYTES;
        end
      end

      if (b_fire)
        wr_resp_pending <= 1'b0;

      if (ar_fire) begin
        rd_busy <= 1'b1;
        rd_id <= ar_id;
        rd_addr <= ar_addr;
        rd_len <= ar_len;
        rd_cnt <= {LEN_WIDTH{1'b0}};
      end

      if (r_fire) begin
        if (r_last) begin
          rd_busy <= 1'b0;
        end else begin
          rd_cnt <= rd_cnt + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
          rd_addr <= rd_addr + BEAT_BYTES;
        end
      end
    end
  end
endmodule
