# Recreate a clean Vivado project from version-controlled source files.
#
# Optional first Tcl argument: FPGA part name. Example:
#   vivado -mode batch -source vivado/create_project.tcl \
#          -tclargs xc7a35tcpg236-1

set script_dir   [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set project_name int8_dot_product_vivado
set project_dir  [file normalize "$script_dir/build"]

set part_name ""
if {[llength $argv] >= 1} {
    set part_name [string trim [lindex $argv 0]]
} elseif {[info exists ::env(INT8_FPGA_PART)]} {
    set part_name [string trim $::env(INT8_FPGA_PART)]
}

if {$part_name ne ""} {
    if {[llength [get_parts -quiet $part_name]] == 0} {
        error "FPGA part '$part_name' is not installed in this Vivado installation"
    }
    create_project -force $project_name $project_dir -part $part_name
} else {
    create_project -force $project_name $project_dir
}

set rtl_file [file normalize "$project_root/rtl/dot_product_int8_vivado.v"]
set tb_file  [file normalize "$script_dir/tb_dot_product_int8_vivado.sv"]
set xdc_file [file normalize "$script_dir/constraints/dot_product_int8_timing.xdc"]

foreach required_file [list $rtl_file $tb_file $xdc_file] {
    if {![file exists $required_file]} {
        error "Required source file not found: $required_file"
    }
}

add_files -norecurse -fileset sources_1 $rtl_file
set_property file_type Verilog [get_files $rtl_file]
set_property top dot_product_int8_vivado [get_filesets sources_1]

add_files -norecurse -fileset constrs_1 $xdc_file

add_files -norecurse -fileset sim_1 $tb_file
set_property file_type SystemVerilog [get_files $tb_file]
set_property top tb_dot_product_int8_vivado [get_filesets sim_1]
set_property top_lib xil_defaultlib [get_filesets sim_1]

set_property target_simulator XSim [current_project]
set_property simulator_language Mixed [current_project]
set_property xsim.elaborate.debug_level typical [get_filesets sim_1]
set_property xsim.simulate.runtime all [get_filesets sim_1]

update_compile_order -fileset sources_1
update_compile_order -fileset sim_1

puts "Created Vivado project: [file normalize $project_dir/$project_name.xpr]"
if {$part_name eq ""} {
    puts "No FPGA part selected: RTL simulation is available; pass a part for synthesis."
} else {
    puts "FPGA part: $part_name"
}
