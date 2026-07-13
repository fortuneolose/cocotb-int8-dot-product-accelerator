`timescale 1ns/1ps

// Cycle-accurate regression between the original parameterized SystemVerilog
// RTL and the conservative Verilog-2001 Vivado translation.
module tb_dot_product_equivalence;
    logic               clk = 1'b0;
    logic               rst_n;
    logic               in_valid;
    logic [31:0]        a_vec;
    logic [31:0]        b_vec;
    logic               out_ready;

    logic               reference_in_ready;
    logic               reference_out_valid;
    logic signed [17:0] reference_out_data;
    logic               vivado_in_ready;
    logic               vivado_out_valid;
    logic signed [17:0] vivado_out_data;

    integer seed;
    integer cycles_checked;

    dot_product_int8 reference_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (reference_in_ready),
        .a_vec     (a_vec),
        .b_vec     (b_vec),
        .out_valid (reference_out_valid),
        .out_ready (out_ready),
        .out_data  (reference_out_data)
    );

    dot_product_int8_vivado vivado_dut (
        .clk       (clk),
        .rst_n     (rst_n),
        .in_valid  (in_valid),
        .in_ready  (vivado_in_ready),
        .a_vec     (a_vec),
        .b_vec     (b_vec),
        .out_valid (vivado_out_valid),
        .out_ready (out_ready),
        .out_data  (vivado_out_data)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        if (rst_n) begin
            cycles_checked = cycles_checked + 1;

            if (reference_in_ready !== vivado_in_ready) begin
                $fatal(1, "in_ready mismatch on cycle %0d", cycles_checked);
            end
            if (reference_out_valid !== vivado_out_valid) begin
                $fatal(1, "out_valid mismatch on cycle %0d", cycles_checked);
            end
            if (reference_out_valid
                && ($signed(reference_out_data) !== $signed(vivado_out_data))) begin
                $fatal(
                    1,
                    "out_data mismatch on cycle %0d: reference=%0d Vivado=%0d",
                    cycles_checked,
                    $signed(reference_out_data),
                    $signed(vivado_out_data)
                );
            end
        end
    end

    initial begin
        seed           = 32'h2026_0713;
        cycles_checked = 0;
        rst_n          = 1'b0;
        in_valid       = 1'b0;
        a_vec          = 32'd0;
        b_vec          = 32'd0;
        out_ready      = 1'b0;

        repeat (4) @(negedge clk);
        rst_n = 1'b1;

        // Directed full-precision signed corner.
        in_valid  = 1'b1;
        out_ready = 1'b1;
        a_vec     = 32'h80808080;
        b_vec     = 32'h80808080;
        @(negedge clk);

        // Random packed INT8 operands, valid gaps, and bursty backpressure.
        repeat (1000) begin
            // Hold a blocked input stable until it is accepted, as required by
            // the ready/valid source contract.
            if (!in_valid || reference_in_ready) begin
                in_valid = (($random(seed) & 32'h7fffffff) % 100) < 82;
                a_vec    = $random(seed);
                b_vec    = $random(seed);
            end
            out_ready = (($random(seed) & 32'h7fffffff) % 100) < 67;
            @(negedge clk);
        end

        // Drain both pipelines before declaring equivalence.
        in_valid  = 1'b0;
        out_ready = 1'b1;
        repeat (8) @(negedge clk);

        $display(
            "VIVADO EQUIVALENCE PASS: %0d cycles matched the original RTL",
            cycles_checked
        );
        $finish;
    end

    initial begin
        #20000;
        $fatal(1, "Equivalence simulation timeout");
    end
endmodule
