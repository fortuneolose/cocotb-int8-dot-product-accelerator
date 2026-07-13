# Reproduced RTL verification results

The following checks were rerun from the repository source with Icarus Verilog
11.0 and cocotb 1.9.2 using deterministic seed `20260630`.

| Check | Result |
|---|---|
| Python reference/renderer tests | 6 passed |
| Cocotb directed latency/reset test | Pass |
| Cocotb randomized stream | 300 inputs and 300 outputs checked |
| Vivado-compatible Verilog smoke test | 7/7 vectors passed |
| SystemVerilog/Verilog translation equivalence | 1,009 active/drain cycles matched |
| Showcase waveform regression | 7/7 vectors passed |

The randomized run completed at 4,815 ns and reached:

- 125 output-backpressure cycles
- 93 propagated input-stall cycles
- 176 consecutive accepts
- maximum scoreboard depth of 2
- negative, zero, and positive result bins
- every defined result-magnitude bin
- all required operand classes, including INT8 extremes

The machine-readable coverage snapshot is retained in
[`functional_seed_20260630.json`](functional_seed_20260630.json).

The showcase produced these checked outputs:

```text
output[0] = 70
output[1] = 65536
output[2] = -70
output[3] = -32510
output[4] = -540
output[5] = 64516
output[6] = 0
VIVADO XSIM SHOWCASE PASS: 7 vectors checked
```

The actual showcase VCD is generated under `artifacts/waves/showcase.vcd`
and is intentionally ignored because CI regenerates and uploads it. The
versioned [showcase SVG](../../showcase-waveform.svg) is rendered from that
VCD by `tools/render_waveform.py`.
