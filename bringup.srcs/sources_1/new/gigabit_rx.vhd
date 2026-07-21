library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library unisim;
use unisim.vcomponents.all;

entity gigabit_rx is
    port (
        clk             : in  std_logic;
        reset_n         : in  std_logic;                     -- active-low reset
        -- RGMII receive from PHY
        RGMII_rx_clk    : in  std_logic;                     -- receive clock from PHY (125 MHz)
        RGMII_rd        : in  std_logic_vector(3 downto 0);  -- DDR receive data nibble
        RGMII_rx_ctrl   : in  std_logic;                     -- RX_DV (rise) / RX_DV xor RX_ER (fall)
        -- AXI-S
        m_axis_tready   : in  std_logic;
        m_axis_tdata    : out std_logic_vector(7 downto 0);  -- received byte
        m_axis_tvalid   : out std_logic;                     -- tdata is valid
        m_axis_tlast    : out std_logic;                     -- final byte of frame
        rx_error        : out std_logic                      -- frame error flag (RX_ER / bad FCS), with tlast
    );
end entity gigabit_rx;

architecture rtl of gigabit_rx is



    type eth_states is (IDLE_S, PREAMBLE_SFD_S, ETH_HEADER_S, PAYLOAD_S, FCS_S);
    signal eth_state      	: eth_states;
    -- rising / falling edge captures from the RGMII DDR inputs
    signal rxd_r            : std_logic_vector(3 downto 0);
    signal rxd_f            : std_logic_vector(3 downto 0);
    signal ctrl_r           : std_logic;
    signal ctrl_f           : std_logic;
    -- Assembled iddr discretes
    signal eth_byte         : std_logic_vector(7 downto 0);
    signal ctrl_dv          : std_logic;    
    signal rx_err           : std_logic;
    
    signal byte_counter     : unsigned(7 downto 0);

    signal dest_mac         : std_logic_vector(47 downto 0); -- Who the frame is for (local link). MAC filtering.
    signal src_mac         : std_logic_vector(47 downto 0);
    signal ethertype         : std_logic_vector(15 downto 0); -- 0x0800 = IPv4, 0x0806 = ARP.
begin


    -- This module acts as the MAC layer and will strip off the preamble, SFD and MACs, ethertype, FCS, while also confirming the CRC is correct otherwise dropping the packet
    -- The module will then pass the layer 3 data (IP + UDP) to the udp_rx.vhd module using an axi stream bus
    -- In order to get the DDR RGMII data to be usable we will need to used xilinx IDDR primitaves to get the rising and falling edge data bits for each RXD and RX CTRL bit

    -- one IDDR per RGMII data line
    gen_rxd_iddr : for i in 0 to 3 generate
        iddr_rxd : IDDR
            generic map (
                DDR_CLK_EDGE => "SAME_EDGE_PINGPONG",
                INIT_Q1      => '0',
                INIT_Q2      => '0',
                SRTYPE       => "ASYNC"
            )
            port map (
                Q1 => rxd_r(i),
                Q2 => rxd_f(i),
                C  => RGMII_rx_clk,
                CE => '1',
                D  => RGMII_rd(i),
                R  => '0',
                S  => '0'
            );
    end generate gen_rxd_iddr;

    -- IDDR for the RGMII control line
    iddr_ctrl : IDDR
        generic map (
            DDR_CLK_EDGE => "SAME_EDGE_PINGPONG",
            INIT_Q1      => '0',
            INIT_Q2      => '0',
            SRTYPE       => "ASYNC"
        )
        port map (
            Q1 => ctrl_r,
            Q2 => ctrl_f,
            C  => RGMII_rx_clk,
            CE => '1',
            D  => RGMII_rx_ctrl,
            R  => '0',
            S  => '0'
        );

    byte_counter : process (RGMII_rx_clk, reset_n)
    begin
        if reset_n = '0' then
            byte_counter    <= (others => '0');
        elsif rising_edge(RGMII_rx_clk) then
            if(eth_state = ETH_HEADER_S) then 
                byte_counter <= byte_counter + 1;
            end if;
        end if;
    end process;

    -- DDR outputs to control and datapath
    ctrl_dv <= ctrl_r;
    rx_err  <= ctrl_r xor ctrl_f;
    eth_byte <= rxd_f & rxd_r when ctrl_dv = '1' else (others => '0'); -- Falling edge bits are upper nibble + Rising edge bits are lower nibble 
    -- Ethernet Parse FSM
    eth_parser : process (RGMII_rx_clk, reset_n)
    begin
        if reset_n = '0' then
            eth_state       <= IDLE_S;
        elsif rising_edge(RGMII_rx_clk) then
            case eth_state is
                when IDLE_S =>
                    if(ctrl_dv = '1') then -- DV stays valid during entire ethernet frame
                        eth_state <= PREAMBLE_SFD_S;        
                    end if;
                when PREAMBLE_SFD_S => 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(eth_byte = x"5D") then 
                        eth_state <= ETH_HEADER_S;
                    end if;
                when ETH_HEADER_S => -- parses out dest MAC, src MAC, ethertype 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(byte_counter = 14) then
                        if(dest_mac /= FPGA_MAC or (ethertype /= IPV4 or ethertype /= ARP)) then
                            eth_state   <= IDLE_S;
                        else
                            eth_state   <= PAYLOAD_S;
                        end if;
                    end if;
                when PAYLOAD_S => -- parses out dest MAC, src MAC, ethertype 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(byte_counter = 14) then
                        eth_state   <= IDLE_S;
                    end if;
                when FCS_S => -- parses out dest MAC, src MAC, ethertype 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(byte_counter = 14) then
                        eth_state   <= IDLE_S;
                    end if;
                when others =>
            end case;
        end if;
    end process;
    dest_mac    <= header_buffer(0 downto 0); 
    src_mac     <= header_buffer(0 downto 0);
    ethertype   <= header_buffer(0 downto 0); 



    m_axis_tdata    <= (others => '0');
    m_axis_tvalid   <= '0';
    m_axis_tlast    <= '0';
    rx_error        <= '0';
end rtl;


