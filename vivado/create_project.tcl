# Create a clean, portable Vivado project from the repository sources.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file dirname $script_dir]
set build_root [file join $repo_root build]
set project_name dot_product_int_8
set project_dir [file join $build_root $project_name]
set part xczu3eg-sfva625-1L-i

file mkdir $build_root
create_project $project_name $project_dir -part $part -force
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]

add_files -norecurse [file join $repo_root rtl dot_product_int8_vivado.v]
add_files -fileset sim_1 -norecurse [file join $repo_root tb tb_dot_product_int8_vivado.sv]
add_files -fileset constrs_1 -norecurse [file join $repo_root constraints dot_product_int8_timing.xdc]

set_property top dot_product_int8_vivado [get_filesets sources_1]
set_property top tb_dot_product_int8_vivado [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]
set_property -name {xsim.simulate.runtime} -value {1000ns} -objects [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property -name {steps.synth_design.args.assert} -value {1} -objects [get_runs synth_1]
puts "Created portable Vivado project: $project_dir"
