# Rencana Verifikasi SECURE-TINY

> **Ringkasan untuk pembaca baru:** testbench adalah program yang bertindak seperti pengguna chip: memberi masukan, lalu memeriksa jawaban. KAT (*Known Answer Test*) ibarat lembar soal dengan kunci jawaban tepercaya. Lulus simulasi berarti model RTL memberikan hasil yang diharapkan pada kasus yang diuji; itu sendiri bukan bukti chip fisik atau sertifikasi. Lihat [glosarium](glossary.md) untuk kepanjangan istilah.

## Catatan eksekusi terbaru

Pada **2 Oktober 2026 sekitar 08.42 WIB**, kami membersihkan hasil simulasi dan cache Python yang dapat dibuat ulang, lalu menjalankan seluruh regresi pada source commit `7963afdb650377aa8344f7462f6409217c6cac57`. Perintah yang dijalankan ialah `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1` dengan OSS CAD Suite dari variabel `OSS_CAD_SUITE`. Seluruh **7 dari 7 runner** selesai dengan kode keluar 0; log run tersimpan lokal di `sim/regression_20261002.log`.

Run itu menghasilkan ulang VCD dan berkas kompilasi Icarus di `sim/`. Analisis VCD tingkat atas menemukan clock, reset, start, mode, busy/done, handshake data, keluaran, tag, hasil autentikasi, ACCEPT, REJECT, dan fase controller. Untuk transaksi terarah, dua dekripsi valid baru menawarkan plaintext ketika hasil autentikasi menyatakan ACCEPT. Tiga dekripsi dengan AD, tag, atau ciphertext yang diubah menyatakan REJECT tanpa `out_valid`. Pemeriksaan ini adalah analisis berkas waveform hasil simulasi, bukan pengujian fisik.

| Bagian yang dijalankan | Hasil eksekusi 2 Oktober 2026 |
|---|---|
| Counter, permutasi, dan unit tag/guard | PASS; pemeriksaan reset/hitung, p8/p12 dan kendali permutasi, handshake pembentuk tag, pembanding tag penuh, serta keputusan guard selesai tanpa `$fatal`. |
| KAT core RTL | PASS; 1.089 rekaman KAT Ascon-C pada enkripsi dan dekripsi, total 2.178 transaksi; total 121.308 siklus, maksimum 88 siklus. |
| Uji terarah top-level | PASS; valid decrypt, penolakan perubahan AD/tag/ciphertext tanpa plaintext, stall/backpressure, start saat sibuk, reset pada tahap menerima/core/verifikasi/menunggu keluaran/tag, dan panjang AD/pesan di atas kapasitas. |
| Sapuan KAT top-level | PASS; 289 pasangan panjang AD/pesan 0–16 byte pada enkripsi dan dekripsi, total 578 transaksi; total 51.019 siklus, maksimum 150 siklus. Ini mencakup AD kosong, pesan kosong, dan panjang maksimum antarmuka. |
| Model Python terhadap ACVP | PASS untuk 14 kasus byte-aligned. Dari 240 kasus dalam berkas sampel, 226 kasus non-byte-aligned sengaja tidak dijalankan oleh checker Python saat ini; jadi angka ini bukan hasil seluruh 240 kasus dan bukan validasi ACVP resmi. |
| Model Python terhadap KAT Ascon-C | PASS; 1.089 kasus bertag penuh, masing-masing diuji untuk enkripsi dan dekripsi. |
| Kegagalan / runner terlewat | 0 kegagalan dan 0 runner terlewat. Runner tidak menyediakan satu total gabungan untuk semua pemeriksaan internal, sehingga kami melaporkan hitungan transaksi per suite agar tidak menjumlahkan kasus yang saling tumpang tindih. |

Icarus Verilog yang digunakan adalah `14.0 (devel) (s20260301-500-g2e81fcccb-dirty)` dan Python OSS CAD Suite `3.11.6`. Icarus mengeluarkan pesan peringatan bahwa `constant selects in always_*` tidak didukung sepenuhnya; pesannya menyatakan sensitivitas diperluas ke seluruh vektor terkait. Tidak ada testbench yang diubah untuk run ini, tidak ada perubahan RTL, KAT, expected result, atau model referensi, dan tidak ada testbench yang dinyatakan lulus hanya berdasarkan kompilasi.

## Rujukan kriptografi

