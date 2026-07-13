# Open the checked-in XSim waveform and add the signals used by the showcase.
set script_dir [file dirname [file normalize [info script]]]
set repo_root [file dirname $script_dir]
set wave_db [file join $repo_root artifacts waves vivado_dot_product.wdb]

if {![file exists $wave_db]} {
    error "Waveform database not found: $wave_db"
}

open_wave_database $wave_db
create_wave_config
add_wave_group "Ready-valid interface"
add_wave /tb_dot_product_int8_vivado/clk
add_wave /tb_dot_product_int8_vivado/rst_n
add_wave /tb_dot_product_int8_vivado/in_valid
add_wave /tb_dot_product_int8_vivado/in_ready
add_wave /tb_dot_product_int8_vivado/out_valid
add_wave /tb_dot_product_int8_vivado/out_ready
add_wave /tb_dot_product_int8_vivado/out_data
add_wave_group "Operands"
add_wave /tb_dot_product_int8_vivado/a_vec
add_wave /tb_dot_product_int8_vivado/b_vec
add_wave_group "Pipeline internals"
add_wave /tb_dot_product_int8_vivado/dut/products_valid_q
add_wave /tb_dot_product_int8_vivado/dut/result_valid_q
save_wave_config [file join $repo_root vivado int8_dot_product_wave.wcfg]
