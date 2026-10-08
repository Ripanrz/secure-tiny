`timescale 1ns/1ps

// Testbench core AEAD yang membaca KAT Ascon-C dari file tepercaya.
// Setiap record dijalankan dalam mode enkripsi dan dekripsi; ciphertext,
// plaintext dan tag dibandingkan, sementara latency dihitung dalam siklus.
module tb_ascon_core;
    localparam int unsigned MAX_DATA_BYTES = 32;

    logic clk = 1'b0;
    logic rst_n = 1'b0;
    logic start = 1'b0;
    logic decrypt = 1'b0;
    logic [127:0] key = '0;
    logic [127:0] nonce = '0;
    logic [31:0] ad_length = '0;
    logic [31:0] data_length = '0;
    logic [MAX_DATA_BYTES*8-1:0] ad_data = '0;
    logic [MAX_DATA_BYTES*8-1:0] data_in = '0;
    logic busy;
    logic done;
    logic command_error;
    logic [MAX_DATA_BYTES*8-1:0] data_out;
    logic [127:0] tag_out;

    integer latency_cycles;
    integer total_latency_cycles = 0;
    integer maximum_latency_cycles = 0;
    integer transaction_count = 0;
    integer kat_file;
    integer scanned;
    integer kat_count;
    integer ad_bytes;
    integer message_bytes;
    integer ciphertext_bytes;
    integer byte_index;
    integer status;
    logic [127:0] key_ref;
    logic [127:0] nonce_ref;
    logic [255:0] ad_ref;
    logic [255:0] plaintext_ref;
    logic [383:0] ciphertext_and_tag_ref;
    logic [MAX_DATA_BYTES*8-1:0] expected_data;
    logic [127:0] expected_tag;
    string line;
    string key_hex;
    string nonce_hex;
    string ad_hex;
    string plaintext_hex;
    string ciphertext_hex;

    ascon_core #(.MAX_DATA_BYTES(MAX_DATA_BYTES)) dut (
        .clk(clk), .rst_n(rst_n), .start(start), .decrypt(decrypt),
        .key(key), .nonce(nonce), .ad_length(ad_length),
        .data_length(data_length), .ad_data(ad_data), .data_in(data_in),
        .busy(busy), .done(done), .command_error(command_error),
        .data_out(data_out), .tag_out(tag_out)
    );

    always #5 clk = ~clk;

    task automatic wait_done;
        integer timeout_cycles;
        begin
            // Timeout mencegah deadlock tersembunyi; hitung siklus dari start
            // sampai pulsa done dan pastikan transaksi valid tidak error.
            timeout_cycles = 0;
            while (!done && timeout_cycles < 400) begin
                @(posedge clk);
                #1;
                timeout_cycles = timeout_cycles + 1;
                latency_cycles = latency_cycles + 1;
            end
            if (!done)
                $fatal(1, "core did not complete before timeout");
            if (command_error)
                $fatal(1, "core reported command_error for a valid KAT input");
            if (busy)
                $fatal(1, "core still busy when done was asserted");
        end
    endtask

    task automatic begin_transaction(input logic decrypt_mode);
        begin
            // Beri start satu siklus, lalu tunggu hasil sebelum transaksi baru.
            @(negedge clk);
            decrypt = decrypt_mode;
            start = 1'b1;
            @(posedge clk);
            #1;
            start = 1'b0;
            if (!busy)
                $fatal(1, "core did not accept start");
            latency_cycles = 1;
            wait_done();
            transaction_count = transaction_count + 1;
            total_latency_cycles = total_latency_cycles + latency_cycles;
            if (latency_cycles > maximum_latency_cycles)
                maximum_latency_cycles = latency_cycles;
            @(posedge clk);
            #1;
            if (done)
                $fatal(1, "done must be a one-cycle pulse");
        end
    endtask

    task automatic fetch_line;
        begin
            // Kegagalan EOF dini berarti record KAT tidak lengkap.
            if ($fgets(line, kat_file) == 0)
                $fatal(1, "unexpected end of Ascon-C KAT file");
        end
    endtask

    initial begin
        $dumpfile("sim/ascon_core.vcd");
        $dumpvars(0, tb_ascon_core);

        @(posedge clk);
        #1;
        rst_n = 1'b1;

        kat_file = $fopen("vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt", "r");
        if (kat_file == 0)
            $fatal(1, "could not open Ascon-C v1.3.0 KAT file");

        while (!$feof(kat_file)) begin
            if ($fgets(line, kat_file) == 0)
                break;
            if ($sscanf(line, "Count = %d", kat_count) == 1) begin
                fetch_line();
                if ($sscanf(line, "Key = %s", key_hex) != 1)
                    $fatal(1, "malformed Key field at KAT Count %0d", kat_count);
                fetch_line();
                if ($sscanf(line, "Nonce = %s", nonce_hex) != 1)
                    $fatal(1, "malformed Nonce field at KAT Count %0d", kat_count);
                fetch_line();
                plaintext_hex = "";
                status = $sscanf(line, "PT = %s", plaintext_hex);
                message_bytes = (status == 1) ? plaintext_hex.len() / 2 : 0;
                fetch_line();
                ad_hex = "";
                status = $sscanf(line, "AD = %s", ad_hex);
                ad_bytes = (status == 1) ? ad_hex.len() / 2 : 0;
                fetch_line();
                if ($sscanf(line, "CT = %s", ciphertext_hex) != 1)
                    $fatal(1, "malformed CT field at KAT Count %0d", kat_count);

                if ((message_bytes > MAX_DATA_BYTES) || (ad_bytes > MAX_DATA_BYTES))
                    $fatal(1, "KAT Count %0d exceeds testbench capacity", kat_count);

                key_ref = '0;
                nonce_ref = '0;
                ad_ref = '0;
                plaintext_ref = '0;
                ciphertext_and_tag_ref = '0;
                expected_data = '0;
                expected_tag = '0;
                if (($sscanf(key_hex, "%h", key_ref) != 1) ||
                    ($sscanf(nonce_hex, "%h", nonce_ref) != 1) ||
                    (($sscanf(plaintext_hex, "%h", plaintext_ref) != 1) && (message_bytes != 0)) ||
                    (($sscanf(ad_hex, "%h", ad_ref) != 1) && (ad_bytes != 0)) ||
                    ($sscanf(ciphertext_hex, "%h", ciphertext_and_tag_ref) != 1))
                    $fatal(1, "hex conversion failed at KAT Count %0d", kat_count);

                ciphertext_bytes = ciphertext_hex.len() / 2;
                if (ciphertext_bytes != message_bytes + 16)
                    $fatal(1, "unexpected ciphertext/tag length at KAT Count %0d", kat_count);

                // Teks KAT menulis byte pertama paling kiri; interface RTL
                // menempatkan byte pertama pada lane paling rendah [7:0].
                key = '0;
                nonce = '0;
                ad_data = '0;
                data_in = '0;
                for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1) begin
                    key[byte_index*8 +: 8] = key_ref[(15-byte_index)*8 +: 8];
                    nonce[byte_index*8 +: 8] = nonce_ref[(15-byte_index)*8 +: 8];
                end
                for (byte_index = 0; byte_index < ad_bytes; byte_index = byte_index + 1)
                    ad_data[byte_index*8 +: 8] = ad_ref[(ad_bytes-1-byte_index)*8 +: 8];
                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1) begin
                    data_in[byte_index*8 +: 8] = plaintext_ref[(message_bytes-1-byte_index)*8 +: 8];
                    expected_data[byte_index*8 +: 8] = ciphertext_and_tag_ref[(ciphertext_bytes-1-byte_index)*8 +: 8];
                end
                for (byte_index = 0; byte_index < 16; byte_index = byte_index + 1)
                    expected_tag[byte_index*8 +: 8] = ciphertext_and_tag_ref[(15-byte_index)*8 +: 8];

                ad_length = ad_bytes;
                data_length = message_bytes;
                begin_transaction(1'b0);
                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                    if (data_out[byte_index*8 +: 8] !== expected_data[byte_index*8 +: 8])
                        $fatal(1, "encryption data mismatch at KAT Count %0d byte %0d", kat_count, byte_index);
                if (tag_out !== expected_tag)
                    $fatal(1, "encryption tag mismatch at KAT Count %0d: got %032h expected %032h", kat_count, tag_out, expected_tag);

                // VCD hanya menyimpan transaksi pertama agar file ringkas;
                // seluruh 2.178 transaksi tetap dihitung dan dilaporkan di log.
                if (kat_count == 1)
                    $dumpoff;

                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                    data_in[byte_index*8 +: 8] = ciphertext_and_tag_ref[(ciphertext_bytes-1-byte_index)*8 +: 8];
                begin_transaction(1'b1);
                for (byte_index = 0; byte_index < message_bytes; byte_index = byte_index + 1)
                    if (data_out[byte_index*8 +: 8] !== plaintext_ref[(message_bytes-1-byte_index)*8 +: 8])
                        $fatal(1, "decryption data mismatch at KAT Count %0d byte %0d", kat_count, byte_index);
                if (tag_out !== expected_tag)
                    $fatal(1, "decryption tag mismatch at KAT Count %0d", kat_count);
            end
        end

        $fclose(kat_file);
        if ((kat_count != 1089) || (transaction_count != 2178))
            $fatal(1, "incomplete KAT run: last count=%0d transactions=%0d", kat_count, transaction_count);
        $display("MEASURE: %0d RTL transactions, total latency %0d cycles, max latency %0d cycles",
                 transaction_count, total_latency_cycles, maximum_latency_cycles);
        $display("PASS: RTL encrypt/decrypt matched all 1089 Ascon-C v1.3.0 full-tag KAT cases");
        $finish;
    end
endmodule
