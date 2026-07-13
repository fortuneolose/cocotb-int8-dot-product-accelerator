# From RTL to a future FPGA implementation

The repository describes a reusable accelerator core, not a complete board image. The intended implementation path is:

    packed INT8 stream -> registered multipliers -> registered sum -> ready/valid stream

## 1. RTL and simulation

Vivado or another SystemVerilog simulator compiles rtl/dot_product_int8_vivado.v with tb/tb_dot_product_int8_vivado.sv. The testbench drives reset, fills the pipeline, deliberately stalls the output, and checks that the result and valid signal obey the ready/valid contract. The simulation log and WDB under artifacts/waves preserve the current evidence.

The elastic stages matter for hardware integration. A downstream block may deassert out_ready; the accelerator then holds the completed result and stops accepting new work when its internal storage is full. A streaming wrapper can therefore connect this core to FIFOs, DMA, or another pipeline without assuming an always-ready consumer.

## 2. Synthesis

Vivado maps each signed 8-by-8 multiplication and the adder tree to the selected FPGA fabric. The packaged implementation uses LUT/carry resources rather than DSP blocks. That is a reasonable small-core trade-off when DSPs are reserved for larger neural-network or signal-processing kernels, but a future performance or density study should compare this result with an explicitly DSP-mapped version.

The synthesized diagram at docs/diagrams/int8_dot_product_synth.svg shows the logical netlist-level structure. It is a visual explanation of the current core, not a board-level wiring diagram.

## 3. Timing and implementation

constraints/dot_product_int8_timing.xdc defines a 100 MHz clock and simple external input/output delay assumptions. Place-and-route can use those constraints to estimate whether the core meets a 10 ns cycle budget. The checked-in reports show positive post-route timing margin for the packaged target part.

The current XDC intentionally omits package pins and I/O standards. This keeps the core portable but means Vivado cannot validate electrical connectivity to a board. The DRC report therefore contains unspecified-I/O warnings. Those warnings must be resolved with the target board's master XDC before a production bitstream is generated.

## 4. Bitstream integration checklist

For a board deployment, add or confirm:

- The exact FPGA part and board master XDC, including clock pin, I/O pins, standards, and timing exceptions.
- A clock/reset wrapper appropriate to the board, including reset synchronisation if reset crosses clock domains.
- A host-facing protocol, such as AXI4-Stream, AXI-Lite plus a register file, DMA, or a custom FIFO interface.
- Input packing and signedness conversion at the system boundary. Lane 0 must occupy bits 7:0 and all four lanes must be interpreted as two's-complement INT8.
- Software or test firmware that feeds vectors, observes in_ready, consumes out_valid, and checks out_data.
- Post-implementation timing, DRC, power, and on-board functional tests.

Only after those items are present should write_bitstream be treated as a board-ready release step. The post-route checkpoint in artifacts/checkpoints is useful for inspection and reproducibility, but it is not a substitute for a bitstream built with the final board constraints.

## Mapping the video to hardware

The waveform video follows the same events that matter in a real streaming connection:

- Reset clears the pipeline.
- in_valid && in_ready accepts a packed vector.
- The multiplier and accumulation stages advance on clock edges.
- out_valid marks a completed sum.
- If out_ready is low, the result stays stable until the consumer can accept it.

This makes the video a compact architectural guide. For sign-off, use the native Vivado waveform database and implementation reports rather than relying on the rendered animation alone.
