`ifndef DEFINES
`define DEFINES

    //----------------//
    // INSTRN Defines
    //----------------//

    localparam XLEN = 32;
    `define INSTRN_CSR_ADDR(instrn)   (instrn[31:20])
    `define INSTRN_CSR(instrn)        (instrn[31:20])
    `define INSTRN_MEM_SIZE(instrn)   (instrn[13:12])
    `define INSTRN_MEM_SIGN(instrn)   (instrn[14])
    `define INSTRN_FM_FENCE(instrn)   (instrn[31:28])

    `define INSTRN_FUNCT7(instrn)     (instrn[31:25])
    `define INSTRN_RS2_ADDR(instrn)   (instrn[24:20])
    `define INSTRN_RS1_ADDR(instrn)   (instrn[19:15])
    `define INSTRN_FUNCT3(instrn)     (instrn[14:12])
    `define INSTRN_RD_ADDR(instrn)    (instrn[11:7])
    `define INSTRN_OPCODE(instrn)     (instrn[6:0])

    localparam FUNCT3_SYS_CSRRW  = 3'b001;
    localparam FUNCT3_SYS_CSRRS  = 3'b010;
    localparam FUNCT3_SYS_CSRRC  = 3'b011;
    localparam FUNCT3_SYS_CSRRWI = 3'b101;
    localparam FUNCT3_SYS_CSRRSI = 3'b110;
    localparam FUNCT3_SYS_CSRRCI = 3'b111;
    localparam FUNCT3_SYS_TRAPS  = 3'b000;

    //--------------//
    // RVFI Defines
    //--------------//

    `define RVFI_OUTPUTS                  \
        output reg        rvfi_valid,     \
        output reg [63:0] rvfi_order,     \
        output reg [31:0] rvfi_insn,      \
        output reg        rvfi_trap,      \
        output reg        rvfi_halt,      \
        output reg        rvfi_intr,      \
        output reg [ 1:0] rvfi_mode,      \
        output reg [ 1:0] rvfi_ixl,       \
        output reg [ 4:0] rvfi_rs1_addr,  \
        output reg [ 4:0] rvfi_rs2_addr,  \
        output reg [31:0] rvfi_rs1_rdata, \
        output reg [31:0] rvfi_rs2_rdata, \
        output reg [ 4:0] rvfi_rd_addr,   \
        output reg [31:0] rvfi_rd_wdata,  \
        output reg [31:0] rvfi_pc_rdata,  \
        output reg [31:0] rvfi_pc_wdata,  \
        output reg [31:0] rvfi_mem_addr,  \
        output reg [ 3:0] rvfi_mem_rmask, \
        output reg [ 3:0] rvfi_mem_wmask, \
        output reg [31:0] rvfi_mem_rdata, \
        output reg [31:0] rvfi_mem_wdata, \

    `define RVFI_INTERCONNECTS                  \
        .rvfi_valid(rvfi_valid),     \
        .rvfi_order(rvfi_order),     \
        .rvfi_insn(rvfi_insn),      \
        .rvfi_trap(rvfi_trap),      \
        .rvfi_halt(rvfi_halt),      \
        .rvfi_intr(rvfi_intr),      \
        .rvfi_mode(rvfi_mode),      \
        .rvfi_ixl(rvfi_ixl),       \
        .rvfi_rs1_addr(rvfi_rs1_addr),  \
        .rvfi_rs2_addr(rvfi_rs2_addr),  \
        .rvfi_rs1_rdata(rvfi_rs1_rdata), \
        .rvfi_rs2_rdata(rvfi_rs2_rdata), \
        .rvfi_rd_addr(rvfi_rd_addr),   \
        .rvfi_rd_wdata(rvfi_rd_wdata),  \
        .rvfi_pc_rdata(rvfi_pc_rdata),  \
        .rvfi_pc_wdata(rvfi_pc_wdata),  \
        .rvfi_mem_addr(rvfi_mem_addr),  \
        .rvfi_mem_rmask(rvfi_mem_rmask), \
        .rvfi_mem_wmask(rvfi_mem_wmask), \
        .rvfi_mem_rdata(rvfi_mem_rdata), \
        .rvfi_mem_wdata(rvfi_mem_wdata), \

`endif
