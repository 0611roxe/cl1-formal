module cache_req_rsp_contract #(
  parameter integer ADDR_WIDTH = 32,
  parameter integer DATA_WIDTH = 32,
  parameter integer MASK_WIDTH = DATA_WIDTH / 8,
  parameter integer LEN_WIDTH = 4,
  parameter integer REQUEST_ASSUME_MODE = 0,
  parameter integer RESPONSE_ASSUME_MODE = 0,
  parameter integer CHECK_RESPONSE_ORDER = 0,
  parameter integer CHECK_STABLE = 1,
  parameter integer CHECK_RESPONSE_STABLE = 1,
  parameter integer RESET_CLEARS_VALID = 0,
  parameter integer WRITE_RESPONSE_ON_LAST = 1,
  parameter integer MAX_SIZE = 2,
  parameter integer MAX_LEN = 15,
  parameter integer LINE_ALIGN_LSB = 4
) (
  input wire                  clock,
  input wire                  reset,

  input wire                  req_valid,
  input wire                  req_ready,
  input wire [ADDR_WIDTH-1:0] req_addr,
  input wire [DATA_WIDTH-1:0] req_data,
  input wire                  req_wen,
  input wire [MASK_WIDTH-1:0] req_mask,
  input wire [LEN_WIDTH-1:0]  req_len,
  input wire [1:0]            req_size,
  input wire                  req_last,

  input wire                  rsp_valid,
  input wire                  rsp_ready,
  input wire [DATA_WIDTH-1:0] rsp_data,
  input wire                  rsp_err,
  input wire                  rsp_last
);
  wire [ADDR_WIDTH + DATA_WIDTH + MASK_WIDTH + LEN_WIDTH + 3:0] req_payload = {
    req_addr,
    req_data,
    req_wen,
    req_mask,
    req_len,
    req_size,
    req_last
  };

  generate
    if (CHECK_STABLE) begin : gen_req_monitor
      cache_valid_ready_monitor #(
        .PAYLOAD_WIDTH(ADDR_WIDTH + DATA_WIDTH + MASK_WIDTH + LEN_WIDTH + 4),
        .ASSUME_MODE(REQUEST_ASSUME_MODE),
        .RESET_CLEARS_VALID(RESET_CLEARS_VALID)
      ) req_monitor (
        .clock  (clock),
        .reset  (reset),
        .valid  (req_valid),
        .ready  (req_ready),
        .payload(req_payload)
      );
    end
  endgenerate

  generate
    if (CHECK_RESPONSE_STABLE) begin : gen_rsp_monitor
      cache_valid_ready_monitor #(
        .PAYLOAD_WIDTH(DATA_WIDTH + 2),
        .ASSUME_MODE(RESPONSE_ASSUME_MODE),
        .RESET_CLEARS_VALID(RESET_CLEARS_VALID)
      ) rsp_monitor (
        .clock  (clock),
        .reset  (reset),
        .valid  (rsp_valid),
        .ready  (rsp_ready),
        .payload({rsp_data, rsp_err, rsp_last})
      );
    end
  endgenerate

  reg                    rsp_pending;
  reg [LEN_WIDTH-1:0]    rsp_len;
  reg [LEN_WIDTH-1:0]    rsp_cnt;

  wire req_fire = req_valid && req_ready;
  wire rsp_fire = rsp_valid && rsp_ready;
  wire req_starts_response = req_fire && (!req_wen || !WRITE_RESPONSE_ON_LAST || req_last);
  wire rsp_completes = rsp_fire && rsp_last;
  localparam [LEN_WIDTH-1:0] MAX_LEN_VALUE = MAX_LEN;

  generate
    if (REQUEST_ASSUME_MODE) begin : gen_request_assume
      always @* begin
        if (!reset && req_valid) begin
          assume (req_size <= MAX_SIZE[1:0]);
          assume (req_len <= MAX_LEN_VALUE);
          if (req_wen)
            assume (req_mask != {MASK_WIDTH{1'b0}});
          if (req_len != {LEN_WIDTH{1'b0}})
            assume (req_addr[LINE_ALIGN_LSB-1:0] == {LINE_ALIGN_LSB{1'b0}});
        end
      end

    end else begin : gen_request_assert
      always @* begin
        if (!reset && req_valid) begin
          assert (req_size <= MAX_SIZE[1:0]);
          assert (req_len <= MAX_LEN_VALUE);
          if (req_wen)
            assert (req_mask != {MASK_WIDTH{1'b0}});
          if (req_len != {LEN_WIDTH{1'b0}})
            assert (req_addr[LINE_ALIGN_LSB-1:0] == {LINE_ALIGN_LSB{1'b0}});
        end
      end
    end

    if (CHECK_RESPONSE_ORDER) begin : gen_rsp_order
      if (RESPONSE_ASSUME_MODE) begin : gen_assume
        always @* begin
          if (!reset && rsp_valid)
            assume (rsp_pending);
          if (!reset && req_starts_response)
            assume (!rsp_pending || rsp_completes);
        end
      end else begin : gen_assert
        always @* begin
          if (!reset && rsp_valid)
            assert (rsp_pending);
          if (!reset && req_starts_response)
            assert (!rsp_pending || rsp_completes);
        end
      end
    end
  endgenerate

  always @(posedge clock) begin
    if (reset) begin
      rsp_pending <= 1'b0;
      rsp_len <= {LEN_WIDTH{1'b0}};
      rsp_cnt <= {LEN_WIDTH{1'b0}};
    end else begin
      if (CHECK_RESPONSE_ORDER && rsp_fire) begin
        if (rsp_last) begin
          rsp_pending <= 1'b0;
          rsp_cnt <= {LEN_WIDTH{1'b0}};
        end else begin
          rsp_cnt <= rsp_cnt + {{(LEN_WIDTH-1){1'b0}}, 1'b1};
        end
      end

      // A completed response and the next request may handshake together.
      // Apply the new request last so it remains pending for the next cycle.
      if (CHECK_RESPONSE_ORDER && req_starts_response) begin
        rsp_pending <= 1'b1;
        rsp_len <= req_wen ? {LEN_WIDTH{1'b0}} : req_len;
        rsp_cnt <= {LEN_WIDTH{1'b0}};
      end
    end
  end

  generate
    if (CHECK_RESPONSE_ORDER) begin : gen_rsp_count
      if (RESPONSE_ASSUME_MODE) begin : gen_rsp_count_assume
        always @(posedge clock) begin
          if (!reset && rsp_fire) begin
            if (rsp_last)
              assume (rsp_cnt == rsp_len);
            else
              assume (rsp_cnt < rsp_len);
          end
        end
      end else begin : gen_rsp_count_assert
        always @(posedge clock) begin
          if (!reset && rsp_fire) begin
            if (rsp_last)
              assert (rsp_cnt == rsp_len);
            else
              assert (rsp_cnt < rsp_len);
          end
        end
      end
    end
  endgenerate
endmodule
