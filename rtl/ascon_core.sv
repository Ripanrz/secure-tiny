// Core Ascon-AEAD128 sinkron untuk satu transaksi yang sudah dikumpulkan.
// Masukan: key, nonce, panjang AD/data, buffer packed, mode start/decrypt.
// Keluaran: data_out, tag_out, busy/done, serta command_error jika panjang
// melampaui MAX_DATA_BYTES. Byte pertama menempati bit [7:0].
// Urutan kerja: inisialisasi -> AD -> pemisahan domain -> pesan -> finalisasi;
// algoritma mengikuti NIST SP 800-232. Parameter kapasitas wajib diberikan.
module ascon_core #(
    parameter int unsigned MAX_DATA_BYTES
) (
    input  logic                              clk,
    input  logic                              rst_n,
    input  logic                              start,
    input  logic                              decrypt,
    input  logic [127:0]                      key,
    input  logic [127:0]                      nonce,
    input  logic [31:0]                       ad_length,
    input  logic [31:0]                       data_length,
    input  logic [MAX_DATA_BYTES*8-1:0]       ad_data,
    input  logic [MAX_DATA_BYTES*8-1:0]       data_in,
    output logic                              busy,
    output logic                              done,
    output logic                              command_error,
    output logic [MAX_DATA_BYTES*8-1:0]       data_out,
    output logic [127:0]                      tag_out
);

    localparam logic [63:0] ASCON_AEAD128_IV = 64'h00001000808c0001;
    localparam logic [3:0] IDLE = 4'd0;
    localparam logic [3:0] INIT_LAUNCH = 4'd1;
    localparam logic [3:0] INIT_WAIT = 4'd2;
    localparam logic [3:0] AD_SETUP = 4'd3;
    localparam logic [3:0] AD_WAIT = 4'd4;
    localparam logic [3:0] DOMAIN_SEPARATE = 4'd5;
    localparam logic [3:0] MESSAGE_SETUP = 4'd6;
    localparam logic [3:0] MESSAGE_WAIT = 4'd7;
    localparam logic [3:0] FINAL_LAUNCH = 4'd8;
    localparam logic [3:0] FINAL_WAIT = 4'd9;
    localparam logic [3:0] FAILED = 4'd10;

    logic [3:0] phase;
    logic [319:0] state_reg;
    logic [127:0] key_reg;
    logic [127:0] nonce_reg;
    logic [31:0] ad_length_reg;
    logic [31:0] data_length_reg;
    logic [31:0] byte_index;
    logic ad_final_block;
    logic decrypt_reg;

    logic perm_start;
    logic [4:0] perm_rounds;
    logic perm_busy;
    logic perm_done;
    logic perm_error;
    logic [319:0] perm_state_out;

    logic [127:0] block_value;
    logic [127:0] padded_block;
    logic [127:0] rate_value;
    logic [127:0] rate_result;
    logic [127:0] output_block;
    logic [4:0] tail_length;
    integer byte_lane;

    function automatic logic [127:0] read_block(
        input logic [MAX_DATA_BYTES*8-1:0] buffer,
        input logic [31:0] first_byte,
        input logic [4:0] byte_count
    );
        integer lane;
        begin
            // Salin paling banyak 16 byte ke blok rate; lane di luar data
            // aktual tetap nol untuk penanganan blok parsial.
            read_block = 128'b0;
            for (lane = 0; lane < 16; lane = lane + 1) begin
                if ((lane < byte_count) && ((first_byte + lane) < MAX_DATA_BYTES))
                    read_block[(lane*8) +: 8] = buffer[((first_byte + lane)*8) +: 8];
            end
        end
    endfunction

    ascon_permutation permutation (
        .clk(clk),
        .rst_n(rst_n),
        .start(perm_start),
        .rounds(perm_rounds),
        .state_in(state_reg),
        .busy(perm_busy),
        .done(perm_done),
        .error(perm_error),
        .state_out(perm_state_out)
    );

    // Siapkan blok AD/pesan dan padding tanpa mengubah register state.
    // Rate Ascon-AEAD128 berukuran 128 bit; byte sisa mendapat delimiter 1.
    always_comb begin
        tail_length = 5'b0;
        block_value = 128'b0;
        padded_block = 128'b0;
        rate_value = {state_reg[255:192], state_reg[319:256]};
        rate_result = rate_value;
        output_block = 128'b0;

        if (phase == AD_SETUP) begin
            if (byte_index < {ad_length_reg[31:4], 4'b0000}) begin
                block_value = read_block(ad_data, byte_index, 5'd16);
            end else begin
                tail_length = {1'b0, ad_length_reg[3:0]};
                block_value = read_block(ad_data, byte_index, tail_length);
                padded_block = block_value | (128'b1 << (tail_length * 8));
            end
        end else if (phase == MESSAGE_SETUP) begin
            if (byte_index < {data_length_reg[31:4], 4'b0000}) begin
                block_value = read_block(data_in, byte_index, 5'd16);
                output_block = decrypt_reg ? (rate_value ^ block_value) : (rate_value ^ block_value);
            end else begin
                tail_length = {1'b0, data_length_reg[3:0]};
                block_value = read_block(data_in, byte_index, tail_length);
                padded_block = block_value | (128'b1 << (tail_length * 8));
                if (decrypt_reg) begin
                    output_block = rate_value ^ block_value;
                    rate_result = (rate_value & ~(128'hffffffffffffffffffffffffffffffff >> (128 - (tail_length * 8)))) |
                                  (block_value & (128'hffffffffffffffffffffffffffffffff >> (128 - (tail_length * 8))));
                    rate_result = rate_result ^ (128'b1 << (tail_length * 8));
                end else begin
                    output_block = rate_value ^ block_value;
                    rate_result = rate_value ^ padded_block;
                end
            end
        end
    end

    // FSM berinteraksi dengan permutasi melalui sinyal start/done. Status
    // done/error berupa pulsa satu siklus untuk melanjutkan fase controller.
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            phase <= IDLE;
            state_reg <= '0;
            key_reg <= '0;
            nonce_reg <= '0;
            ad_length_reg <= '0;
            data_length_reg <= '0;
            byte_index <= '0;
            ad_final_block <= 1'b0;
            decrypt_reg <= 1'b0;
            perm_start <= 1'b0;
            perm_rounds <= '0;
            busy <= 1'b0;
            done <= 1'b0;
            command_error <= 1'b0;
            data_out <= '0;
            tag_out <= '0;
        end else begin
            perm_start <= 1'b0;
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
                            key_reg <= key;
                            nonce_reg <= nonce;
                            ad_length_reg <= ad_length;
                            data_length_reg <= data_length;
                            decrypt_reg <= decrypt;
                            byte_index <= '0;
                            data_out <= '0;
                            tag_out <= '0;
                            busy <= 1'b1;
                            phase <= INIT_LAUNCH;
                        end
                    end
                end

                // Susun IV, key, dan nonce sesuai urutan word standar.
                INIT_LAUNCH: begin
                    state_reg <= {ASCON_AEAD128_IV, key_reg[63:0], key_reg[127:64],
                                  nonce_reg[63:0], nonce_reg[127:64]};
                    perm_rounds <= 5'd12;
                    perm_start <= 1'b1;
                    phase <= INIT_WAIT;
                end

                INIT_WAIT: begin
                    if (perm_done) begin
                        if (perm_error) begin
                            phase <= FAILED;
                        end else begin
                            state_reg <= perm_state_out;
                            state_reg[127:64] <= perm_state_out[127:64] ^ key_reg[63:0];
                            state_reg[63:0] <= perm_state_out[63:0] ^ key_reg[127:64];
                            byte_index <= '0;
                            phase <= AD_SETUP;
                        end
                    end
                end

                // Proses AD per blok 16 byte, dengan padding pada blok terakhir.
                AD_SETUP: begin
                    if (ad_length_reg == 0) begin
                        phase <= DOMAIN_SEPARATE;
                    end else begin
                        if (byte_index < {ad_length_reg[31:4], 4'b0000}) begin
                            state_reg[319:256] <= state_reg[319:256] ^ block_value[63:0];
                            state_reg[255:192] <= state_reg[255:192] ^ block_value[127:64];
                            byte_index <= byte_index + 32'd16;
                            ad_final_block <= 1'b0;
                        end else begin
                            state_reg[319:256] <= state_reg[319:256] ^ padded_block[63:0];
                            state_reg[255:192] <= state_reg[255:192] ^ padded_block[127:64];
                            ad_final_block <= 1'b1;
                        end
                        perm_rounds <= 5'd8;
                        perm_start <= 1'b1;
                        phase <= AD_WAIT;
                    end
                end

                AD_WAIT: begin
                    if (perm_done) begin
                        if (perm_error) begin
                            phase <= FAILED;
                        end else begin
                            state_reg <= perm_state_out;
                            if (ad_final_block) begin
                                phase <= DOMAIN_SEPARATE;
                            end else begin
                                phase <= AD_SETUP;
                            end
                        end
                    end
                end

                // Pisahkan domain AD dan pesan sebelum pemrosesan pesan.
                DOMAIN_SEPARATE: begin
                    state_reg[63] <= ~state_reg[63];
                    byte_index <= '0;
                    phase <= MESSAGE_SETUP;
                end

                // XOR rate membentuk output; state menyerap ciphertext baik
                // pada enkripsi maupun dekripsi, sebagaimana ditentukan AEAD.
                MESSAGE_SETUP: begin
                    if (byte_index < {data_length_reg[31:4], 4'b0000}) begin
                        if (decrypt_reg) begin
                            state_reg[319:256] <= block_value[63:0];
                            state_reg[255:192] <= block_value[127:64];
                        end else begin
                            state_reg[319:256] <= output_block[63:0];
                            state_reg[255:192] <= output_block[127:64];
                        end
                        for (byte_lane = 0; byte_lane < 16; byte_lane = byte_lane + 1)
                            data_out[((byte_index + byte_lane)*8) +: 8] <= output_block[(byte_lane*8) +: 8];
                        byte_index <= byte_index + 32'd16;
                        perm_rounds <= 5'd8;
                        perm_start <= 1'b1;
                        phase <= MESSAGE_WAIT;
                    end else begin
                        state_reg[319:256] <= rate_result[63:0];
                        state_reg[255:192] <= rate_result[127:64];
                        for (byte_lane = 0; byte_lane < 16; byte_lane = byte_lane + 1)
                            if (byte_lane < tail_length)
                                data_out[((byte_index + byte_lane)*8) +: 8] <= output_block[(byte_lane*8) +: 8];
                        phase <= FINAL_LAUNCH;
                    end
                end

                MESSAGE_WAIT: begin
                    if (perm_done) begin
                        if (perm_error) begin
                            phase <= FAILED;
                        end else begin
                            state_reg <= perm_state_out;
                            phase <= MESSAGE_SETUP;
                        end
                    end
                end

                // Finalisasi memasukkan key lagi, lalu p12 menghasilkan state
                // akhir yang dipakai untuk membentuk tag 128-bit.
                FINAL_LAUNCH: begin
                    state_reg[191:128] <= state_reg[191:128] ^ key_reg[63:0];
                    state_reg[127:64] <= state_reg[127:64] ^ key_reg[127:64];
                    perm_rounds <= 5'd12;
                    perm_start <= 1'b1;
                    phase <= FINAL_WAIT;
                end

                FINAL_WAIT: begin
                    if (perm_done) begin
                        if (perm_error) begin
                            phase <= FAILED;
                        end else begin
                            state_reg <= perm_state_out;
                            tag_out <= {perm_state_out[63:0] ^ key_reg[127:64],
                                        perm_state_out[127:64] ^ key_reg[63:0]};
                            busy <= 1'b0;
                            done <= 1'b1;
                            phase <= IDLE;
                        end
                    end
                end

                FAILED: begin
                    busy <= 1'b0;
                    command_error <= 1'b1;
                    done <= 1'b1;
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
