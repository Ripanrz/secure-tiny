`timescale 1ns/1ps

module tb_counter;
    localparam int unsigned WIDTH = 4;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic enable = 1'b0;
    logic [WIDTH-1:0] count;

    counter #(.WIDTH(WIDTH)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .enable(enable),
        .count(count)
    );

    always #5 clk = ~clk;

    task automatic expect_count(input logic [WIDTH-1:0] expected);
        if (count !== expected) begin
            $error("count mismatch: got %0d expected %0d", count, expected);
            $fatal(1);
        end
    endtask

    initial begin
        $dumpfile("sim/counter.vcd");
        $dumpvars(0, tb_counter);

        // Synchronous reset is sampled on a rising clock edge.
        @(posedge clk);
        #1;
        expect_count(4'd0);

        rst_n = 1'b1;
        enable = 1'b1;
        @(posedge clk);
        #1;
        expect_count(4'd1);

        enable = 1'b0;
        @(posedge clk);
        #1;
        expect_count(4'd1);

        enable = 1'b1;
        repeat (14) begin
            @(posedge clk);
            #1;
        end
        expect_count(4'd15);

        @(posedge clk);
        #1;
        expect_count(4'd0);

        rst_n = 1'b0;
        @(posedge clk);
        #1;
        expect_count(4'd0);

        $display("PASS: counter reset, enable, hold, and wrap checks");
        $finish;
    end
endmodule
