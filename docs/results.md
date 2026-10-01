# Hasil Verifikasi SECURE-TINY

Regression simulasi utama, Verilator lint, dan sintesis Yosys generik dijalankan ulang pada 2026-10-01; percobaan build Quartus juga diperiksa pada tanggal tersebut. `PASS` hanya merujuk pemeriksaan yang benar-benar dijalankan; bukan validasi sertifikasi atau bukti keamanan implementasi fisik.

VCD dan log di `sim/` adalah output runner yang dapat dibuat ulang dan dikecualikan dari repository publik. Nama artefak pada tabel adalah lokasi output lokal; jalankan command yang dicantumkan untuk membuatnya kembali.

## Lingkungan dan perintah

- Tool suite: OSS CAD Suite for Windows; lokasi dikonfigurasi melalui `OSS_CAD_SUITE`.
- Icarus Verilog: `14.0 (devel) (s20260301-500-g2e81fcccb-dirty)`; Yosys: `0.69+156` (`9d0c91b23-dirty`); Verilator: `5.053 devel rev v5.052-119-g014c9820d (mod)`.
- Command simulasi: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1` (menjalankan ketujuh test script satu demi satu).
- Command lint: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16`.
- Command sintesis generik: `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1 -MaxDataBytes 16`.
- Suite menyediakan Python yang dipakai runner; kedua checker Python selesai dengan exit code 0.

## Hasil yang diamati

| Pemeriksaan | Hasil | Bukti |
|---|---|---|
| Counter pembelajaran | PASS: reset, enable, hold, wrap | `tb/tb_counter.sv`; waveform `sim/counter.vcd` |
| Permutasi | PASS: output state p8 dan p12 serta kontrol/error | `tb/tb_ascon_permutation.sv`; `sim/ascon_permutation.vcd` |
| Ascon core RTL | PASS: seluruh 1.089 kasus KAT Ascon-C v1.3.0 diuji langsung di RTL untuk enkripsi dan dekripsi (2.178 transaksi), termasuk semua kombinasi panjang AD/pesan pada file KAT, hingga 32 byte | `tb/tb_ascon_core.sv`; `sim/ascon_core.vcd`; KAT `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt` |
| Tag generator, verifier, authentication guard (unit) | PASS: handshake/backpressure, pembandingan tag penuh dari input latched, mismatch bit tinggi, keputusan valid/invalid, clear, dan reset | `tb/tb_tag_auth_modules.sv`; `sim/tag_auth_modules.vcd` |
| Top-level | PASS: KAT, stall handshake, output stabil saat backpressure, encrypt/decrypt, AD-only, pesan penuh 16 byte, tag/ciphertext salah ditolak tanpa plaintext, start saat busy, reset saat menerima data/core/verifikasi/menunggu output atau tag, serta AD dan data yang masing-masing melebihi kapasitas ditolak dengan pulsa `command_error`/`done` | `tb/tb_secure_tiny_top.sv`; `sim/secure_tiny_top.vcd` |
| Top-level length-pair KAT | PASS: 289 pasangan panjang AD/pesan (masing-masing 0–16 byte), untuk encrypt dan decrypt (578 transaksi); transfer diuji melalui interface byte-wide top-level dan setiap data/tag dibandingkan ke KAT | `tb/tb_secure_tiny_kat.sv`; `sim/secure_tiny_kat.vcd`; sumber KAT Ascon-C v1.3.0 |
| Model Python vs ACVP | PASS: 14 kasus byte-aligned yang dipilih dari sampel NIST ACVP SP 800-232 | `python/check_ascon_acvp_sample.py`; data di `vectors/ascon_aead128_*.json` |
| Model Python vs KAT | PASS: seluruh 1.089 kasus full-tag file Ascon-C v1.3.0, enkripsi dan dekripsi | `python/check_ascon_c_kat.py`; file KAT di `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt` |
| Verilator lint top-level | PASS: elaborasi `secure_tiny_top` dengan `MAX_DATA_BYTES=16`, 9 modul, exit code 0 tanpa warning | `scripts/lint_verilator.ps1`; Verilator 5.053; `sim/verilator_secure_tiny_16.log` |
| Sintesis generik | PASS: hierarchy/proc/check/synth Yosys, `check` melaporkan 0 masalah | `sim/yosys_secure_tiny_16.log`; konfigurasi `MAX_DATA_BYTES=16`; 20.887 sel generik |
| Percobaan pemetaan Cyclone V via Yosys ALM | ABORTED: Yosys berhenti pada internal assertion AIGER2 di tahap ABC9; tidak menghasilkan angka ALM yang dapat digunakan | `sim/yosys_cyclonev_16.log`; bukan hasil Quartus dan bukan bukti RTL gagal/lulus untuk perangkat |
| Preflight project DE10-Nano | PASS: QPF/QSF/SDC, tujuh sumber RTL, target device, parameter, pin clock/reset, dan constraint 50 MHz konsisten | `scripts/check_quartus_project.ps1` |
| Quartus DE10-Nano | BELUM DIJALANKAN: `quartus_sh` tidak ditemukan di PATH maupun lokasi instalasi umum yang diperiksa | 2026-10-01: `scripts/build_quartus.ps1` preflight PASS, lalu keluar 1 karena Quartus tidak ditemukan; compile FPGA tidak berjalan |
| Runner Quartus metrik | BLOCKED: parser PowerShell valid dan preflight PASS; `quartus_map`, `quartus_fit`, dan `quartus_sta` tidak ditemukan, runner keluar 2 sebelum compile | `scripts/build_quartus_metrics.ps1`; tidak ada report Quartus yang diproses dan tidak ada metrik baru; parser report belum dapat dicocokkan terhadap output Quartus aktual |

