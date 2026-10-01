// Compares all tag bits and reports the result as a one-cycle pulse.
module tag_verifier (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic [127:0] calculated_tag,
    input  logic [127:0] received_tag,
    output logic         busy,
    output logic         done,
    output logic         match,
    output logic         mismatch
);
    logic [127:0] calculated_latched;
    logic [127:0] received_latched;
    logic compare_pending;

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            calculated_latched <= '0;
            received_latched <= '0;
            compare_pending <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            match <= 1'b0;
            mismatch <= 1'b0;
        end else begin
            done <= 1'b0;
            match <= 1'b0;
            mismatch <= 1'b0;

            if (start && !busy) begin
                calculated_latched <= calculated_tag;
                received_latched <= received_tag;
                compare_pending <= 1'b1;
                busy <= 1'b1;
            end else if (compare_pending) begin
                compare_pending <= 1'b0;
                busy <= 1'b0;
                done <= 1'b1;
                if ((calculated_latched ^ received_latched) == 128'b0)
                    match <= 1'b1;
                else
                    mismatch <= 1'b1;
            end
        end
    end
endmodule
