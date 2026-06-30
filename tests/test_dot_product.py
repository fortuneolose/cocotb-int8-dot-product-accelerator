"""Cocotb verification for the pipelined INT8 dot-product unit."""

from __future__ import annotations

import os
import random
from collections import deque
from dataclasses import dataclass
from pathlib import Path

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import ClockCycles, FallingEdge, RisingEdge, Timer

from tests.coverage import FunctionalCoverage
from tests.reference_model import dot_product, pack_signed_lanes, signed_from_bits


LANES = 4
DATA_WIDTH = 8
ACC_WIDTH = 18
ROOT = Path(__file__).resolve().parents[1]


@dataclass(frozen=True)
class Transaction:
    a: list[int]
    b: list[int]

    @property
    def expected(self) -> int:
        return dot_product(self.a, self.b)


DIRECTED_VECTORS = [
    Transaction([0, 0, 0, 0], [0, 0, 0, 0]),
    Transaction([1, 2, 3, 4], [5, 6, 7, 8]),
    Transaction([-1, -2, -3, -4], [5, 6, 7, 8]),
    Transaction([-128, -128, -128, -128], [-128, -128, -128, -128]),
    Transaction([-128, -128, -128, -128], [127, 127, 127, 127]),
    Transaction([127, 127, 127, 127], [127, 127, 127, 127]),
    Transaction([-128, 127, -1, 1], [127, -128, -1, 1]),
]


def _integer(signal) -> int:
    assert signal.value.is_resolvable, f"{signal._name} contains X/Z: {signal.value}"
    return int(signal.value)


async def _reset(dut) -> None:
    dut.rst_n.value = 0
    dut.in_valid.value = 0
    dut.a_vec.value = 0
    dut.b_vec.value = 0
    dut.out_ready.value = 0
    await ClockCycles(dut.clk, 3)
    await FallingEdge(dut.clk)
    dut.rst_n.value = 1


def _drive_transaction(dut, transaction: Transaction | None) -> None:
    if transaction is None:
        dut.in_valid.value = 0
        dut.a_vec.value = 0
        dut.b_vec.value = 0
    else:
        dut.in_valid.value = 1
        dut.a_vec.value = pack_signed_lanes(transaction.a, DATA_WIDTH)
        dut.b_vec.value = pack_signed_lanes(transaction.b, DATA_WIDTH)


@cocotb.test()
async def test_directed_latency_and_reset(dut) -> None:
    """Check edge arithmetic, reset flushing, and the unstalled latency."""
    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await _reset(dut)
    dut.out_ready.value = 1

    transaction = DIRECTED_VECTORS[3]
    await FallingEdge(dut.clk)
    _drive_transaction(dut, transaction)
    await Timer(1, units="ns")
    assert _integer(dut.in_ready) == 1

    await RisingEdge(dut.clk)  # accepted into product stage
    await FallingEdge(dut.clk)
    _drive_transaction(dut, None)
    assert _integer(dut.out_valid) == 0

    await RisingEdge(dut.clk)  # transferred into result stage
    await FallingEdge(dut.clk)
    assert _integer(dut.out_valid) == 1
    actual = signed_from_bits(_integer(dut.out_data), ACC_WIDTH)
    assert actual == transaction.expected

    # Reset must discard a valid result immediately at the next active edge.
    dut.rst_n.value = 0
    await RisingEdge(dut.clk)
    await FallingEdge(dut.clk)
    assert _integer(dut.out_valid) == 0


@cocotb.test()
async def test_randomized_stream_with_backpressure(dut) -> None:
    """Randomized scoreboard test with valid gaps and output backpressure."""
    seed = int(os.getenv("RANDOM_SEED", "20260630"))
    transaction_count = int(os.getenv("NUM_TRANSACTIONS", "300"))
    rng = random.Random(seed)
    coverage = FunctionalCoverage()
    pending = deque(DIRECTED_VECTORS)
    pending.extend(
        Transaction(
            [rng.randint(-128, 127) for _ in range(LANES)],
            [rng.randint(-128, 127) for _ in range(LANES)],
        )
        for _ in range(transaction_count - len(DIRECTED_VECTORS))
    )
    expected: deque[tuple[int, int]] = deque()
    current: Transaction | None = None
    accepted_inputs = 0
    accepted_outputs = 0
    cycle = 0
    previous_blocked: tuple[bool, int] | None = None

    cocotb.start_soon(Clock(dut.clk, 10, units="ns").start())
    await _reset(dut)

    maximum_cycles = transaction_count * 12
    while accepted_outputs < transaction_count:
        cycle += 1
        assert cycle <= maximum_cycles, "test timed out; possible pipeline deadlock"
        await FallingEdge(dut.clk)

        if current is None and pending and (rng.random() < 0.82 or not expected):
            current = pending.popleft()
        _drive_transaction(dut, current)

        # Bursty stalls exercise propagation of backpressure through both stages.
        force_progress = cycle % 17 == 0
        dut.out_ready.value = int(force_progress or rng.random() < 0.67)
        await Timer(1, units="ns")

        in_valid = _integer(dut.in_valid)
        in_ready = _integer(dut.in_ready)
        out_valid = _integer(dut.out_valid)
        out_ready = _integer(dut.out_ready)
        out_value = signed_from_bits(_integer(dut.out_data), ACC_WIDTH)
        input_accepted = bool(in_valid and in_ready)
        output_accepted = bool(out_valid and out_ready)
        output_blocked = bool(out_valid and not out_ready)
        input_blocked = bool(in_valid and not in_ready)

        if previous_blocked is not None and previous_blocked[0]:
            assert out_valid, "out_valid dropped while backpressured"
            assert out_value == previous_blocked[1], "out_data changed while backpressured"
        previous_blocked = (output_blocked, out_value)

        if output_accepted:
            assert expected, "DUT produced an output without an accepted input"
            wanted, accepted_cycle = expected.popleft()
            assert out_value == wanted, (
                f"cycle {cycle}: expected {wanted}, got {out_value}; "
                f"input accepted on cycle {accepted_cycle}"
            )
            accepted_outputs += 1

        if input_accepted:
            assert current is not None
            wanted = current.expected
            expected.append((wanted, cycle))
            coverage.sample_input(current.a, current.b, wanted)
            accepted_inputs += 1
            current = None

        coverage.sample_cycle(
            input_accepted=input_accepted,
            output_accepted=output_accepted,
            output_blocked=output_blocked,
            input_blocked=input_blocked,
            scoreboard_depth=len(expected),
        )
        await RisingEdge(dut.clk)

    _drive_transaction(dut, None)
    dut.out_ready.value = 1
    assert accepted_inputs == transaction_count
    assert not expected

    # Coverage closure checks are deterministic because directed vectors precede
    # the random stream.
    assert {"all_zero", "contains_int8_extreme", "mixed_sign_values"} <= coverage.input_classes
    assert {"negative", "zero", "positive"} <= coverage.result_signs
    assert {"zero", "small_1_255", "medium_256_16383", "large_16384_plus"} <= (
        coverage.result_magnitudes
    )
    assert coverage.backpressure_cycles > 0
    assert coverage.input_stall_cycles > 0
    assert coverage.consecutive_accepts > 0

    report = ROOT / "artifacts" / "coverage" / f"functional_seed_{seed}.json"
    coverage.write_json(report)
    dut._log.info("Functional coverage: %s", coverage.as_dict())
