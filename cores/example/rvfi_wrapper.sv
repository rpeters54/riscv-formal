`timescale 1ns / 1ps

`include "rvfi_defines.vh"

module rvfi_wrapper (
	`RVFI_OUTPUTS
	input         clock,
	input         reset
);

	(* keep *) `rvformal_rand_reg [31:0] w_intrpt;
	(* keep *) `rvformal_rand_reg [31:0] w_imem_r_data;
	(* keep *) `rvformal_rand_reg [31:0] w_dmem_r_data;

	(* keep *) wire [31:0] w_imem_addr;
	(* keep *) wire        w_dmem_re;
	(* keep *) wire        w_dmem_we;
	(* keep *) wire [ 3:0] w_dmem_sel;
	(* keep *) wire [31:0] w_dmem_addr;
	(* keep *) wire [31:0] w_dmem_w_data;


    otter_mcu # (
        .RESET_VEC('0)
    ) u_otter_mcu (
        .i_clk          (clock),
        .i_rst          (reset),
        .i_intrpt       (w_intrpt),

        `RVFI_INTERCONNECTS

        .i_imem_r_data  (w_imem_r_data),
        .o_imem_addr    (w_imem_addr),

        .i_dmem_r_data  (w_dmem_r_data),
        .o_dmem_re      (w_dmem_re),
        .o_dmem_we      (w_dmem_we),
        .o_dmem_sel     (w_dmem_sel),
        .o_dmem_addr    (w_dmem_addr),
        .o_dmem_w_data  (w_dmem_w_data)
    );


endmodule
