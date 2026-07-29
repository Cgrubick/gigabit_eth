library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mdio_controller is
    port (
        clk   : in std_logic;
        rst_n : in std_logic;
        -- MDIO management interface (PHY register access)
        MDIO_PHY_mdc     : out   std_logic;                 -- management clock (max 25 MHz for RTL8211F)
        MDIO_PHY_mdio_io : inout std_logic                  -- bidirectional management data
        
    );
end entity mdio_controller;

architecture rtl of mdio_controller is

begin

    

end architecture;