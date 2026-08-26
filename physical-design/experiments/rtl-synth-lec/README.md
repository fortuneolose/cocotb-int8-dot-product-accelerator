# RTL-to-Synthesis Sequential Equivalence Experiments

This directory records direct formal equivalence experiments between the
original RTL implementation of the INT8 dot-product accelerator and the
exact Nangate45 gate-level netlist produced by the OpenROAD/Yosys flow.

## Compared designs

Reference RTL:

    rtl/dot_product_int8_vivado.v

Synthesized implementation:

    results/nangate45/dot_product_int8_vivado/lec-100mhz/1_2_yosys.v

Top module:

    dot_product_int8_vivado

Standard-cell library:

    NangateOpenCellLibrary_typical.lib

Kepler Formal was run in `-sv2v` mode so that the reference design was
parsed as SystemVerilog RTL while the implementation was parsed as a
gate-level Verilog netlist with Nangate45 Liberty semantics.

## PDR experiment

Configuration:

    Verification: sequential equivalence checking (SEC)
    Engine: pdr
    Encoding: dual_rail_steady
    Maximum k: 32
    Solver: KISSAT

Result:

    SEC checked-output coverage: 35.00% (7/20)
    7 of 20 observed outputs formally proved equivalent
    13 of 20 observed outputs were inconclusive
    No counterexample was reported
    Exit status: 1 (partial proof)

The remaining inconclusive outputs were `out_data[5]` through
`out_data[17]`.

Evidence:

    pdr_dualrail_k32.log

This is a partial formal proof and must not be interpreted as full
RTL-to-gate sequential equivalence.

## k-induction experiment

Configuration:

    Verification: sequential equivalence checking (SEC)
    Engine: k_induction
    Encoding: dual_rail_steady
    Maximum k: 32
    Solver: KISSAT

Both the RTL and synthesized gate-level design were successfully loaded
and the formal process remained computationally active under sustained
CPU utilisation.

The experiment was manually terminated after approximately 2.5 hours
because of excessive runtime before Kepler produced a formal verdict.

Result:

    No formal verdict obtained
    Manual SIGINT termination
    Exit status: 130

Evidence:

    k_induction_dualrail_k32_interrupted.log
    k_induction_dualrail_k32_runtime_snapshot.txt
    k_induction_dualrail_k32_status.txt

The interrupted experiment must not be classified as either equivalent,
non-equivalent, or formally inconclusive because the solver did not
complete.

## Verification conclusion

Direct RTL-to-gate SEC was successfully exercised with Kepler Formal.

The PDR experiment established equivalence for 7 of 20 observed outputs,
while the remaining 13 outputs were inconclusive. No counterexample was
reported.

Full RTL-to-synthesis sequential equivalence therefore remains unproven
for this project milestone.

This experiment is separate from the OpenROAD CTS timing-repair LEC,
which completed successfully and proved the before/after physical-design
netlists logically equivalent.
