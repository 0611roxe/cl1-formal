module cache_valid_ready_monitor #(
  parameter integer PAYLOAD_WIDTH = 1,
  parameter integer ASSUME_MODE = 0,
  parameter integer RESET_CLEARS_VALID = 0
) (
  input wire                     clock,
  input wire                     reset,
  input wire                     valid,
  input wire                     ready,
  input wire [PAYLOAD_WIDTH-1:0] payload
);
  reg past_valid = 1'b0;
  always @(posedge clock) past_valid <= 1'b1;

  generate
    if (ASSUME_MODE) begin : gen_assume
      always @(posedge clock) begin
        if (RESET_CLEARS_VALID && reset)
          assume (!valid);

        if (past_valid && !$past(reset) && $past(valid && !ready)) begin
          assume (valid);
          assume (payload == $past(payload));
        end
      end
    end else begin : gen_assert
      always @(posedge clock) begin
        if (RESET_CLEARS_VALID && past_valid && $past(reset))
          assert (!valid);

        if (past_valid && !reset && !$past(reset) && $past(valid && !ready)) begin
          assert (valid);
          assert (payload == $past(payload));
        end
      end
    end
  endgenerate
endmodule
