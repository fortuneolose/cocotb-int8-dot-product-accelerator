`timescale 1ns/1ps

module tb_dot_product_int8_vivado;
    logic               clk = 1'b0;
    logic               rst_n;
    logic               in_valid;
    logic               in_ready;
    logic [31:0]        a_vec;
    logic [31:0]        b_vec;
    logic               out_valid;
    logic               out_ready;
    logic signed [17:0] out_data;

    integer expected [0:31];
    integer write_pointer;
    integer read_pointer;
    logic previous_stalled;
    logic signed [17:0] previous_stalled_data;

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

    always #5 clk = ~clk;

    task automatic send_vector(
        input integer a0,
        input integer a1,
        input integer a2,
        input integer a3,
        input integer b0,
        input integer b1,
        input integer b2,
        input integer b3
    );
        integer golden;
        begin
            golden = (a0 * b0) + (a1 * b1) + (a2 * b2) + (a3 * b3);

            @(negedge clk);
            a_vec    = {a3[7:0], a2[7:0], a1[7:0], a0[7:0]};
            b_vec    = {b3[7:0], b2[7:0], b1[7:0], b0[7:0]};
            in_valid = 1'b1;

            @(posedge clk);
            while (!in_ready) begin
                @(posedge clk);
            end

            expected[write_pointer] = golden;
            write_pointer = write_pointer + 1;

            @(negedge clk);
            in_valid = 1'b0;
        end
    endtask

    // Ordered scoreboard and ready/valid stability check.
    always @(posedge clk) begin
        if (!rst_n) begin
            previous_stalled      <= 1'b0;
            previous_stalled_data <= 18'sd0;
        end else begin
            if (previous_stalled) begin
                if (!out_valid) begin
                    $fatal(1, "out_valid dropped while the output was stalled");
                end
                if ($signed(out_data) !== $signed(previous_stalled_data)) begin
                    $fatal(1, "out_data changed while the output was stalled");
                end
            end

            previous_stalled      <= out_valid && !out_ready;
            previous_stalled_data <= out_data;

            if (out_valid && out_ready) begin
                if (read_pointer >= write_pointer) begin
                    $fatal(1, "Output observed without a matching input");
                end
                if ($signed(out_data) !== expected[read_pointer]) begin
                    $fatal(
                        1,
                        "Mismatch at output %0d: expected %0d, got %0d",
                        read_pointer,
                        expected[read_pointer],
                        $signed(out_data)
                    );
                end
                $display(
                    "%0t: output[%0d] = %0d (PASS)",
                    $time,
                    read_pointer,
                    $signed(out_data)
                );
                read_pointer = read_pointer + 1;
            end
        end
    end

    initial begin
        rst_n                = 1'b0;
        in_valid             = 1'b0;
        out_ready            = 1'b1;
        a_vec                = 32'd0;
        b_vec                = 32'd0;
        write_pointer        = 0;
        read_pointer         = 0;
        previous_stalled     = 1'b0;
        previous_stalled_data = 18'sd0;

        repeat (4) @(posedge clk);
        @(negedge clk);
        rst_n = 1'b1;

        // 1*5 + 2*6 + 3*7 + 4*8 = 70.
        send_vector(1, 2, 3, 4, 5, 6, 7, 8);

        // 0x80808080 is four lanes of -128, not one 32-bit operand.
        // Four copies of (-128 * -128) produce the full-precision result 65536.
        send_vector(-128, -128, -128, -128, -128, -128, -128, -128);

        send_vector(-1, -2, -3, -4, 5, 6, 7, 8);
        send_vector(-128, 127, -1, 1, 127, -128, -1, 1);

        // Fill both elastic stages, then verify stable output and propagated
        // backpressure while the consumer is blocked.
        @(negedge clk);
        out_ready = 1'b0;
        fork
            begin
                send_vector(20, -30, 40, -50, -2, 3, -4, 5);
                send_vector(127, 127, 127, 127, 127, 127, 127, 127);
            end
            begin
                repeat (7) @(negedge clk);
                out_ready = 1'b1;
            end
        join

        send_vector(0, 0, 0, 0, 0, 0, 0, 0);

        repeat (12) @(posedge clk);
        if (read_pointer != write_pointer) begin
            $fatal(
                1,
                "Simulation ended with %0d unchecked result(s)",
                write_pointer - read_pointer
            );
        end

        $display(
            "VIVADO RTL PASS: %0d vectors checked; signed INT8 corner = 65536",
            read_pointer
        );
        $finish;
    end

    initial begin
        #5000;
        $fatal(1, "Simulation timeout");
    end
endmodule
