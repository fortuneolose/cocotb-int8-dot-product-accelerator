# Vivado implementation evidence

These reports were exported from the fully routed
`dot_product_int8_vivado` design in Vivado 2025.1.1.

| Property | Value |
|---|---|
| Part | `xczu3eg-sfva625-1L-i` |
| Clock | 100 MHz / 10.000 ns |
| Setup | WNS +1.538 ns, TNS 0.000 ns |
| Hold | WHS +0.077 ns, THS 0.000 ns |
| Failing setup/hold endpoints | 0 / 0 |
| Utilization | 298 LUT, 84 FF, 41 CARRY8, 0 DSP, 0 BRAM |
| I/O | 88 / 180 bonded I/O sites |

The DRC contains only `NSTD-1` and `UCIO-1`. They remain critical warnings
because the project intentionally has no physical-board pin assignments or
I/O standards. Consequently, these reports prove routed implementation and
timing for the evaluation target, not board-ready bitstream sign-off.

The reports are retained verbatim. Regenerate equivalent working reports with:

```powershell
.\vivado\run_project.ps1 -Action Implement -Part xczu3eg-sfva625-1L-i
```

Vivado writes regenerated reports and the post-route checkpoint under
`vivado/reports/`, which is intentionally ignored as generated state.
