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

    // Asynchronous assertion, synchronous deassertion.
    (* ASYNC_REG = "TRUE" *) reg [1:0] reset_sync = 2'b00;

    always @(posedge clk or posedge btnC) begin
           if (btnC)
               reset_sync <= 2'b00;
           else
               reset_sync <= {reset_sync[0], 1'b1};
    end

    assign rst_n = reset_sync[1];

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

    // VIO provides JTAG-controlled operands, handshaking and result observation.
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