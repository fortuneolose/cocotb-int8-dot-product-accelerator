`timescale 1ns / 1ps

module basys3_dot_product_top (
    input wire clk,
    input wire btnC
);

    wire rst_n;

    wire [31:0] a_vec;
    wire [31:0] b_vec;
    wire        in_valid;
    wire        in_ready;
    wire        out_valid;
    wire        out_ready;
    wire signed [17:0] out_data;

    // Basys 3 centre button is active high.
    // The accelerator reset input is active low.
    assign rst_n = ~btnC;

    dot_product_int8_vivado dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (in_ready),
        .a_vec     (a_vec),
        .b_vec     (b_vec),
        .out_valid (out_valid),
        .out_ready (out_ready),
        .out_data  (out_data)
    );

    // This IP will be generated in the next step.
    vio_0 control_vio (
        .clk        (clk),
        .probe_in0  (in_ready),
        .probe_in1  (out_valid),
        .probe_in2  (out_data),
        .probe_out0 (a_vec),
        .probe_out1 (b_vec),
        .probe_out2 (in_valid),
        .probe_out3 (out_ready)
    );

endmodule