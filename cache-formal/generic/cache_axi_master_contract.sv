module cache_axi_master_contract #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer STRB_WIDTH = DATA_WIDTH / 8,
  parameter integer ID_WIDTH = 2,
  parameter integer LEN_WIDTH = 8,
  parameter integer MAX_BURST_LEN = 3,
  parameter integer LINE_ALIGN_LSB = 4,
  parameter integer CHECK_BURST_FORMAT = 1,
  parameter integer CHECK_TRANSACTION_ORDER = 1,
  parameter integer CHECK_WRITE_STROBE = 1
) (
  input wire                  clock,
  input wire                  reset,

  input wire                  aw_valid,
  input wire                  aw_ready,
  input wire [ADDR_WIDTH-1:0] aw_addr,
  input wire [ID_WIDTH-1:0]   aw_id,
  input wire [LEN_WIDTH-1:0]  aw_len,
  input wire [2:0]            aw_size,
  input wire [1:0]            aw_burst,

  input wire                  w_valid,
  input wire                  w_ready,
  input wire [DATA_WIDTH-1:0] w_data,
  input wire [STRB_WIDTH-1:0] w_strb,
  input wire                  w_last,

  input wire                  b_valid,
  input wire                  b_ready,

  input wire                  ar_valid,
  input wire                  ar_ready,
  input wire [ADDR_WIDTH-1:0] ar_addr,
  input wire [ID_WIDTH-1:0]   ar_id,
  input wire [LEN_WIDTH-1:0]  ar_len,
  input wire [2:0]            ar_size,
  input wire [1:0]            ar_burst,

  input wire                  r_valid,
  input wire                  r_ready,
  input wire                  r_last
);
  wire aw_fire = aw_valid && aw_ready;
  wire w_fire = w_valid && w_ready;
  wire b_fire = b_valid && b_ready;
  wire ar_fire = ar_valid && ar_ready;
  wire r_fire = r_valid && r_ready;
  localparam [LEN_WIDTH-1:0] MAX_BURST_LEN_VALUE = MAX_BURST_LEN;

  cache_valid_ready_monitor #(
    .PAYLOAD_WIDTH(ADDR_WIDTH + ID_WIDTH + LEN_WIDTH + 5),
    .ASSUME_MODE(0),
    .RESET_CLEARS_VALID(0)
  ) aw_monitor (
    .clock  (clock),
    .reset  (reset),
    .valid  (aw_valid),
    .ready  (aw_ready),
    .payload({aw_addr, aw_id, aw_len, aw_size, aw_burst})
  );

  cache_valid_ready_monitor #(
    .PAYLOAD_WIDTH(DATA_WIDTH + STRB_WIDTH + 1),
    .ASSUME_MODE(0),
    .RESET_CLEARS_VALID(0)
  ) w_monitor (
    .clock  (clock),
    .reset  (reset),
    .valid  (w_valid),
    .ready  (w_ready),
    .payload({w_data, w_strb, w_last})
  );

  cache_valid_ready_monitor #(
    .PAYLOAD_WIDTH(ADDR_WIDTH + ID_WIDTH + LEN_WIDTH + 5),
    .ASSUME_MODE(0),
    .RESET_CLEARS_VALID(0)
  ) ar_monitor (
    .clock  (clock),
    .reset  (reset),
    .valid  (ar_valid),
    .ready  (ar_ready),
    .payload({ar_addr, ar_id, ar_len, ar_size, ar_burst})
  );

  reg wr_active;
  reg wr_data_active;
  reg [LEN_WIDTH-1:0] wr_len;
  reg [LEN_WIDTH-1:0] wr_cnt;
  reg rd_active;
  reg [LEN_WIDTH-1:0] rd_len;
  reg [LEN_WIDTH-1:0] rd_cnt;

  always @(posedge clock) begin
    if (reset) begin
      wr_active <= 1'b0;
      wr_data_active <= 1'b0;
      wr_len <= {LEN_WIDTH{1'b0}};
      wr_cnt <= {LEN_WIDTH{1'b0}};
      rd_active <= 1'b0;
      rd_len <= {LEN_WIDTH{1'b0}};
      rd_cnt <= {LEN_WIDTH{1'b0}};
    end else if (CHECK_TRANSACTION_ORDER) begin
      if (aw_fire) begin
        wr_active <= 1'b1;
        wr_data_active <= 1'b1;
        wr_len <= aw_len;
        wr_cnt <= {LEN_WIDTH{1'b0}};
      end

      if (w_fire) begin
        if (w_last) begin
          wr_data_active <= 1'b0;
          wr_cnt <= {LEN_WIDTH{1'b0}};
        end else begin
          wr_cnt <= wr_cnt + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
        end
      end

      if (b_fire)
        wr_active <= 1'b0;

      if (ar_fire) begin
        rd_active <= 1'b1;
        rd_len <= ar_len;
        rd_cnt <= {LEN_WIDTH{1'b0}};
      end

      if (r_fire) begin
        if (r_last) begin
          rd_active <= 1'b0;
          rd_cnt <= {LEN_WIDTH{1'b0}};
        end else begin
          rd_cnt <= rd_cnt + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
        end
      end
    end
  end

  always @(posedge clock) begin
    if (!reset) begin
      if (CHECK_BURST_FORMAT && aw_valid) begin
        assert (aw_len <= MAX_BURST_LEN_VALUE);
        assert (aw_burst == 2'b01);
        assert (aw_size <= 3'h2);
        if (aw_len != {LEN_WIDTH{1'b0}})
          assert (aw_addr[LINE_ALIGN_LSB-1:0] == {LINE_ALIGN_LSB{1'b0}});
      end

      if (CHECK_BURST_FORMAT && ar_valid) begin
        assert (ar_len <= MAX_BURST_LEN_VALUE);
        assert (ar_burst == 2'b01);
        assert (ar_size <= 3'h2);
        if (ar_len != {LEN_WIDTH{1'b0}})
          assert (ar_addr[LINE_ALIGN_LSB-1:0] == {LINE_ALIGN_LSB{1'b0}});
      end

      if (CHECK_WRITE_STROBE && w_valid)
        assert (w_strb != {STRB_WIDTH{1'b0}});

      if (CHECK_TRANSACTION_ORDER) begin
        assert (!(aw_fire && wr_active));
        assert (!(ar_fire && rd_active));

        if (w_fire) begin
          assert (wr_data_active || aw_fire);
          if (w_last)
            assert (wr_cnt == (wr_data_active ? wr_len : aw_len));
          else
            assert (wr_cnt < (wr_data_active ? wr_len : aw_len));
        end

        if (b_fire)
          assert (wr_active && !wr_data_active);

        if (r_fire) begin
          assert (rd_active);
          if (r_last)
            assert (rd_cnt == rd_len);
          else
            assert (rd_cnt < rd_len);
        end
      end
    end
  end
endmodule
