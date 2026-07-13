# Vivado RTL and XSIM flow

The recommended flow creates a normal Vivado project with separate Design
Sources, Simulation Sources, and Constraints. The accelerator is translated
to conservative Verilog-2001 in `rtl/dot_product_int8_vivado.v`; this avoids
file-type ambiguity while preserving the original signed arithmetic,
two-stage pipeline, and ready/valid backpressure behavior.

## Run the native project

From the repository root in a Vivado-enabled PowerShell terminal:

```powershell
# Create, elaborate, and run the self-checking XSIM testbench.
.\vivado\run_project.ps1 -Action Simulate

# Create the project for use in the Vivado GUI.
.\vivado\run_project.ps1 -Action Create
vivado.bat .\vivado\build\int8_dot_product_vivado.xpr

# Synthesize for the exact installed FPGA part on your board.
.\vivado\run_project.ps1 -Action Synthesize -Part xc7a35tcpg236-1

# Synthesize, place, route, and generate timing/utilization/DRC reports.
.\vivado\run_project.ps1 -Action Implement -Part xczu3eg-sfva625-1L-i
```

The same operations can be run directly with Tcl:

```powershell
vivado.bat -mode batch -source .\vivado\run_project_simulation.tcl
vivado.bat -mode batch -source .\vivado\create_project.tcl
vivado.bat -mode batch -source .\vivado\run_synthesis.tcl `
  -tclargs xc7a35tcpg236-1
vivado.bat -mode batch -source .\vivado\run_implementation.tcl `
  -tclargs xczu3eg-sfva625-1L-i
```

A successful simulation prints:

```text
VIVADO RTL PASS: 7 vectors checked; signed INT8 corner = 65536
```

CI also compiles the Verilog translation independently and compares it against
the original parameterized SystemVerilog RTL for 1,000 randomized cycles with
valid gaps and output backpressure.

The generated project lives under `vivado/build/`; synthesis/implementation
reports and checkpoints live under `vivado/reports/`. Both directories are
generated and intentionally ignored by Git. Audited post-route text reports
from the demonstrated XCZU3EG run are retained under `docs/results/vivado/`.

The timing XDC assumes a 100 MHz clock and a 2 ns external I/O budget. It does
not contain package pins or I/O standards. Add the master XDC for your exact
board before implementation or bitstream generation.

## Direct XSIM showcase

This optional native-Windows flow runs a focused seven-vector testbench with
Vivado XSIM and opens the resulting waveform database in Vivado's interactive
wave viewer.

From the repository root:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass `
  -File .\vivado\run_showcase.ps1 -OpenGui
```

The testbench checks positive, negative, zero, full-precision INT8 corner, and
backpressured transactions. A successful run prints:

```text
VIVADO XSIM SHOWCASE PASS: 7 vectors checked
```

Generated build state is kept under `vivado/xsim_work/`. The waveform database
is `artifacts/waves/vivado_dot_product.wdb`; both are ignored by Git.
