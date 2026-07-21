library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity gigabit_tx is
    port (
        clk            : in    std_logic;                     -- 125 MHz transmit clock
        reset          : in    std_logic;                     -- synchronous reset, active high

        -- User byte stream (frame contents: DA, SA, type, payload)
        tx_data        : in    std_logic_vector(7 downto 0);  -- payload byte in
        tx_valid       : in    std_logic;                     -- tx_data is valid
        tx_last        : in    std_logic;                     -- asserted with the final byte of the frame
        tx_ready       : out   std_logic;                     -- module accepts a byte this cycle

        -- RGMII transmit interface to PHY
        RGMII_td     : out   std_logic_vector(3 downto 0);  -- DDR transmit data nibble
        RGMII_txc    : out   std_logic;                     -- transmit clock to PHY
        RGMII_tx_ctl : out   std_logic;                     -- TX_EN (rising) / TX_EN xor TX_ER (falling)

        -- MDIO management interface (PHY register access)
        MDIO_PHY_mdc     : out   std_logic;                 -- management clock (max 25 MHz for RTL8211F)
        MDIO_PHY_mdio_io : inout std_logic                  -- bidirectional management data
    );
end entity gigabit_tx;

architecture rtl of gigabit_tx is

begin

    

end rtl;


