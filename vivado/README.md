# Vivado flow

The repository contains both a captured Vivado project and a portable project generator. Use the generator when the checkout path or Vivado installation differs from the machine that produced the snapshot.

From the repository root:

    vivado -mode batch -source vivado/create_project.tcl

The generated project is placed in build/dot_product_int_8. To run the canonical XSim testbench and write artifacts/waves/vivado_dot_product.wdb:

    powershell -ExecutionPolicy Bypass -File vivado\run_showcase.ps1

Set VIVADO_BIN if Vivado is not on PATH:

    $env:VIVADO_BIN = "C:\Xilinx\2025.1.1\Vivado\bin"
    powershell -ExecutionPolicy Bypass -File vivado\run_showcase.ps1

Use -OpenGui to open the database with the curated waveform signal list:

    powershell -ExecutionPolicy Bypass -File vivado\run_showcase.ps1 -OpenGui

The script checks for the testbench's VIVADO RTL PASS marker. The XDC is intentionally a portable timing model without board pins; add the target board's master XDC before creating a board bitstream.