Kami menggunakan Ascon-AEAD128 dalam **NIST SP 800-232 final, Agustus 2025** sebagai acuan normatif: [halaman publikasi NIST](https://csrc.nist.gov/pubs/sp/800/232/final), [PDF final](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-232.pdf). Kami tidak mencampur vektor dari spesifikasi submission Ascon terdahulu dengan standar final.

Kami memakai pasangan `prompt.json` dan `expectedResults.json` dari set vektor resmi NIST ACVP di direktori [Ascon-AEAD128-SP800-232](https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232). Format kasusnya: `algorithm=Ascon`, `mode=AEAD128`, `revision=SP800-232`. Kami menyimpan sampel ACVP di `vectors/ascon_aead128_prompt.json` dan `vectors/ascon_aead128_expected.json`; pemeriksa Python membandingkan kasus berukuran kelipatan byte dengan hasil NIST. Pemeriksaan ini menguji model referensi Python, sedangkan testbench RTL memakai KAT tetap. Untuk uji diferensial tambahan, kami memakai KAT dari hulu [ascon/ascon-c v1.3.0](https://github.com/ascon/ascon-c/tree/v1.3.0), berkas `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`. Nama `ascon128av13` merujuk implementasi Ascon-AEAD128 NIST SP 800-232 pada rilis v1.3.0; KAT ini merupakan tambahan dan bukan pengganti vektor ACVP normatif. Kami tidak menyalin implementasi tersebut ke RTL atau mengubah nilai harapan tanpa sumber.

## Tahapan dan bukti

| Tahap | Pemeriksaan minimum | Bukti yang dicatat |
|---|---|---|
| Lint RTL | Jalankan Verilator `--lint-only` pada modul tingkat atas dengan parameter build target | Versi alat, perintah, kode keluar, seluruh peringatan/kesalahan |
| Pembelajaran counter/FSM | Kompilasi dan simulasi perilaku hitung/state/reset | Perintah, log, assertion/pemeriksaan, waveform VCD |
| Permutasi | Uji operasi ronde yang dipakai AEAD dan beberapa state uji terpilih dari sumber tepercaya | Versi rujukan, kasus, masukan/keluaran, log, waveform |
| Core dan pengendali | Panjang 0, parsial, batas blok rate, KAT enkripsi/dekripsi langsung di RTL, handshake, jeda, start saat sibuk, reset | Hasil per kasus dan waveform sinyal kendali/data; core menjalankan seluruh 1.089 rekaman KAT Ascon-C hingga 32 byte |
| Penanganan tag dan guard | Penahanan keluaran pembentuk tag, perbandingan tag penuh, hasil cocok/tidak cocok, keputusan guard, pembersihan dan reset | `tb/tb_tag_auth_modules.sv` dan `sim/tag_auth_modules.vcd` |
| Integrasi tingkat atas | Seluruh 289 pasangan panjang AD/pesan 0–16 byte dari KAT, enkripsi/dekripsi melalui aliran data, urutan ciphertext-tag, keluaran plaintext setelah autentikasi | `tb/tb_secure_tiny_kat.sv`, total 578 transaksi, serta `sim/secure_tiny_kat.vcd` |
| AEAD tingkat atas | KAT enkripsi dan dekripsi terhadap pembanding; AD/pesan kosong dan panjang parsial | Identitas vektor, keluaran RTL, keluaran rujukan, hasil perbandingan |
| Authentication Guard | Tag benar diterima; tag salah, ciphertext berubah, dan AD berubah ditolak; tidak ada keluaran plaintext valid saat ditolak | Status accept/reject, jumlah byte keluaran, waveform; kasus AD memakai KAT Ascon-C Count 35 sebagai kontrol valid dan mengubah AD saja |
| Ketahanan kendali | Reset saat menerima data, core aktif, verifikasi tag aktif, data keluaran tertahan, dan tag menunggu handshake; AD/data melebihi kapasitas; penahanan keluaran; urutan start/busy/done | `tb/tb_secure_tiny_top.sv`; assertion/log dan `sim/secure_tiny_top.vcd` |
| Sintesis target | Elaborasi/sintesis Quartus dengan nilai `MAX_DATA_BYTES` tercatat | Versi alat, perangkat DE10-Nano, laporan resource/timing aktual |

Status pengujian dicatat di [`results.md`](results.md). Jalankan lint dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16`, rangkaian simulasi dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1`, dan sintesis Yosys generik dengan `scripts/synth_yosys.ps1 -MaxDataBytes 16`. Build Quartus memerlukan Quartus Prime terpasang dan `quartus_sh` tersedia di PATH atau diberikan melalui `-QuartusSh` (`scripts/build_quartus.ps1`).

Kompilasi saja tidak cukup untuk menyatakan PASS. PASS hanya boleh dicatat jika pemeriksaan dan perbandingan yang disyaratkan benar-benar dijalankan. Kegagalan testbench atau ketidakcocokan vektor harus dicatat sebagai FAIL, bukan diperbaiki dengan mengubah nilai harapan tanpa sumber baru.

Waveform minimum untuk transaksi AEAD: `clk`, `rst_n`, `start`, `busy`, masukan `valid/ready/data`, panjang, fase pengendali, permintaan/penyelesaian permutasi, `tag_valid`, status autentikasi, keluaran `valid/ready/data`, dan `done`. Berkas hasil sintesis atau waveform merupakan artefak pengujian; jangan mengklaim metrik yang tidak tercantum dalam laporan aktual.

## Batas klaim

Vektor ACVP untuk uji informal tidak dengan sendirinya menyatakan validasi sertifikasi. Pengujian fungsional tidak membuktikan keamanan implementasi terhadap side-channel, injeksi kesalahan, atau seluruh kondisi fisik. Laporkan hanya hasil yang benar-benar diamati.

## Verifikasi security-by-design

Setiap properti keamanan harus ditautkan ke aset, batas interface, dan bukti pengujian. Status berikut merangkum implementasi saat ini; “sudah diuji” hanya berarti skenario yang tercatat di `docs/results.md`.

| Invarian/keputusan | Bukti yang diperlukan | Status sekarang |
|---|---|---|
| Plaintext dekripsi tidak tersedia sebelum tag cocok | Assertion/waveform urutan verifikasi dan handshake output | Diuji pada skenario integrasi tercatat |
| Tag/ciphertext salah tidak menghasilkan transfer plaintext | Test negatif menghitung transfer output dan memeriksa REJECT | Diuji pada skenario terarah tercatat |
| Panjang di luar kapasitas dan reset tidak membuka plaintext | Uji reset/error di tiap fase dan hitung transfer output | Reset/error tertentu tercatat; bukan evaluasi fisik |
| Keunikan nonce untuk key yang sama | Kontrak caller dan dokumentasi batas IP | Tanggung jawab caller; IP tidak menyimpan riwayat nonce |
| Key/calon plaintext dibersihkan pada akhir transaksi | Inventaris register, pengujian clear untuk sukses/reject/error/reset, dan regresi KAT setelah clear | Belum diimplementasikan/diukur sebagai lifecycle property |
| Side-channel, fault injection, tamper fisik | Threat model dan pengukuran serangan/countermeasure yang sesuai | Di luar cakupan bukti saat ini; tidak boleh diklaim |

Security-by-design tidak berarti seluruh threat sudah dimitigasi. Untuk menambahkan clear key/data atau staging privat, terlebih dahulu tetapkan sinyal/status dan semua jalur terminal, jelaskan perubahan RTL, lalu tambahkan testbench sebelum menulis klaim keberhasilan.

## Gerbang untuk perubahan arsitektur mendatang

Daftar ini adalah rencana verifikasi untuk perubahan yang belum diterapkan. Jangan menandai item sebagai lulus sebelum testbench dan run aktual tersedia.

### Sebelum mengubah RTL

1. Bekukan commit baseline dan catat parameter, perintah regresi, versi tool, dan hasil Quartus jika sudah tersedia.
2. Tuliskan hipotesis terukur, misalnya jumlah register turun pada kapasitas tertentu dengan KAT tetap cocok.
3. Tentukan apakah kontrak port berubah. Bila berubah, perbarui PRD/spesifikasi port dan semua pemanggil/testbench terkait sebelum menyatakan antarmuka stabil.

### Jika controller/core diubah menjadi streaming

- Uji AD kosong, pesan kosong, panjang parsial, batas blok rate, beberapa blok, dan panjang maksimum yang dikonfigurasi.
- Uji stall pada input AD, input pesan, output data, dan output tag; data serta `valid` harus bertahan sampai handshake.
- Uji urutan fase AD lalu pesan, panjang yang tidak cocok dengan jumlah transfer, reset pada setiap fase, dan transaksi berikutnya setelah sukses/reject.
- Untuk dekripsi, assertion harus memastikan tidak ada handshake plaintext sebelum verifikasi tag berhasil. Pada AD/tag/ciphertext salah, jumlah byte plaintext keluar harus nol.
- Jika plaintext ditampung di staging, uji bahwa staging tidak dapat diamati dari interface sebelum commit dan dibatalkan/dibersihkan saat reject sesuai kontrak yang didefinisikan.
- Jika memakai verifikasi lalu dekripsi dua tahap, uji agar ciphertext/AD yang dipakai tahap kedua identik dengan yang diverifikasi; perubahan input di antaranya harus mustahil atau ditolak.

### Jika lifecycle key/data diubah

- Identifikasi semua register yang menyimpan key, state turunan, ciphertext, dan calon plaintext.
- Uji clear pada sukses, reject, reset, error, serta pembatalan transaksi jika pembatalan ditambahkan.
- Buktikan transaksi berikutnya tetap cocok dengan KAT setelah clear.
- Klaim hanya pembersihan register RTL yang diuji. Jangan menyebutnya penghapusan aman terhadap serangan fisik tanpa metode pengujian yang sesuai.

### Perbandingan PPA

Baseline dan kandidat harus memakai device `5CSEBA6U23I7`, versi Quartus yang sama, SDC yang sama, nilai `MAX_DATA_BYTES` yang sama, serta konfigurasi compile yang setara. Catat ALM, register, memori, Fmax/slack, dan siklus transaksi. Angka lintas device, tool, parameter, atau standar Ascon yang berbeda tidak boleh disajikan sebagai perbandingan langsung.
