`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: top
// Description: Custom top level. Wraps the design_1 block design (Zynq PS) and
//              instantiates the led_counter RTL directly, clocked by FCLK_CLK0.
//              Set this module as Top (Sources > right-click > Set as Top).
//
// Prereq in design_1.bd: FCLK_CLK0 and FCLK_RESET0_N made external.
// NOTE: confirm the external port names Vivado assigned (they may get a _0
//       suffix, e.g. FCLK_CLK0_0). Match the .FCLK_* connections below to them.
//////////////////////////////////////////////////////////////////////////////////

module top (
    // PS DDR / FIXED_IO (passthrough to the block design)
    inout  [14:0] DDR_addr,
    inout  [2:0]  DDR_ba,
    inout         DDR_cas_n,
    inout         DDR_ck_n,
    inout         DDR_ck_p,
    inout         DDR_cke,
    inout         DDR_cs_n,
    inout  [3:0]  DDR_dm,
    inout  [31:0] DDR_dq,
    inout  [3:0]  DDR_dqs_n,
    inout  [3:0]  DDR_dqs_p,
    inout         DDR_odt,
    inout         DDR_ras_n,
    inout         DDR_reset_n,
    inout         DDR_we_n,
    inout         FIXED_IO_ddr_vrn,
    inout         FIXED_IO_ddr_vrp,
    inout  [53:0] FIXED_IO_mio,
    inout         FIXED_IO_ps_clk,
    inout         FIXED_IO_ps_porb,
    inout         FIXED_IO_ps_srstb,
    input         clk_in50M,
    // Fabric LEDs driven by led_counter
    output [7:0]  LED
);

    // Clock / reset sourced from the PS
    wire clk;
    // No external reset wired up for bring-up: hold reset de-asserted
    // (active-low, so tie high) so the counter is free-running.
    wire reset_n = 1'b1;

    // Block design (Zynq PS)
    design_1 design_1_i (
        .DDR_addr          (DDR_addr),
        .DDR_ba            (DDR_ba),
        .DDR_cas_n         (DDR_cas_n),
        .DDR_ck_n          (DDR_ck_n),
        .DDR_ck_p          (DDR_ck_p),
        .DDR_cke           (DDR_cke),
        .DDR_cs_n          (DDR_cs_n),
        .DDR_dm            (DDR_dm),
        .DDR_dq            (DDR_dq),
        .DDR_dqs_n         (DDR_dqs_n),
        .DDR_dqs_p         (DDR_dqs_p),
        .DDR_odt           (DDR_odt),
        .DDR_ras_n         (DDR_ras_n),
        .DDR_reset_n       (DDR_reset_n),
        .DDR_we_n          (DDR_we_n),
        .FIXED_IO_ddr_vrn  (FIXED_IO_ddr_vrn),
        .FIXED_IO_ddr_vrp  (FIXED_IO_ddr_vrp),
        .FIXED_IO_mio      (FIXED_IO_mio),
        .FIXED_IO_ps_clk   (FIXED_IO_ps_clk),
        .FIXED_IO_ps_porb  (FIXED_IO_ps_porb),
        .FIXED_IO_ps_srstb (FIXED_IO_ps_srstb)
        // Newly-exposed PS clock/reset (rename if Vivado added a _0 suffix)
    );

    // Fabric LED counter/shifter
    led_counter u_led_counter (
        .clk     (clk_in50M),
        .reset_n (reset_n),
        .LED     (LED)
    );

endmodule
