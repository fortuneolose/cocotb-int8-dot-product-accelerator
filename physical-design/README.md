# ASIC Physical Design — OpenROAD / Nangate45

This directory documents the RTL-to-GDSII implementation of the four-lane signed INT8 dot-product accelerator using Yosys, OpenROAD, Kepler Formal, and the Nangate45 standard-cell platform.

The ASIC flow uses the canonical accelerator RTL:

`rtl/dot_product_int8_vivado.v`

## Flow

RTL → Yosys synthesis → floorplanning → placement → CTS → routing → parasitic extraction → STA → power/IR analysis → GDSII

## Implementation target

| Item | Configuration |
| --- | --- |
| RTL top | `dot_product_int8_vivado` |
| Platform | Nangate45 |
| Clock target | 100 MHz |
| Clock period | 10.000 ns |
| Physical-design framework | OpenROAD Flow Scripts |
| Synthesis | Yosys |
| Formal verification | Kepler Formal |

The OpenROAD configuration is available in
[`orfs/config.mk`](orfs/config.mk), with timing constraints in
[`constraints/dot_product_int8.sdc`](constraints/dot_product_int8.sdc).

## Final physical-design results

| Metric | Result |
| --- | ---: |
| Target frequency | 100 MHz |
| Final reported slack | +5.842 ns |
| Active design area | 2,844 µm² |
| Core utilization | 41% |
| Routed wirelength | 12,991 µm |
| Via count | 9,237 |
| Detailed-route DRC violations | 0 |
| Antenna net violations | 0 |
| Antenna pin violations | 0 |
| Estimated total power | 0.900 mW |
| Worst VDD IR drop | 1.17 mV |
| Worst VSS IR drop | 1.78 mV |
| Final GDSII | Generated |

The consolidated implementation record is
[`experiments/lec-100mhz/final_metrics.txt`](experiments/lec-100mhz/final_metrics.txt).


## Formal equivalence

### CTS timing-repair LEC

Kepler Formal was enabled around the OpenROAD CTS timing-repair transformation.

The checked-in formal log reports:

> SAT solver finished: UNSAT  
> Circuits are IDENTICAL

This establishes logical equivalence across the checked CTS timing-repair
transformation.

Evidence:

[experiments/lec-100mhz/cts_timing_repair_lec.log](experiments/lec-100mhz/cts_timing_repair_lec.log)

### Direct RTL-to-synthesis SEC

A separate sequential-equivalence experiment compared the original RTL against
the synthesized structural implementation.

The PDR experiment:

- proved 7 of 20 observed outputs;
- left 13 outputs inconclusive;
- reported no counterexample.

A separate k-induction attempt remained computationally active for approximately
2.5 hours and was manually terminated before obtaining a formal verdict.

Full RTL-to-gate sequential equivalence is therefore **not claimed**.

The complete scope and limitations are documented in
[experiments/rtl-synth-lec/README.md](experiments/rtl-synth-lec/README.md).

## OpenSTA synthesis compatibility

The mapped Yosys structural netlist required a small compatibility pass because
OpenSTA's structural Verilog parser rejected residual whole-word `signed`
qualifiers after arithmetic had already been technology mapped.

The canonical RTL was not modified.

The compatibility wrapper is:

[scripts/synth_opensta_compat.tcl](scripts/synth_opensta_compat.tcl)

## Reproducibility

A baseline implementation was compared with the LEC-enabled implementation.

The comparison showed:

- byte-identical final ODB;
- byte-identical final DEF;
- byte-identical final SDC;
- byte-identical final structural Verilog;
- byte-identical SPEF after removal of generation-date metadata; and
- byte-identical GDSII after normalization of `BGNLIB` and `BGNSTR` timestamp records.

The normalized GDSII SHA-256 was identical between both runs:

`4f1c04fd51bd1f6a64ddc6607647db0617b522c3d1f1d050cca140c2dc62dde2`

This demonstrates that enabling CTS-stage LEC did not perturb the final physical implementation.

The checked-in reproducibility record is included in:

[experiments/lec-100mhz/final_metrics.txt](experiments/lec-100mhz/final_metrics.txt)

## Evidence map

| Evidence | Path |
| --- | --- |
| Timing constraints | [constraints/dot_product_int8.sdc](constraints/dot_product_int8.sdc) |
| ORFS configuration | [orfs/config.mk](orfs/config.mk) |
| OpenSTA compatibility wrapper | [scripts/synth_opensta_compat.tcl](scripts/synth_opensta_compat.tcl) |
| Baseline synthesis statistics | [experiments/baseline-100mhz/synth_stat.txt](experiments/baseline-100mhz/synth_stat.txt) |
| Baseline CTS report | [experiments/baseline-100mhz/4_cts_final.rpt](experiments/baseline-100mhz/4_cts_final.rpt) |
| Baseline global-route report | [experiments/baseline-100mhz/5_global_route.rpt](experiments/baseline-100mhz/5_global_route.rpt) |
| Baseline route DRC | [experiments/baseline-100mhz/5_route_drc.rpt](experiments/baseline-100mhz/5_route_drc.rpt) |
| Baseline final report | [experiments/baseline-100mhz/6_finish.rpt](experiments/baseline-100mhz/6_finish.rpt) |
| Final DEF | [experiments/lec-100mhz/6_final.def](experiments/lec-100mhz/6_final.def) |
| Final GDSII | [experiments/lec-100mhz/6_final.gds](experiments/lec-100mhz/6_final.gds) |
| Final SDC | [experiments/lec-100mhz/6_final.sdc](experiments/lec-100mhz/6_final.sdc) |
| Final structural Verilog | [experiments/lec-100mhz/6_final.v](experiments/lec-100mhz/6_final.v) |
| Final artifact hashes | [experiments/lec-100mhz/SHA256SUMS](experiments/lec-100mhz/SHA256SUMS) |
| CTS formal LEC | [experiments/lec-100mhz/cts_timing_repair_lec.log](experiments/lec-100mhz/cts_timing_repair_lec.log) |
| Final metrics / reproducibility | [experiments/lec-100mhz/final_metrics.txt](experiments/lec-100mhz/final_metrics.txt) |
| RTL-to-synthesis SEC methodology | [experiments/rtl-synth-lec/README.md](experiments/rtl-synth-lec/README.md) |
| PDR SEC log | [experiments/rtl-synth-lec/pdr_dualrail_k32.log](experiments/rtl-synth-lec/pdr_dualrail_k32.log) |
| Interrupted k-induction log | [experiments/rtl-synth-lec/k_induction_dualrail_k32_interrupted.log](experiments/rtl-synth-lec/k_induction_dualrail_k32_interrupted.log) |

## Scope

This is an open-PDK educational and portfolio physical-design implementation.
It is not presented as a fabricated or silicon-validated ASIC.

The checked-in evidence demonstrates synthesis, physical implementation,
routing, timing analysis, physical verification checks, formal verification at
the documented transformation boundary, reproducibility analysis, and final
GDSII generation.
