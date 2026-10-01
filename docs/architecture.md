# Arsitektur RTL SECURE-TINY

## Identitas dan sumber kebenaran

Produk: **SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman**.

Tantangan utama: **Hardware Cryptography Accelerator**. Tantangan pendukung: **Secure Communication**. Algoritma: **Ascon-AEAD128 menurut NIST SP 800-232 final**. Target: **DE10-Nano FPGA/SoC**. Bentuk hasil saat ini adalah IP RTL dengan antarmuka streaming byte; integrasi bus host dan pemetaan pin pengguna masih tahap integrasi papan.

## Arsitektur yang diimplementasikan

Satu transaksi diproses pada satu waktu. Antarmuka AD dan pesan memakai transfer satu byte dengan `valid/ready`. Controller mengumpulkan seluruh AD dan pesan ke buffer internal, lalu memulai core buffered. Core melakukan AEAD dan memegang hasil dalam buffer keluaran sampai controller mengirimkannya. Buffer input tetap stabil saat core sibuk.

```text
Command + key/nonce/length/tag
              |
              v
     AEAD Controller <----> Ascon Core <----> Ascon Permutation
       |      ^                 |  
       |      |                 +---- data result + computed tag
       |      |                               |
 AD/message input streams              +------+------+
                                      Tag Generator  Tag Verifier
                                        (encrypt)     (decrypt)
                                                          |
                                                  Authentication Guard
                                                          |
                                             output byte stream + status
```

`tag_generator` menangkap dan menyajikan tag final yang dihitung core. `tag_verifier` membandingkan seluruh 128 bit tag hasil hitung dan tag masuk. Guard hanya mengizinkan keluaran plaintext setelah hasil dekripsi cocok. Antarmuka top-level tidak mengimplementasikan AXI, Avalon, DMA, atau protokol HPS.

## Kontrak transaksi

1. `start` diterima ketika `busy=0`; perintah, key, nonce, panjang, mode, dan tag masuk disimpan. `start` saat sibuk diabaikan.
2. Setelah perintah diterima, controller menerima tepat `ad_length` byte AD, lalu `data_length` byte pesan/ciphertext. Transfer terjadi hanya ketika `valid && ready` pada tepi naik clock. Panjang nol tidak memerlukan transfer.
3. Byte pertama ditempatkan pada `[7:0]` pada vektor buffer packed. `MAX_DATA_BYTES` membatasi masing-masing panjang AD dan pesan, bukan jumlah gabungannya.
4. Core menjalankan inisialisasi, absorpsi AD, pemrosesan pesan, dan finalisasi NIST SP 800-232. Permutasi berjalan iteratif satu ronde per siklus aktif; urutan ronde dan transformasi mengikuti standar.
5. Enkripsi mengeluarkan ciphertext melalui handshake terlebih dahulu. `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau sesudah core selesai untuk pesan kosong), lalu tag menunggu handshake `tag_ready`. Dekripsi menahan seluruh calon plaintext sampai verifikasi tag berakhir. Pada tag salah tidak ada byte plaintext yang dikeluarkan.
6. `done` adalah pulsa satu siklus setelah hasil enkripsi diterima, atau sesudah semua byte plaintext terautentikasi diterima; penolakan dekripsi dan perintah di luar kapasitas juga mengakhiri transaksi dengan pulsa `done`. Panjang di luar kapasitas menghasilkan `command_error`.

## Konfigurasi kapasitas dan biaya

`MAX_DATA_BYTES` adalah parameter positif wajib tanpa nilai default. Implementasi menyusun vektor dengan lebar `8*MAX_DATA_BYTES`; kapasitas praktis dibatasi oleh elaborator, memori, dan sumber daya FPGA. Konfigurasi build awal DE10-Nano adalah **16 byte per AD dan 16 byte per pesan**. Parameter ini adalah batas desain, bukan ukuran block kriptografi. Buffer membuat konsumsi register tumbuh seiring kapasitas; konfigurasi 16 byte dipilih sebagai baseline agar desain dapat diuji, dan belum membuktikan klaim hemat sumber daya. Nilai resource Cyclone V dan timing berstatus `TBD — belum diukur` sampai build Quartus berhasil.

Tidak ada klaim area, Fmax, latensi, throughput, atau daya sebelum pengukuran pada tool/target yang sesuai. Angka sintesis generik Yosys dicatat sebagai jumlah sel generik saja, bukan resource Cyclone V.

## Reset dan tahap target

`rst_n` adalah reset aktif-rendah sinkron terhadap `clk`. Reset membatalkan transaksi dan menurunkan seluruh sinyal `valid`/status sesuai kontrak RTL.

Caller bertanggung jawab memakai nonce yang unik untuk setiap enkripsi dengan key yang sama. IP menerima nonce dari caller dan tidak membuat atau menyimpan riwayat nonce. Hardware Authentication Guard hanya meloloskan plaintext dekripsi setelah tag cocok; guard ini bukan sensor tamper fisik atau mitigasi side-channel.

Top-level bersifat board-independent. Proyek Quartus menetapkan device DE10-Nano, clock 50 MHz, reset board, serta virtual pins untuk seluruh interface IP. Konfigurasi itu menyiapkan elaborasi/sintesis FPGA; virtual pins tidak menyediakan jalur host yang dapat dipakai untuk mengirim transaksi pada papan. Integrasi Avalon/HPS atau pemetaan antarmuka ke pin ekspansi dan uji papan adalah langkah tersendiri.
