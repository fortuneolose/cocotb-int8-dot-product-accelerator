`timescale 1ns/1ps

// Two-stage, backpressure-aware signed dot-product pipeline.
//
// Input and output transfers occur when valid and ready are both high on a
// rising clock edge. With no stalls, each accepted input appears at the output
// two cycles later and the unit sustains one vector per cycle.
module dot_product_int8 #(
    parameter integer DATA_WIDTH = 8,
    parameter integer LANES      = 4,
    parameter integer ACC_WIDTH  = (2 * DATA_WIDTH) + $clog2(LANES)
) (
    input  logic                         clk,
    input  logic                         rst_n,

    input  logic                         in_valid,
    output logic                         in_ready,
    input  logic [LANES*DATA_WIDTH-1:0]  a_vec,
    input  logic [LANES*DATA_WIDTH-1:0]  b_vec,

    output logic                         out_valid,
    input  logic                         out_ready,
    output logic signed [ACC_WIDTH-1:0]  out_data
);

    localparam integer PROD_WIDTH = 2 * DATA_WIDTH;

    logic signed [PROD_WIDTH-1:0] products [0:LANES-1];
    logic signed [ACC_WIDTH-1:0]  sum_products;
    logic signed [ACC_WIDTH-1:0]  result_q;
    logic                          products_valid_q;
    logic                          result_valid_q;
    logic                          stage1_ready;
    logic                          stage2_ready;

    assign stage2_ready = ~result_valid_q | out_ready;
    assign stage1_ready = ~products_valid_q | stage2_ready;
    assign in_ready     = stage1_ready;
    assign out_valid    = result_valid_q;
    assign out_data     = result_q;

    always_comb begin
        sum_products = '0;
        for (integer lane = 0; lane < LANES; lane = lane + 1) begin
            sum_products = sum_products
                + {{(ACC_WIDTH-PROD_WIDTH){products[lane][PROD_WIDTH-1]}},
                   products[lane]};
        end
    end

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            products_valid_q <= 1'b0;
            result_valid_q   <= 1'b0;
            result_q         <= '0;
            for (integer lane = 0; lane < LANES; lane = lane + 1) begin
                products[lane] <= '0;
            end
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
                    for (integer lane = 0; lane < LANES; lane = lane + 1) begin
                        products[lane] <=
                            $signed(a_vec[lane*DATA_WIDTH +: DATA_WIDTH])
                            * $signed(b_vec[lane*DATA_WIDTH +: DATA_WIDTH]);
                    end
                end
            end
        end
    end

    // Protocol assertion: a blocked output must remain valid and stable.
    logic                         stalled_q;
    logic signed [ACC_WIDTH-1:0] stalled_data_q;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            stalled_q      <= 1'b0;
            stalled_data_q <= '0;
        end else begin
            if (stalled_q) begin
                assert (out_valid)
                    else $error("out_valid dropped while the output was stalled");
                assert (out_data == stalled_data_q)
                    else $error("out_data changed while the output was stalled");
            end
            stalled_q      <= out_valid && !out_ready;
            stalled_data_q <= out_data;
        end
    end

    initial begin
        if (LANES < 1) begin
            $fatal(1, "LANES must be at least one");
        end
        if (ACC_WIDTH < PROD_WIDTH + $clog2(LANES)) begin
            $fatal(1, "ACC_WIDTH is too narrow for a full-precision result");
        end
    end

`ifdef DUMP_WAVES
    initial begin
        $dumpfile("artifacts/waves/dot_product.vcd");
        $dumpvars(0, dot_product_int8);
    end
`endif

endmodule
