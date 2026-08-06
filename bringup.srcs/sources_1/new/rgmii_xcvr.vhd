library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity rgmii_xcvr is
    port (
        clk             : in std_logic;
        rst_n           : in std_logic;
        -- RX I/O
        RGMII_RX_CLK    : in std_logic;
        RGMII_RD        : in std_logic_vector(3 downto 0);
        RGMII_rx_ctrl   : in std_logic;
        -- RX AXI-S Interface
        m_axis_tready   : in std_logic;
        m_axis_tdata    : out std_logic_vector(7 downto 0);
        m_axis_tvalid   : in std_logic;
        m_axis_tlast    : in std_logic;
        -- TX I/O
        -- TX AXI-S Interface
        -- Status and Control 
        rx_error        : out std_logic
    );
end entity rgmii_xcvr;

architecture rtl of rgmii_xcvr is

    component gigabit_rx is
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
    end component;


begin

    Gbe_rx : gigabit_rx
     port map(
        clk             => clk,
        reset_n         => rst_n,
        RGMII_rx_clk    => RGMII_rx_clk,
        RGMII_rd        => RGMII_rd,
        RGMII_rx_ctrl   => RGMII_rx_ctrl,
        m_axis_tready   => m_axis_tready,
        m_axis_tdata    => m_axis_tdata,
        m_axis_tvalid   => m_axis_tvalid,
        m_axis_tlast    => m_axis_tlast,
        rx_error        => rx_error
    );

    

end architecture;
