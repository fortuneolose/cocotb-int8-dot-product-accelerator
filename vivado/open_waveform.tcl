set script_dir [file dirname [file normalize [info script]]]
set project_root [file dirname $script_dir]
set waveform_db [file normalize "$project_root/artifacts/waves/vivado_dot_product.wdb"]

if {![file exists $waveform_db]} {
    error "Waveform database not found: $waveform_db"
}

open_wave_database $waveform_db
create_wave_config

set clock_group [add_wave_group "Clock and reset"]
add_wave -into $clock_group \
    /tb_dot_product_showcase/clk \
    /tb_dot_product_showcase/rst_n

set input_handshake_group [add_wave_group "Input handshake"]
add_wave -into $input_handshake_group \
    /tb_dot_product_showcase/in_valid \
    /tb_dot_product_showcase/in_ready

set input_vector_group [add_wave_group "Input vectors"]
add_wave -into $input_vector_group -radix hex \
    /tb_dot_product_showcase/a_vec \
    /tb_dot_product_showcase/b_vec

set pipeline_group [add_wave_group "Pipeline state"]
add_wave -into $pipeline_group \
    /tb_dot_product_showcase/dut/products_valid_q \
    /tb_dot_product_showcase/dut/result_valid_q

set output_handshake_group [add_wave_group "Output handshake"]
add_wave -into $output_handshake_group \
    /tb_dot_product_showcase/out_valid \
    /tb_dot_product_showcase/out_ready

set result_group [add_wave_group "Signed result"]
add_wave -into $result_group -radix dec \
    /tb_dot_product_showcase/out_data

puts "Opened interactive waveform: $waveform_db"