## Latensi simulasi

Testbench mengukur siklus dari tepi clock saat `start` diterima hingga tepi `done`. Run KAT RTL menggunakan `MAX_DATA_BYTES=32` agar seluruh panjang pada file dapat diuji. Hasil run terakhir:

- Core langsung: **2.178 transaksi**, total **121.308 siklus**, maksimum **88 siklus per transaksi** pada keseluruhan suite KAT.
- Top-level untuk encrypt 1 byte dengan backpressure / AD-only / encrypt 16 byte via stream / decrypt valid / reject tag / reject ciphertext: **45 / 50 / 96 / 41 / 41 / 41 siklus**.
- Top-level KAT length-pair sweep: **578 transaksi**, total **51.019 siklus**, maksimum **150 siklus/transaksi**. Latensi diukur dari `start` diterima sampai `done` dan mencakup waktu pengiriman AD/pesan melalui handshake.

Pengukuran top-level mencakup pacing handshake testbench dan stall output yang dinyatakan; ini bukan throughput kontinu atau hasil timing FPGA. Testbench core membandingkan byte ciphertext/plaintext dan tag langsung terhadap setiap record KAT, untuk mode enkripsi dan dekripsi. Testbench top-level membandingkan seluruh 289 length pair hingga kapasitas 16 byte pada kedua mode. Waveform core menyimpan transaksi awal sebagai contoh agar file tetap ringkas; waveform top-level dan KAT dibuat ulang oleh testbench pada run tersebut.

Length-pair regression juga menangkap deadlock ketika `tag_ready` tinggi sejak awal: tag sebelumnya dapat di-consume sebelum controller masuk ke fase pengiriman tag. Controller sekarang baru memuat tag setelah byte ciphertext terakhir diterima; pesan kosong memulai pengiriman tag segera setelah core selesai. Seluruh regression top-level lulus setelah perubahan ini.

Trace event dari `sim/secure_tiny_top.vcd` juga diperiksa: pada dekripsi valid, `auth_result_valid` dan `accept` naik pada saat plaintext `out_valid` pertama kali naik (2355000 ps); pada transaksi tag/ciphertext yang dimodifikasi, `reject` naik tanpa adanya pulsa `out_valid` (2775000 ps dan 3195000 ps). `done` muncul setelah status hasil pada transaksi tersebut. Ini konsisten dengan assertion di testbench yang melarang plaintext sebelum verifikasi dan pada reject.

Waveform unit `sim/tag_auth_modules.vcd` diperiksa: verifier mengeluarkan `tag_match` dan `verify_done` pada 65000 ps untuk tag sama, serta `tag_mismatch` dan `verify_done` pada 95000 ps untuk mismatch; guard mengeluarkan `accept`/`plaintext_allowed` pada 135000 ps dan `reject` tanpa izin plaintext pada 165000 ps. Generator menahan `tag_valid` selama backpressure dan membersihkannya setelah handshake.

Icarus mencetak peringatan `constant selects in always_* processes are not fully supported`; simulator menyatakan proses akan sensitif terhadap seluruh vektor terkait. Seluruh test tetap selesai PASS. Sintesis Yosys yang dijalankan ulang berakhir exit code 0, dengan statistik akhir dan `check` melaporkan 0 masalah.

## Identitas data vector

Sumber NIST ACVP: `usnistgov/ACVP-Server`, direktori `gen-val/json-files/Ascon-AEAD128-SP800-232` (prompt dan expectedResults; sampel berlabel `isSample=true`). SHA-256 lokal:

- `vectors/ascon_aead128_prompt.json`: `717D20C79ABDB55CF3AFAFAC6322172EB4E2B8288148D6B8C0B5CA73B75DD357`
- `vectors/ascon_aead128_expected.json`: `413D9E1524CDB1F3DE5ECDD2592474EB2026904C5D1EF6099355F944CFB33235`

Sumber supplemental KAT: `ascon/ascon-c` tag `v1.3.0`, `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`; SHA-256 `6A5B08DDD81C0B4858D39A5572F2F81590B82F4A22FC72C6E67FE505248A6949`.

## Build papan dan batas hasil

Proyek Quartus disiapkan untuk Cyclone V `5CSEBA6U23I7`, parameter 16 byte, clock 50 MHz, dan virtual pins bagi interface IP. `scripts/check_quartus_project.ps1` memeriksa konsistensi file dan jalur secara lokal; pemeriksaan statis ini tidak membuktikan QSF/SDC diterima oleh Quartus. Quartus tidak terpasang/tersedia di sesi ini. Virtual pins juga tidak memberi jalur host untuk menguji transaksi pada papan.

- Resource FPGA Cyclone V: `TBD - belum diukur`.
- Fmax/timing FPGA: `TBD - belum diukur`.
- Bitstream `.sof`/programming file: `TBD - belum dibuat`.
- Uji pada papan DE10-Nano: `TBD - belum dilakukan`.
- Integrasi Avalon/HPS atau pemetaan pin interface transaksi: belum didefinisikan/diimplementasikan.

Jumlah 20.887 sel adalah hasil mapping generik Yosys, bukan jumlah ALM/LE Cyclone V dan tidak boleh dipakai sebagai klaim resource FPGA.
