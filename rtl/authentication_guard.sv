// Stores the authentication decision and gates decryption plaintext release.
module authentication_guard (
    input  logic clk,
    input  logic rst_n,
    input  logic clear,
    input  logic decrypt,
    input  logic decision_valid,
    input  logic tag_match,
    output logic auth_result_valid,
    output logic accept,
    output logic reject,
    output logic plaintext_allowed
);
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            auth_result_valid <= 1'b0;
            accept <= 1'b0;
            reject <= 1'b0;
            plaintext_allowed <= 1'b0;
        end else if (clear) begin
            auth_result_valid <= 1'b0;
            accept <= 1'b0;
            reject <= 1'b0;
            plaintext_allowed <= 1'b0;
        end else if (decision_valid && decrypt) begin
            auth_result_valid <= 1'b1;
            accept <= tag_match;
            reject <= !tag_match;
            plaintext_allowed <= tag_match;
        end
    end
endmodule
