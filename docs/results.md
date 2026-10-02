# Hasil Verifikasi SECURE-TINY

> **Cara membaca angka:** ALM (*Adaptive Logic Module*) dan register menunjukkan sumber daya FPGA yang dipakai pada konfigurasi ini. Fmax adalah frekuensi maksimum yang dilaporkan untuk jalur yang dianalisis; karena pin transaksi masih virtual, angka tersebut belum berarti seluruh masukan/keluaran board sudah memenuhi timing. Analogi sederhananya: kita sudah mengukur kecepatan mesin di dalam bengkel, tetapi belum mengukur seluruh jalur kabel pada pemasangan akhir. Kepanjangan istilah lain ada di [glosarium](glossary.md).

Kami menjalankan ulang regresi simulasi utama, lint Verilator, sintesis Yosys generik, dan build penuh Quartus pada 2026-10-01. Build Quartus untuk Cyclone V berhasil, tetapi pengujian transaksi pada board masih menunggu antarmuka fisik dan akses DE10-Nano. `PASS` (lulus) hanya merujuk pemeriksaan yang benar-benar kami jalankan; status tersebut bukan validasi sertifikasi atau bukti keamanan implementasi fisik.

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
| Lint Verilator modul tingkat atas | PASS (lulus): elaborasi `secure_tiny_top` dengan `MAX_DATA_BYTES=16`, 9 modul, kode keluar 0 tanpa peringatan | `scripts/lint_verilator.ps1`; Verilator 5.053; `sim/verilator_secure_tiny_16.log` |
| Sintesis generik | PASS (lulus): hierarchy/proc/check/synth Yosys; `check` melaporkan 0 masalah | `sim/yosys_secure_tiny_16.log`; konfigurasi `MAX_DATA_BYTES=16`; 20.887 sel generik |
| Pemeriksaan portabilitas RTL | Pemeriksaan statis kata kunci primitive/vendor pada `rtl/` tidak menemukan kecocokan; Verilator dan sintesis generik Yosys sebelumnya lulus. Ini hanya pemeriksaan awal, bukan bukti siap ASIC | Sumber `rtl/*.sv`; tidak ada primitive khusus yang dikenal pada jalur RTL saat pemeriksaan |
| LibreLane/ASIC | BELUM DIJALANKAN: `librelane` dan `openroad` tidak ada di PATH; direktori konfigurasi `librelane/`, `asic/`, `openlane/`, dan `config.json` tidak ditemukan di root proyek | Tidak ada flow, PDK, node, timing fisik, DRC/LVS, atau hasil layout yang diverifikasi; pemeriksaan tidak menyimpulkan status seluruh instalasi PDK mesin |
| Percobaan pemetaan Cyclone V dengan Yosys ALM | DIHENTIKAN: Yosys berhenti karena assertion internal AIGER2 pada tahap ABC9; tidak menghasilkan angka ALM yang dapat digunakan | `sim/yosys_cyclonev_16.log`; bukan hasil Quartus dan bukan bukti RTL gagal/lulus untuk perangkat |
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
