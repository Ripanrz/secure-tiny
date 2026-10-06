# Hasil Verifikasi SECURE-TINY

## Validasi ulang untuk proposal final — 6 Oktober 2026

Perintah dan hasil berikut dijalankan ulang pada working tree saat ini, setelah penambahan komentar belajar berbahasa Indonesia. Tidak ada perubahan fungsional RTL pada working tree dibanding sumber RTL regresi 2 Oktober; pemeriksaan ulang dilakukan agar proposal memakai bukti terbaru, bukan menyalin status lama sebagai run baru.

| Tahap | Hasil aktual 6 Okt 2026 | Sebelum/perubahan |
|---|---|---|
| Regresi Icarus + model Python | PASS, 7/7 runner, exit code 0. Core: 2.178 transaksi, 121.308 siklus, maksimum 88; top-level: 578 transaksi, 51.019 siklus, maksimum 150. KAT/ACVP hit count sama dengan run 2 Okt. | Sama dengan run 2 Okt. Kasus ACVP non-byte-aligned tetap dilewati (226/240); bukan sertifikasi ACVP. Log baru `sim/regression_20261006.log`; waveform unit dan top-level dibuat ulang di `sim/`. |
| Advisory simulasi | Icarus mengeluarkan pesan `constant selects in always_* processes are not fully supported`; keterangannya menyatakan proses menjadi peka terhadap semua bit vector terkait. Runner menyelesaikan seluruh assertion dan exit code 0. | Sama jenis advisory dengan run terdahulu; tetap dicatat sebagai keterbatasan tool. |
| Verilator lint | PASS, Verilator 5.053, 0 warning; top-level `secure_tiny_top`, `MAX_DATA_BYTES=16`. | Lint historis 1 Okt juga PASS; log baru `sim/verilator_secure_tiny_16.log`. |
| Yosys generik | PASS, Yosys 0.69+156; `check` melaporkan 0 masalah; 20.937 sel generik. Run kedua yang diulang untuk memastikan hitungan memberikan hasil yang sama. | Catatan 1 Okt sebelumnya 20.887 sel. Selisih +50 belum dapat dijelaskan dari log lama yang sudah dibersihkan; tidak ditafsirkan sebagai perubahan ALM atau regresi FPGA. Log run baru `sim/yosys_secure_tiny_16.log`. |
| Quartus Cyclone V | Full compile PASS, 0 error/5 warning; 2.464 ALM (6% dari 41.910), 2.800 register, 0 RAM/M10K, 0 DSP. Fmax 79,72 MHz untuk clock teranalisis; setup slack +7,456 ns, hold slack +0,338 ns pada slow 1100 mV/100°C. | Sama dengan hasil Quartus 1 Okt. Baru dijalankan ulang pada 6 Okt memakai Quartus Prime Lite 25.1, `5CSEBA6U23I7`, `MAX_DATA_BYTES=16`, clock constraint 50 MHz. |
| Constraint/bitstream | 616 transaction pins tetap virtual. Quartus menyatakan desain belum fully constrained untuk setup/hold I/O. Assembler membuat `.sof` 6.690.378 byte; SHA-256 `D49CD7D1AB67C963D93CC399FCBB4835A818B56F6DA71E43596412F1E20F4112`. Power Analyzer tidak dijalankan karena `FLOW_ENABLE_POWER_ANALYZER` tidak diaktifkan. | Sebelum: `.sof` tercatat 6.690.378 byte dengan SHA-256 berbeda. Berkas konfigurasi bukan bukti telah diprogram ke board. |
| DE10-Nano fisik / software baseline | Tidak diuji; belum ada transaksi board atau benchmark software-versus-RTL pada HPS yang sama. | Tetap belum dilakukan. Tidak ada hasil real-time, daya, atau energi board. |

### Perbandingan sebelum dan sesudah validasi

Fungsi yang disimulasikan, jumlah kasus, siklus testbench, resource Quartus, slack clock, dan Fmax sama antara catatan terdahulu dan validasi 6 Oktober. Validasi ini memperkuat keterulangan baseline, bukan menunjukkan peningkatan performa desain. Satu perbedaan angka, yaitu hitungan sel generik Yosys `20.887 → 20.937`, tidak dipakai sebagai klaim perubahan desain: log terdahulu sudah tidak tersedia untuk audit opsi/seed/tool environment, sedangkan dua run Yosys baru stabil pada 20.937. Metrik FPGA yang relevan di proposal tetap berasal dari laporan Quartus Cyclone V.

