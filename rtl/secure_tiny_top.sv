// Top-level IP yang tidak bergantung pada board.
// Port perintah membawa mode/key/nonce/panjang/tag; port data memakai
// handshake valid/ready; status menyatakan autentikasi dan akhir transaksi.
// Modul ini hanya menghubungkan controller. Wrapper Avalon/HPS atau GPIO
// DE10-Nano adalah lapisan integrasi terpisah dan belum ada di sini.
module secure_tiny_top #(
    parameter int unsigned MAX_DATA_BYTES
) (
    input  logic         clk,
    input  logic         rst_n,
    input  logic         start,
    input  logic         decrypt,
    input  logic [127:0] key,
    input  logic [127:0] nonce,
    input  logic [31:0]  ad_length,
    input  logic [31:0]  data_length,
    input  logic [127:0] received_tag,
    input  logic         ad_valid,
    output logic         ad_ready,
    input  logic [7:0]   ad_data,
    input  logic         data_valid,
    output logic         data_ready,
    input  logic [7:0]   data_in,
    output logic         out_valid,
    input  logic         out_ready,
    output logic [7:0]   out_data,
    output logic         tag_valid,
    input  logic         tag_ready,
    output logic [127:0] tag_out,
    output logic         auth_result_valid,
    output logic         accept,
    output logic         reject,
    output logic         busy,
    output logic         done,
    output logic         command_error
);
    aead_controller #(.MAX_DATA_BYTES(MAX_DATA_BYTES)) controller (
        .clk(clk), .rst_n(rst_n), .start(start), .decrypt(decrypt),
        .key(key), .nonce(nonce), .ad_length(ad_length),
        .data_length(data_length), .received_tag(received_tag),
        .ad_valid(ad_valid), .ad_ready(ad_ready), .ad_data(ad_data),
        .data_valid(data_valid), .data_ready(data_ready), .data_in(data_in),
        .out_valid(out_valid), .out_ready(out_ready), .out_data(out_data),
        .tag_valid(tag_valid), .tag_ready(tag_ready), .tag_out(tag_out),
        .auth_result_valid(auth_result_valid), .accept(accept), .reject(reject),
        .busy(busy), .done(done), .command_error(command_error)
    );
endmodule
