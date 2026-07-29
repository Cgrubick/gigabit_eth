`timescale 1ns / 1ps

module gigabit_rx_tb;

    logic       clk;
    logic       reset_n;
    logic       RGMII_rx_clk;
    logic [3:0] RGMII_rd;
    logic       RGMII_rx_ctrl;

    logic       m_axis_tready;
    logic [7:0] m_axis_tdata;
    logic       m_axis_tvalid;
    logic       m_axis_tlast;
    logic       rx_error;

    // preamble+SFD, dst MAC, src MAC, ethertype(IPv4), payload, FCS(placeholder)
    byte unsigned frame[34] = '{
        8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'hD5,
        8'h01,8'h02,8'h03,8'h04,8'h05,8'h06,               // dst MAC (FPGA)
        8'hAF,8'h93,8'hB4,8'hE0,8'hFF,8'h10,               // src MAC (host) AF:93:84:E0:FF:10. NTOL = FA:39:48:0E:FF:01
        8'h08,8'h00,                                       // ethertype
        8'hDE,8'hAD,8'hBE,8'hEF,8'h01,8'h02,8'h03,8'h04,   // payload
        8'h00,8'h00,8'h00,8'h00                            // FCS (TODO: real CRC-32)
    };

    byte unsigned bad_frame[34] = '{
        8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'hD5,
        8'hff,8'h02,8'h03,8'h04,8'h05,8'h06,               // dst MAC (FPGA)
        8'hAF,8'h93,8'hB4,8'hE0,8'hFF,8'h10,               // src MAC (host) AF:93:84:E0:FF:10. NTOL = FA:39:48:0E:FF:01
        8'h08,8'h00,                                       // ethertype
        8'hDE,8'hAD,8'hBE,8'hEF,8'h01,8'h02,8'h03,8'h04,   // payload
        8'h00,8'h00,8'h00,8'h00                            // FCS (TODO: real CRC-32)
    };

    byte unsigned arp_frame[34] = '{
        8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'h55,8'hD5,
        8'hff,8'hff,8'hff,8'hff,8'hff,8'hff,               // dst MAC (FPGA)
        8'hAF,8'h93,8'hB4,8'hE0,8'hFF,8'h10,               // src MAC (host) AF:93:84:E0:FF:10. NTOL = FA:39:48:0E:FF:01
        8'h08,8'h06,                                       // ethertype
        8'hDE,8'hAD,8'hBE,8'hEF,8'h01,8'h02,8'h03,8'h04,   // payload
        8'h00,8'h00,8'h00,8'h00                            // FCS (TODO: real CRC-32)
    };

    gigabit_rx dut (
        .clk           (clk),
        .reset_n       (reset_n),
        .RGMII_rx_clk  (RGMII_rx_clk),
        .RGMII_rd      (RGMII_rd),
        .RGMII_rx_ctrl (RGMII_rx_ctrl),
        .m_axis_tready (m_axis_tready),
        .m_axis_tdata  (m_axis_tdata),
        .m_axis_tvalid (m_axis_tvalid),
        .m_axis_tlast  (m_axis_tlast),
        .rx_error      (rx_error)
    );

    initial clk = 1'b0;
    always #4 clk = ~clk;               // 125 MHz
    assign RGMII_rx_clk = clk;

    // rising edge: lower nibble + RX_DV=1 ; falling edge: upper nibble + (DV^ER)=1
    // drop RGMII_rx_ctrl to 0 after the last byte.
    // Drive each nibble one edge BEFORE the IDDR samples it, using nonblocking
    // assignments, so the DUT captures the pre-edge value deterministically.
    // Nothing changes on a sampling edge -> no race -> ModelSim and xsim agree.
    // rising edge captures the lower nibble, falling edge the upper nibble.
    task send_frame(input byte unsigned f[34]);
        for(int i = 0; i < $size(f); i++) begin
            @ (negedge clk)
            RGMII_rd        <= f[i][3:0];   // lower nibble -> next rising edge
            RGMII_rx_ctrl   <= 1'b1;
            @ (posedge clk)
            RGMII_rd        <= f[i][7:4];   // upper nibble -> next falling edge
            RGMII_rx_ctrl   <= 1'b1;
        end
        @ (negedge clk)
        RGMII_rx_ctrl   <= 1'b0;
        RGMII_rd        <= 4'h0;
    endtask

    initial begin
        reset_n       = 1'b0;
        m_axis_tready = 1'b1;
        RGMII_rd      = 4'h0;
        RGMII_rx_ctrl = 1'b0;
        repeat (4) @(posedge clk);
        reset_n = 1'b1;
        repeat (4) @(posedge clk);

        send_frame(frame);

        #250 
        
        send_frame(bad_frame);

        #250 
        
        send_frame(arp_frame);

        #250
        $finish;
    end

endmodule