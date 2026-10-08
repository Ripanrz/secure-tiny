`timescale 1ns/1ps

// Testbench unit permutasi. State contoh yang tetap diuji untuk p8/p12,
// sementara jumlah ronde 0 dan 17 harus ditolak. Juga memeriksa busy/done/error.
module tb_ascon_permutation;
    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic [4:0] rounds = 5'd0;
    logic [319:0] state_in = {
        64'h0123456789abcdef, 64'hfedcba9876543210,
        64'h0f1e2d3c4b5a6978, 64'h8877665544332211,
        64'h1020304050607080
    };
    logic busy;
    logic done;
    logic error;
    logic [319:0] state_out;

    ascon_permutation dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .rounds(rounds),
        .state_in(state_in),
        .busy(busy),
        .done(done),
        .error(error),
        .state_out(state_out)
    );

    always #5 clk = ~clk;

    task automatic check_round_count(input logic [4:0] requested_rounds);
        integer cycle;
        begin
            // Jalankan satu permintaan dan pastikan selesai tepat setelah
            // jumlah ronde; hasil p8/p12 dicocokkan dengan model independen.
            @(negedge clk);
            rounds = requested_rounds;
            start = 1'b1;
            @(posedge clk);
            #1;
            if (requested_rounds == 0 || requested_rounds > 16) begin
                if (!done || !error || busy)
                    $fatal(1, "invalid round count was not rejected");
            end else begin
                if (!busy || done || error)
                    $fatal(1, "valid request did not enter busy state");
                @(negedge clk);
                start = 1'b0;
                for (cycle = 1; cycle < requested_rounds; cycle = cycle + 1) begin
                    @(posedge clk);
                    #1;
                    if (!busy || done || error)
                        $fatal(1, "request completed before all rounds ran");
                end
                @(posedge clk);
                #1;
                if (busy || !done || error)
                    $fatal(1, "request did not complete after requested rounds");
                if (requested_rounds == 8 && state_out !== {
                    64'h7eb8a7a7b88fed54, 64'h4ee95e2d357c7d95,
                    64'h04d63c229e8552a9, 64'h46c0a63dc9ed3806,
                    64'h1b5096816b9abec5
                })
                    $fatal(1, "p[8] result differs from the independent model");
                if (requested_rounds == 12 && state_out !== {
                    64'h1ab762f9981b8474, 64'h76c9d1406c5af9cf,
                    64'h263ff543e83f8b9d, 64'haef5b63dcf6a9d39,
                    64'hf78cce93a77b5f09
                })
                    $fatal(1, "p[12] result differs from the independent model");
                @(posedge clk);
                #1;
                if (done || error)
                    $fatal(1, "done/error must be one-cycle pulses");
            end
            @(negedge clk);
            start = 1'b0;
        end
    endtask

    initial begin
        $dumpfile("sim/ascon_permutation.vcd");
        $dumpvars(0, tb_ascon_permutation);

        @(posedge clk);
        #1;
        if (busy || done || error)
            $fatal(1, "reset state is not idle");

        @(negedge clk);
        rst_n = 1'b1;

        check_round_count(5'd8);
        check_round_count(5'd12);
        check_round_count(5'd0);
        check_round_count(5'd17);

        $display("PASS: p[8]/p[12] state checks and permutation control checks");
        $finish;
    end
endmodule
