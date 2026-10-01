# Spesifikasi Modul RTL SECURE-TINY

Kontrak ini mencerminkan implementasi RTL saat ini. Semua modul sekuensial menggunakan `clk` dan reset aktif-rendah sinkron `rst_n`. Key, nonce, dan tag masing-masing 128 bit sesuai Ascon-AEAD128 NIST SP 800-232 final. Parameter `MAX_DATA_BYTES` wajib ditentukan saat elaborasi dan membatasi panjang AD dan pesan secara terpisah.

## Konvensi interface

Input dan output AD/pesan menggunakan satu byte per transfer. Transfer terjadi pada tepi naik ketika `valid && ready`. Sumber data mempertahankan `valid` dan `data` hingga transfer. Panjang operasi adalah jumlah byte unsigned 32-bit dan tidak ada sinyal `last`; controller berhenti menerima setelah jumlah yang dinyatakan tercapai. Untuk semua vektor packed, byte indeks 0 berada pada `[7:0]`.

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

Enkripsi mengeluarkan ciphertext melalui `out_valid/out_ready`; `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau setelah core selesai jika pesan kosong), lalu tag ditahan sampai handshake `tag_ready`. Dekripsi memverifikasi tag sebelum `out_valid` dapat menunjukkan plaintext. Status `auth_result_valid` dan salah satu `accept`/`reject` berlaku setelah verifikasi dan bertahan sampai perintah berikutnya atau reset. Pada reject tidak ada plaintext keluar. `done` satu siklus menandai seluruh hasil sudah dikonsumsi downstream atau dekripsi ditolak.

Jika `ad_length` atau `data_length` melebihi `MAX_DATA_BYTES`, command ditolak segera dengan pulsa `command_error` dan `done`; core tidak dipanggil dan status autentikasi tidak dinyatakan. Start saat busy diabaikan. Reset membatalkan transaksi serta menurunkan busy, valid, status autentikasi, `command_error`, dan `done`.

`MAX_DATA_BYTES` harus positif dan dipilih sesuai batas elaborasi serta sumber daya target. Build awal menetapkan 16. Penggunaan buffer dan resource meningkat dengan kapasitas; angka resource FPGA harus diukur lewat Quartus.

## Belum termasuk interface IP

Protokol bus, DMA, queue, transaksi paralel, transfer parsial berbasis `last`, dan integrasi HPS tidak termasuk top-level ini. File Quartus menetapkan interface IP sebagai virtual pins untuk sintesis. Pemetaan fisik untuk kendali transaksi perlu didefinisikan sebelum uji fungsional dari host pada DE10-Nano.
