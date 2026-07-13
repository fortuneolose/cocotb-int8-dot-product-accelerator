"""Cross-platform cocotb runner; useful where GNU Make is unavailable."""

from __future__ import annotations

import argparse
import os
from pathlib import Path

try:
    from cocotb_tools.runner import get_runner
except ImportError:  # cocotb 1.x
    from cocotb.runner import get_runner


ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sim", choices=("icarus", "verilator"), default="icarus")
    parser.add_argument("--waves", action="store_true")
    parser.add_argument("--seed", type=int, default=20260630)
    parser.add_argument("--transactions", type=int, default=300)
    args = parser.parse_args()

    os.environ["RANDOM_SEED"] = str(args.seed)
    os.environ["NUM_TRANSACTIONS"] = str(args.transactions)

    build_args = ["-Wall"]
    if args.sim == "icarus":
        # The cocotb scoreboard duplicates the RTL's immediate protocol
        # assertions, which are not implemented by every Icarus release.
        build_args.extend(("-g2012", "-DSYNTHESIS"))
        if args.waves:
            build_args.append("-DDUMP_WAVES")
    else:
        build_args.append("--Wno-fatal")

    runner = get_runner(args.sim)
    runner.build(
        sources=[ROOT / "rtl" / "dot_product_int8.sv"],
        hdl_toplevel="dot_product_int8",
        build_dir=ROOT / "sim_build" / args.sim,
        build_args=build_args,
        always=True,
    )
    runner.test(
        hdl_toplevel="dot_product_int8",
        test_module="tests.test_dot_product",
        test_dir=ROOT,
        waves=args.waves,
    )


if __name__ == "__main__":
    main()
