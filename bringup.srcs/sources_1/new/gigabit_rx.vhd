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

   constant FPGA_MAC : std_logic_vector(47 downto 0)  := x"010203040506";
   constant IPV4     : std_logic_vector(15 downto 0)  := x"0800";
   constant ARP      : std_logic_vector(15 downto 0)  := x"0806";

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
    signal ctrl_dv_prev     : std_logic;  
    signal ctrl_dv_rise     : std_logic;  
    signal rx_err           : std_logic;
    
    signal byte_count       : unsigned(7 downto 0);

    signal dest_mac         : std_logic_vector(47 downto 0); -- Who the frame is for (local link). MAC filtering.
    signal src_mac          : std_logic_vector(47 downto 0);
    signal ethertype        : std_logic_vector(15 downto 0); -- 0x0800 = IPv4, 0x0806 = ARP.
    signal packet_dropped   : std_logic;
    signal is_arp           : std_logic;
    signal is_ipv4          : std_logic;

    type pipeline_t is array(0 to 3) of std_logic_vector(7 downto 0);
    signal payload_pipeline : pipeline_t;
    signal pipe_count       : unsigned(2 downto 0); 
    alias pipeline_full     : std_logic is pipe_count(2);
    signal pipeline_valid   : std_logic;
    signal payload_data     : std_logic_vector(7 downto 0);

    signal fcs_payload      : std_logic_vector(31 downto 0);

begin


    -- This module acts as the MAC layer and will strip off the preamble, SFD and MACs, ethertype, FCS, while also confirming the CRC is correct otherwise dropping the packet
    -- The module will then pass the layer 3 data (IP + UDP) to the udp_rx.vhd module using an axi stream bus
    -- In order to get the DDR RGMII data to be usable we will need to used xilinx IDDR primitaves to get the rising and falling edge data bits for each RXD and RX CTRL bit

    -- one IDDR per RGMII data line
    gen_rxd_iddr : for i in 0 to 3 generate
        iddr_rxd : IDDR
            generic map (
                DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",
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
            DDR_CLK_EDGE => "SAME_EDGE_PIPELINED",
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
            byte_count    <= (others => '0');
        elsif rising_edge(RGMII_rx_clk) then
            if(eth_state = ETH_HEADER_S) then 
                byte_count <= byte_count + 1;
            else
                byte_count <= (others => '0');
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
            eth_state      <= IDLE_S;
            packet_dropped <= '0';
            is_arp         <= '0';
            is_ipv4        <= '0';
        elsif rising_edge(RGMII_rx_clk) then
            -- axi driver logic
            m_axis_tdata    <= payload_data;
            m_axis_tvalid   <= pipeline_valid;
            m_axis_tlast    <= '0';
            
            case eth_state is
                when IDLE_S =>
                    packet_dropped  <= '0';
                    is_ipv4         <= '0';
                    is_arp          <= '0';
                    ctrl_dv_prev    <= ctrl_dv;
                    ctrl_dv_rise    <= ctrl_dv and not ctrl_dv_prev; -- to prevent the FSM from going back into preamble if packet is dropped mid packet
                    if(ctrl_dv_rise = '1') then -- DV stays valid during entire ethernet frame
                        eth_state <= PREAMBLE_SFD_S;        
                    end if;
                when PREAMBLE_SFD_S => 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(eth_byte = x"D5") then
                        eth_state <= ETH_HEADER_S;
                    end if;
                when ETH_HEADER_S => -- parses out dest MAC, src MAC, ethertype 
                    if(ctrl_dv = '0') then
                        eth_state   <= IDLE_S;
                    elsif(byte_count = 14) then
                        if ((ethertype /= IPV4 or dest_mac /= FPGA_MAC) and (ethertype /= ARP)) then
                            eth_state        <= IDLE_S;
                            packet_dropped   <= '1';
                        else
                            if(ethertype = IPV4) then
                                is_ipv4 <= '1';
                                is_arp  <= '0';
                            elsif(ethertype = ARP) then
                                is_ipv4 <= '0';
                                is_arp  <= '1';
                            end if;
                            eth_state   <= PAYLOAD_S;
                        end if;
                    end if;
                when PAYLOAD_S => -- parses out dest MAC, src MAC, ethertype, FCS - 4 BYTE, must strip and check it before moving onto passing IP packet over AXI stream
                    if(ctrl_dv = '1') then
                        payload_pipeline(0) <= eth_byte;          -- 4-byte delay line
                        payload_pipeline(1) <= payload_pipeline(0);
                        payload_pipeline(2) <= payload_pipeline(1);
                        payload_pipeline(3) <= payload_pipeline(2);
                        if(pipeline_full = '0') then
                            pipe_count      <= pipe_count + 1;
                            pipeline_valid  <= '0';
                        else
                            payload_data    <= payload_pipeline(3);
                            pipeline_valid  <= '1';
                        end if;
                    else -- end of frame, collect fcs and return to idle state
                        fcs_payload     <= payload_pipeline(3) & payload_pipeline(2) & payload_pipeline(1) & payload_pipeline(0); 
                        -- !!!!!!!!!!!!!!!!!!!!!!!!!!!
                        -- TODO CHECK FCS and raise flag for FCS error so downstream module knows to drop packet
                        -- !!!!!!!!!!!!!!!!!!!!!!!!!!!
                        m_axis_tlast    <= pipeline_valid;
                        pipeline_valid  <= '0';
                        pipe_count      <= (others => '0');
                        eth_state       <= IDLE_S;
                    end if;
                    
                when others =>
            end case;
        end if;
    end process;

    byte_shift : process (RGMII_rx_clk, reset_n)
    begin
        if reset_n = '0' then
            dest_mac    <= (others => '0');
            src_mac     <= (others => '0');
            ethertype   <= (others => '0'); 
        elsif rising_edge(RGMII_rx_clk) then
            if(eth_state = ETH_HEADER_S and byte_count < 6 and byte_count >= 0) then
                dest_mac <= dest_mac(39 downto 0) & eth_byte;
            elsif(eth_state = ETH_HEADER_S and byte_count < 12 and byte_count >= 6) then
                src_mac <= src_mac(39 downto 0) & eth_byte;
            elsif(eth_state = ETH_HEADER_S and byte_count < 14 and byte_count >= 12) then
                ethertype <= ethertype(7 downto 0) & eth_byte;
            elsif(eth_state = Idle_S and byte_count >= 14) then
            end if;
        end if;
    end process;

    rx_error        <= packet_dropped;

end rtl;

 