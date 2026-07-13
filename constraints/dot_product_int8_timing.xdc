# Board-independent timing constraints for the RTL demonstration.
# Replace or extend this file with the clock pin, I/O pins, I/O standards, and
# board-specific delays before generating a bitstream for physical hardware.

create_clock -name clk -period 10.000 [get_ports clk]

# A simple 2 ns external interface budget around the 100 MHz clock. These
# values make timing analysis reproducible; adapt them to the connected logic.
set_input_delay  -clock clk 2.000 [get_ports {rst_n in_valid out_ready a_vec[*] b_vec[*]}]
set_output_delay -clock clk 2.000 [get_ports {in_ready out_valid out_data[*]}]