Build Quartus tetap menggunakan Auto Fit dan melewatkan optimasi tertentu demi mengurangi waktu kompilasi. Timing Analyzer juga tidak menganalisis 616 port transaksi sebagai pin fisik. Karena itu, `Fmax` serta slack yang tercatat menggambarkan clock/path yang dianalisis, bukan sign-off interface board. Tidak ada pengujian bitstream pada DE10-Nano.

> **Cara membaca angka:** ALM (*Adaptive Logic Module*) dan register menunjukkan sumber daya FPGA yang dipakai pada konfigurasi ini. Fmax adalah frekuensi maksimum yang dilaporkan untuk jalur yang dianalisis; karena pin transaksi masih virtual, angka tersebut belum berarti seluruh masukan/keluaran board sudah memenuhi timing. Analogi sederhananya: kita sudah mengukur kecepatan mesin di dalam bengkel, tetapi belum mengukur seluruh jalur kabel pada pemasangan akhir. Kepanjangan istilah lain ada di [glosarium](glossary.md).

## Regresi simulasi terbaru — 2 Oktober 2026

Kami membersihkan berkas simulasi lama yang dapat dibuat ulang dan cache Python, lalu menjalankan ulang regresi penuh pada source commit `7963afdb650377aa8344f7462f6409217c6cac57`. Perintah: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1`. OSS CAD Suite: `C:\Users\arpan\Downloads\chipset_peruri\oss-cad-suite-windows-x64-20260929\oss-cad-suite`; Icarus Verilog: `14.0 (devel) (s20260301-500-g2e81fcccb-dirty)`; Python: `3.11.6`. Ketujuh runner berakhir dengan kode keluar `0`, dengan ringkasan `PASS: all SECURE-TINY test scripts completed`.

| Hasil terbaru | Bukti yang dibuat ulang |
|---|---|
| Counter, permutasi, dan modul tag/guard | PASS; `sim/counter.vcd`, `sim/ascon_permutation.vcd`, `sim/tag_auth_modules.vcd` |
| KAT core RTL | PASS; 1.089 KAT Ascon-C masing-masing untuk enkripsi dan dekripsi (2.178 transaksi), total 121.308 siklus, maksimum 88 siklus; `sim/ascon_core.vcd` |
| Uji terarah tingkat atas | PASS; pengujian tag/ciphertext/AD salah, plaintext ditahan sampai autentikasi, handshake stall, start ketika sibuk, reset beberapa fase, dan panjang di atas kapasitas; `sim/secure_tiny_top.vcd` |
| Sapuan KAT tingkat atas | PASS; 289 pasangan panjang 0–16 byte, enkripsi dan dekripsi (578 transaksi), total 51.019 siklus, maksimum 150 siklus; `sim/secure_tiny_kat.vcd` |
| Model Python terhadap NIST ACVP | PASS untuk 14 kasus byte-aligned. Checker melewati 226 dari 240 kasus sampel karena panjang bit-nya bukan kelipatan 8; kasus tersebut tidak didukung checker byte-aligned ini. |
| Model Python terhadap KAT Ascon-C | PASS untuk 1.089 kasus bertag penuh, enkripsi dan dekripsi. |
| Regresi keseluruhan | 7/7 runner PASS; 0 runner gagal; 0 runner terlewat; kode keluar `0`. Tidak tersedia total gabungan kasus unik karena sebagian pengujian menggunakan pasangan KAT yang sama pada lapisan berbeda. |

Log konsol terbaru disimpan secara lokal di `sim/regression_20261002.log`; semua waveform di atas dibuat pada run ini. Analisis berkas `sim/secure_tiny_top.vcd` mengonfirmasi dua dekripsi valid hanya menawarkan plaintext setelah ACCEPT dan tiga pengujian perubahan AD/tag/ciphertext menghasilkan REJECT tanpa `out_valid`. Berkas tersebut memuat sinyal clock, reset, start, mode, busy/done, valid/ready, ciphertext/plaintext, tag, hasil verifikasi, status autentikasi, dan fase controller. Waktu siklus waveform ini mencakup uji terarah; hasilnya hanya bukti simulasi RTL.

Icarus menampilkan peringatan `constant selects in always_* processes are not fully supported` pada permutasi/core, dan menjelaskan bahwa proses menjadi peka terhadap semua bit vektor terkait. Seluruh assertion tetap aktif dan run selesai dengan kode 0. Tidak ada source RTL, testbench, nilai KAT, expected result, atau reference model yang diubah pada pengulangan ini.

Kami sebelumnya menjalankan lint Verilator, sintesis Yosys generik, dan build penuh Quartus pada 2026-10-01. Build Quartus untuk Cyclone V berhasil, tetapi pengujian transaksi pada board masih menunggu antarmuka fisik dan akses DE10-Nano. `PASS` (lulus) hanya merujuk pemeriksaan yang benar-benar kami jalankan; status tersebut bukan validasi sertifikasi atau bukti keamanan implementasi fisik. Simulasi terbaru yang dicatat di atas tidak menjalankan ulang lint, Yosys, atau Quartus.

Kami menyimpan VCD dan log di `sim/` sebagai keluaran skrip yang dapat dibuat ulang dan mengecualikannya dari repositori publik. Nama artefak pada tabel menunjukkan lokasi keluaran lokal.

## Lingkungan dan perintah

- Paket alat: OSS CAD Suite for Windows; lokasinya dikonfigurasi melalui `OSS_CAD_SUITE`.
- Quartus Prime Lite 25.1: kami memasangnya di `C:\altera_lite\25.1std`; build melaporkan `25.1std.0 Build 1129 10/21/2025 SC Lite Edition` dan menerima perangkat `5CSEBA6U23I7`.
- Icarus Verilog: `14.0 (devel) (s20260301-500-g2e81fcccb-dirty)`; Yosys: `0.69+156` (`9d0c91b23-dirty`); Verilator: `5.053 devel rev v5.052-119-g014c9820d (mod)`.
- Perintah simulasi: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1` (menjalankan ketujuh skrip pengujian secara berurutan).
- Perintah lint: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16`.
- Perintah sintesis generik: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1 -MaxDataBytes 16`.
- Paket alat menyediakan Python yang digunakan skrip; kedua pemeriksa Python selesai dengan kode keluar 0.

