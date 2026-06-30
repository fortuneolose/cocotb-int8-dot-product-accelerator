# Vivado XSIM showcase

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
