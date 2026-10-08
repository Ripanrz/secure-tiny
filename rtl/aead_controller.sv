// Pengendali satu transaksi AEAD pada satu waktu.
// Masukan: perintah/key/nonce/tag dan stream byte AD serta pesan.
// Keluaran: ready/valid, tag/status, busy/done/error.
// Urutan: terima AD -> data -> jalankan core -> verifikasi saat dekripsi ->
// kirim hasil. Buffer dibatasi MAX_DATA_BYTES; plaintext ditahan sampai tag
// cocok agar tidak terlihat melalui port lebih awal.
module aead_controller #(
    parameter int unsigned MAX_DATA_BYTES
) (
    input  logic                            clk,
    input  logic                            rst_n,
    input  logic                            start,
    input  logic                            decrypt,
    input  logic [127:0]                    key,
    input  logic [127:0]                    nonce,
    input  logic [31:0]                     ad_length,
    input  logic [31:0]                     data_length,
    input  logic [127:0]                    received_tag,
    input  logic                            ad_valid,
    output logic                            ad_ready,
    input  logic [7:0]                      ad_data,
    input  logic                            data_valid,
    output logic                            data_ready,
    input  logic [7:0]                      data_in,
    output logic                            out_valid,
    input  logic                            out_ready,
    output logic [7:0]                      out_data,
    output logic                            tag_valid,
    input  logic                            tag_ready,
    output logic [127:0]                    tag_out,
    output logic                            auth_result_valid,
    output logic                            accept,
    output logic                            reject,
    output logic                            busy,
    output logic                            done,
    output logic                            command_error
);

    localparam logic [3:0] IDLE = 4'd0;
    localparam logic [3:0] RECEIVE_AD = 4'd1;
    localparam logic [3:0] RECEIVE_DATA = 4'd2;
    localparam logic [3:0] CORE_LAUNCH = 4'd3;
    localparam logic [3:0] CORE_WAIT = 4'd4;
    localparam logic [3:0] VERIFY_LAUNCH = 4'd5;
    localparam logic [3:0] VERIFY_WAIT = 4'd6;
    localparam logic [3:0] SEND_DATA = 4'd7;
    localparam logic [3:0] SEND_TAG = 4'd8;
    localparam logic [3:0] REJECT_DONE = 4'd9;

    // phase menyimpan langkah transaksi; counter menghitung byte yang sudah
    // berjabat tangan. Byte pertama buffer packed berada pada lane terendah.
    logic [3:0] phase;
    logic decrypt_reg;
    logic [127:0] key_reg;
    logic [127:0] nonce_reg;
    logic [127:0] received_tag_reg;
    logic [31:0] ad_length_reg;
    logic [31:0] data_length_reg;
    logic [31:0] ad_count;
    logic [31:0] data_count;
    logic [31:0] output_count;
    logic [MAX_DATA_BYTES*8-1:0] ad_buffer;
    logic [MAX_DATA_BYTES*8-1:0] data_buffer;
    logic [MAX_DATA_BYTES*8-1:0] core_data_out;
    logic [127:0] core_tag_out;
    logic core_start;
    logic core_busy;
    logic core_done;
    logic core_error;

    logic tag_load;
    logic verifier_start;
    logic verifier_busy;
    logic verifier_done;
    logic verifier_match;
    logic verifier_mismatch;
    logic guard_clear;
    logic plaintext_allowed;
    // Ready hanya aktif pada fase/panjang yang sesuai. Transfer terjadi saat
    // valid dan ready sama-sama tinggi pada tepi clock.
    assign ad_ready = (phase == RECEIVE_AD) && (ad_count < ad_length_reg);
    assign data_ready = (phase == RECEIVE_DATA) && (data_count < data_length_reg);
    // Guard menjadi syarat tambahan bagi plaintext dekripsi. Ketika tag tidak
    // cocok, out_valid tetap nol sehingga tidak ada transfer plaintext.
    assign out_valid = (phase == SEND_DATA) &&
                       (!decrypt_reg || plaintext_allowed) &&
                       (output_count < data_length_reg);
    assign guard_clear = (phase == IDLE) && start;

    function automatic logic [7:0] select_output_byte(
        input logic [MAX_DATA_BYTES*8-1:0] byte_buffer,
        input logic [31:0] byte_number
    );
        integer lane;
        begin
            // Pilih lane ke-n dari buffer packed untuk stream keluaran 8-bit.
            select_output_byte = 8'b0;
            for (lane = 0; lane < MAX_DATA_BYTES; lane = lane + 1) begin
                if (byte_number == lane)
                    select_output_byte = byte_buffer[(lane*8) +: 8];
            end
        end
    endfunction

    assign out_data = out_valid ? select_output_byte(core_data_out, output_count) : 8'b0;

    ascon_core #(.MAX_DATA_BYTES(MAX_DATA_BYTES)) core (
        .clk(clk), .rst_n(rst_n), .start(core_start), .decrypt(decrypt_reg),
        .key(key_reg), .nonce(nonce_reg), .ad_length(ad_length_reg),
        .data_length(data_length_reg), .ad_data(ad_buffer), .data_in(data_buffer),
        .busy(core_busy), .done(core_done), .command_error(core_error),
        .data_out(core_data_out), .tag_out(core_tag_out)
    );

    tag_generator tag_hold (
        .clk(clk), .rst_n(rst_n), .load(tag_load), .tag_in(core_tag_out),
        .tag_valid(tag_valid), .tag_ready(tag_ready), .tag_out(tag_out)
    );

    tag_verifier verifier (
        .clk(clk), .rst_n(rst_n), .start(verifier_start),
        .calculated_tag(core_tag_out), .received_tag(received_tag_reg),
        .busy(verifier_busy), .done(verifier_done), .match(verifier_match),
        .mismatch(verifier_mismatch)
    );

    authentication_guard guard_block (
        .clk(clk), .rst_n(rst_n), .clear(guard_clear), .decrypt(decrypt_reg),
        .decision_valid(verifier_done), .tag_match(verifier_match),
        .auth_result_valid(auth_result_valid), .accept(accept), .reject(reject),
        .plaintext_allowed(plaintext_allowed)
    );

    // FSM mengunci perintah saat idle, mengumpulkan input, lalu menahan hasil
    // sampai konsumen siap. Reset membatalkan transaksi dan statusnya.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            phase <= IDLE;
            decrypt_reg <= 1'b0;
            key_reg <= '0;
            nonce_reg <= '0;
            received_tag_reg <= '0;
            ad_length_reg <= '0;
            data_length_reg <= '0;
            ad_count <= '0;
            data_count <= '0;
            output_count <= '0;
            ad_buffer <= '0;
            data_buffer <= '0;
            core_start <= 1'b0;
            tag_load <= 1'b0;
            verifier_start <= 1'b0;
            busy <= 1'b0;
            done <= 1'b0;
            command_error <= 1'b0;
        end else begin
            core_start <= 1'b0;
            tag_load <= 1'b0;
            verifier_start <= 1'b0;
            done <= 1'b0;
            command_error <= 1'b0;

            case (phase)
                IDLE: begin
                    busy <= 1'b0;
                    if (start) begin
                        if ((ad_length > MAX_DATA_BYTES) || (data_length > MAX_DATA_BYTES)) begin
                            command_error <= 1'b1;
                            done <= 1'b1;
                        end else begin
                            decrypt_reg <= decrypt;
                            key_reg <= key;
                            nonce_reg <= nonce;
                            received_tag_reg <= received_tag;
                            ad_length_reg <= ad_length;
                            data_length_reg <= data_length;
                            ad_count <= '0;
                            data_count <= '0;
                            output_count <= '0;
                            busy <= 1'b1;
                            if (ad_length != 0)
                                phase <= RECEIVE_AD;
                            else if (data_length != 0)
                                phase <= RECEIVE_DATA;
                            else
                                phase <= CORE_LAUNCH;
                        end
                    end
                end

                // Simpan AD hanya pada handshake; pesan menunggu sampai
                // seluruh AD dengan panjang terdeklarasi terkumpul.
                RECEIVE_AD: begin
                    if (ad_valid && ad_ready) begin
                        ad_buffer[(ad_count*8) +: 8] <= ad_data;
                        ad_count <= ad_count + 32'd1;
                        if (ad_count + 32'd1 == ad_length_reg) begin
                            if (data_length_reg != 0)
                                phase <= RECEIVE_DATA;
                            else
                                phase <= CORE_LAUNCH;
                        end
                    end
                end

                RECEIVE_DATA: begin
                    if (data_valid && data_ready) begin
                        data_buffer[(data_count*8) +: 8] <= data_in;
                        data_count <= data_count + 32'd1;
                        if (data_count + 32'd1 == data_length_reg)
                            phase <= CORE_LAUNCH;
                    end
                end

                CORE_LAUNCH: begin
                    core_start <= 1'b1;
                    phase <= CORE_WAIT;
                end

                // Setelah core selesai, enkripsi menuju output; dekripsi harus
                // menunggu verifier sebelum plaintext bisa dikeluarkan.
                CORE_WAIT: begin
                    if (core_done) begin
                        if (core_error) begin
                            command_error <= 1'b1;
                            done <= 1'b1;
                            busy <= 1'b0;
                            phase <= IDLE;
                        end else begin
                            output_count <= '0;
                            if (decrypt_reg) begin
                                verifier_start <= 1'b1;
                                phase <= VERIFY_WAIT;
                            end else begin
                                phase <= SEND_DATA;
                            end
                        end
                    end
                end

                // Match membuka stream. Mismatch berakhir tanpa masuk SEND_DATA.
                VERIFY_WAIT: begin
                    if (verifier_done) begin
                        if (verifier_match) begin
                            output_count <= '0;
                            phase <= SEND_DATA;
                        end else begin
                            phase <= REJECT_DONE;
                        end
                    end
                end

                // Counter hanya maju setelah handshake. Saat out_ready rendah,
                // byte yang sama tetap tersedia sampai diterima.
                SEND_DATA: begin
                    if (data_length_reg == 0) begin
                        if (decrypt_reg) begin
                            done <= 1'b1;
                            busy <= 1'b0;
                            phase <= IDLE;
                        end else begin
                            tag_load <= 1'b1;
                            phase <= SEND_TAG;
                        end
                    end else if (out_valid && out_ready) begin
                        if (output_count + 32'd1 == data_length_reg) begin
                            if (decrypt_reg) begin
                                done <= 1'b1;
                                busy <= 1'b0;
                                phase <= IDLE;
                            end else begin
                                tag_load <= 1'b1;
                                phase <= SEND_TAG;
                            end
                        end else begin
                            output_count <= output_count + 32'd1;
                        end
                    end
                end

                SEND_TAG: begin
                    if (tag_valid && tag_ready) begin
                        done <= 1'b1;
                        busy <= 1'b0;
                        phase <= IDLE;
                    end
                end

                REJECT_DONE: begin
                    done <= 1'b1;
                    busy <= 1'b0;
                    phase <= IDLE;
                end

                default: begin
                    phase <= IDLE;
                    busy <= 1'b0;
                    command_error <= 1'b1;
                end
            endcase
        end
    end
endmodule
