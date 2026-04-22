// check privileged instruction behavior (ECALL, EBREAK, MRET)
//
// This verifies that ECALL, EBREAK, and MRET instructions produce the
// correct CSR side-effects and next-PC values per the RISC-V Privileged Spec.
//
// ECALL/EBREAK expected behavior:
//   - mepc <- current PC (aligned)
//   - mcause <- appropriate exception code
//   - mstatus.MPIE <- mstatus.MIE, mstatus.MIE <- 0
//   - pc_wdata <- mtvec BASE (direct mode, mtvec_rdata & ~3)
//   - rd_addr == 0, no memory access
//   - rvfi_trap == 0 (these are "normal" instructions, not traps)
//
// MRET expected behavior:
//   - pc_wdata <- mepc_rdata (return to saved PC)
//   - mstatus.MIE <- mstatus.MPIE (restore interrupt enable)
//   - mcause <- 0
//   - rd_addr == 0, no memory access
//   - rvfi_trap == 0
//
// Copyright (C) 2026  Hanzhang Liu
//
// Permission to use, copy, modify, and/or distribute this software for any
// purpose with or without fee is hereby granted, provided that the above
// copyright notice and this permission notice appear in all copies.
//
// THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
// WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
// MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR
// ANY SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
// WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
// ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
// OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

