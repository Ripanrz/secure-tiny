# Hasil Verifikasi SECURE-TINY

Regresi simulasi utama, lint Verilator, dan sintesis Yosys generik dijalankan ulang pada 2026-10-01, termasuk pengulangan setelah audit dokumentasi; percobaan build Quartus yang lebih lama tercatat pada tanggal yang sama. Atas arahan pemilik proyek, pekerjaan Quartus dan pengembangan/pengujian DE10-Nano kini ditahan sementara. `PASS` (lulus) hanya merujuk pemeriksaan yang benar-benar dijalankan; status tersebut bukan validasi sertifikasi atau bukti keamanan implementasi fisik.

VCD dan log di `sim/` adalah keluaran skrip yang dapat dibuat ulang dan dikecualikan dari repositori publik. Nama artefak pada tabel menunjukkan lokasi keluaran lokal; jalankan perintah yang dicantumkan untuk membuatnya kembali.

## Lingkungan dan perintah

- Paket alat: OSS CAD Suite for Windows; lokasinya dikonfigurasi melalui `OSS_CAD_SUITE`.
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
| Modul tingkat atas | PASS (lulus): KAT, jeda handshake, kestabilan keluaran saat ditahan, enkripsi/dekripsi, AD saja, pesan penuh 16 byte, tag/ciphertext salah ditolak tanpa plaintext, start saat sibuk, reset saat menerima data/core/verifikasi/menunggu keluaran atau tag, serta AD dan data yang masing-masing melebihi kapasitas ditolak dengan pulsa `command_error`/`done` | `tb/tb_secure_tiny_top.sv`; `sim/secure_tiny_top.vcd` |
| KAT pasangan panjang tingkat atas | PASS (lulus): 289 pasangan panjang AD/pesan (masing-masing 0–16 byte), untuk enkripsi dan dekripsi (578 transaksi); transfer diuji melalui antarmuka satu byte tingkat atas dan setiap data/tag dibandingkan dengan KAT | `tb/tb_secure_tiny_kat.sv`; `sim/secure_tiny_kat.vcd`; sumber KAT Ascon-C v1.3.0 |
| Model Python dibandingkan dengan ACVP | PASS (lulus): 14 kasus berukuran kelipatan byte yang dipilih dari sampel NIST ACVP SP 800-232 | `python/check_ascon_acvp_sample.py`; data di `vectors/ascon_aead128_*.json` |
| Model Python dibandingkan dengan KAT | PASS (lulus): seluruh 1.089 kasus bertag penuh dari berkas Ascon-C v1.3.0, enkripsi dan dekripsi | `python/check_ascon_c_kat.py`; berkas KAT di `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt` |
| Lint Verilator modul tingkat atas | PASS (lulus): elaborasi `secure_tiny_top` dengan `MAX_DATA_BYTES=16`, 9 modul, kode keluar 0 tanpa peringatan | `scripts/lint_verilator.ps1`; Verilator 5.053; `sim/verilator_secure_tiny_16.log` |
| Sintesis generik | PASS (lulus): hierarchy/proc/check/synth Yosys; `check` melaporkan 0 masalah | `sim/yosys_secure_tiny_16.log`; konfigurasi `MAX_DATA_BYTES=16`; 20.887 sel generik |
| Percobaan pemetaan Cyclone V dengan Yosys ALM | DIHENTIKAN: Yosys berhenti karena assertion internal AIGER2 pada tahap ABC9; tidak menghasilkan angka ALM yang dapat digunakan | `sim/yosys_cyclonev_16.log`; bukan hasil Quartus dan bukan bukti RTL gagal/lulus untuk perangkat |
| Pemeriksaan awal proyek DE10-Nano | PASS (lulus): QPF/QSF/SDC, tujuh sumber RTL, target perangkat, parameter, pin clock/reset, dan constraint 50 MHz konsisten | `scripts/check_quartus_project.ps1` |
| Quartus DE10-Nano | BELUM DIJALANKAN: `quartus_sh` tidak ditemukan di PATH maupun lokasi instalasi umum yang diperiksa | 2026-10-01: pemeriksaan awal `scripts/build_quartus.ps1` lulus, lalu proses keluar dengan kode 1 karena Quartus tidak ditemukan; kompilasi FPGA tidak berjalan |
| Skrip metrik Quartus | TERHALANG: parser PowerShell valid dan pemeriksaan awal lulus; `quartus_map`, `quartus_fit`, serta `quartus_sta` tidak ditemukan, skrip keluar dengan kode 2 sebelum kompilasi | `scripts/build_quartus_metrics.ps1`; tidak ada laporan Quartus yang diproses atau metrik baru; parser laporan belum dapat dicocokkan dengan keluaran Quartus aktual |

## Latensi simulasi

Testbench mengukur siklus dari tepi clock saat `start` diterima hingga tepi `done`. Pengujian KAT RTL menggunakan `MAX_DATA_BYTES=32` agar seluruh panjang pada berkas dapat diuji. Hasil pengujian terakhir:

- Core langsung: **2.178 transaksi**, total **121.308 siklus**, maksimum **88 siklus per transaksi** pada keseluruhan suite KAT.
- Modul tingkat atas untuk enkripsi 1 byte dengan penahanan keluaran / AD saja / enkripsi 16 byte melalui aliran data / dekripsi valid / penolakan tag / penolakan ciphertext: **45 / 50 / 96 / 41 / 41 / 41 siklus**.
- Sapuan KAT pasangan panjang modul tingkat atas: **578 transaksi**, total **51.019 siklus**, maksimum **150 siklus/transaksi**. Latensi diukur sejak `start` diterima sampai `done` dan mencakup waktu pengiriman AD/pesan melalui handshake.