## Hasil yang diamati

| Pemeriksaan | Hasil | Bukti |
|---|---|---|
| Counter pembelajaran | PASS (lulus): reset, aktifkan, tahan, dan limpahan | `tb/tb_counter.sv`; waveform `sim/counter.vcd` |
| Permutasi | PASS (lulus): keluaran state p8 dan p12 serta kendali/kesalahan | `tb/tb_ascon_permutation.sv`; `sim/ascon_permutation.vcd` |
| Core Ascon RTL | PASS (lulus): seluruh 1.089 kasus KAT Ascon-C v1.3.0 diuji langsung pada RTL untuk enkripsi dan dekripsi (2.178 transaksi), termasuk semua kombinasi panjang AD/pesan pada berkas KAT, hingga 32 byte | `tb/tb_ascon_core.sv`; `sim/ascon_core.vcd`; KAT `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt` |
| Pembentuk tag, pemeriksa, dan authentication guard (unit) | PASS (lulus): handshake/penahanan keluaran, pembandingan tag penuh dari masukan tersimpan, ketidakcocokan bit tinggi, keputusan valid/tidak valid, pembersihan, dan reset | `tb/tb_tag_auth_modules.sv`; `sim/tag_auth_modules.vcd` |
| Modul tingkat atas | PASS (lulus): KAT, jeda handshake, kestabilan keluaran saat ditahan, enkripsi/dekripsi, AD saja, pesan penuh 16 byte, tag/ciphertext/AD yang salah ditolak tanpa plaintext, start saat sibuk, reset saat menerima data/core/verifikasi/menunggu keluaran atau tag, serta AD dan data yang masing-masing melebihi kapasitas ditolak dengan pulsa `command_error`/`done` | `tb/tb_secure_tiny_top.sv`; `sim/secure_tiny_top.vcd`; kasus AD menggunakan KAT Ascon-C v1.3.0 Count 35 sebagai kontrol valid, lalu hanya AD diubah |
| KAT pasangan panjang tingkat atas | PASS (lulus): 289 pasangan panjang AD/pesan (masing-masing 0–16 byte), untuk enkripsi dan dekripsi (578 transaksi); transfer diuji melalui antarmuka satu byte tingkat atas dan setiap data/tag dibandingkan dengan KAT | `tb/tb_secure_tiny_kat.sv`; `sim/secure_tiny_kat.vcd`; sumber KAT Ascon-C v1.3.0 |
| Model Python dibandingkan dengan ACVP | PASS (lulus): 14 kasus berukuran kelipatan byte yang dipilih dari sampel NIST ACVP SP 800-232 | `python/check_ascon_acvp_sample.py`; data di `vectors/ascon_aead128_*.json` |
| Model Python dibandingkan dengan KAT | PASS (lulus): seluruh 1.089 kasus bertag penuh dari berkas Ascon-C v1.3.0, enkripsi dan dekripsi | `python/check_ascon_c_kat.py`; berkas KAT di `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt` |
| Lint Verilator modul tingkat atas | PASS (lulus) pada run historis 1 Oktober 2026: elaborasi `secure_tiny_top` dengan `MAX_DATA_BYTES=16`, 9 modul, kode keluar 0 tanpa peringatan. Tidak diulang pada regresi simulasi 2 Oktober. | `scripts/lint_verilator.ps1`; Verilator 5.053; log lokal lama dibersihkan pada 2 Oktober 2026 |
| Sintesis generik | PASS (lulus) pada run historis 1 Oktober 2026: hierarchy/proc/check/synth Yosys; `check` melaporkan 0 masalah. Tidak diulang pada regresi simulasi 2 Oktober. | Konfigurasi `MAX_DATA_BYTES=16`; 20.887 sel generik; log lokal lama dibersihkan pada 2 Oktober 2026 |
| Pemeriksaan portabilitas RTL | Pemeriksaan statis kata kunci primitive/vendor pada `rtl/` tidak menemukan kecocokan; Verilator dan sintesis generik Yosys sebelumnya lulus. Ini hanya pemeriksaan awal, bukan bukti siap ASIC | Sumber `rtl/*.sv`; tidak ada primitive khusus yang dikenal pada jalur RTL saat pemeriksaan |
| LibreLane/ASIC | BELUM DIJALANKAN: `librelane` dan `openroad` tidak ada di PATH; direktori konfigurasi `librelane/`, `asic/`, `openlane/`, dan `config.json` tidak ditemukan di root proyek | Tidak ada flow, PDK, node, timing fisik, DRC/LVS, atau hasil layout yang diverifikasi; pemeriksaan tidak menyimpulkan status seluruh instalasi PDK mesin |
| Percobaan pemetaan Cyclone V dengan Yosys ALM | DIHENTIKAN pada percobaan historis: Yosys berhenti karena assertion internal AIGER2 pada tahap ABC9; tidak menghasilkan angka ALM yang dapat digunakan. Tidak diulang pada regresi simulasi 2 Oktober. | Bukan hasil Quartus dan bukan bukti RTL gagal/lulus untuk perangkat; log lokal lama dibersihkan pada 2 Oktober 2026 |
| Pemeriksaan awal proyek DE10-Nano | PASS (lulus): QPF/QSF/SDC, tujuh sumber RTL, target perangkat, parameter, pin clock/reset, dan constraint 50 MHz konsisten | `scripts/check_quartus_project.ps1` |
| Build penuh Quartus Cyclone V | PASS (lulus): Analysis & Synthesis, Fitter, Assembler, dan Timing Analyzer; kode keluar `0`, 0 error, 5 warning | `quartus/output_files/secure_tiny.flow.rpt`; `quartus/output_files/secure_tiny.done` |
| Pembuatan berkas konfigurasi | PASS (lulus): Assembler membuat `.sof` untuk perangkat target | `quartus/output_files/secure_tiny.sof` (6.690.378 byte; artefak lokal yang dikecualikan Git) |
| Ekstraksi melalui `build_quartus_metrics.ps1` | BELUM DIJALANKAN terpisah: angka di bawah kami baca dari laporan resmi run penuh agar tidak mengulang Fitter | Skrip itu dapat dijalankan terpisah untuk membuat CSV, tetapi menjalankan map/fit/sta lagi |

