import cocotb
from cocotb.triggers import RisingEdge, FallingEdge
from cocotb.clock import Clock


@cocotb.test()
async def smoke_test(dut):
    # 125 MHz on the PHY receive clock (8 ns period)
    cocotb.start_soon(Clock(dut.RGMII_rx_clk, 8, unit="ns").start())

    # hold active-low reset, park the inputs
    dut.reset_n.value       = 0
    dut.m_axis_tready.value = 1
    dut.RGMII_rd.value      = 0
    dut.RGMII_rx_ctrl.value = 0

    for _ in range(4):
        await RisingEdge(dut.RGMII_rx_clk)

    dut.reset_n.value = 1

    send_frame(dut, )

async def send_frame(dut, frame): 
    for byte in frame:
        await FallingEdge(dut.RGMII_rx_clk)
        dut.RGMII_rd.value      = byte & 0x0F
        dut.RGMII_tx_ctrl.value = 1
        await RisingEdge(dut.RGMII_rx_clk)
        dut.RGMII_rd.value      = (byte >> 4) & 0x0F
        dut.RGMII_tx_ctrl.value = 1
    await FallingEdge(dut.RGMII_rx_clk)
    dut.RGMII_rd.value      = 0
    dut.RGMII_tx_ctrl.value = 0

