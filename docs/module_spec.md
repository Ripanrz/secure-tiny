# Spesifikasi Modul RTL SECURE-TINY

Kontrak ini mencerminkan implementasi RTL saat ini. Semua modul sekuensial menggunakan `clk` dan reset aktif-rendah sinkron `rst_n`. Key, nonce, dan tag masing-masing 128 bit sesuai Ascon-AEAD128 NIST SP 800-232 final. Parameter `MAX_DATA_BYTES` wajib ditentukan saat elaborasi dan membatasi panjang AD dan pesan secara terpisah.

## Konvensi interface

Input/output AD dan pesan memakai satu byte per transfer. Transfer terjadi pada tepi naik ketika `valid && ready`. Sumber mempertahankan `valid` dan `data` hingga transfer. Panjang adalah jumlah byte unsigned 32-bit; tidak ada sinyal `last`. Untuk semua nilai yang direpresentasikan sebagai urutan byte di antarmuka (`key`, `nonce`, AD, pesan, tag), byte pertama berada di `[7:0]`, byte kedua di `[15:8]`, dan seterusnya. KAT teks menuliskan byte pertama paling kiri; checker RTL memetakan urutan tersebut ke lane terendah.

### Port top-level `secure_tiny_top`

| Sinyal | Arah | Lebar | Fungsi |
|---|---|---:|---|
| `clk`, `rst_n` | input | 1, 1 | Clock tunggal; reset sinkron aktif-rendah. |
| `start`, `decrypt` | input | 1, 1 | Request command dan pilih mode dekripsi (`1`) atau enkripsi (`0`). |
| `key`, `nonce`, `received_tag` | input | 128 tiap sinyal | Key, nonce, dan tag masuk dekripsi. Tag masuk diabaikan pada enkripsi. |
| `ad_length`, `data_length` | input | 32 tiap sinyal | Jumlah byte AD dan pesan/ciphertext. |
| `ad_valid`, `ad_data` | input | 1, 8 | Stream AD dari caller. |
| `ad_ready` | output | 1 | AD diterima hanya saat fase AD dan panjang belum terpenuhi. |
| `data_valid`, `data_in` | input | 1, 8 | Stream plaintext (enkripsi) atau ciphertext (dekripsi). |
| `data_ready` | output | 1 | Data diterima hanya setelah fase AD selesai dan panjang belum terpenuhi. |
| `out_valid`, `out_data` | output | 1, 8 | Ciphertext enkripsi atau plaintext dekripsi yang boleh dikonsumsi. |
| `out_ready` | input | 1 | Backpressure/handshake untuk stream keluaran byte. |
| `tag_valid`, `tag_out` | output | 1, 128 | Tag hasil enkripsi yang ditahan sampai handshake. |
| `tag_ready` | input | 1 | Handshake penerimaan tag keluaran. |
| `auth_result_valid`, `accept`, `reject` | output | 1 tiap sinyal | Keputusan autentikasi dekripsi; tidak digunakan untuk enkripsi. |
| `busy`, `done`, `command_error` | output | 1 tiap sinyal | Status transaksi, pulsa penyelesaian satu siklus, dan pulsa command di luar kapasitas. |

Tidak ada port `command_ready` terpisah. Command diambil pada tepi naik saat `start && !busy`; saat busy, start diabaikan.

## Modul

| Modul | Peran dan kontrak |
|---|---|
| `counter.sv` | Modul pembelajaran terpisah untuk reset, enable, hold, dan wrap counter; bukan bagian datapath AEAD. |
| `ascon_permutation.sv` | Menerima state 320-bit dan 8 atau 12 ronde, menjalankan satu ronde per siklus aktif, lalu mengeluarkan state akhir dan pulsa `done`. Transformasi mengikuti NIST SP 800-232. |
| `ascon_core.sv` | Mesin AEAD buffered. Menerima key, nonce, panjang, dan vektor AD/pesan packed yang stabil selama busy. Menjalankan init, absorpsi, pemrosesan, finalisasi, dan mengeluarkan seluruh hasil packed serta tag. Tidak memiliki antarmuka host. |
| `aead_controller.sv` | Menerima streaming byte ke buffer AD dan data, memulai core setelah input lengkap, mengatur handshake keluaran, verifikasi tag, dan penyelesaian. State tambahan digunakan untuk fase receive/core/verify/send. |
| `tag_generator.sv` | Menangkap tag final dari core dan menyajikannya dengan `tag_valid/tag_ready`; tidak menghitung tag. |
| `tag_verifier.sv` | Membandingkan seluruh 128 bit tag hasil hitung dan tag diterima, lalu mengeluarkan pulsa match atau mismatch. |
| `authentication_guard.sv` | Menyimpan keputusan autentikasi dan hanya membuka keluaran plaintext dekripsi ketika tag cocok. Pada reject, tidak ada transfer plaintext. |
| `secure_tiny_top.sv` | Integrasi IP board-independent: command, stream byte, tag, status, busy, done, dan command_error. Parameter `MAX_DATA_BYTES` wajib. |

## Perilaku transaksi top-level

Command berisi `start`, `decrypt`, `key[127:0]`, `nonce[127:0]`, `ad_length[31:0]`, `data_length[31:0]`, serta `received_tag[127:0]` (dipakai untuk dekripsi). Command diterima saat idle. Controller menerima AD lebih dulu lalu data/ciphertext, masing-masing tepat sepanjang panjang yang diumumkan. Panjang nol melewati fase input terkait.

Enkripsi mengeluarkan ciphertext melalui `out_valid/out_ready`; `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau setelah core selesai jika pesan kosong), lalu tag ditahan sampai handshake `tag_ready`. `done` berpulsa setelah tag diterima. Dekripsi memverifikasi tag sebelum `out_valid` dapat menunjukkan plaintext. Hanya dekripsi yang menghasilkan keputusan autentikasi: setelah verifikasi, `auth_result_valid` dan tepat salah satu `accept`/`reject` menjadi aktif dan bertahan sampai `start` saat idle atau reset. Pada reject tidak ada plaintext keluar. `done` satu siklus menandai seluruh plaintext diterima downstream, pesan kosong berhasil diverifikasi, atau dekripsi ditolak.

Jika `ad_length` atau `data_length` melebihi `MAX_DATA_BYTES`, command ditolak segera dengan pulsa `command_error` dan `done`; core tidak dipanggil dan status autentikasi tidak dinyatakan. Start saat busy diabaikan. Reset membatalkan transaksi serta menurunkan busy, valid, status autentikasi, `command_error`, dan `done`.

`MAX_DATA_BYTES` harus positif dan dipilih sesuai batas elaborasi serta sumber daya target. Build awal menetapkan 16. Penggunaan buffer dan resource meningkat dengan kapasitas; angka resource FPGA harus diukur lewat Quartus. Pemanggil bertanggung jawab agar nonce tidak digunakan ulang untuk enkripsi lain dengan key yang sama; IP tidak membuat maupun melacak nonce.

## Belum termasuk interface IP

Protokol bus, DMA, queue, transaksi paralel, transfer parsial berbasis `last`, dan integrasi HPS tidak termasuk top-level ini. File Quartus menetapkan interface IP sebagai virtual pins untuk sintesis. Pemetaan fisik untuk kendali transaksi perlu didefinisikan sebelum uji fungsional dari host pada DE10-Nano.