## Latensi simulasi

Testbench mengukur siklus dari tepi clock saat `start` diterima hingga tepi `done`. Pengujian KAT RTL menggunakan `MAX_DATA_BYTES=32` agar seluruh panjang pada berkas dapat diuji. Hasil pengujian terakhir:

- Core langsung: **2.178 transaksi**, total **121.308 siklus**, maksimum **88 siklus per transaksi** pada keseluruhan suite KAT.
- Modul tingkat atas untuk enkripsi 1 byte dengan penahanan keluaran / AD saja / enkripsi 16 byte melalui aliran data / dekripsi valid / KAT dengan AD valid / penolakan AD berubah / penolakan tag / penolakan ciphertext: **45 / 50 / 96 / 41 / 53 / 53 / 41 / 41 siklus**.
- Sapuan KAT pasangan panjang modul tingkat atas: **578 transaksi**, total **51.019 siklus**, maksimum **150 siklus/transaksi**. Latensi diukur sejak `start` diterima sampai `done` dan mencakup waktu pengiriman AD/pesan melalui handshake.

Pengukuran modul tingkat atas mencakup pengaturan jeda handshake testbench dan penahanan keluaran yang dinyatakan; ini bukan throughput kontinu atau hasil timing FPGA. Testbench core membandingkan byte ciphertext/plaintext dan tag langsung dengan setiap rekaman KAT pada mode enkripsi dan dekripsi. Testbench tingkat atas membandingkan seluruh 289 pasangan panjang hingga kapasitas 16 byte pada kedua mode. Waveform core menyimpan transaksi awal sebagai contoh agar berkas tetap ringkas; waveform tingkat atas dan KAT dibuat ulang oleh testbench saat pengujian.

