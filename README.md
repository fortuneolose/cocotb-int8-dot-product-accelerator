# INT8 Dot-Product Accelerator

This repository is the Vivado-oriented handoff for a four-lane signed INT8 dot-product accelerator. It contains the canonical RTL, its Vivado/XSim testbench, timing constraints, the Vivado project snapshot, synthesis and implementation evidence, a synthesized circuit diagram, and a review-friendly waveform video.

The original repository layout was replaced with the cleaned Vivado content from the local project. The checked-in artifacts make the current design inspectable without treating an uncommitted Vivado workspace as the source of truth.

## What the accelerator computes

For each accepted transaction, the circuit calculates:

    result = a[0] * b[0] + a[1] * b[1] + a[2] * b[2] + a[3] * b[3]

The operands are signed two's-complement INT8 values. Each packed input vector is 32 bits wide, with lane 0 in bits 7:0, lane 1 in bits 15:8, lane 2 in bits 23:16, and lane 3 in bits 31:24. The signed result is 18 bits wide, which provides headroom for the sum of four signed 8-by-8 products.

The top-level module is dot_product_int8_vivado in rtl/dot_product_int8_vivado.v. It uses a ready/valid interface:

- An input transfer occurs when in_valid and in_ready are high on a rising clock edge.
- An output transfer occurs when out_valid and out_ready are high on a rising clock edge.
- out_data remains stable while out_valid is high and the consumer is applying backpressure.
- The two registered pipeline stages provide elastic buffering. Throughput can reach one vector per cycle after filling, while the exact input-to-output delay depends on whether either side stalls.

## Architecture

The implementation has two sequential stages:

1. Four signed INT8 multipliers unpack the operands and register the four 16-bit products.
2. The registered products are sign-extended, summed, and stored in the output stage.

The synthesized view of this structure is available at [docs/diagrams/int8_dot_product_synth.svg](docs/diagrams/int8_dot_product_synth.svg). The SVG is generated from the Vivado synthesized design and is the most direct visual reference for the current RTL structure.

## Verification

The Vivado testbench is [tb/tb_dot_product_int8_vivado.sv](tb/tb_dot_product_int8_vivado.sv). It exercises seven directed vectors, including positive and negative products, the signed INT8 corner case, zero, and output backpressure. The packaged XSim log reports:

    VIVADO RTL PASS: 7 vectors checked; signed INT8 corner = 65536

The expected signed results in the run are 70, 65536, -70, -32510, -540, 64516, and 0. The checked-in waveform database is [artifacts/waves/vivado_dot_product.wdb](artifacts/waves/vivado_dot_product.wdb), and the text log is [artifacts/waves/vivado_xsim.log](artifacts/waves/vivado_xsim.log).

## Reproduce the Vivado run

The portable Tcl entry point creates a fresh project under build/dot_product_int_8 using the target part xczu3eg-sfva625-1L-i:

    vivado -mode batch -source vivado/create_project.tcl

To run XSim and write a waveform database into artifacts/waves, use PowerShell:

    powershell -ExecutionPolicy Bypass -File vivado\run_showcase.ps1

Add -OpenGui to launch Vivado with the waveform database and a curated signal layout:

    powershell -ExecutionPolicy Bypass -File vivado\run_showcase.ps1 -OpenGui

The GUI-oriented Tcl file is [vivado/open_waveform.tcl](vivado/open_waveform.tcl). The repository also retains the original project snapshot at [vivado/dot_product_int_8.xpr](vivado/dot_product_int_8.xpr); the portable Tcl flow is preferred when opening the project on another machine.

## Waveform showcase

The [waveform showcase video](docs/media/int8_dot_product_waveform_showcase.mp4) pairs the ready/valid waveform with an animated view of the datapath: operand unpacking, four signed multipliers, sign extension and accumulation, and the registered output. It highlights reset, normal streaming, a consumer stall, stable output data during backpressure, and queue drain after out_ready returns.

The MP4 is a rendered companion for code review and documentation. The native Vivado WDB remains authoritative for signal-level inspection and can be opened with the Tcl flow above; the video is not presented as a raw screen recording of a particular Vivado installation.

## FPGA implementation relevance

The timing constraint in [constraints/dot_product_int8_timing.xdc](constraints/dot_product_int8_timing.xdc) models a 100 MHz clock with 2 ns input and output delays. The packaged post-route reports show:

- 298 LUTs
- 84 flip-flops
- 41 CARRY8 primitives
- 0 DSP blocks and 0 block RAMs
- 1.538 ns WNS (positive timing slack) and 0 ns total negative slack (TNS) in the packaged timing summary

The design currently has no board-specific pin assignments or I/O standards. Consequently, the implementation evidence is useful for resource and timing review, but it is not a board-ready bitstream handoff. The packaged DRC report records the expected UCIO-1 and NSTD-1 constraints warnings for unspecified I/O. A future board implementation must add the board master XDC, clock/reset strategy, physical I/O mapping, and any required CDC or host-streaming wrapper before bitstream generation.

See [docs/fpga-implementation.md](docs/fpga-implementation.md) for the path from RTL simulation to a deployable FPGA design and the remaining bring-up work.

## Repository contents

- [rtl/dot_product_int8_vivado.v](rtl/dot_product_int8_vivado.v) — canonical synthesizable accelerator RTL.
- [tb/tb_dot_product_int8_vivado.sv](tb/tb_dot_product_int8_vivado.sv) — self-checking Vivado XSim testbench.
- [constraints/dot_product_int8_timing.xdc](constraints/dot_product_int8_timing.xdc) — 100 MHz timing model.
- [vivado/dot_product_int_8.xpr](vivado/dot_product_int_8.xpr) — captured Vivado project snapshot.
- [vivado/create_project.tcl](vivado/create_project.tcl) — portable project generator.
- [vivado/run_showcase.ps1](vivado/run_showcase.ps1) — XSim/WDB runner with optional GUI launch.
- [docs/diagrams/int8_dot_product_synth.svg](docs/diagrams/int8_dot_product_synth.svg) — synthesized circuit diagram.
- [docs/media/int8_dot_product_waveform_showcase.mp4](docs/media/int8_dot_product_waveform_showcase.mp4) — waveform and datapath video.
- [artifacts/reports](artifacts/reports) — synthesis, implementation, timing, and DRC evidence.
- [artifacts/checkpoints/int8_dot_product_post_route.dcp](artifacts/checkpoints/int8_dot_product_post_route.dcp) — post-route Vivado checkpoint.

## Scope and limitations

This repository focuses on the accelerator core and its Vivado evidence. It does not yet include a board wrapper, AXI-stream or memory-mapped host interface, board pin constraints, clock-generation IP, software driver, or a completed bitstream. Those are integration tasks for the target FPGA platform.
