library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

entity mdio_controller is
    port (
        clk                 : in std_logic; -- 50MHz system clock
        rst_n               : in std_logic;
        -- MDIO management interface (PHY register access)
        MDIO_PHY_mdc        : out std_logic;    -- management clock (max 25 MHz for RTL8211F)
        MDIO_PHY_mdio_io    : inout std_logic;  -- bidirectional management data
        mdio_comms_fail     : out std_logic     -- Flag to indicate phy ID read failed
    );
end entity mdio_controller;

architecture rtl of mdio_controller is
-- Table 13. Management Frame Description 
-- Preamble 32  Contiguous Logical 1’s Sent by the MAC on MDIO, along with 32 Corresponding Cycles on MDC. 
--              This provides synchronization for the PHY. 

-- ST           Start of Frame. 
--              Indicated by a 01 pattern. 

-- OP           Operation Code. 
--              Read: 10 
--              Write: 01 
-- PHYAD PHY Address. 
--              Up to eight PHYs can be connected to one MAC. This 3-bit field selects which PHY the frame is directed to.
-- REGAD Register Address. 
--              This is a 5-bit field that sets which of the 32 registers of the PHY this operation refers to. 
-- TA Turnaround. 
--              This is a 2-bit-time spacing between the register address and the data field of a frame to avoid contention 
--               for the first bit time of the turnaround. The PHY drives a zero bit during the second bit time of the turnaround 
-- of a read transaction. 
-- DATA Data. These are the 16 bits of data. 
-- IDLE Idle Condition. 
-- Not truly part of the management frame. This is a high impedance state. Electrically, the PHY’s pull-up 
-- resistor will pull the MDIO line to a logical ‘1’. 
    constant PHYID1         : std_logic_vector(15 downto 0) := x"001C";
    constant PHYID1_ADDR    : std_logic_vector(7 downto 0)  := x"02";

    signal cnt              : unsigned(7 downto 0);
    
begin

    process(clk)
    begin
      if rising_edge(clk) then
        mdc_tick <= '0';
        if run = '1' then            -- only clock while a transaction is active
          if cnt = HALF_DIV-1 then
            cnt     <= 0;
            mdc_int <= not mdc_int;  -- toggle MDC
            mdc_tick <= '1';         -- flag the edge for your shift FSM
          else
            cnt <= cnt + 1;
          end if;
        else
          cnt     <= 0;
          mdc_int <= '0';            -- park MDC low when idle
        end if;
      end if;
    end process;
    MDIO_PHY_mdc <= mdc_int;

end architecture;