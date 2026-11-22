# SPDX-License-Identifier: Apache-2.0
"""V6 RTL/gate-level smoke tests, with physical ring oscillators OFF.

Checks reset, enable gating, MUX selection controls and unused outputs.
Does not simulate physical oscillation or oscillator frequencies.
"""
import cocotb
from cocotb.triggers import Timer


async def assert_off(dut, context):
    await Timer(1000, unit="ns")
    raw_outputs = int(dut.uo_out.value)
    assert raw_outputs == 0, f"{context}: expected both raw outputs off, got {raw_outputs:#04x}"
    assert int(dut.uio_out.value) == 0, f"{context}: uio_out must be 0"
    assert int(dut.uio_oe.value) == 0, f"{context}: uio pins must remain inputs"


@cocotb.test()
async def test_v6_disabled_reset_and_mux_selectors(dut):
    dut.clk.value = 0
    dut.ui_in.value = 0
    dut.uio_in.value = 0
    dut.ena.value = 0
    dut.rst_n.value = 0
    await assert_off(dut, "initial reset")

    selectors = ((0, 0), (0, 3), (1, 2), (2, 1), (3, 0), (3, 3))

    # Local enable high, but the Tiny Tapeout project enable is low.
    dut.rst_n.value = 1
    for a, b in selectors:
        dut.ui_in.value = 0b10000 | (b << 2) | a
        await assert_off(dut, f"ena=0, A={a}, B={b}")

    # Project enable high, but local enable low.
    dut.ena.value = 1
    for a, b in selectors:
        dut.ui_in.value = (b << 2) | a
        await assert_off(dut, f"RO_ENABLE=0, A={a}, B={b}")

    # Both enables requested, but reset still active.
    dut.rst_n.value = 0
    for a, b in selectors:
        dut.ui_in.value = 0b10000 | (b << 2) | a
        await assert_off(dut, f"rst_n=0, A={a}, B={b}")

    dut._log.info("V6 inactive-state smoke tests passed. Physical frequency not tested.")
