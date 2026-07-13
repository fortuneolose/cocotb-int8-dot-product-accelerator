# Recreate the project, synthesize, place, route, and write reviewable reports.
#
# A valid installed FPGA part is required:
#   vivado -mode batch -source vivado/run_implementation.tcl \
#          -tclargs xczu3eg-sfva625-1L-i

set script_dir [file dirname [file normalize [info script]]]

if {[llength $argv] < 1 && ![info exists ::env(INT8_FPGA_PART)]} {
    error "Implementation requires an FPGA part via -tclargs or INT8_FPGA_PART"
}

source [file normalize "$script_dir/create_project.tcl"]

set selected_part [get_property PART [current_project]]
if {$selected_part eq ""} {
    error "Implementation requires an FPGA part"
}

set report_dir [file normalize "$script_dir/reports"]
file mkdir $report_dir

launch_runs synth_1 -jobs 4
wait_on_run synth_1
set synth_status [get_property STATUS [get_runs synth_1]]
if {[string first "Complete" $synth_status] < 0} {
    error "Vivado synthesis did not complete successfully: $synth_status"
}

launch_runs impl_1 -to_step route_design -jobs 4
wait_on_run impl_1
set impl_status [get_property STATUS [get_runs impl_1]]
if {[string first "Complete" $impl_status] < 0} {
    error "Vivado implementation did not complete successfully: $impl_status"
}

open_run impl_1
report_utilization -file "$report_dir/post_route_utilization.rpt"
report_timing_summary -file "$report_dir/post_route_timing_summary.rpt"
report_drc -file "$report_dir/post_route_drc.rpt"
write_checkpoint -force "$report_dir/dot_product_int8_post_route.dcp"

puts "Vivado implementation PASS for part $selected_part"
puts "Reports written under $report_dir"
close_project
