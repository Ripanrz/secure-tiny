`timescale 1ns/1ps

// Sapuan integrasi top-level: semua pasangan panjang AD/data 0..16 byte,
// masing-masing enkripsi dan dekripsi terhadap KAT Ascon-C.
// Monitor clock menghitung byte handshake serta memeriksa plaintext tidak
// valid sebelum keputusan autentikasi.
module tb_secure_tiny_kat;
    localparam int unsigned MAX_DATA_BYTES = 16;
    localparam int unsigned LENGTH_PAIR_COUNT = (MAX_DATA_BYTES + 1) * (MAX_DATA_BYTES + 1);

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic decrypt = 1'b0;
    logic [127:0] key = '0;
    logic [127:0] nonce = '0;
    logic [31:0] ad_length = '0;
    logic [31:0] data_length = '0;
    logic [127:0] received_tag = '0;
    logic ad_valid = 1'b0;
    logic ad_ready;
    logic [7:0] ad_data = '0;
    logic data_valid = 1'b0;
    logic data_ready;
    logic [7:0] data_in = '0;
    logic out_valid;
    logic out_ready = 1'b1;
    logic [7:0] out_data;
    logic tag_valid;
    logic tag_ready = 1'b1;
    logic [127:0] tag_out;
    logic auth_result_valid;
    logic accept;
    logic reject;
    logic busy;
    logic done;
    logic command_error;

    logic [127:0] observed_tag;
    logic [MAX_DATA_BYTES*8-1:0] observed_data;
    logic [LENGTH_PAIR_COUNT-1:0] seen_length_pairs = '0;
    integer observed_data_count = 0;
    integer observed_tag_count = 0;
    integer cycle_count = 0;
    integer transaction_start_cycle = 0;
    integer total_cycles = 0;
    integer maximum_cycles = 0;
    integer transaction_count = 0;
    integer kat_case_count = 0;
    integer kat_file;
    integer kat_count;
    integer status;
    integer ad_bytes;
    integer message_bytes;
    integer ciphertext_bytes;
    integer byte_index;
    integer pair_index;
    integer ad_length_check;
    integer data_length_check;

    logic [127:0] key_ref;
    logic [127:0] nonce_ref;
    logic [255:0] ad_ref;
    logic [255:0] plaintext_ref;
    logic [383:0] ciphertext_and_tag_ref;
    logic [MAX_DATA_BYTES*8-1:0] expected_ciphertext;
    logic [127:0] expected_tag;
    string line;
    string key_hex;
    string nonce_hex;
    string ad_hex;
    string plaintext_hex;
    string ciphertext_hex;

    secure_tiny_top #(.MAX_DATA_BYTES(MAX_DATA_BYTES)) dut (.*);

    always #5 clk = ~clk;

    always @(posedge clk) begin
        // Monitor pasif mengumpulkan output dan menegakkan invarian protokol
        // pada setiap siklus, bukan hanya setelah transaksi berakhir.
        cycle_count = cycle_count + 1;
        if (rst_n) begin
            if (out_valid && out_ready) begin
                if (observed_data_count >= MAX_DATA_BYTES)
                    $fatal(1, "too many output bytes in top-level KAT transaction");
                observed_data[observed_data_count*8 +: 8] = out_data;
                observed_data_count = observed_data_count + 1;
            end
            if (tag_valid && tag_ready) begin
                observed_tag = tag_out;
                observed_tag_count = observed_tag_count + 1;
            end
            if (tag_valid && decrypt)
                $fatal(1, "decrypt transaction unexpectedly exposed an output tag");
            if (tag_valid && (observed_data_count < data_length))
                $fatal(1, "tag became valid before all ciphertext bytes were accepted");
            if (decrypt && out_valid && !auth_result_valid)
                $fatal(1, "plaintext became valid before authentication decision");
        end
    end

    task automatic fetch_line;
        begin
            // Ambil satu baris KAT; EOF prematur menandakan vector terpotong.
            if ($fgets(line, kat_file) == 0)
                $fatal(1, "unexpected end of KAT file");
        end
    endtask

    task automatic launch(input logic decrypt_mode);
        begin
            // Kirim satu perintah dan catat titik awal pengukuran latency.
            @(negedge clk);
            decrypt = decrypt_mode;
            start = 1'b1;
            @(posedge clk);
            #1;
            start = 1'b0;
            if (!busy)
                $fatal(1, "top-level KAT command was not accepted");
            transaction_start_cycle = cycle_count;
        end
    endtask

    task automatic send_ad_byte(input logic [7:0] value);
        begin
            // Pengirim memegang valid dan data sampai ready menandai transfer.
            @(negedge clk);
            ad_data = value;
            ad_valid = 1'b1;
            do @(posedge clk); while (!ad_ready);
            @(negedge clk);
            ad_valid = 1'b0;
        end
    endtask

    task automatic send_data_byte(input logic [7:0] value);
        begin
            // Kirim plaintext untuk enkripsi atau ciphertext untuk dekripsi.
            @(negedge clk);
            data_in = value;
            data_valid = 1'b1;
            do @(posedge clk); while (!data_ready);
            @(negedge clk);
            data_valid = 1'b0;
        end
    endtask

    task automatic wait_for_done;
        integer timeout_cycles;
        integer measured_cycles;
        begin
            timeout_cycles = 0;
            while (!done && timeout_cycles < 1200) begin
                @(posedge clk);
                #1;
                timeout_cycles = timeout_cycles + 1;
            end
            if (!done)
                $fatal(1, "top-level KAT %0d mode %0d did not finish (phase=%0d busy=%b out_count=%0d tag_valid=%b auth_valid=%b accept=%b reject=%b)",
                       kat_count, decrypt, dut.controller.phase, busy, observed_data_count,
                       tag_valid, auth_result_valid, accept, reject);
            if (busy || command_error)
                $fatal(1, "top-level KAT ended busy or with command_error");
            measured_cycles = cycle_count - transaction_start_cycle;
            total_cycles = total_cycles + measured_cycles;
            if (measured_cycles > maximum_cycles)
                maximum_cycles = measured_cycles;
        end
    endtask

    task automatic check_transaction(input logic decrypt_mode);
        begin
            // Jalankan satu vector lengkap, kemudian cek panjang, tag, output,
            // status autentikasi, dan setiap byte hasil.
            observed_data = '0;
            observed_tag = '0;
            observed_data_count = 0;
            observed_tag_count = 0;
            launch(decrypt_mode);
            for (byte_index = 0; byte_index < ad_bytes; byte_index = byte_index + 1)
                send_ad_byte(ad_ref[(ad_bytes-1-byte_index)*8 +: 8]);
            for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1) begin
                if (decrypt_mode)
                    send_data_byte(ciphertext_and_tag_ref[(ciphertext_bytes-1-byte_index)*8 +: 8]);
                else
                    send_data_byte(plaintext_ref[(message_bytes-1-byte_index)*8 +: 8]);
            end
            wait_for_done();

            if (observed_data_count != message_bytes)
                $fatal(1, "KAT %0d mode %0d output length %0d expected %0d",
                       kat_count, decrypt_mode, observed_data_count, message_bytes);
            if (decrypt_mode) begin
                if (observed_tag_count != 0)
                    $fatal(1, "KAT %0d decrypt unexpectedly emitted a tag", kat_count);
                if (!auth_result_valid || !accept || reject)
                    $fatal(1, "KAT %0d valid decrypt was not accepted", kat_count);
                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                    if (observed_data[byte_index*8 +: 8] !== plaintext_ref[(message_bytes-1-byte_index)*8 +: 8])
                        $fatal(1, "KAT %0d plaintext mismatch at byte %0d", kat_count, byte_index);
            end else begin
                if (observed_tag_count != 1 || observed_tag !== expected_tag)
                    $fatal(1, "KAT %0d tag output mismatch: got %032h expected %032h",
                           kat_count, observed_tag, expected_tag);
                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                    if (observed_data[byte_index*8 +: 8] !== expected_ciphertext[byte_index*8 +: 8])
                        $fatal(1, "KAT %0d ciphertext mismatch at byte %0d", kat_count, byte_index);
            end
            transaction_count = transaction_count + 1;
        end
    endtask

    initial begin
        $dumpfile("sim/secure_tiny_kat.vcd");
        $dumpvars(0, tb_secure_tiny_kat);

        @(posedge clk);
        #1;
        rst_n = 1'b1;
        kat_file = $fopen("vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt", "r");
        if (kat_file == 0)
            $fatal(1, "could not open Ascon-C KAT file");

        while (!$feof(kat_file)) begin
            if ($fgets(line, kat_file) == 0)
                break;
            if ($sscanf(line, "Count = %d", kat_count) == 1) begin
                fetch_line();
                if ($sscanf(line, "Key = %s", key_hex) != 1)
                    $fatal(1, "malformed Key at KAT %0d", kat_count);
                fetch_line();
                if ($sscanf(line, "Nonce = %s", nonce_hex) != 1)
                    $fatal(1, "malformed Nonce at KAT %0d", kat_count);
                fetch_line();
                plaintext_hex = "";
                status = $sscanf(line, "PT = %s", plaintext_hex);
                message_bytes = (status == 1) ? plaintext_hex.len()/2 : 0;
                fetch_line();
                ad_hex = "";
                status = $sscanf(line, "AD = %s", ad_hex);
                ad_bytes = (status == 1) ? ad_hex.len()/2 : 0;
                fetch_line();
                if ($sscanf(line, "CT = %s", ciphertext_hex) != 1)
                    $fatal(1, "malformed CT at KAT %0d", kat_count);

                if ((ad_bytes <= MAX_DATA_BYTES) && (message_bytes <= MAX_DATA_BYTES)) begin
                    pair_index = (ad_bytes * (MAX_DATA_BYTES + 1)) + message_bytes;
                    if (seen_length_pairs[pair_index])
                        $fatal(1, "duplicate KAT length pair AD=%0d message=%0d", ad_bytes, message_bytes);
                    seen_length_pairs[pair_index] = 1'b1;

                    key_ref = '0;
                    nonce_ref = '0;
                    ad_ref = '0;
                    plaintext_ref = '0;
                    ciphertext_and_tag_ref = '0;
                    expected_ciphertext = '0;
                    expected_tag = '0;
                    if (($sscanf(key_hex, "%h", key_ref) != 1) ||
                        ($sscanf(nonce_hex, "%h", nonce_ref) != 1) ||
                        (($sscanf(plaintext_hex, "%h", plaintext_ref) != 1) && (message_bytes != 0)) ||
                        (($sscanf(ad_hex, "%h", ad_ref) != 1) && (ad_bytes != 0)) ||
                        ($sscanf(ciphertext_hex, "%h", ciphertext_and_tag_ref) != 1))
                        $fatal(1, "hex conversion failed at KAT %0d", kat_count);

                    ciphertext_bytes = ciphertext_hex.len()/2;
                    if (ciphertext_bytes != message_bytes + 16)
                        $fatal(1, "unexpected ciphertext/tag length at KAT %0d", kat_count);

                    for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1) begin
                        key[byte_index*8 +: 8] = key_ref[(15-byte_index)*8 +: 8];
                        nonce[byte_index*8 +: 8] = nonce_ref[(15-byte_index)*8 +: 8];
                    end
                    for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                        expected_ciphertext[byte_index*8 +: 8] = ciphertext_and_tag_ref[(ciphertext_bytes-1-byte_index)*8 +: 8];
                    for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1)
                        expected_tag[byte_index*8 +: 8] = ciphertext_and_tag_ref[(15-byte_index)*8 +: 8];

                    ad_length = ad_bytes;
                    data_length = message_bytes;
                    received_tag = expected_tag;
                    check_transaction(1'b0);
                    check_transaction(1'b1);
                    kat_case_count = kat_case_count + 1;
                    if (kat_count == 34)
                        $dumpoff;
                end
            end
        end

        $fclose(kat_file);
        for (ad_length_check = 0; ad_length_check <= MAX_DATA_BYTES; ad_length_check = ad_length_check + 1)
            for (data_length_check = 0; data_length_check <= MAX_DATA_BYTES; data_length_check = data_length_check + 1)
                if (!seen_length_pairs[(ad_length_check * (MAX_DATA_BYTES + 1)) + data_length_check])
                    $fatal(1, "missing KAT length pair AD=%0d message=%0d", ad_length_check, data_length_check);
        if ((kat_case_count != 289) || (transaction_count != 578))
            $fatal(1, "incomplete top-level KAT run: cases=%0d transactions=%0d",
                   kat_case_count, transaction_count);
        $display("MEASURE: %0d top-level transactions, total latency %0d cycles, max latency %0d cycles",
                 transaction_count, total_cycles, maximum_cycles);
        $display("PASS: top-level encrypt/decrypt matched all 289 KAT length pairs through 16-byte interface");
        $finish;
    end
endmodule
