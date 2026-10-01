# Rencana Verifikasi SECURE-TINY

## Rujukan kriptografi

Implementasi normatif adalah Ascon-AEAD128 dalam **NIST SP 800-232 final, Agustus 2025**: [halaman publikasi NIST](https://csrc.nist.gov/pubs/sp/800/232/final), [PDF final](https://nvlpubs.nist.gov/nistpubs/SpecialPublications/NIST.SP.800-232.pdf). Jangan mencampur vektor dari spesifikasi submission Ascon terdahulu dengan standar final.

Pembanding normatif adalah set vektor resmi NIST ACVP di direktori [Ascon-AEAD128-SP800-232](https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232), berupa pasangan `prompt.json` dan `expectedResults.json`. Format kasusnya: `algorithm=Ascon`, `mode=AEAD128`, `revision=SP800-232`. Salinan sampel ACVP tersimpan di `vectors/ascon_aead128_prompt.json` dan `vectors/ascon_aead128_expected.json`; pemeriksa Python membandingkan kasus berukuran kelipatan byte dengan hasil NIST. Pemeriksaan ini menguji model referensi Python, sedangkan testbench RTL memakai KAT tetap. Untuk uji diferensial tambahan digunakan KAT dari hulu [ascon/ascon-c v1.3.0](https://github.com/ascon/ascon-c/tree/v1.3.0), berkas `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`. Nama `ascon128av13` merujuk implementasi Ascon-AEAD128 NIST SP 800-232 pada rilis v1.3.0; KAT ini merupakan tambahan dan bukan pengganti vektor ACVP normatif. Jangan menyalin implementasi tersebut ke RTL atau mengubah nilai harapan tanpa sumber.

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
| Authentication Guard | Tag benar diterima; tag salah dan ciphertext berubah ditolak; tidak ada keluaran plaintext valid saat ditolak | Status accept/reject, jumlah byte keluaran, waveform |
| Ketahanan kendali | Reset saat menerima data, core aktif, verifikasi tag aktif, data keluaran tertahan, dan tag menunggu handshake; AD/data melebihi kapasitas; penahanan keluaran; urutan start/busy/done | `tb/tb_secure_tiny_top.sv`; assertion/log dan `sim/secure_tiny_top.vcd` |
| Sintesis target | Elaborasi/sintesis Quartus dengan nilai `MAX_DATA_BYTES` tercatat | Versi alat, perangkat DE10-Nano, laporan resource/timing aktual |

Status pengujian dicatat di [`results.md`](results.md). Jalankan lint dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/lint_verilator.ps1 -MaxDataBytes 16`, rangkaian simulasi dengan `powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/run_all_tests.ps1`, dan sintesis Yosys generik dengan `scripts/synth_yosys.ps1 -MaxDataBytes 16`. Build Quartus memerlukan Quartus Prime terpasang dan `quartus_sh` tersedia di PATH atau diberikan melalui `-QuartusSh` (`scripts/build_quartus.ps1`).

Kompilasi saja tidak cukup untuk menyatakan PASS. PASS hanya boleh dicatat jika pemeriksaan dan perbandingan yang disyaratkan benar-benar dijalankan. Kegagalan testbench atau ketidakcocokan vektor harus dicatat sebagai FAIL, bukan diperbaiki dengan mengubah nilai harapan tanpa sumber baru.

Waveform minimum untuk transaksi AEAD: `clk`, `rst_n`, `start`, `busy`, masukan `valid/ready/data`, panjang, fase pengendali, permintaan/penyelesaian permutasi, `tag_valid`, status autentikasi, keluaran `valid/ready/data`, dan `done`. Berkas hasil sintesis atau waveform merupakan artefak pengujian; jangan mengklaim metrik yang tidak tercantum dalam laporan aktual.

## Batas klaim

Vektor ACVP untuk uji informal tidak dengan sendirinya menyatakan validasi sertifikasi. Pengujian fungsional tidak membuktikan keamanan implementasi terhadap side-channel, injeksi kesalahan, atau seluruh kondisi fisik. Laporkan hanya hasil yang benar-benar diamati.