Regresi pasangan panjang juga menemukan kebuntuan ketika `tag_ready` tinggi sejak awal: tag dapat diterima sebelum pengendali memasuki fase pengiriman tag. Pengendali sekarang baru memuat tag setelah byte ciphertext terakhir diterima; untuk pesan kosong, pengiriman tag dimulai segera setelah core selesai. Seluruh regresi tingkat atas lulus setelah perubahan ini.

Waveform `sim/secure_tiny_top.vcd` dibuat ulang oleh regresi yang mencakup kasus baru. Assertion testbench memastikan dekripsi KAT valid hanya menawarkan plaintext setelah ACCEPT; pada uji AD berubah, nilai yang diubah adalah satu-satunya perbedaan dari kontrol KAT dan transaksi berakhir REJECT tanpa `out_valid`. Pemeriksaan ini terbatas pada simulasi RTL dan skenario yang dicantumkan.

Waveform unit `sim/tag_auth_modules.vcd` diperiksa: pemeriksa mengeluarkan `tag_match` dan `verify_done` pada 65000 ps untuk tag yang sama, serta `tag_mismatch` dan `verify_done` pada 95000 ps untuk tag yang berbeda; guard mengeluarkan `accept`/`plaintext_allowed` pada 135000 ps dan `reject` tanpa izin plaintext pada 165000 ps. Pembentuk tag mempertahankan `tag_valid` selama keluaran ditahan dan membersihkannya setelah handshake.

Icarus mencetak peringatan `constant selects in always_* processes are not fully supported`; simulator menyatakan proses akan peka terhadap seluruh vektor terkait. Seluruh pengujian tetap selesai dengan status PASS. Sintesis Yosys yang dijalankan ulang berakhir dengan kode keluar 0; statistik akhir dan `check` melaporkan 0 masalah.

## Identitas data vektor

Sumber NIST ACVP: `usnistgov/ACVP-Server`, direktori `gen-val/json-files/Ascon-AEAD128-SP800-232` (prompt dan expectedResults; sampel berlabel `isSample=true`). Nilai SHA-256 lokal:

- `vectors/ascon_aead128_prompt.json`: `717D20C79ABDB55CF3AFAFAC6322172EB4E2B8288148D6B8C0B5CA73B75DD357`
- `vectors/ascon_aead128_expected.json`: `413D9E1524CDB1F3DE5ECDD2592474EB2026904C5D1EF6099355F944CFB33235`

