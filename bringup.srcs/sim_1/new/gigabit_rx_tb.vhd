library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

library work;
use work.ip_defs_pkg.all;

entity gigabit_rx_tb is
end entity gigabit_rx_tb;

architecture sim of gigabit_rx_tb is

    type byte_array_t is array(natural range <>) of std_logic_vector(7 downto 0);

    -- 125 MHz RGMII receive clock -> 8 ns period
    constant CLK_PERIOD : time := 8 ns;

  

    -- 7 bytes of 0x55 preamble, then the 0xD5 Start-of-Frame Delimiter
    constant PREAMBLE_SFD : byte_array_t := (
        x"55", x"55", x"55", x"55", x"55", x"55", x"55", x"D5"
    );
    constant FRAME_BODY : byte_array_t := (
        ----------------------------------------------------------------
        -- Destination MAC (6 bytes) -- the frame is addressed to us.
        -- Transmitted most-significant byte first.
        ----------------------------------------------------------------
        FPGA_MAC(47 downto 40), FPGA_MAC(39 downto 32), FPGA_MAC(31 downto 24),
        FPGA_MAC(23 downto 16), FPGA_MAC(15 downto  8), FPGA_MAC( 7 downto  0),
        ----------------------------------------------------------------
        -- Source MAC (6 bytes) -- from the host.
        ----------------------------------------------------------------
        HOST_MAC(47 downto 40), HOST_MAC(39 downto 32), HOST_MAC(31 downto 24),
        HOST_MAC(23 downto 16), HOST_MAC(15 downto  8), HOST_MAC( 7 downto  0),
        ----------------------------------------------------------------
        -- EtherType = 0x0800 (IPv4)
        ----------------------------------------------------------------
        x"08", x"00",
        ----------------------------------------------------------------
        -- Payload
        ----------------------------------------------------------------
        x"DE", x"AD", x"BE", x"EF",
        x"01", x"02", x"03", x"04",
        x"05", x"06", x"07", x"08"
    );

    -- Frame Check Sequence: CRC-32 over FRAME_BODY.
    -- TODO: compute the real value once you're testing FCS checking.
    --       Poly 0xEDB88320, init 0xFFFFFFFF, final XOR, transmitted
    --       LSB-first per byte -- matches your crc32.vhd. For now these
    --       zeros are fine because gigabit_rx doesn't check the FCS yet.
    constant FCS : byte_array_t := (
        x"00", x"00", x"00", x"00"
    );

    constant TEST_FRAME : byte_array_t := PREAMBLE_SFD & FRAME_BODY & FCS;

    signal clk           : std_logic := '0';
    signal reset_n       : std_logic := '0';
    signal rgmii_rx_clk  : std_logic := '0';
    signal rgmii_rd      : std_logic_vector(3 downto 0) := (others => '0');
    signal rgmii_rx_ctrl : std_logic := '0';

    signal m_axis_tready : std_logic := '1';
    signal m_axis_tdata  : std_logic_vector(7 downto 0);
    signal m_axis_tvalid : std_logic;
    signal m_axis_tlast  : std_logic;
    signal rx_error      : std_logic;

    signal sim_done      : boolean := false;

    -------------------------------------------------------------------------
    -- YOU WRITE THIS.
    --
    -- Drive one whole frame onto the RGMII pins. RGMII is DDR, so each byte
    -- is sent as two nibbles across one clock period:
    --
    --   * rising edge of clk : lower nibble on rxd, RX_DV on rx_ctrl
    --   * falling edge of clk: upper nibble on rxd, (RX_DV xor RX_ER) on rx_ctrl
    --
    -- For a clean (error-free) frame RX_ER = 0, so rx_ctrl = '1' on BOTH
    -- edges for every byte of the frame. After the last byte, drop rx_ctrl
    -- to '0' to signal end-of-frame (this is what the FSM watches for).
    --
    -- Tip: `wait until rising_edge(clk)` / `wait until falling_edge(clk)`
    -- are your friends. Remember lower nibble = byte(3 downto 0),
    -- upper nibble = byte(7 downto 4).
    -------------------------------------------------------------------------
    procedure send_frame(
        constant frame   : in  byte_array_t;
        signal   clk_i   : in  std_logic;
        signal   rxd     : out std_logic_vector(3 downto 0);
        signal   rx_ctrl : out std_logic
    ) is
    begin
        -- TODO: implement me.
        report "send_frame not implemented yet" severity note;
    end procedure send_frame;

begin

    clk_gen : process
    begin
        while not sim_done loop
            clk <= '0';
            wait for CLK_PERIOD / 2;
            clk <= '1';
            wait for CLK_PERIOD / 2;
        end loop;
        wait;
    end process clk_gen;

    rgmii_rx_clk <= clk;

    dut : entity work.gigabit_rx
        port map (
            clk           => clk,
            reset_n       => reset_n,
            RGMII_rx_clk  => rgmii_rx_clk,
            RGMII_rd      => rgmii_rd,
            RGMII_rx_ctrl => rgmii_rx_ctrl,
            m_axis_tready => m_axis_tready,
            m_axis_tdata  => m_axis_tdata,
            m_axis_tvalid => m_axis_tvalid,
            m_axis_tlast  => m_axis_tlast,
            rx_error      => rx_error
        );

    stim : process
    begin
        -- Hold reset for a few clocks, then release.
        reset_n <= '0';
        rgmii_rx_ctrl <= '0';
        rgmii_rd      <= (others => '0');
        wait for 4 * CLK_PERIOD;
        reset_n <= '1';
        wait until rising_edge(clk);

        -- A little idle time before the frame starts.
        wait for 4 * CLK_PERIOD;

        -- Send the packet (once your send_frame is written).
        send_frame(TEST_FRAME, clk, rgmii_rd, rgmii_rx_ctrl);

        -- Let the tail of the frame drain through the DUT.
        wait for 20 * CLK_PERIOD;

        report "Simulation finished." severity note;
        sim_done <= true;
        wait;
    end process stim;

end architecture sim;
