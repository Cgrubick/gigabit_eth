library ieee;
use ieee.std_logic_1164.all;
use ieee.numeric_std.all;

-- Copy this file to ip_defs_pkg.vhd and fill in your real addresses.
-- ip_defs_pkg.vhd is gitignored so your addresses stay private.
package ip_defs_pkg is
    -- IPv4 addresses (32-bit) 
    constant FPGA_IP        : std_logic_vector(31 downto 0) := x"0700000A"; 
    constant HOST_IP        : std_logic_vector(31 downto 0) := x"5000000A"; 
    -- UDP/TCP ports (16-bit)
    constant FPGA_PORT      : std_logic_vector(15 downto 0) := x"0001";  
    constant HOST_PORT      : std_logic_vector(15 downto 0) := x"0002";  
    -- MAC addresses (48-bit)
    constant FPGA_MAC       : std_logic_vector(47 downto 0) := x"000000000000"; 
    constant HOST_MAC       : std_logic_vector(47 downto 0) := x"AF93B4E0FF10"; 
    constant CHECK_DEST     : std_logic := '1';
end package ip_defs_pkg;
