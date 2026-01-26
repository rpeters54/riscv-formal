
`timescale 1ns / 1ps
`include "rvfi_defines.vh"

module otter_rvfi (
    input             i_clk,    // clk signal
    input             i_rst,    // active-high reset
    input             i_valid,  // valid signal (1 if a new instruction will be fetched next cycle)
    input             i_excp,   // 1 if an interrupt occurs this cycle
    input             i_trap,   // 1 if a synchronous trap occurs this cycle
                                //   - this is caused by an illegal instruction
                                //   or the ecall/ebreak instructions (if implemented)

    // instruction signals
    input      [31:0] i_instrn, // instruction signal

    // operation type signals
    input             i_is_reg_type,   // add, sub, etc.
    input             i_is_imm_type,   // addi, slti, etc.
    input             i_is_load,       // lb, lh, lw, etc.
    input             i_is_store,      // sb, sh, sw
    input             i_is_branch,     // beq, bnez, etc.
    input             i_is_jal,        // jal
    input             i_is_jalr,       // jalr
    input             i_is_csr_write,  // csrrw (can be wired zero if unimplemented)

    // pc selection
    input             i_br_taken,    // 1 if branch taken
    input      [31:0] i_pc_addr,     // current pc address
    input      [31:0] i_br_tgt_addr, // jump/branch instruction target address
    input      [31:0] i_epc_addr,    // exception address, mepc or mtvec depending on type

    // rfile data
    input             i_rfile_we,     // rfile write-enable
    input      [31:0] i_rfile_w_data, // rfile write data
    input      [31:0] i_rfile_r_rs1,  // rfile rs1 read data
    input      [31:0] i_rfile_r_rs2,  // rfile rs2 read data

    // dmem interface
    input      [3:0]  i_dmem_sel,    // byte mask for data memory
    input      [31:0] i_dmem_addr,   // address read from/written to in dmem
    input      [31:0] i_dmem_r_data, // data read from dmem
    input      [31:0] i_dmem_w_data, // data written to dmem

    `RVFI_OUTPUTS

    // dummy signal needed because of trailing comma
    input _dummy
);

    wire w_jmp_taken = (
        (i_is_branch && i_br_taken) ||
         i_is_jal ||
         i_is_jalr
    );

    // csr read and write checks to check for rs1 and rd usage
    reg        w_csr_use_rs1;
    wire [2:0] w_funct3 = `INSTRN_FUNCT3(i_instrn);
    always @(*) begin
        w_csr_use_rs1  = 0;
        if (i_is_csr_write) begin
            case (w_funct3)
                FUNCT3_SYS_CSRRW, FUNCT3_SYS_CSRRS, FUNCT3_SYS_CSRRC : begin
                    w_csr_use_rs1  = 1;
                end
                FUNCT3_SYS_CSRRWI, FUNCT3_SYS_CSRRSI, FUNCT3_SYS_CSRRCI : begin
                    w_csr_use_rs1  = 0;
                end
                default : ;
            endcase
        end
    end

    wire w_use_rs2     = i_is_reg_type
                      || i_is_store
                      || i_is_branch;
    wire w_use_rs1     = w_use_rs2
                      || i_is_imm_type
                      || i_is_load
                      || i_is_jalr
                      || w_csr_use_rs1;

    reg [31:0] w_pc_next;
    always @(*) begin
        if (i_trap) begin
            w_pc_next = i_epc_addr;
        end else if (w_jmp_taken) begin
            w_pc_next = i_br_tgt_addr;
        end else begin
            w_pc_next = i_pc_addr + 4;
        end
    end

    // used to drive the rvfi_intr signal
    // registers when an exception occurs
    reg w_next_vld_is_trap_handler;
    always @(posedge i_clk) begin
        if (i_rst) begin
            w_next_vld_is_trap_handler <= 0;
        end else if (i_excp || i_trap) begin
            w_next_vld_is_trap_handler <= 1;
        end else if (i_valid) begin
            w_next_vld_is_trap_handler <= 0;
        end
    end

    //==============================//
    // RVFI Base Interface Manager
    //==============================//

    wire [4:0] w_rfile_w_addr  = `INSTRN_RD_ADDR(i_instrn);
    wire [4:0] w_rfile_r_addr1 = `INSTRN_RS1_ADDR(i_instrn);
    wire [4:0] w_rfile_r_addr2 = `INSTRN_RS2_ADDR(i_instrn);

    always @(posedge i_clk) begin
        rvfi_valid <= i_valid;

        // Fixed values
        rvfi_halt <= 0; // Never Halts
        rvfi_mode <= 3; // Machine Mode
        rvfi_ixl  <= 1; // Always 32-bit

        if (i_rst) begin
            rvfi_valid     <= 0;
            rvfi_order     <= 0;
            rvfi_insn      <= 0;
            rvfi_pc_rdata  <= 0;
            rvfi_pc_wdata  <= 0;
            rvfi_rd_addr   <= 0;
            rvfi_rd_wdata  <= 0;
            rvfi_rs1_addr  <= 0;
            rvfi_rs1_rdata <= 0;
            rvfi_rs2_addr  <= 0;
            rvfi_rs2_rdata <= 0;
            rvfi_trap      <= 0;
            rvfi_intr      <= 0;
            rvfi_mem_addr  <= 0;
            rvfi_mem_rmask <= 0;
            rvfi_mem_rdata <= 0;
            rvfi_mem_wmask <= 0;
            rvfi_mem_wdata <= 0;
        end else if (i_valid) begin
            // have a monotonically increasing counter that tracks the instruction order
            rvfi_order <= rvfi_order + 1;

            // current instruction fetched from memory
            rvfi_insn <= i_instrn;

            // pc addresses
            rvfi_pc_rdata <= i_pc_addr;
            rvfi_pc_wdata <= w_pc_next;

            // rfile dest traces
            if (i_rfile_we) begin
                rvfi_rd_addr   <= w_rfile_w_addr;
                rvfi_rd_wdata  <= w_rfile_w_addr != 0 ? i_rfile_w_data : 0;
            end else begin
                rvfi_rd_addr   <= 0;
                rvfi_rd_wdata  <= 0;
            end

            // rfile sources and corresponding data
            if (w_use_rs1) begin
                rvfi_rs1_addr  <= w_rfile_r_addr1;
                rvfi_rs1_rdata <= i_rfile_r_rs1;
            end else begin
                rvfi_rs1_addr  <= 0;
                rvfi_rs1_rdata <= 0;
            end
            if (w_use_rs2) begin
                rvfi_rs2_addr  <= w_rfile_r_addr2;
                rvfi_rs2_rdata <= i_rfile_r_rs2;
            end else begin
                rvfi_rs2_addr  <= 0;
                rvfi_rs2_rdata <= 0;
            end

            // flag if next instruction is a synchronous exception
            rvfi_trap <= i_trap;
            rvfi_intr <= w_next_vld_is_trap_handler;

            // add checks for memory access
            // NOTE: added trap_taken check to avoid showing mem reads/writes
            // on trap
            if (i_is_store && !i_trap) begin
                rvfi_mem_addr  <= i_dmem_addr;
                rvfi_mem_rmask <= 0;
                rvfi_mem_rdata <= 0;
                rvfi_mem_wmask <= i_dmem_sel;
                rvfi_mem_wdata <= i_dmem_w_data;
            end else if (i_is_load && !i_trap) begin
                rvfi_mem_addr  <= i_dmem_addr;
                rvfi_mem_rmask <= i_dmem_sel;
                rvfi_mem_rdata <= i_dmem_r_data;
                rvfi_mem_wmask <= 0;
                rvfi_mem_wdata <= 0;
            end else begin
                rvfi_mem_addr  <= 0;
                rvfi_mem_rmask <= 0;
                rvfi_mem_rdata <= 0;
                rvfi_mem_wmask <= 0;
                rvfi_mem_wdata <= 0;
            end
        end
    end

endmodule
