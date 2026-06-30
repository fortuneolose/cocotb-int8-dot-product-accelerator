# Verification plan

## DUT contract

The DUT accepts two packed vectors when `in_valid && in_ready` is true at a
rising edge. It returns their full-precision signed dot product when
`out_valid && out_ready` is true. An unstalled transfer has two-cycle latency;
the elastic pipeline can accept one vector per cycle.

## Checks

| Requirement | Verification method |
|---|---|
| Signed INT8 multiplication and accumulation | Python integer golden model and ordered scoreboard |
| Full-precision corner results | Directed minimum/maximum operand vectors |
| Two-cycle unstalled latency | Dedicated directed test |
| One input accepted per cycle | Consecutive-valid randomized traffic |
| Correct backpressure | Random `out_ready`, scoreboard occupancy, input-stall coverage |
| Stable blocked output | Cocotb temporal check and RTL immediate assertions |
| Reset flushes the pipeline | Directed reset test |
| No unknowns on observed interface | Resolvability assertion before every conversion |
| No loss, duplication, or reordering | Queue-based end-to-end scoreboard |

## Reproducibility

The default seed is `20260630`. Override it and the transaction count with:

```bash
RANDOM_SEED=42 NUM_TRANSACTIONS=2000 make SIM=icarus
```

Every failing arithmetic message reports the cycle, expected value, actual
value, and input-accept cycle.
