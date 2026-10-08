# Indeks Evidence SECURE-TINY

Indeks ini menautkan klaim teknis ke artefak hasil yang benar-benar tersedia di repository. Nomor baris mengacu pada berkas yang disertakan; waveform dirujuk melalui nama sinyal dan urutan transaksi karena VCD adalah format biner-teks yang dihasilkan simulator.

## Bukti utama

| Evidence ID | Klaim | File | Line / Signal / Reference | Status |
|---|---|---|---|---|
| EV-01 | Regression Icarus dan model Python menyelesaikan seluruh runner | `sim/regression_20261006.log` | L3, L23, L50, L54, L88, L115, L118–L120 | VERIFIED |
| EV-02 | Latensi suite core: 2.178 transaksi, 121.308 siklus total, maksimum 88 siklus | `sim/regression_20261006.log` | L49 | VERIFIED |
| EV-03 | Sweep top-level: 578 transaksi, 51.019 siklus total, maksimum 150; 289 pasangan panjang pada kedua mode | `sim/regression_20261006.log` | L114–L115 | VERIFIED |
| EV-04 | Dekripsi valid membuka plaintext setelah verifikasi cocok | `sim/secure_tiny_top.vcd`; `rtl/aead_controller.sv` | VCD: `start`, `decrypt`, `verifier_done`, `verifier_match`, `auth_result_valid`, `accept`, `plaintext_allowed`, `out_valid`, `out_data`, `done`; urutkan per transaksi dekripsi valid. Gate RTL: L85–L87 | VERIFIED |
| EV-05 | AD/tag/ciphertext tidak valid ditolak tanpa transfer plaintext pada skenario terarah | `sim/secure_tiny_top.vcd`; `sim/regression_20261006.log` | VCD: transaksi negatif berurutan; `reject`, `auth_result_valid`, `out_valid`, `done`. Log L88 menyatakan pemeriksaan reject/guard lulus; assertion dan hitungan transfer ada di `tb/tb_secure_tiny_top.sv` | VERIFIED |
| EV-06 | Core dan permutasi menghasilkan waveform simulasi | `sim/ascon_core.vcd`; `sim/ascon_permutation.vcd` | Core: `clk`, `rst_n`, `busy`, `done`, `phase`, state/round signals; permutasi: `clk`, `rst_n`, `start`, `rounds`, `state_in`, `state_out`, `busy`, `done` | VERIFIED |
| EV-07 | Lint Verilator top-level dan pemeriksaan/sintesis Yosys generik | `sim/verilator_secure_tiny_16.log`; `sim/yosys_secure_tiny_16.log` | Verilator L1–L3 (5.053, elaborasi 9 modul; tidak ada baris warning); Yosys L791, L863, L880, L4517, L4537, L4551 (0 masalah; 20.937 sel generik) | VERIFIED |
| EV-08 | Quartus Fitter resource untuk Cyclone V `5CSEBA6U23I7` | `quartus/output_files/secure_tiny.fit.summary`; `quartus/output_files/secure_tiny.flow.rpt` | fit.summary L3–L14; flow.rpt L44, L49–L56 | VERIFIED |
| EV-09 | Fmax dan slack clock yang dianalisis Quartus | `quartus/output_files/secure_tiny.sta.rpt`; `quartus/output_files/secure_tiny.sta.summary` | sta.rpt L132–L136, L1733–L1737, L1799–L1800; sta.summary bagian Timing Analyzer Summary | PARTIALLY VERIFIED — laporan memperingatkan setup/hold belum fully constrained; bukan sign-off I/O |
| EV-10 | Assembler menghasilkan `.sof`; identitas artefak tercatat dengan SHA-256 | `docs/results.md`; `quartus/output_files/secure_tiny.flow.rpt` | flow.rpt L44–L49; SHA-256 `D49CD7D1AB67C963D93CC399FCBB4835A818B56F6DA71E43596412F1E20F4112`, ukuran 6.690.378 byte. `.sof` tidak disertakan karena artefak distribusi/biner; salinan lokal diperiksa saat audit | VERIFIED — pembuatan artefak, bukan pemrograman board |
| EV-11 | Authentication guard menahan `out_valid` dekripsi sampai izin autentikasi aktif | `rtl/aead_controller.sv`; `rtl/authentication_guard.sv`; `rtl/tag_verifier.sv` | `aead_controller.sv` L85–L87; `authentication_guard.sv` L22–L35; `tag_verifier.sv` L36–L48 | VERIFIED untuk perilaku RTL dan skenario simulasi tercatat |
| EV-12 | Pengujian fisik DE10-Nano | N/A | Tidak ada transaksi board, pemetaan antarmuka fisik, atau bukti SignalTap di repository | NOT CLAIMED |

## Audit berkas submission

| Kategori | Isi yang dipertahankan atau dikecualikan |
|---|---|
| REQUIRED FOR SUBMISSION | RTL `rtl/`; testbench `tb/`; runner dan build scripts `scripts/`; model/reference Python `python/`; KAT dan sampel ACVP `vectors/`; file proyek Quartus `quartus/secure_tiny.qpf`, `.qsf`, `.sdc`; laporan dan waveform yang dirujuk EV-01–EV-11; README dan dokumentasi teknis. |
| OPTIONAL | Log regression 2 Oktober sebagai riwayat pembanding; waveform `sim/secure_tiny_kat.vcd` (1.360.676 byte) untuk sweep tambahan; laporan Quartus `secure_tiny.fit.rpt`/`secure_tiny.asm.rpt` yang lebih rinci bila diperlukan untuk audit lanjutan. Artefak ini tersedia lokal tetapi tidak diperlukan oleh indeks minimal. |
| INTERNAL DEVELOPMENT / EXCLUDED | Proposal (`proposal-draft.md`, `proposal-draft1.md`, `proposal-final.md`, dokumen DOCX dan merge), instruksi finalisasi ini, `AGENTS.md`/prompt/agent config, file lock editor `~$*.docx`, generator DOCX khusus proposal, dump pin sementara `quartus/c5_pin_model_dump.txt`, cache Quartus `db/` dan `incremental_db/`, executable simulasi `.vvp`, serta file sementara OS/editor. Tidak ada berkas tersebut yang dimasukkan ke commit final. |

Waveform VCD dan log build disimpan sebagai bukti reproduksi yang terpilih meskipun `.gitignore` mengecualikan artefak hasil generate secara umum. VCD sweep KAT dan `.sof` tidak dipaksa masuk Git; cara membuat ulang VCD dijelaskan di [REPRODUCIBILITY.md](REPRODUCIBILITY.md), sedangkan hash `.sof` dicatat di atas dan di `results.md`.

## Status klaim

- **VERIFIED:** klaim yang ditunjukkan langsung oleh log, RTL/testbench, atau laporan yang dirujuk.
- **PARTIALLY VERIFIED:** hanya bagian yang benar-benar tercatat yang tervalidasi; batasannya tertulis pada baris evidence.
- **NOT VERIFIED:** belum ada bukti repository yang cukup untuk klaim tersebut.
- **NOT CLAIMED:** klaim sengaja tidak dibuat, termasuk validasi fisik DE10-Nano.
