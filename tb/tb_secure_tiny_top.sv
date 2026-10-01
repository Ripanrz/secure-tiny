`timescale 1ns/1ps

module tb_secure_tiny_top;
    localparam int unsigned MAX_DATA_BYTES = 16;
    localparam logic [127:0] FULL_BLOCK_CIPHERTEXT =
        128'he37452ce8ea4d07cee4aa4d289d270e7;
    // Ascon-C v1.3.0 KAT Count 35: PT=00, AD=00, CT=25 || tag.
    localparam logic [127:0] AD_KAT_TAG =
        128'h30222973f620badc1785acd40e704beb;
    localparam logic [7:0] AD_KAT_CIPHERTEXT = 8'h25;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic decrypt = 1'b0;
    logic [127:0] key = 128'h0f0e0d0c0b0a09080706050403020100;
    logic [127:0] nonce = 128'h0f0e0d0c0b0a09080706050403020100;
    logic [31:0] ad_length = 0;
    logic [31:0] data_length = 1;
    logic [127:0] received_tag = 128'h47f103dde1f838d4b551fc41f5f1589f;
    logic ad_valid = 1'b0;
    logic ad_ready;
    logic [7:0] ad_data = 0;
    logic data_valid = 1'b0;
    logic data_ready;
    logic [7:0] data_in = 0;
    logic out_valid;
    logic out_ready = 1'b0;
    logic [7:0] out_data;
    logic tag_valid;
    logic tag_ready = 1'b0;
    logic [127:0] tag_out;
    logic auth_result_valid;
    logic accept;
    logic reject;
    logic busy;
    logic done;
    logic command_error;
    integer cycle_count = 0;
    integer transaction_start_cycle = 0;

    secure_tiny_top #(.MAX_DATA_BYTES(MAX_DATA_BYTES)) dut (.*);
    always #5 clk = ~clk;
    always @(posedge clk) cycle_count = cycle_count + 1;

    task automatic launch(input logic decrypt_mode);
        begin
            @(negedge clk);
            decrypt = decrypt_mode;
            start = 1'b1;
            @(posedge clk);
            #1;
            start = 1'b0;
            if (!busy)
                $fatal(1, "top did not accept a valid command");
            transaction_start_cycle = cycle_count;
        end
    endtask

    task automatic send_one_byte(input logic [7:0] value);
        begin
            @(negedge clk);
            data_in = value;
            data_valid = 1'b1;
            do @(posedge clk); while (!data_ready);
            @(negedge clk);
            data_valid = 1'b0;
        end
    endtask

    task automatic send_one_ad_byte(input logic [7:0] value);
        begin
            @(negedge clk);
            ad_data = value;
            ad_valid = 1'b1;
            do @(posedge clk); while (!ad_ready);
            @(negedge clk);
            ad_valid = 1'b0;
        end
    endtask

    task automatic send_full_message_block;
        integer lane;
        begin
            for (lane = 0; lane < 16; lane = lane + 1)
                send_one_byte(lane[7:0]);
        end
    endtask

    task automatic wait_for_done;
        integer cycles;
        begin
            cycles = 0;
            while (!done && cycles < 500) begin
                @(posedge clk);
                #1;
                cycles = cycles + 1;
            end
            if (!done)
                $fatal(1, "top did not complete before timeout");
            if (busy)
                $fatal(1, "top busy remained high at done");
            $display("MEASURE: top transaction latency %0d cycles (start accepted to done)",
                     cycle_count - transaction_start_cycle);
        end
    endtask

    task automatic abort_with_reset;
        begin
            @(negedge clk);
            rst_n = 1'b0;
            start = 1'b0;
            ad_valid = 1'b0;
            data_valid = 1'b0;
            out_ready = 1'b0;
            tag_ready = 1'b0;
            @(posedge clk);
            #1;
            if (busy || out_valid || tag_valid || accept || reject ||
                auth_result_valid || command_error || done)
                $fatal(1, "reset did not clear active operation and visible status");
            @(negedge clk);
            rst_n = 1'b1;
        end
    endtask

    initial begin
        $dumpfile("sim/secure_tiny_top.vcd");
        $dumpvars(0, tb_secure_tiny_top);
        @(posedge clk);
        #1;
        rst_n = 1'b1;

        // Encrypt KAT Count 34: plaintext 00 -> ciphertext E7 plus tag.
        launch(1'b0);
        send_one_byte(8'h00);
        wait(out_valid);
        #1;
        if (out_data !== 8'he7)
            $fatal(1, "encrypted output byte mismatch: %02h", out_data);
        repeat (3) begin
            @(posedge clk);
            #1;
            if (!out_valid || out_data !== 8'he7)
                $fatal(1, "output changed while downstream was stalled");
        end
        @(negedge clk);
        out_ready = 1'b1;
        @(posedge clk);
        #1;
        out_ready = 1'b0;
        wait(tag_valid);
        #1;
        if (tag_out !== 128'h47f103dde1f838d4b551fc41f5f1589f)
            $fatal(1, "top tag mismatch: %032h", tag_out);
        repeat (2) begin
            @(posedge clk);
            #1;
            if (!tag_valid)
                $fatal(1, "tag_valid dropped under backpressure");
        end
        @(negedge clk);
        tag_ready = 1'b1;
        @(posedge clk);
        #1;
        tag_ready = 1'b0;
        wait_for_done();

        // KAT Count 2 exercises a padded AD-only operation.
        ad_length = 1;
        data_length = 0;
        launch(1'b0);
        send_one_ad_byte(8'h00);
        wait(tag_valid);
        if (tag_out !== 128'h8585bb79a915772821033a919db73a10)
            $fatal(1, "AD-only tag mismatch: %032h", tag_out);
        @(negedge clk);
        tag_ready = 1'b1;
        @(posedge clk);
        #1;
        tag_ready = 1'b0;
        wait_for_done();

        // KAT Count 529 exercises the external byte stream across one full block.
        ad_length = 0;
        data_length = 16;
        launch(1'b0);
        send_full_message_block();
        wait(out_valid);
        #1;
        out_ready = 1'b1;
        for (integer lane = 0; lane < 16; lane = lane + 1) begin
            while (!out_valid) @(negedge clk);
            if (out_data !== FULL_BLOCK_CIPHERTEXT[(lane*8) +: 8])
                $fatal(1, "full-block output mismatch at byte %0d: got %02h count %0d valid %b core %032h", lane, out_data,
                       dut.controller.output_count, out_valid, dut.controller.core_data_out[127:0]);
            @(posedge clk);
            #1;
        end
        out_ready = 1'b0;
        wait(tag_valid);
        if (tag_out !== 128'h1184a7f5725974f256e5c48f9a1f72ea)
            $fatal(1, "full-block tag mismatch: %032h", tag_out);
        @(negedge clk);
        tag_ready = 1'b1;
        @(posedge clk);
        #1;
        tag_ready = 1'b0;
        wait_for_done();

        // Valid decryption must expose plaintext only after ACCEPT.
        data_length = 1;
        received_tag = 128'h47f103dde1f838d4b551fc41f5f1589f;
        out_ready = 1'b0;
        launch(1'b1);
        send_one_byte(8'he7);
        while (!auth_result_valid) begin
            @(posedge clk);
            #1;
            if (out_valid && !auth_result_valid)
                $fatal(1, "plaintext appeared before authentication completed");
        end
        if (!accept || reject || !out_valid || out_data !== 8'h00)
            $fatal(1, "valid tag did not release plaintext after ACCEPT");
        @(negedge clk);
        out_ready = 1'b1;
        @(posedge clk);
        #1;
        out_ready = 1'b0;
        wait_for_done();

        // KAT Count 35 is the valid control case for modified-AD rejection.
        ad_length = 1;
        data_length = 1;
        received_tag = AD_KAT_TAG;
        launch(1'b1);
        send_one_ad_byte(8'h00);
        send_one_byte(AD_KAT_CIPHERTEXT);
        while (!auth_result_valid) begin
            @(posedge clk);
            #1;
            if (out_valid && !auth_result_valid)
                $fatal(1, "plaintext appeared before AD KAT authentication");
        end
        if (!accept || reject || !out_valid || out_data !== 8'h00)
            $fatal(1, "valid AD KAT was not accepted with expected plaintext");
        @(negedge clk);
        out_ready = 1'b1;
        @(posedge clk);
        #1;
        out_ready = 1'b0;
        wait_for_done();

        // Change only AD while retaining the KAT ciphertext and tag.
        launch(1'b1);
        send_one_ad_byte(8'h01);
        send_one_byte(AD_KAT_CIPHERTEXT);
        wait_for_done();
        if (!auth_result_valid || accept || !reject || out_valid)
            $fatal(1, "modified AD was not rejected without plaintext");
        ad_length = 0;

        // A modified tag must reject and produce no plaintext transfer.
        received_tag = 128'h47f103dde1f838d4b551fc41f5f1589e;
        launch(1'b1);
        send_one_byte(8'he7);
        wait_for_done();
        if (!auth_result_valid || accept || !reject || out_valid)
            $fatal(1, "modified tag was not rejected without plaintext");

        // A modified ciphertext with the original tag is also rejected.
        received_tag = 128'h47f103dde1f838d4b551fc41f5f1589f;
        launch(1'b1);
        send_one_byte(8'hee);
        wait_for_done();
        if (!auth_result_valid || accept || !reject || out_valid)
            $fatal(1, "modified ciphertext was not rejected without plaintext");

        // Start while busy is ignored; reset then aborts the waiting command.
        launch(1'b0);
        @(negedge clk);
        start = 1'b1;
        @(posedge clk);
        #1;
        start = 1'b0;
        if (!busy || done || command_error)
            $fatal(1, "start while busy changed the active transaction");
        abort_with_reset();

        // Reset also aborts each long-running or output-wait phase.
        data_length = 0;
        launch(1'b0);
        wait(dut.controller.core_busy);
        abort_with_reset();

        launch(1'b1);
        wait(dut.controller.verifier_busy);
        abort_with_reset();

        data_length = 1;
        launch(1'b0);
        send_one_byte(8'h00);
        wait(out_valid);
        abort_with_reset();

        data_length = 0;
        launch(1'b0);
        wait(tag_valid);
        abort_with_reset();

        // Oversized commands fail before accepting any stream data.
        data_length = 1;
        @(negedge clk);
        ad_length = MAX_DATA_BYTES + 1;
        start = 1'b1;
        @(posedge clk);
        #1;
        start = 1'b0;
        if (!command_error || !done || busy || auth_result_valid)
            $fatal(1, "oversized command did not report command_error");

        // Oversized message length is rejected independently of AD length.
        @(posedge clk);
        #1;
        if (command_error || done)
            $fatal(1, "command_error and done were not one-cycle pulses");
        @(negedge clk);
        ad_length = 0;
        data_length = MAX_DATA_BYTES + 1;
        start = 1'b1;
        @(posedge clk);
        #1;
        start = 1'b0;
        if (!command_error || !done || busy || ad_ready || data_ready ||
            auth_result_valid || accept || reject)
            $fatal(1, "oversized data command was not rejected before stream acceptance");

        $display("PASS: top-level KAT, handshake stalls, auth guard, reject, and AD/data length checks");
        $finish;
    end
endmodule
