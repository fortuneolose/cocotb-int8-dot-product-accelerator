# Create the project, synthesize the Verilog-2001 implementation, and write
# reviewable utilization/timing reports plus a post-synthesis checkpoint.
#
# A valid installed FPGA part is required:
#   vivado -mode batch -source vivado/run_synthesis.tcl \
#          -tclargs xc7a35tcpg236-1

set script_dir [file dirname [file normalize [info script]]]

if {[llength $argv] < 1 && ![info exists ::env(INT8_FPGA_PART)]} {
    error "Synthesis requires an FPGA part via -tclargs or INT8_FPGA_PART"
}

source [file normalize "$script_dir/create_project.tcl"]

set selected_part [get_property PART [current_project]]
if {$selected_part eq ""} {
    error "Synthesis requires an FPGA part"
}

set report_dir [file normalize "$script_dir/reports"]
file mkdir $report_dir

launch_runs synth_1 -jobs 4
wait_on_run synth_1

set synth_status [get_property STATUS [get_runs synth_1]]
if {[string first "Complete" $synth_status] < 0} {
    error "Vivado synthesis did not complete successfully: $synth_status"
}

open_run synth_1
report_utilization -file "$report_dir/post_synth_utilization.rpt"
report_timing_summary -file "$report_dir/post_synth_timing_summary.rpt"
write_checkpoint -force "$report_dir/dot_product_int8_post_synth.dcp"

puts "Vivado synthesis PASS for part $selected_part"
puts "Reports written under $report_dir"
close_project
