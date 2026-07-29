# Create the work library
vlib work

# Create unisim library and compile behavioral IDDR model into it
vlib unisim
vcom -2008 -quiet -work unisim iddr_model.vhd

# Compile the design (VHDL) and testbench (SystemVerilog)
vcom -2008 -quiet -work work ../../../sources_1/new/gigabit_rx.vhd
vlog -sv +acc -quiet -work work gigabit_rx_tb.sv

# Load the simulation
vsim -quiet gigabit_rx_tb

# Setup the wave window
view wave
configure wave -namecolwidth 300
configure wave -valuecolwidth 250
quietly set NumericStdNoWarnings 1
run 0 ns
quietly set NumericStdNoWarnings 0

# ---- Ports ----
add wave -divider {Ports}
add wave /gigabit_rx_tb/clk
add wave /gigabit_rx_tb/reset_n
add wave /gigabit_rx_tb/RGMII_rx_clk
add wave -hex /gigabit_rx_tb/RGMII_rd
add wave /gigabit_rx_tb/RGMII_rx_ctrl
add wave /gigabit_rx_tb/rx_error

# ---- Internal Signals ----
add wave -divider {Internal Signals}
add wave /gigabit_rx_tb/dut/eth_state
add wave -hex /gigabit_rx_tb/dut/rxd_r
add wave -hex /gigabit_rx_tb/dut/rxd_f
add wave /gigabit_rx_tb/dut/ctrl_r
add wave /gigabit_rx_tb/dut/ctrl_f
add wave -hex /gigabit_rx_tb/dut/eth_byte
add wave /gigabit_rx_tb/dut/ctrl_dv
add wave /gigabit_rx_tb/dut/rx_err
add wave -unsigned /gigabit_rx_tb/dut/byte_count
add wave -hex /gigabit_rx_tb/dut/dest_mac
add wave -hex /gigabit_rx_tb/dut/src_mac
add wave -hex /gigabit_rx_tb/dut/ethertype
add wave /gigabit_rx_tb/dut/packet_dropped
add wave /gigabit_rx_tb/dut/is_ipv4
add wave /gigabit_rx_tb/dut/is_arp 


add wave -divider {AXI-S Interface}
add wave /gigabit_rx_tb/m_axis_tready
add wave /gigabit_rx_tb/m_axis_tready
add wave /gigabit_rx_tb/m_axis_tdata 
add wave /gigabit_rx_tb/m_axis_tvalid
add wave /gigabit_rx_tb/m_axis_tlast 

run 2us
wave zoom full
