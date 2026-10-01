# Rencana Verifikasi SECURE-TINY

## Acuan kriptografi

Implementasi normatif adalah Ascon-AEAD128 dalam **NIST SP 800-232 final, Agustus 2025**: [halaman publikasi NIST](https://csrc.nist.gov/pubs/sp/800/232/final), [PDF final](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-232.pdf). Jangan mencampur vektor dari spesifikasi submission Ascon terdahulu dengan standar final.

Oracle normatif adalah vector set resmi NIST ACVP pada direktori [Ascon-AEAD128-SP800-232](https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232), pasangan `prompt.json` dan `expectedResults.json`. Format kasus: `algorithm=Ascon`, `mode=AEAD128`, `revision=SP800-232`. Salinan sampel ACVP tersimpan di `vectors/ascon_aead128_prompt.json` dan `vectors/ascon_aead128_expected.json`; checker Python membandingkan kasus byte-aligned dengan hasil NIST. Pemeriksaan ini menguji model referensi Python, sedangkan testbench RTL memakai KAT tetap. Untuk uji diferensial tambahan digunakan KAT upstream [ascon/ascon-c v1.3.0](https://github.com/ascon/ascon-c/tree/v1.3.0), file `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`. Nama `ascon128av13` merujuk implementasi Ascon-AEAD128 NIST SP 800-232 dalam rilis v1.3.0; KAT ini tambahan dan bukan pengganti vector ACVP normatif. Jangan menyalin implementasi tersebut ke RTL atau mengubah expected value tanpa sumber.

## Tahapan dan bukti

| Tahap | Pemeriksaan minimum | Bukti yang dicatat |
|---|---|---|
| Lint RTL | Jalankan Verilator `--lint-only` pada top-level dengan parameter build target | Versi tool, command, exit code dan seluruh warning/error |
| Pembelajaran counter/FSM | Kompilasi dan simulasi perilaku count/state/reset | Perintah, log, assertion/check, waveform VCD |
| Permutasi | Uji operasi ronde yang dipakai AEAD dan beberapa state uji terpilih dari sumber tepercaya | Versi referensi, kasus, input/output, log, waveform |
| Core dan controller | Panjang 0, parsial, batas rate block, KAT enkripsi/dekripsi langsung di RTL, handshake, stall, start saat sibuk, reset | Hasil per kasus dan waveform sinyal kontrol/data; core menjalankan seluruh 1.089 record KAT Ascon-C hingga 32 byte |
| Tag handling dan guard | Backpressure generator, perbandingan tag penuh, hasil match/mismatch, keputusan guard, clear dan reset | `tb/tb_tag_auth_modules.sv` dan `sim/tag_auth_modules.vcd` |
| Integrasi top-level | Seluruh 289 pasangan panjang AD/pesan 0–16 byte dari KAT, encrypt/decrypt melalui stream, urutan ciphertext-tag, keluaran plaintext setelah autentikasi | `tb/tb_secure_tiny_kat.sv`, total 578 transaksi, serta `sim/secure_tiny_kat.vcd` |
| AEAD top-level | KAT enkripsi dan dekripsi terhadap oracle; AD/pesan kosong dan panjang parsial | Identitas vektor, keluaran RTL, keluaran referensi, hasil compare |
| Authentication guard | Tag benar diterima; tag salah dan ciphertext berubah ditolak; tidak ada output plaintext valid pada reject | Status accept/reject, hitungan output byte, waveform |
| Robustness kontrol | Reset diuji saat menerima data, core aktif, verifikasi tag aktif, data keluaran tertahan, dan tag menunggu handshake; AD/data di atas kapasitas; backpressure output; urutan start/busy/done | `tb/tb_secure_tiny_top.sv`; assertion/log dan `sim/secure_tiny_top.vcd` |
| Sintesis target | Elaborasi/sintesis Quartus dengan `MAX_DATA_BYTES` tercatat | Versi tool, device DE10-Nano, laporan resource/timing aktual |

Status run dicatat di [`results.md`](results.md). Jalankan lint dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16`, suite simulasi dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1`, dan sintesis Yosys generik dengan `scripts/synth_yosys.ps1 -MaxDataBytes 16`. Build Quartus memerlukan Quartus Prime terpasang dan `quartus_sh` tersedia di PATH atau diberikan melalui `-QuartusSh` (`scripts/build_quartus.ps1`).

Kompilasi sendiri tidak cukup untuk menyatakan PASS. PASS hanya boleh dicatat jika pemeriksaan dan perbandingan yang disyaratkan benar-benar berjalan. Kegagalan testbench atau ketidakcocokan vector harus dicatat sebagai FAIL, bukan diperbaiki dengan mengubah expected value tanpa sumber baru.

Waveform minimal untuk transaksi AEAD: `clk`, `rst_n`, `start`, `busy`, input `valid/ready/data`, panjang, fase controller, permintaan/selesai permutasi, `tag_valid`, status autentikasi, output `valid/ready/data`, dan `done`. File hasil sintesis atau waveform adalah artefak pengujian; jangan mengklaim metrik yang tidak muncul dalam laporan aktual.

## Batas klaim

Vectors ACVP untuk uji informal tidak dengan sendirinya menyatakan validasi sertifikasi. Pengujian fungsional tidak membuktikan keamanan implementasi terhadap side-channel, fault injection, atau seluruh kondisi fisik. Laporkan hanya hasil yang diamati.
