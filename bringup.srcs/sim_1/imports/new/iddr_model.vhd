library ieee;
use ieee.std_logic_1164.all;

package vcomponents is
    component IDDR is
        generic (
            DDR_CLK_EDGE : string  := "SAME_EDGE_PIPELINED";
            INIT_Q1      : bit     := '0';
            INIT_Q2      : bit     := '0';
            SRTYPE       : string  := "ASYNC"
        );
        port (
            Q1 : out std_logic;
            Q2 : out std_logic;
            C  : in  std_logic;
            CE : in  std_logic;
            D  : in  std_logic;
            R  : in  std_logic;
            S  : in  std_logic
        );
    end component IDDR;
end package vcomponents;

library ieee;
use ieee.std_logic_1164.all;

entity IDDR is
    generic (
        DDR_CLK_EDGE : string  := "SAME_EDGE_PIPELINED";
        INIT_Q1      : bit     := '0';
        INIT_Q2      : bit     := '0';
        SRTYPE       : string  := "ASYNC"
    );
    port (
        Q1 : out std_logic;
        Q2 : out std_logic;
        C  : in  std_logic;
        CE : in  std_logic;
        D  : in  std_logic;
        R  : in  std_logic;
        S  : in  std_logic
    );
end entity IDDR;

-- Models the real Xilinx IDDR in SAME_EDGE_PIPELINED mode: Q1 (rising sample)
-- and Q2 (falling sample) are presented together as a matched pair from the
-- SAME DDR period, delayed one full clock. This matches Vivado's unisim IDDR.
architecture behavioral of IDDR is
    signal d_rise : std_logic := to_stdulogic(INIT_Q1);  -- this period's rising sample
    signal d_fall : std_logic := to_stdulogic(INIT_Q2);  -- this period's falling sample
    signal q1_int : std_logic := to_stdulogic(INIT_Q1);
    signal q2_int : std_logic := to_stdulogic(INIT_Q2);
begin

    process (C, R, S)
    begin
        if R = '1' then
            d_rise <= '0';
            d_fall <= '0';
            q1_int <= '0';
            q2_int <= '0';
        elsif S = '1' then
            d_rise <= '1';
            d_fall <= '1';
            q1_int <= '1';
            q2_int <= '1';
        elsif rising_edge(C) then
            if CE = '1' then
                q1_int <= d_rise;   -- present the matched pair captured over
                q2_int <= d_fall;   -- the previous period (1-cycle latency)
                d_rise <= D;        -- capture this period's rising bit
            end if;
        elsif falling_edge(C) then
            if CE = '1' then
                d_fall <= D;        -- capture this period's falling bit
            end if;
        end if;
    end process;

    Q1 <= q1_int;
    Q2 <= q2_int;

end architecture behavioral;
