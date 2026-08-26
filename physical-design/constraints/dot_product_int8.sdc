create_clock -name clk -period 10.000 [get_ports clk]

set_input_delay -clock clk 2.000 \
    [get_ports {rst_n in_valid out_ready a_vec[*] b_vec[*]}]

set_output_delay -clock clk 2.000 \
    [get_ports {in_ready out_valid out_data[*]}]
