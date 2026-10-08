// Menyimpan hasil autentikasi dan mengendalikan izin plaintext dekripsi.
// decision_valid/tag_match berasal dari verifier; clear memulai transaksi baru.
// Guard ini hanya batas keluaran digital, bukan sensor tamper atau mitigasi
// side-channel. Keputusan bertahan sampai clear atau reset berikutnya.
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
    // Hanya hasil dekripsi yang dicatat. ACCEPT membuka plaintext; REJECT
    // mempertahankan plaintext_allowed rendah (fail-closed).
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
