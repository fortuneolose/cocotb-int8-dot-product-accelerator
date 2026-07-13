`timescale 1ns/1ps
`default_nettype none

// Vivado-oriented, synthesizable Verilog-2001 implementation of the
// four-lane signed INT8 dot-product accelerator.
//
// Lane zero is the least-significant byte:
//   a_vec = {a3, a2, a1, a0}
//   b_vec = {b3, b2, b1, b0}
//
// The result is full precision:
//   four signed INT8 products -> signed INT18 result.
//
// The datapath is a two-entry elastic pipeline. A transfer occurs on a rising
// clock edge when valid and ready are both asserted. Output data remains
// stable while out_valid is high and out_ready is low.
module dot_product_int8_vivado (
    input  wire               clk,
    input  wire               rst_n,

    input  wire               in_valid,
    output wire               in_ready,
    input  wire [31:0]        a_vec,
    input  wire [31:0]        b_vec,

    output wire               out_valid,
    input  wire               out_ready,
    output wire signed [17:0] out_data
);

    wire signed [7:0] a0;
    wire signed [7:0] a1;
    wire signed [7:0] a2;
    wire signed [7:0] a3;
    wire signed [7:0] b0;
    wire signed [7:0] b1;
    wire signed [7:0] b2;
    wire signed [7:0] b3;

    reg signed [15:0] product0_q;
    reg signed [15:0] product1_q;
    reg signed [15:0] product2_q;
    reg signed [15:0] product3_q;
    reg               products_valid_q;

    wire signed [17:0] product0_ext;
    wire signed [17:0] product1_ext;
    wire signed [17:0] product2_ext;
    wire signed [17:0] product3_ext;
    wire signed [17:0] sum_products;

    reg signed [17:0] result_q;
    reg               result_valid_q;

    wire stage1_ready;
    wire stage2_ready;

    assign a0 = a_vec[7:0];
    assign a1 = a_vec[15:8];
    assign a2 = a_vec[23:16];
    assign a3 = a_vec[31:24];

    assign b0 = b_vec[7:0];
    assign b1 = b_vec[15:8];
    assign b2 = b_vec[23:16];
    assign b3 = b_vec[31:24];

    // Explicit sign extension prevents unsigned promotion during accumulation.
    assign product0_ext = {{2{product0_q[15]}}, product0_q};
    assign product1_ext = {{2{product1_q[15]}}, product1_q};
    assign product2_ext = {{2{product2_q[15]}}, product2_q};
    assign product3_ext = {{2{product3_q[15]}}, product3_q};

    assign sum_products = product0_ext + product1_ext
                        + product2_ext + product3_ext;

    assign stage2_ready = ~result_valid_q | out_ready;
    assign stage1_ready = ~products_valid_q | stage2_ready;

    assign in_ready  = stage1_ready;
    assign out_valid = result_valid_q;
    assign out_data  = result_q;

    always @(posedge clk) begin
        if (!rst_n) begin
            product0_q       <= 16'sd0;
            product1_q       <= 16'sd0;
            product2_q       <= 16'sd0;
            product3_q       <= 16'sd0;
            products_valid_q <= 1'b0;
            result_q         <= 18'sd0;
            result_valid_q   <= 1'b0;
        end else begin
            if (stage2_ready) begin
                result_valid_q <= products_valid_q;
                if (products_valid_q) begin
                    result_q <= sum_products;
                end
            end

            if (stage1_ready) begin
                products_valid_q <= in_valid;
                if (in_valid) begin
                    product0_q <= a0 * b0;
                    product1_q <= a1 * b1;
                    product2_q <= a2 * b2;
                    product3_q <= a3 * b3;
                end
            end
        end
    end

endmodule

`default_nettype wire
