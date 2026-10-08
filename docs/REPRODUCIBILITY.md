# Reproduksibilitas SECURE-TINY

Panduan ini menjelaskan cara menjalankan ulang simulasi dan pemeriksaan yang mendasari [indeks evidence](EVIDENCE.md). Perintah di bawah diasumsikan dijalankan dari root repository pada Windows PowerShell.

## Environment

- Icarus Verilog dan Python berasal dari OSS CAD Suite. Atur `OSS_CAD_SUITE` ke direktori instalasi suite; runner memakai executable dari direktori `bin`.
- Versi pada run evidence 6 Oktober 2026: Icarus Verilog `14.0 (devel) (s20260301-500-g2e81fcccb-dirty)`, Python `3.11.6`, Verilator `5.053`, Yosys `0.69+156`.
- Quartus Prime Lite `25.1std.0 Build 1129`, target Cyclone V `5CSEBA6U23I7`, `MAX_DATA_BYTES=16`.
- GTKWave diperlukan hanya untuk melihat waveform. Semua versi di atas mengidentifikasi run yang tercatat; hasil dapat berubah jika source, parameter, opsi, atau versi alat berubah.

## Regression simulasi

Jalankan tujuh runner berurutan; runner berhenti pada kegagalan pertama:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1
```

Output dan waveform dibuat di `sim/`. Artefak baseline audit yang dipertahankan: `regression_20261006.log`, `verilator_secure_tiny_16.log`, `yosys_secure_tiny_16.log`, `secure_tiny_top.vcd`, `ascon_core.vcd`, dan `ascon_permutation.vcd`. Script regresi tidak otomatis menulis file `regression_20261006.log`; untuk menyimpan output run baru, salurkan output PowerShell ke nama log baru secara eksplisit.

## Verilator dan Yosys

Pastikan `OSS_CAD_SUITE` menunjuk instalasi OSS CAD Suite, lalu jalankan:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/synth_yosys.ps1 -MaxDataBytes 16
```

Keduanya menyimpan log di `sim/`. Hitungan sel Yosys adalah sel generik dan tidak setara dengan ALM/LUT FPGA.

## Melihat waveform

```powershell
gtkwave sim/secure_tiny_top.vcd
gtkwave sim/ascon_core.vcd
gtkwave sim/ascon_permutation.vcd
```

Di waveform top-level, cari setiap transaksi dari tepi `start` yang diterima. Untuk dekripsi valid, amati urutan `verifier_done`/`verifier_match`, `auth_result_valid`/`accept`, lalu `plaintext_allowed` dan `out_valid`; untuk tiga skenario negatif terarah, amati `reject` dan pastikan tidak ada handshake `out_valid && out_ready` sebelum `done`. Sinyal stimulus/keluaran yang berguna: `decrypt`, `ad_valid`, `data_valid`, `out_data`, `tag_valid`, `verifier_done`, `verifier_match`, `auth_result_valid`, `accept`, `reject`, `plaintext_allowed`, `out_valid`, `out_ready`, dan `done`. Testbench terarah berada di `tb/tb_secure_tiny_top.sv`; urutan skenario terlihat di task dan pemanggilan testbench.

Pada `ascon_core.vcd`, amati `start`, `busy`, `done`, fase, state, dan handshake permutasi. Pada `ascon_permutation.vcd`, amati `start`, `rounds`, `state_in`, `state_out`, `busy`, dan `done`.

VCD adalah generated artifact. File yang diperlukan dapat dibuat ulang oleh `run_all_tests.ps1`; tidak perlu mengambil screenshot sebagai bukti utama.

## Build Quartus

Pastikan `quartus_sh` tersedia di `PATH` atau berikan path executable Quartus Prime Lite:

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/build_quartus.ps1 -QuartusSh 'C:\altera_lite\25.1std\quartus\bin64\quartus_sh.exe'
```

Script menjalankan preflight, lalu Analysis & Synthesis, Fitter, Assembler, dan Timing Analyzer untuk project `quartus/secure_tiny.qpf`. Output report berada di `quartus/output_files/`, termasuk `secure_tiny.flow.rpt`, `secure_tiny.fit.summary`, `secure_tiny.sta.summary`, dan `secure_tiny.sta.rpt`; `.sof` dibuat oleh Assembler.

Verifikasi hash file `.sof` hasil build:

```powershell
Get-FileHash quartus/output_files/secure_tiny.sof -Algorithm SHA256
```

Hash `.sof` yang tercatat pada audit 6 Oktober 2026: `D49CD7D1AB67C963D93CC399FCBB4835A818B56F6DA71E43596412F1E20F4112` (6.690.378 byte). Hash akan berbeda bila hasil build berbeda. File `.sof` adalah artefak generated dan tidak disertakan dalam commit evidence ini.

## Batas validasi hardware

Build dan timing report berasal dari Quartus, bukan dari board. Laporan menyebut desain belum fully constrained untuk setup/hold; 616 transaction pins adalah virtual. Dengan demikian Fmax/slack hanya merujuk clock/path yang dianalisis dan bukan sign-off timing I/O. Tidak ada bukti pemrograman atau transaksi fisik DE10-Nano, HPS/Avalon, SignalTap, pengukuran daya, atau throughput board di repository.
