library IEEE;
use IEEE.STD_LOGIC_1164.ALL;
use IEEE.NUMERIC_STD.ALL;

entity top is
    port (
        clk_50M         : in std_logic;
        rst_n           : in std_logic;
        -- RGMII RX I/O
        RGMII_RX_CLK    : in std_logic;
        RGMII_RD        : in std_logic_vector(3 downto 0);
        RGMII_rx_ctrl   : in std_logic;
        FPGA_LED        : out std_logic_vector(1 downto 0);
        -- AXI4-Lite slave (connected to PS M_AXI_GP0)
        s_axi_aclk      : in  std_logic;
        s_axi_aresetn   : in  std_logic;
        s_axi_awaddr    : in  std_logic_vector(4 downto 0);
        s_axi_awprot    : in  std_logic_vector(2 downto 0);
        s_axi_awvalid   : in  std_logic;
        s_axi_awready   : out std_logic;
        s_axi_wdata     : in  std_logic_vector(31-1 downto 0);
        s_axi_wstrb     : in  std_logic_vector((31/8)-1 downto 0);
        s_axi_wvalid    : in  std_logic;
        s_axi_wready    : out std_logic;
        s_axi_bresp     : out std_logic_vector(1 downto 0);
        s_axi_bvalid    : out std_logic;
        s_axi_bready    : in  std_logic;
        s_axi_araddr    : in  std_logic_vector(31-1 downto 0);
        s_axi_arprot    : in  std_logic_vector(2 downto 0);
        s_axi_arvalid   : in  std_logic;
        s_axi_arready   : out std_logic;
        s_axi_rdata     : out std_logic_vector(31-1 downto 0);
        s_axi_rresp     : out std_logic_vector(1 downto 0);
        s_axi_rvalid    : out std_logic;
        s_axi_rready    : in  std_logic
    );
end entity top;

architecture rtl of top is

    component rgmii_xcvr is
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
            m_axis_tvalid   : out std_logic;
            m_axis_tlast    : out std_logic;
            -- TX I/O
            -- TX AXI-S Interface
            -- Status and Control
            rx_error        : out std_logic
        );
    end component;

    signal rx_error         : std_logic;
    signal m_axis_tready    : std_logic;
    signal m_axis_tdata     : std_logic_vector(7 downto 0);
    signal m_axis_tvalid    : std_logic;
    signal m_axis_tlast     : std_logic;

    -- ---------------------------------------------------------------------
    -- AXI4-Lite address decode helpers
    -- ---------------------------------------------------------------------

    -- AXI4-Lite internal handshaking
    signal axi_awaddr   : std_logic_vector(31 downto 0);
    signal axi_awready  : std_logic;
    signal axi_wready   : std_logic;
    signal axi_bresp    : std_logic_vector(1 downto 0);
    signal axi_bvalid   : std_logic;
    signal axi_araddr   : std_logic_vector(31 downto 0);
    signal axi_arready  : std_logic;
    signal axi_rdata    : std_logic_vector(31 downto 0);
    signal axi_rresp    : std_logic_vector(1 downto 0);
    signal axi_rvalid   : std_logic;
    signal aw_en        : std_logic;
    signal slv_reg_wren : std_logic;
    signal slv_reg_rden : std_logic;
    signal reg_data_out : std_logic_vector(31 downto 0);

    -- Software-writable register storage (PS -> PL)
    signal reg_mdio_ctrl  : std_logic_vector(31 downto 0);
    signal reg_mdio_wdata : std_logic_vector(31 downto 0);
    signal reg_scratch    : std_logic_vector(31 downto 0);
    signal mdio_start     : std_logic;   -- one-cycle pulse toward MDIO master

    -- Hardware-driven status (PL -> PS, read-only through the mux)
    signal mdio_rdata     : std_logic_vector(31 downto 0);
    signal mdio_busy      : std_logic_vector(31 downto 0);
    signal mdio_done      : std_logic_vector(31 downto 0);
    signal link_up        : std_logic_vector(31 downto 0);
    signal link_speed     : std_logic_vector(1 downto 0);
    signal link_duplex    : std_logic;
    signal rx_frame_count : unsigned(31 downto 0);
    signal rx_error_count : unsigned(31 downto 0);
    signal rx_error_d     : std_logic;

    signal reg_sel        : unsigned(7 downto 0); -- axi register select

begin

    rgmii_if : rgmii_xcvr
     port map(
        clk             => clk_50M,
        rst_n           => rst_n,
        RGMII_RX_CLK    => RGMII_RX_CLK,
        RGMII_RD        => RGMII_RD,
        RGMII_rx_ctrl   => RGMII_rx_ctrl,
        m_axis_tready   => m_axis_tready,
        m_axis_tdata    => m_axis_tdata,
        m_axis_tvalid   => m_axis_tvalid,
        m_axis_tlast    => m_axis_tlast,
        rx_error        => rx_error
    );


    -- Register select: capture the read address (clocked decode)
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            reg_sel <= resize(unsigned(s_axi_araddr), 8);
        end if;
    end process;

    -- Registered read mux (PL -> PS). RO registers return live PL signals, so
    -- the fabric "writes" simply by driving them - no bus contention.
    process(s_axi_aclk)
    begin
        if rising_edge(s_axi_aclk) then
            case reg_sel is
                when x"00" => reg_data_out <= reg_mdio_ctrl;                     -- MDIO_CTRL
                when x"04" => reg_data_out <= reg_mdio_wdata;                    -- MDIO_WDATA
                when x"08" => reg_data_out <= mdio_rdata;                        -- MDIO_RDATA
                when x"0C" => reg_data_out <= mdio_busy;                         -- MDIO_STATUS
                when x"10" => reg_data_out <= link_up;                           -- LINK_STATUS
                when x"14" => reg_data_out <= std_logic_vector(rx_frame_count);  -- RX_FRAMES
                when x"18" => reg_data_out <= std_logic_vector(rx_error_count);  -- RX_ERRORS
                when x"1C" => reg_data_out <= reg_scratch;                       -- SCRATCH
                when others => reg_data_out <= (others => '0');
            end case;
        end if;
    end process;

   

  
    mdio_rdata  <= (others => '0');
    mdio_busy   <= (others => '0');
    mdio_done   <= (others => '0');
    link_up     <= (others => '0');
    link_speed  <= "00";
    link_duplex <= '0';

end architecture;
