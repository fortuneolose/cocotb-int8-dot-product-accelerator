## Basys 3 100 MHz oscillator
set_property -dict {PACKAGE_PIN W5 IOSTANDARD LVCMOS33} [get_ports clk]
create_clock -add -name sys_clk_pin -period 10.000 \
    -waveform {0.000 5.000} [get_ports clk]

## Basys 3 centre pushbutton
set_property -dict {PACKAGE_PIN U18 IOSTANDARD LVCMOS33} [get_ports btnC]

## btnC is an asynchronous reset source
set_false_path -from [get_ports btnC]

## FPGA configuration-bank voltage
set_property CONFIG_VOLTAGE 3.3 [current_design]
set_property CFGBVS VCCO [current_design]