# Create the project and run the self-checking testbench in Vivado XSIM.

set script_dir [file dirname [file normalize [info script]]]
source [file normalize "$script_dir/create_project.tcl"]

launch_simulation
run all
close_sim -force
close_project

puts "Vivado project-mode simulation completed."