Pengukuran modul tingkat atas mencakup pengaturan jeda handshake testbench dan penahanan keluaran yang dinyatakan; ini bukan throughput kontinu atau hasil timing FPGA. Testbench core membandingkan byte ciphertext/plaintext dan tag langsung dengan setiap rekaman KAT pada mode enkripsi dan dekripsi. Testbench tingkat atas membandingkan seluruh 289 pasangan panjang hingga kapasitas 16 byte pada kedua mode. Waveform core menyimpan transaksi awal sebagai contoh agar berkas tetap ringkas; waveform tingkat atas dan KAT dibuat ulang oleh testbench saat pengujian.

Regresi pasangan panjang juga menemukan kebuntuan ketika `tag_ready` tinggi sejak awal: tag dapat diterima sebelum pengendali memasuki fase pengiriman tag. Pengendali sekarang baru memuat tag setelah byte ciphertext terakhir diterima; untuk pesan kosong, pengiriman tag dimulai segera setelah core selesai. Seluruh regresi tingkat atas lulus setelah perubahan ini.

Jejak peristiwa dari `sim/secure_tiny_top.vcd` juga diperiksa: pada dekripsi valid, `auth_result_valid` dan `accept` naik saat plaintext `out_valid` pertama kali naik (2355000 ps); pada transaksi dengan tag/ciphertext yang diubah, `reject` naik tanpa pulsa `out_valid` (2775000 ps dan 3195000 ps). `done` muncul setelah status hasil pada transaksi tersebut. Hasil ini sesuai dengan assertion testbench yang melarang plaintext sebelum verifikasi dan saat penolakan.

Waveform unit `sim/tag_auth_modules.vcd` diperiksa: pemeriksa mengeluarkan `tag_match` dan `verify_done` pada 65000 ps untuk tag yang sama, serta `tag_mismatch` dan `verify_done` pada 95000 ps untuk tag yang berbeda; guard mengeluarkan `accept`/`plaintext_allowed` pada 135000 ps dan `reject` tanpa izin plaintext pada 165000 ps. Pembentuk tag mempertahankan `tag_valid` selama keluaran ditahan dan membersihkannya setelah handshake.

Icarus mencetak peringatan `constant selects in always_* processes are not fully supported`; simulator menyatakan proses akan peka terhadap seluruh vektor terkait. Seluruh pengujian tetap selesai dengan status PASS. Sintesis Yosys yang dijalankan ulang berakhir dengan kode keluar 0; statistik akhir dan `check` melaporkan 0 masalah.

## Identitas data vektor

Sumber NIST ACVP: `usnistgov/ACVP-Server`, direktori `gen-val/json-files/Ascon-AEAD128-SP800-232` (prompt dan expectedResults; sampel berlabel `isSample=true`). Nilai SHA-256 lokal:

- `vectors/ascon_aead128_prompt.json`: `717D20C79ABDB55CF3AFAFAC6322172EB4E2B8288148D6B8C0B5CA73B75DD357`
- `vectors/ascon_aead128_expected.json`: `413D9E1524CDB1F3DE5ECDD2592474EB2026904C5D1EF6099355F944CFB33235`

Sumber KAT tambahan: tag `v1.3.0` dari `ascon/ascon-c`, berkas `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`; SHA-256 `6A5B08DDD81C0B4858D39A5572F2F81590B82F4A22FC72C6E67FE505248A6949`.

## Hasil pembuatan untuk papan dan batas pengujian

Proyek Quartus disiapkan untuk Cyclone V `5CSEBA6U23I7`, parameter 16 byte, clock 50 MHz, dan pin virtual bagi antarmuka IP. `scripts/check_quartus_project.ps1` memeriksa konsistensi berkas dan jalur secara lokal; pemeriksaan statis ini tidak membuktikan QSF/SDC diterima oleh Quartus. Quartus tidak terpasang/tersedia pada sesi ini. Pin virtual juga tidak menyediakan jalur host untuk menguji transaksi pada board.

- Penggunaan sumber daya FPGA Cyclone V: `TBD - belum diukur`.
- Fmax/timing FPGA: `TBD - belum diukur`.
- Bitstream `.sof`/berkas pemrograman: `TBD - belum dibuat`.
- Uji pada papan DE10-Nano: `TBD - belum dilakukan`.
- Integrasi Avalon/HPS atau pemetaan pin antarmuka transaksi: belum ditentukan/diterapkan.

Jumlah 20.887 sel adalah hasil pemetaan generik Yosys, bukan jumlah ALM/LE Cyclone V, sehingga tidak boleh digunakan sebagai klaim penggunaan sumber daya FPGA.

Pada pengulangan sintesis Yosys 1 Oktober 2026, proses berakhir dengan kode keluar 0, menghasilkan 20.887 sel generik, dan `check` melaporkan 0 masalah. Keluaran ABC juga memuat satu pesan akses berkas sementara yang sedang dipakai proses lain; sintesis tetap menyelesaikan seluruh tahap dan menghasilkan laporan akhir. Catat pesan itu sebagai peringatan lingkungan Windows, bukan sebagai metrik FPGA atau bukti kompilasi Quartus.
