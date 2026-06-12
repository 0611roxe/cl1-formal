`define CACHE_FORMAL_SEED_WORD(FN_NAME, HI_XOR) \
  function automatic [31:0] FN_NAME(input [31:0] addr); \
    FN_NAME = {addr[31:16] ^ HI_XOR, addr[15:0] ^ 16'h5eed}; \
  endfunction

`define CACHE_FORMAL_MERGE_MASK(FN_NAME) \
  function automatic [31:0] FN_NAME( \
    input [31:0] old_word, \
    input [31:0] new_word, \
    input [3:0] mask \
  ); \
    integer i; \
    begin \
      FN_NAME = old_word; \
      for (i = 0; i < 4; i = i + 1) \
        if (mask[i]) \
          FN_NAME[i*8 +: 8] = new_word[i*8 +: 8]; \
    end \
  endfunction

`define CACHE_FORMAL_MASK_FROM_SIZE(FN_NAME) \
  function automatic [3:0] FN_NAME(input [1:0] addr_lsb, input [1:0] size); \
    begin \
      case (size) \
        2'b00: FN_NAME = 4'b0001 << addr_lsb; \
        2'b01: FN_NAME = addr_lsb[1] ? 4'b1100 : 4'b0011; \
        default: FN_NAME = 4'b1111; \
      endcase \
    end \
  endfunction
