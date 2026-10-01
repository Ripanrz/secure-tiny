`timescale 1ns/1ps

module tb_tag_auth_modules;
    logic clk = 1'b0;
    logic rst_n = 1'b0;

    logic tag_load = 1'b0;
    logic [127:0] tag_in = '0;
    logic tag_valid;
    logic tag_ready = 1'b0;
    logic [127:0] tag_out;

    logic verify_start = 1'b0;
    logic [127:0] calculated_tag = '0;
    logic [127:0] received_tag = '0;
    logic verify_busy;
    logic verify_done;
    logic tag_match;
    logic tag_mismatch;

    logic guard_clear = 1'b0;
    logic decrypt = 1'b0;
    logic decision_valid = 1'b0;
    logic decision_match = 1'b0;
    logic auth_result_valid;
    logic accept;
    logic reject;
    logic plaintext_allowed;

    tag_generator generator (
        .clk(clk), .rst_n(rst_n), .load(tag_load), .tag_in(tag_in),
        .tag_valid(tag_valid), .tag_ready(tag_ready), .tag_out(tag_out)
    );

    tag_verifier verifier (
        .clk(clk), .rst_n(rst_n), .start(verify_start),
        .calculated_tag(calculated_tag), .received_tag(received_tag),
        .busy(verify_busy), .done(verify_done), .match(tag_match),
        .mismatch(tag_mismatch)
    );

    authentication_guard guard_unit (
        .clk(clk), .rst_n(rst_n), .clear(guard_clear), .decrypt(decrypt),
        .decision_valid(decision_valid), .tag_match(decision_match),
        .auth_result_valid(auth_result_valid), .accept(accept), .reject(reject),
        .plaintext_allowed(plaintext_allowed)
    );

    always #5 clk = ~clk;

    task automatic tick;
        begin
            @(posedge clk);
            #1;
        end
    endtask

    initial begin
        $dumpfile("sim/tag_auth_modules.vcd");
        $dumpvars(0, tb_tag_auth_modules);

        tick();
        if (tag_valid || tag_out !== 128'b0 || verify_busy || verify_done ||
            tag_match || tag_mismatch || auth_result_valid || accept || reject || plaintext_allowed)
            $fatal(1, "synchronous reset did not clear tag/authentication modules");
        rst_n = 1'b1;

        // The tag generator must hold its value through backpressure.
        @(negedge clk);
        tag_in = 128'h00112233445566778899aabbccddeeff;
        tag_load = 1'b1;
        tick();
        tag_load = 1'b0;
        if (!tag_valid || tag_out !== 128'h00112233445566778899aabbccddeeff)
            $fatal(1, "tag generator failed to capture a tag");
        @(negedge clk);
        tag_in = 128'hffeeddccbbaa99887766554433221100;
        tag_load = 1'b1;
        tick();
        tag_load = 1'b0;
        if (!tag_valid || tag_out !== 128'h00112233445566778899aabbccddeeff)
            $fatal(1, "tag generator changed its output while stalled");

        // A simultaneous consume and load replaces the tag without a gap.
        @(negedge clk);
        tag_ready = 1'b1;
        tag_load = 1'b1;
        tick();
        tag_ready = 1'b0;
        tag_load = 1'b0;
        if (!tag_valid || tag_out !== 128'hffeeddccbbaa99887766554433221100)
            $fatal(1, "tag generator did not replace a consumed tag");
        @(negedge clk);
        tag_ready = 1'b1;
        tick();
        tag_ready = 1'b0;
        if (tag_valid)
            $fatal(1, "tag generator did not clear valid after handshake");

        // The verifier must compare its latched inputs, not changing inputs.
        @(negedge clk);
        calculated_tag = 128'h112233445566778899aabbccddeeff00;
        received_tag = calculated_tag;
        verify_start = 1'b1;
        tick();
        verify_start = 1'b0;
        if (!verify_busy || verify_done || tag_match || tag_mismatch)
            $fatal(1, "tag verifier did not enter its compare phase");
        calculated_tag = '0;
        received_tag = '1;
        tick();
        if (verify_busy || !verify_done || !tag_match || tag_mismatch)
            $fatal(1, "tag verifier did not report a match from latched values");
        tick();
        if (verify_done || tag_match || tag_mismatch)
            $fatal(1, "tag verifier result was not a one-cycle pulse");

        // A one-bit difference anywhere in the full tag must reject.
        @(negedge clk);
        calculated_tag = 128'b0;
        received_tag = 128'h80000000000000000000000000000000;
        verify_start = 1'b1;
        tick();
        verify_start = 1'b0;
        tick();
        if (!verify_done || tag_match || !tag_mismatch)
            $fatal(1, "tag verifier failed to detect a high-order tag mismatch");
        tick();

        // The guard ignores encryption decisions and never opens early.
        @(negedge clk);
        decrypt = 1'b1;
        decision_match = 1'b1;
        decision_valid = 1'b0;
        tick();
        if (auth_result_valid || accept || reject || plaintext_allowed)
            $fatal(1, "guard exposed plaintext before a valid decision");
        @(negedge clk);
        decrypt = 1'b0;
        decision_valid = 1'b1;
        tick();
        if (auth_result_valid || accept || reject || plaintext_allowed)
            $fatal(1, "guard incorrectly processed an encryption decision");

        // A valid decrypt decision releases plaintext and remains sticky.
        @(negedge clk);
        decrypt = 1'b1;
        decision_match = 1'b1;
        tick();
        decision_valid = 1'b0;
        if (!auth_result_valid || !accept || reject || !plaintext_allowed)
            $fatal(1, "guard failed to accept authenticated plaintext");
        tick();
        if (!auth_result_valid || !accept || reject || !plaintext_allowed)
            $fatal(1, "guard did not hold the accepted decision");

        // Clear the prior decision, then check invalid authentication.
        @(negedge clk);
        guard_clear = 1'b1;
        tick();
        guard_clear = 1'b0;
        if (auth_result_valid || accept || reject || plaintext_allowed)
            $fatal(1, "guard clear did not revoke the prior decision");
        @(negedge clk);
        decision_match = 1'b0;
        decision_valid = 1'b1;
        tick();
        decision_valid = 1'b0;
        if (!auth_result_valid || accept || !reject || plaintext_allowed)
            $fatal(1, "guard failed to reject unauthenticated plaintext");

        @(negedge clk);
        rst_n = 1'b0;
        tick();
        if (auth_result_valid || accept || reject || plaintext_allowed ||
            tag_valid || verify_busy || verify_done)
            $fatal(1, "reset did not revoke visible module state");

        $display("PASS: tag generator handshake, full-width tag verifier, and authentication guard checks");
        $finish;
    end
endmodule