module rvfi_priv_insn_check (
	input clock, reset, check,
	`RVFI_INPUTS
);
	`RVFI_CHANNEL(rvfi, `RISCV_FORMAL_CHANNEL_IDX)

	// Instruction encoding detection
	// SYSTEM opcode = 7'b1110011, funct3 = 3'b000
	wire [6:0] insn_opcode = rvfi.insn[6:0];
	wire [2:0] insn_funct3 = rvfi.insn[14:12];
	wire [6:0] insn_funct7 = rvfi.insn[31:25];
	wire [4:0] insn_rs2    = rvfi.insn[24:20];
	wire [11:0] insn_imm12 = rvfi.insn[31:20];

	wire is_system = (insn_opcode == 7'b1110011) && (insn_funct3 == 3'b000);
	wire insn_rd_zero  = (rvfi.insn[11:7]  == 5'b0);
	wire insn_rs1_zero = (rvfi.insn[19:15] == 5'b0);
	// SYSTEM/PRIV instructions (ECALL/EBREAK/MRET/WFI) require rd==0 and
	// rs1==0; encodings with non-zero rd/rs1 are illegal and will trap as
	// illegal-instruction, not as the named priv operation. Only classify
	// them as the priv insn when both fields are zero.
	wire is_ecall  = is_system && insn_rd_zero && insn_rs1_zero && (insn_imm12 == 12'b0000000_00000);
	wire is_ebreak = is_system && insn_rd_zero && insn_rs1_zero && (insn_imm12 == 12'b0000000_00001);
	wire is_mret   = is_system && insn_rd_zero && insn_rs1_zero && (insn_imm12 == 12'b0011000_00010);
	wire is_wfi    = is_system && insn_rd_zero && insn_rs1_zero && (insn_imm12 == 12'b0001000_00101);

`ifdef RISCV_FORMAL_CSR_MTVEC
	(* keep *) wire [`RISCV_FORMAL_XLEN-1:0] mtvec_rdata = rvfi.csr_mtvec_rdata;
	(* keep *) wire [`RISCV_FORMAL_XLEN-1:0] mtvec_base  = {mtvec_rdata[`RISCV_FORMAL_XLEN-1:2], 2'b00};
`endif

`ifdef RISCV_FORMAL_CSR_MEPC
	(* keep *) wire [`RISCV_FORMAL_XLEN-1:0] mepc_rdata = rvfi.csr_mepc_rdata;
	(* keep *) wire [`RISCV_FORMAL_XLEN-1:0] mepc_wdata = rvfi.csr_mepc_wdata;
`endif

`ifdef RISCV_FORMAL_CSR_MCAUSE
	(* keep *) wire [`RISCV_FORMAL_XLEN-1:0] mcause_wdata = rvfi.csr_mcause_wdata;
`endif

`ifdef RISCV_FORMAL_CSR_MSTATUS
	(* keep *) wire mie_before  = rvfi.csr_mstatus_rdata[3];
	(* keep *) wire mpie_before = rvfi.csr_mstatus_rdata[7];
	(* keep *) wire mie_after   = rvfi.csr_mstatus_wdata[3];
	(* keep *) wire mpie_after  = rvfi.csr_mstatus_wdata[7];
`endif

	always @* begin
		if (!reset && check) begin
			assume(rvfi.valid);
			assume(!rvfi.intr);   // not an interrupt-injected instruction

			// ================================================================
			// ECALL checks
			// ================================================================
			if (is_ecall) begin
				// Gap 1 fix: assert (not assume) that ECALL is not a trap
				assert(!rvfi.trap);                                                // H0
`ifdef RISCV_FORMAL_CSR_MEPC
				// H: mepc <- current PC (aligned)
				assert(&rvfi.csr_mepc_wmask);                                     // H1: mepc is written
`ifdef RISCV_FORMAL_COMPRESSED
				assert(mepc_wdata[0] == 1'b0);                                    // H2: mepc aligned
				assert(mepc_wdata[`RISCV_FORMAL_XLEN-1:1] ==
				       rvfi.pc_rdata[`RISCV_FORMAL_XLEN-1:1]);                    // H3: mepc == pc
`else
				assert(mepc_wdata[1:0] == 2'b00);                                 // H2
				assert(mepc_wdata[`RISCV_FORMAL_XLEN-1:2] ==
				       rvfi.pc_rdata[`RISCV_FORMAL_XLEN-1:2]);                    // H3
`endif
`endif

`ifdef RISCV_FORMAL_CSR_MCAUSE
				// I: mcause <- ECALL from M-mode (code 11)
				assert(mcause_wdata == 32'h0000000b);                              // I
`endif

`ifdef RISCV_FORMAL_CSR_MSTATUS
				// J: mstatus transition
				assert(mpie_after == mie_before);                                  // J1: MPIE <- MIE
				assert(mie_after == 1'b0);                                         // J2: MIE <- 0
`endif

`ifdef RISCV_FORMAL_CSR_MTVEC
				// K: pc_wdata <- mtvec BASE
				assert(rvfi.pc_wdata[`RISCV_FORMAL_XLEN-1:2] ==
				       mtvec_base[`RISCV_FORMAL_XLEN-1:2]);                        // K
`endif
				// L: no register write, no memory access
				assert(rvfi.rd_addr == 0);                                         // L1
				assert(rvfi.mem_rmask == 0);                                       // L2
				assert(rvfi.mem_wmask == 0);                                       // L3
			end

			// ================================================================
			// EBREAK checks
			// ================================================================
			if (is_ebreak) begin
				assert(!rvfi.trap);                                                // M0
`ifdef RISCV_FORMAL_CSR_MEPC
				// M: mepc <- current PC (aligned)
				assert(&rvfi.csr_mepc_wmask);                                     // M1
`ifdef RISCV_FORMAL_COMPRESSED
				assert(mepc_wdata[0] == 1'b0);                                    // M2
				assert(mepc_wdata[`RISCV_FORMAL_XLEN-1:1] ==
				       rvfi.pc_rdata[`RISCV_FORMAL_XLEN-1:1]);                    // M3
`else
				assert(mepc_wdata[1:0] == 2'b00);                                 // M2
				assert(mepc_wdata[`RISCV_FORMAL_XLEN-1:2] ==
				       rvfi.pc_rdata[`RISCV_FORMAL_XLEN-1:2]);                    // M3
`endif
`endif

`ifdef RISCV_FORMAL_CSR_MCAUSE
				// N: mcause <- Breakpoint (code 3)
				assert(mcause_wdata == 32'h00000003);                              // N
`endif

`ifdef RISCV_FORMAL_CSR_MSTATUS
				// O: mstatus transition
				assert(mpie_after == mie_before);                                  // O1: MPIE <- MIE
				assert(mie_after == 1'b0);                                         // O2: MIE <- 0
`endif

`ifdef RISCV_FORMAL_CSR_MTVEC
				// P: pc_wdata <- mtvec BASE
				assert(rvfi.pc_wdata[`RISCV_FORMAL_XLEN-1:2] ==
				       mtvec_base[`RISCV_FORMAL_XLEN-1:2]);                        // P
`endif
				// Q: no register write, no memory access
				assert(rvfi.rd_addr == 0);                                         // Q1
				assert(rvfi.mem_rmask == 0);                                       // Q2
				assert(rvfi.mem_wmask == 0);                                       // Q3
			end

			// ================================================================
			// MRET checks
			// ================================================================
			if (is_mret) begin
				assert(!rvfi.trap);                                                // R0

`ifdef RISCV_FORMAL_CSR_MEPC
				// R: pc_wdata <- mepc (return address)
				assert(rvfi.pc_wdata == mepc_rdata);                               // R
`endif

`ifdef RISCV_FORMAL_CSR_MSTATUS
				// S: mstatus.MIE <- mstatus.MPIE (restore interrupt enable)
				assert(mie_after == mpie_before);                                  // S1
				// Gap 4: RISC-V Priv Spec 3.1.6.1: MPIE <- 1 on MRET
				assert(mpie_after == 1'b1);                                        // S2
`endif

`ifdef RISCV_FORMAL_CSR_MCAUSE
				// T: MRET must not modify mcause (Priv spec says nothing about it)
				assert(rvfi.csr_mcause_wmask == 0);                                // T
`endif
				// U: no register write, no memory access
				assert(rvfi.rd_addr == 0);                                         // U1
				assert(rvfi.mem_rmask == 0);                                       // U2
				assert(rvfi.mem_wmask == 0);                                       // U3
			end

			// ================================================================
			// WFI checks (Gap 5: verify NOP-like behavior)
			// ================================================================
			if (is_wfi) begin
				assert(!rvfi.trap);                                                // V0
				assert(rvfi.rd_addr == 0);                                         // V1
				assert(rvfi.mem_rmask == 0);                                       // V2
				assert(rvfi.mem_wmask == 0);                                       // V3
				// WFI as NOP: pc_wdata = pc_rdata + 4
				assert(rvfi.pc_wdata == rvfi.pc_rdata + 4);                        // V4
`ifdef RISCV_FORMAL_CSR_MCAUSE
				// WFI should not modify mcause
				assert(mcause_wdata == rvfi.csr_mcause_rdata);                     // V5
`endif
			end

			// Coverage
			cover(is_ecall);
			cover(is_ebreak);
			cover(is_mret);
			cover(is_wfi);
		end
	end
endmodule
