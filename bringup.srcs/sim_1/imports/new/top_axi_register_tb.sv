module top_axi_register_tb;



stimulus : process
begin
-- Set an idle state
address <= X"00000000";
write_data <= X"00000000";
rnw <= '0';
go <= '0';
wait for simulation_interval;
-- Generate a write transaction to the Manual Mode Control Register
address <= X"30000000";
write_data <= X"DEADBEEF";
rnw <= '0';
go <= '1';
wait for AXI_ACLK_period;
wait until done = '1';
go <= '0';
wait for AXI_ACLK_period;
address <= X"00000000";
wait for simulation_interval;
-- Generate a read transaction from the Manual Mode Control Register
address <= X"30000000";
write_data <= X"00000000";
rnw <= '1';
go <= '1';
wait for AXI_ACLK_period;
wait until done = '1';
go <= '0';
wait for AXI_ACLK_period;
address <= X"00000000";
wait for simulation_interval;
{... add additional stimuli here ...}
-- End of Stimuli. Give some time to finish up.
wait for simulation_interval;
sim_end <= true;
wait;
end process stimulus;

endmodule