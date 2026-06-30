# Coverage notes

This project uses explicit functional coverage in the cocotb scoreboard. It is
dependency-free: the regression records bins in JSON so reviewers can see
exactly what was exercised.

## Functional bins

| Coverpoint | Bins |
|---|---|
| Input class | all-zero, contains zero, INT8 extreme, mixed signs, all nonnegative, all nonpositive |
| Result sign | negative, zero, positive |
| Result magnitude | zero, 1–255, 256–16,383, 16,384+ |
| Flow control | output backpressure, propagated input stall, consecutive accepts |
| Pipeline occupancy | maximum outstanding scoreboard depth |

The directed prefix guarantees the important arithmetic corner bins. Seeded
random traffic expands the state space and independently randomizes input gaps
and output readiness. The test fails if mandatory corner, sign, magnitude, or
flow-control bins are not reached.

The generated report is written to:

```text
artifacts/coverage/functional_seed_<seed>.json
```

## Structural coverage

Open-source line/toggle coverage is intentionally not presented as functional
closure. Verilator coverage can be added with `--coverage`, but it answers a
different question: whether RTL implementation points toggled, not whether the
specified numerical and protocol scenarios were checked.

## Remaining gaps

- Parameter sweep beyond the default 4 lanes and 8-bit data
- Formal proof of no loss, duplication, or reordering
- Reset assertion in every possible occupied/stalled pipeline state
- Code and toggle coverage collection in CI
