`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Module Name: gigabit_rx_tb
// Description: Simple testbench skeleton for gigabit_rx. Generates clocks and a
//              reset, instantiates the DUT, then leaves a stimulus block for you
//              to drive the RGMII inputs. (Mixed-language: DUT is VHDL.)
//////////////////////////////////////////////////////////////////////////////////

module gigabit_rx_tb;

    // DUT inputs
    logic       clk;
    logic       reset_n;
    logic       RGMII_rx_clk;
    logic [3:0] RGMII_rd;
    logic       RGMII_rx_ctrl;

    // DUT outputs
    logic [7:0] m_axis_tdata;
    logic       m_axis_tvalid;
    logic       m_axis_tlast;
    logic       m_axis_tuser;

    // Device under test
    gigabit_rx dut (
        .clk           (clk),
        .reset_n       (reset_n),
        .RGMII_rx_clk  (RGMII_rx_clk),
        .RGMII_rd      (RGMII_rd),
        .RGMII_rx_ctrl (RGMII_rx_ctrl),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tlast  (m_axis_tlast),
        .m_axis_tuser  (m_axis_tuser)
    );

    // System clock (adjust period to your design)
    initial clk = 1'b0;
    always #4 clk = ~clk;               // 125 MHz

    // RGMII receive clock (125 MHz)
    initial RGMII_rx_clk = 1'b0;
    always #4 RGMII_rx_clk = ~RGMII_rx_clk;

    // Reset
    initial begin
        reset_n = 1'b0;
        #100;
        reset_n = 1'b1;
    end

    // Stimulus
    initial begin
        RGMII_rd      = 4'h0;
        RGMII_rx_ctrl = 1'b0;

        // wait for reset to release
        @(posedge reset_n);
        @(posedge RGMII_rx_clk);

        // TODO: drive RGMII data here

        #1000;
        $finish;
    end

endmodule