Sumber KAT tambahan: tag `v1.3.0` dari `ascon/ascon-c`, berkas `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`; SHA-256 `6A5B08DDD81C0B4858D39A5572F2F81590B82F4A22FC72C6E67FE505248A6949`.

## Hasil pembuatan untuk papan dan batas pengujian

Kami menjalankan build penuh pada Cyclone V `5CSEBA6U23I7`, `MAX_DATA_BYTES=16`, dan clock `FPGA_CLK1_50` berperiode 20 ns. Karena Quartus/Tcl salah menormalisasi direktori kerja proyek saat kami menjalankannya dari `Downloads`, kami memetakan working tree ke drive sementara `R:` dengan `subst`; build kedua memakai berkas proyek yang sebenarnya dan berhasil. Fitter melaporkan Auto Fit.

Perintah yang kami gunakan untuk mengulang build dari root proyek:

```powershell
subst R: 'C:\Users\arpan\Downloads\chipset_peruri\secure-tiny'
Push-Location R:\quartus
try {
    powershell.exe -NoProfile -ExecutionPolicy Bypass -File R:\scripts\build_quartus.ps1 -QuartusSh 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe'
} finally {
    Pop-Location
    subst R: /d
}
```

| Metrik/hasil | Nilai laporan Quartus | Bukti |
|---|---:|---|
| ALM setelah Fitter | 2.464 / 41.910 (6%) | `quartus/output_files/secure_tiny.fit.summary` |
| Register | 2.800 | `quartus/output_files/secure_tiny.fit.summary` |
| Memori blok / RAM | 0 bit / 0 M10K | `quartus/output_files/secure_tiny.fit.summary` |
| DSP | 0 | `quartus/output_files/secure_tiny.fit.summary` |
| Fmax `FPGA_CLK1_50`, slow 1100 mV 100°C | 79,72 MHz | `quartus/output_files/secure_tiny.sta.rpt`, Fmax Summary |
| Setup slack terburuk, slow 1100 mV 100°C | +7,456 ns | `quartus/output_files/secure_tiny.sta.summary` |
| Hold slack terburuk, slow 1100 mV 100°C | +0,338 ns | `quartus/output_files/secure_tiny.sta.summary` |
| Berkas `.sof` | Dibuat, 6.690.378 byte | `quartus/output_files/secure_tiny.sof` |

SHA-256 `.sof`: `CF070C96D2A23C1ABEB9943FEB864250918783A26675298867D09B14456AD342`.

Fmax 79,72 MHz adalah hasil timing untuk jalur yang dianalisis Quartus, bukan bukti performa pada board. Timing Analyzer menyatakan desain belum sepenuhnya constrained untuk setup maupun hold karena 616 port transaksi adalah virtual pins dan tidak memiliki batasan input/output fisik. Clock internal 50 MHz menunjukkan setup slack positif, tetapi hasil ini belum menjadi sign-off timing I/O untuk integrasi DE10-Nano. Kami juga belum mengukur daya atau throughput fisik.

Jumlah 20.887 sel adalah hasil pemetaan generik Yosys dan berbeda makna dari 2.464 ALM Quartus; kami tidak membandingkan keduanya sebagai metrik yang setara.

Quartus menyelesaikan Analysis & Synthesis, Fitter, Assembler, dan Timing Analyzer dengan kode keluar 0. Rangkuman flow mencatat 0 error dan 5 warning; peringatan log mencakup jumlah prosesor yang tidak ditetapkan dan fitur LogicLock yang memerlukan lisensi subscription. Timing Analyzer juga mencatat bahwa constraint setup/hold belum lengkap. Kami tidak menafsirkan status sukses ini sebagai uji board.

Jumlah 20.887 sel adalah hasil pemetaan generik Yosys, bukan jumlah ALM/LE Cyclone V, sehingga tidak boleh digunakan sebagai klaim penggunaan sumber daya FPGA.

Pada pengulangan sintesis Yosys 1 Oktober 2026, proses berakhir dengan kode keluar 0, menghasilkan 20.887 sel generik, dan `check` melaporkan 0 masalah. Keluaran ABC juga memuat satu pesan akses berkas sementara yang sedang dipakai proses lain; sintesis tetap menyelesaikan seluruh tahap dan menghasilkan laporan akhir. Pesan itu merupakan peringatan lingkungan Windows, bukan metrik FPGA.
