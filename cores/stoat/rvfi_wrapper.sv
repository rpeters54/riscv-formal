`timescale 1ns / 1ps
`include "otter_defines.vh"

module rvfi_wrapper (

`define CSR_MACRO_OP(NAME) \
    output [31:0] rvfi_csr_``NAME``_rmask, \
    output [31:0] rvfi_csr_``NAME``_wmask, \
    output [31:0] rvfi_csr_``NAME``_rdata, \
    output [31:0] rvfi_csr_``NAME``_wdata,

    `RVFI_OUTPUTS
    `RVFI_BUS_OUTPUTS

`undef CSR_MACRO_OP
    input         clock,
    input         reset
);

    wire i_clk = clock;
    wire i_rst = reset;

    (* keep *) `rvformal_rand_reg [31:0] i_intrpt;

    (* keep *) `rvformal_rand_reg        w_ibus_ack;
    (* keep *) `rvformal_rand_reg        w_ibus_stall;
    (* keep *) `rvformal_rand_reg [31:0] w_ibus_data_miso;
    (* keep *) wire                      w_ibus_cyc;
    (* keep *) wire                      w_ibus_stb;
    (* keep *) wire               [31:0] w_ibus_addr;

    (* keep *) `rvformal_rand_reg        w_dbus_ack;
    (* keep *) `rvformal_rand_reg        w_dbus_stall;
    (* keep *) `rvformal_rand_reg [31:0] w_dbus_data_miso;
    (* keep *) wire                      w_dbus_cyc;
    (* keep *) wire                      w_dbus_stb;
    (* keep *) wire                      w_dbus_we;
    (* keep *) wire               [3:0]  w_dbus_sel;
    (* keep *) wire               [31:0] w_dbus_addr;
    (* keep *) wire               [31:0] w_dbus_data_mosi;

    (* keep *) wire                      w_full_flush;

    stoat_mcu # (
        .RESET_VEC('0)
    ) u_stoat_mcu (
        .i_clk(i_clk),
        .i_rst(i_rst),
        .i_intrpt(i_intrpt),

    //=============================//
    // RVFI Interface
    //=============================//
    `define CSR_MACRO_OP(NAME) \
        .rvfi_csr_``NAME``_rmask(rvfi_csr_``NAME``_rmask), \
        .rvfi_csr_``NAME``_wmask(rvfi_csr_``NAME``_wmask), \
        .rvfi_csr_``NAME``_rdata(rvfi_csr_``NAME``_rdata), \
        .rvfi_csr_``NAME``_wdata(rvfi_csr_``NAME``_wdata),

        `RVFI_INTERCONNECTS
        `RVFI_BUS_INTERCONNECTS

    `undef CSR_MACRO_OP

        .o_full_flush       (w_full_flush),

        //=============================//
        // IMEM read-only wishbone bus port
        .i_ibus_ack         (w_ibus_ack),
        .i_ibus_stall       (w_ibus_stall),
        .i_ibus_data_miso   (w_ibus_data_miso),

        .o_ibus_cyc         (w_ibus_cyc),
        .o_ibus_stb         (w_ibus_stb),
        .o_ibus_addr        (w_ibus_addr),

        //=============================//
        // DMEM read-write wishbone bus port
        .i_dbus_ack         (w_dbus_ack),
        .i_dbus_stall       (w_dbus_stall),
        .i_dbus_data_miso   (w_dbus_data_miso),

        .o_dbus_cyc         (w_dbus_cyc),
        .o_dbus_stb         (w_dbus_stb),
        .o_dbus_we          (w_dbus_we),
        .o_dbus_addr        (w_dbus_addr),
        .o_dbus_sel         (w_dbus_sel),
        .o_dbus_data_mosi   (w_dbus_data_mosi)
    );

    // Stall and Ack can only occur during a valid transaction
    reg w_ibus_cyc_past;
    reg w_dbus_cyc_past;
    initial begin
        w_ibus_cyc_past = 0;
        w_dbus_cyc_past = 0;
    end
    always @(posedge i_clk) begin
        w_ibus_cyc_past <= w_ibus_cyc;
        w_dbus_cyc_past <= w_dbus_cyc;
    end
    always @(posedge i_clk) begin
        if (w_ibus_stall || w_ibus_ack) begin
            assume(w_ibus_cyc && w_ibus_cyc_past);
        end
        if (w_dbus_stall || w_dbus_ack) begin
            assume(w_dbus_cyc && w_dbus_cyc_past);
        end
    end

    reg [15:0] w_ibus_pending_count;
    reg [15:0] w_dbus_pending_count;

    wire w_ibus_req_accepted = w_ibus_cyc && w_ibus_stb && !w_ibus_stall;
    wire w_dbus_req_accepted = w_dbus_cyc && w_dbus_stb && !w_dbus_stall;

    // count the number of access requests inflight
    wire [15:0] w_ibus_pending_count_next = w_ibus_pending_count + w_ibus_req_accepted - w_ibus_ack;
    wire [15:0] w_dbus_pending_count_next = w_dbus_pending_count + w_dbus_req_accepted - w_dbus_ack;


    always @(posedge i_clk) begin
        if (w_full_flush) begin
            w_ibus_pending_count <= 0;
            w_dbus_pending_count <= 0;
        end else begin
            w_ibus_pending_count <= $signed(w_ibus_pending_count_next) >= 0 ? w_ibus_pending_count_next : 0;
            w_dbus_pending_count <= $signed(w_dbus_pending_count_next) >= 0 ? w_dbus_pending_count_next : 0;
        end
    end

    // cant ack an item sent during the same cycle
    always @(*) begin
        if (w_ibus_pending_count == 0) begin
            assume(!w_ibus_ack);
        end
        if (w_dbus_pending_count == 0) begin
            assume(!w_dbus_ack);
        end
    end

`ifdef RISCV_FORMAL_FAIRNESS

    //====================================//
    // Fairness Assumptions (for liveness)
    //====================================//

    // Bound stalls to a maximum number of cycles
    localparam MAX_STALL_CYCLES = 2;

    reg [15:0] w_ibus_stall_counter;
    reg [15:0] w_dbus_stall_counter;
    always @(posedge i_clk) begin
        if (i_rst) begin
            w_ibus_stall_counter <= 0;
            w_dbus_stall_counter <= 0;
        end else begin
            if (w_ibus_stall) begin
                w_ibus_stall_counter <= w_ibus_stall_counter + 1;
            end else begin
                w_ibus_stall_counter <= 0;
            end
            if (w_dbus_stall) begin
                w_dbus_stall_counter <= w_dbus_stall_counter + 1;
            end else begin
                w_dbus_stall_counter <= 0;
            end
        end

        assume(w_ibus_stall_counter < MAX_STALL_CYCLES);
        assume(w_dbus_stall_counter < MAX_STALL_CYCLES);
    end

    // Bound the maximum delay between acknowledgements
    localparam MAX_ACK_DELAY = 2;

    // ensure that the acknowledgement is sent in some bounded number of cycles
    reg [15:0] w_ibus_ack_wait_timer;
    reg [15:0] w_dbus_ack_wait_timer;
    always @(posedge i_clk) begin
        if (i_rst) begin
            w_ibus_ack_wait_timer <= 0;
            w_dbus_ack_wait_timer <= 0;
        end else begin
            if (w_ibus_ack || w_ibus_pending_count <= 0) begin
                w_ibus_ack_wait_timer <= 0;
            end else begin
                w_ibus_ack_wait_timer <= w_ibus_ack_wait_timer + 1;
            end
            if (w_dbus_ack || w_dbus_pending_count <= 0) begin
                w_dbus_ack_wait_timer <= 0;
            end else begin
                w_dbus_ack_wait_timer <= w_dbus_ack_wait_timer + 1;
            end
        end

        assume(w_ibus_ack_wait_timer < MAX_ACK_DELAY);
        assume(w_dbus_ack_wait_timer < MAX_ACK_DELAY);
    end

`endif
endmodule
