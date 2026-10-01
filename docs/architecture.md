# Arsitektur RTL SECURE-TINY

## Identitas dan sumber kebenaran

Produk: **SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman**.

Tantangan utama: **Hardware Cryptography Accelerator**. Tantangan pendukung: **Secure Communication**. Algoritma: **Ascon-AEAD128 menurut NIST SP 800-232 final**. Target: **DE10-Nano FPGA/SoC**. Hasil saat ini berupa IP RTL dengan antarmuka aliran data per byte. Integrasi bus host dan pemetaan pin pengguna masih menjadi pekerjaan integrasi board.

## Arsitektur yang diterapkan

Satu transaksi diproses pada satu waktu. Antarmuka AD dan pesan memakai transfer satu byte dengan `valid/ready`. Pengendali mengumpulkan seluruh AD dan pesan di penyangga internal, lalu memulai core dengan penyangga. Core menjalankan AEAD dan menahan hasil di penyangga keluaran sampai pengendali mengirimkannya. Isi penyangga masukan tetap stabil saat core sibuk.

```text
Perintah + key/nonce/panjang/tag
              |
              v
     Pengendali AEAD <----> Core Ascon <----> Permutasi Ascon
       |      ^                 |  
       |      |                 +---- hasil data + tag terhitung
       |      |                               |
 Aliran masukan AD/pesan              +------+------+
                                      Pembentuk Tag  Pemeriksa Tag
                                        (enkripsi)     (dekripsi)
                                                          |
                                                  Hardware Authentication Guard
                                                          |
                                             aliran byte keluaran + status
```

`tag_generator` menangkap dan menyajikan tag akhir yang dihitung core. `tag_verifier` membandingkan seluruh 128 bit tag hasil hitung dengan tag masukan. Guard hanya mengizinkan keluaran plaintext setelah hasil dekripsi cocok. Antarmuka tingkat atas tidak menerapkan AXI, Avalon, DMA, atau protokol HPS.

## Kontrak transaksi

1. `start` diterima ketika `busy=0`; perintah, key, nonce, panjang, mode, dan tag masukan disimpan. `start` saat sibuk diabaikan.
2. Setelah perintah diterima, pengendali menerima tepat `ad_length` byte AD, lalu `data_length` byte pesan/ciphertext. Transfer terjadi hanya ketika `valid && ready` pada tepi naik clock. Panjang nol tidak memerlukan transfer.
3. Byte pertama ditempatkan pada `[7:0]` dalam vektor packed penyangga. `MAX_DATA_BYTES` membatasi masing-masing panjang AD dan pesan, bukan jumlah gabungannya.
4. Core menjalankan inisialisasi, absorpsi AD, pemrosesan pesan, dan finalisasi NIST SP 800-232. Permutasi berjalan secara iteratif satu ronde per siklus aktif; urutan ronde dan transformasi mengikuti standar.
5. Enkripsi mengeluarkan ciphertext melalui handshake terlebih dahulu. `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau sesudah core selesai untuk pesan kosong), lalu tag menunggu handshake `tag_ready`. Dekripsi menahan seluruh calon plaintext sampai verifikasi tag berakhir. Jika tag salah, tidak ada byte plaintext yang dikeluarkan.
6. `done` adalah pulsa satu siklus setelah hasil enkripsi diterima atau setelah seluruh byte plaintext terautentikasi diterima. Penolakan dekripsi dan perintah di luar kapasitas juga mengakhiri transaksi dengan pulsa `done`. Panjang di luar kapasitas menghasilkan `command_error`.

## Konfigurasi kapasitas dan biaya

`MAX_DATA_BYTES` adalah parameter positif wajib tanpa nilai bawaan. Implementasi menyusun vektor dengan lebar `8*MAX_DATA_BYTES`; kapasitas praktis dibatasi oleh elaborator, memori, dan sumber daya FPGA. Konfigurasi build awal DE10-Nano adalah **16 byte per AD dan 16 byte per pesan**. Parameter ini adalah batas desain, bukan ukuran blok kriptografi. Penyangga membuat konsumsi register bertambah seiring kapasitas; konfigurasi 16 byte dipilih sebagai nilai awal agar desain dapat diuji, tetapi belum membuktikan klaim hemat sumber daya. Nilai resource Cyclone V dan timing berstatus `TBD — belum diukur` sampai build Quartus berhasil.

Tidak ada klaim area, Fmax, latensi, throughput, atau daya sebelum pengukuran pada perangkat dan sasaran yang sesuai. Angka sintesis generik Yosys dicatat sebagai jumlah sel generik saja, bukan resource Cyclone V.

## Reset dan tahap target

`rst_n` adalah reset aktif-rendah sinkron terhadap `clk`. Reset membatalkan transaksi dan menurunkan seluruh sinyal `valid`/status sesuai kontrak RTL.

Pemanggil bertanggung jawab memakai nonce yang unik untuk setiap enkripsi dengan key yang sama. IP menerima nonce dari pemanggil dan tidak membuat atau menyimpan riwayat nonce. Hardware Authentication Guard hanya meloloskan plaintext dekripsi setelah tag cocok; guard ini bukan sensor gangguan fisik atau mitigasi side-channel.

Modul tingkat atas tidak bergantung pada board. Proyek Quartus menetapkan perangkat DE10-Nano, clock 50 MHz, reset board, serta pin virtual untuk seluruh antarmuka IP. Konfigurasi itu menyiapkan elaborasi/sintesis FPGA; pin virtual tidak menyediakan jalur host untuk mengirim transaksi pada board. Integrasi Avalon/HPS atau pemetaan antarmuka ke pin ekspansi dan pengujian board merupakan tahapan tersendiri.
