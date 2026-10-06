# SECURE-TINY: IP Core Ascon-AEAD128 dengan Guard Pelepasan Plaintext untuk Komunikasi Edge

**Kompetisi:** PERURI Chip Hackathon 2026  
**Kategori:** Perancangan Chip IC dan Implementasi FPGA  
**Tantangan utama:** Hardware Cryptography Accelerator  
**Tantangan pendukung:** Secure Communication  
**Target:** Terasic DE10-Nano, FPGA Cyclone V 5CSEBA6U23I7  
**Tim:** Ngadu Nasib — Universitas Pendidikan Indonesia  
**Anggota menurut draft tim:** Ripan (ketua), Andhika Pratama, Andra Vijatmi, Muhammad Iqbal Ridho  
**NIM, kontak resmi, pembimbing:** [lengkapi dan konfirmasi ejaan/nama sesuai data panitia]

> **Status bukti.** Simulasi, lint, sintesis generik, dan build Quartus dijalankan ulang pada 6 Oktober 2026; rincian run dan artefaknya dicatat di `docs/results.md`, `sim/regression_20261006.log`, dan report Quartus. *Hasil aktual* merujuk pada run tersebut, *target* adalah kriteria rencana, *estimasi* adalah hitungan turunan, dan *TBD* berarti belum diukur. Build Quartus bukan pengujian pada board fisik.

## 1. Ringkasan Ide (Executive Summary)

### 1.1 Masalah yang Diangkat

Proposal memfokuskan masalah pada telemetri ringkas Advanced Metering Infrastructure (AMI): meter mengirimkan pembacaan dan peristiwa ke pengumpul/gateway, sementara privasi serta integritas data meter termasuk pertimbangan keamanan smart grid yang didokumentasikan NIST [15]. NIST juga menetapkan perlindungan data sebagai kemampuan dasar perangkat IoT [2]. Pada dekripsi AEAD, hasil plaintext belum sah sebelum tag autentikasi diverifikasi; core Ascon pembanding yang mengeluarkan plaintext lebih awal meminta wrapper eksternal menahan data tersebut [4]. Gap yang ditangani adalah evaluasi integrasi buffer, verifikasi tag, dan guard fail-closed dalam satu IP byte-stream mandiri, bukan klaim bahwa AMI belum memiliki perlindungan atau bahwa semua meter memerlukan Ascon.

### 1.2 Solusi yang Ditawarkan

SECURE-TINY adalah IP core SystemVerilog untuk enkripsi dan dekripsi terautentikasi Ascon-AEAD128 sesuai NIST SP 800-232 [1]. Arsitektur iteratif memproses satu ronde permutasi per siklus aktif, menerima AD dan pesan melalui antarmuka byte 8-bit, memverifikasi tag, dan menahan calon plaintext dekripsi sampai autentikasi berhasil. Jika tag tidak cocok, guard tidak mengeluarkan byte plaintext dan melaporkan `reject`. Untuk aplikasi AMI, demonstrasi yang diusulkan adalah paket pembacaan/peristiwa meter 16 byte ke gateway: metadata identitas meter, jenis pesan, dan nomor urut masuk sebagai AD; data ukur masuk sebagai payload. Format ini adalah contoh pemetaan data untuk demonstrator, bukan format standar AMI.

Konfigurasi demonstrator yang telah dibangun membatasi panjang AD dan pesan secara terpisah hingga 16 byte. Ini batas implementasi saat ini, bukan batas algoritma Ascon atau klaim kapasitas aplikasi. Keunikan nonce untuk setiap enkripsi dengan key yang sama menjadi tanggung jawab pemanggil; IP tidak membuat ataupun menyimpan riwayat nonce.

### 1.3 Implementasi pada DE10-Nano

**Hasil aktual, run 6 Okt 2026:** Quartus Prime Lite 25.1 berhasil mengompilasi Cyclone V `5CSEBA6U23I7` dengan 0 error dan 5 warning; report mencatat 2.464 ALM, 2.800 register, 0 M10K, 0 DSP, Fmax 79,72 MHz, setup slack +7,456 ns, hold slack +0,338 ns, dan `.sof` 6.690.378 byte [13]. Clock SDC 50 MHz. Sebanyak 616 port transaksi masih virtual dan tidak memiliki constraint I/O board, sehingga ini bukan sign-off interface lengkap. Bitstream belum diuji pada board fisik; wrapper HPS/Avalon, SignalTap capture, daya, dan throughput fisik belum ada.

DE10-Nano menyediakan FPGA Cyclone V `5CSEBA6U23I7`, HPS ARM Cortex-A9, Ethernet, dan antarmuka ekspansi [6]. Integrasi yang diusulkan menempatkan SECURE-TINY pada FPGA fabric; HPS menjalankan stack jaringan, pengaturan transaksi, serta pengelolaan nonce/key di lapisan sistem. Jalur HPS/Avalon tersebut belum diimplementasikan dalam build saat ini.

### 1.4 Kebaruan dan Keunggulan

Ascon-AEAD128 adalah algoritma standar, bukan algoritma baru yang diklaim tim [1]. Core Ascon reconfigurable dan serialisasi telah dipublikasikan; studi 2026 terbaru juga menunjukkan trade-off paralelisme, area, frekuensi, dan daya pada platform berbeda [16], [17]. Karena itu proposal **tidak mengklaim kebaruan kriptografi, serialisasi, reconfigurability, metode dua-pass pertama, atau keunggulan performa atas desain terdahulu**.

Kontribusi yang dapat diuji adalah integrasi controller, buffer kapasitas kecil, verifier, dan guard yang menegakkan perilaku “tidak ada plaintext sah sebelum tag cocok” di dalam satu IP, disertai KAT, pengujian gangguan digital, build Cyclone V, dan dokumentasi bukti. Potensi kebaruan algoritmik terbatas pada eksperimen controller dua-pass *verify-only lalu decrypt* yang diusulkan pada §3.1.4. Pola dua-pass sudah memiliki preseden [11]; nilainya bagi SECURE-TINY baru dapat dipertimbangkan jika implementasi menunjukkan trade-off terukur yang lebih baik untuk batas board dan workload yang ditetapkan.

Dengan bukti yang ada, posisi proposal yang defensible adalah kontribusi rekayasa dan evaluasi: perilaku fail-closed dijadikan kontrak antarmuka, diuji pada tingkat modul dan top-level, lalu disintesis untuk Cyclone V. Belum ada dasar untuk menyebutnya algoritma baru atau mengklaim mengungguli implementasi existing. Untuk memperkuat novelty sebelum kompetisi, eksperimen harus membandingkan varian pada tool, device, constraint, workload, dan kebijakan keluaran plaintext yang sama; hipotesis yang tidak menghasilkan manfaat terukur harus dilaporkan sebagai hasil negatif.

## 2. Latar Belakang & Rumusan Masalah (Problem Statement)

### 2.1 Latar Belakang

NIST SP 800-232 menetapkan Ascon-AEAD128 sebagai authenticated encryption with associated data (AEAD) untuk perangkat terbatas [1]. AEAD menghasilkan ciphertext dan tag untuk enkripsi; dekripsi memeriksa tag atas key, nonce, AD, dan ciphertext sebelum plaintext diterima sebagai autentik. AD ikut diautentikasi tetapi tidak dienkripsi. NISTIR 8259A menempatkan perlindungan data sebagai salah satu kemampuan dasar keamanan perangkat IoT [2]. Kedua sumber tersebut mendukung relevansi fungsi, tetapi tidak membuktikan adanya kebutuhan spesifik dari pengguna atau industri PERURI; use case dan workload nyata masih perlu divalidasi.

Akselerator hardware merupakan pilihan implementasi untuk memindahkan operasi kriptografi dari perangkat lunak ke logika khusus, tetapi manfaat latency, throughput, energi, atau resource tidak dapat diasumsikan: semuanya bergantung pada algoritma, interface, device, clock, toolchain, dan beban kerja. Oleh sebab itu, proyek mengukur fungsi serta implementasi aktual dan tidak menyatakan akselerasi dibanding software tanpa benchmark yang setara.

### 2.2 Rumusan Masalah & Perancangan

**Rumusan masalah:** bagaimana merancang IP Ascon-AEAD128 yang modular dan dapat diverifikasi, membatasi plaintext dekripsi agar hanya tersedia setelah autentikasi, serta mengukur kelayakan implementasinya pada Cyclone V DE10-Nano?

**Ruang masalah teknik:**

1. Urutan transaksi AEAD, byte, AD, tag, dan backpressure perlu konsisten pada controller dan core.
2. Keluaran plaintext yang belum terautentikasi harus tetap tertahan; transaksi invalid harus gagal tertutup.
3. Penggunaan buffer untuk menegakkan aturan itu berpengaruh pada register/resource dan latency.
4. Simulasi dan compile FPGA harus dibedakan dari pengujian board, serta interface fisik perlu constraint timing lengkap.
5. Klaim “hemat resource” atau “lebih cepat” perlu pembanding yang arsitektur, device, tool, clock, interface, dan workload-nya sepadan.

**Batas lingkup:** satu transaksi aktif, satu domain clock, input AD dan data dibuffer sebelum core mulai, kapasitas konfigurasi build 16 byte AD dan 16 byte pesan, serta tidak ada AXI/Avalon/HPS wrapper pada baseline. Model ancaman mencakup kesalahan digital pada AD/ciphertext/tag. Side-channel daya/EM, fault injection, ketahanan fisik, manajemen key, dan secure zeroization belum menjadi klaim atau fitur terverifikasi.

## 3. Proposed Chip Design

### 3.1 Solusi & Arsitektur Sistem

#### 3.1.1 Diagram Blok Sistem

```text
Pemanggil
  ├─ perintah, key, nonce, panjang AD/pesan, tag masuk
  ├─ stream byte AD ───────┐
  └─ stream byte pesan ────┤
                           v
                ┌──────────────────────┐
                │ AEAD Controller      │── buffer AD/data terbatas
                │ FSM + handshake      │
                └──────────┬───────────┘
                           v
                ┌──────────────────────┐      ┌────────────────────┐
                │ Ascon-AEAD Core      │<────>│ Permutasi Ascon    │
                └───────┬────────┬─────┘      └────────────────────┘
                        │        └── tag hitung ─> Tag Verifier <── tag masuk
                        │                                │
                        │                       Authentication Guard
                        │                                │ accept/reject
                        └── hasil data ─> output buffer/gate ───────┘
                                       │
                                       └── plaintext hanya setelah accept

Enkripsi: ciphertext + tag dikembalikan kepada pemanggil.
Dekripsi: calon plaintext ditahan sampai tag cocok; mismatch tidak mengeluarkan byte.
HPS/Avalon, driver, pemetaan pin board: integrasi lanjutan, belum tersedia.
```

#### 3.1.2 Rincian Modul RTL

| Modul | Fungsi dan antarmuka utama |
|---|---|
| `ascon_permutation.sv` | Menyimpan/memperbarui state permutasi dan menjalankan ronde sinkron. Input mencakup state dan kendali ronde; output state hasil. |
| `ascon_core.sv` | Mengatur inisialisasi, absorb AD, pemrosesan pesan, finalisasi, serta tag sesuai Ascon-AEAD128 [1]. Menggunakan permutasi sebagai blok ronde. |
| `aead_controller.sv` | Mengatur start/busy/done, fase input dan output, buffer terikat kapasitas, serta urutan core dan tag. Transfer byte terjadi hanya pada `valid && ready`. |
| `tag_generator.sv` | Menangkap dan menahan tag akhir core melalui `tag_valid/tag_ready`; bukan algoritma pembentuk tag tersendiri. |
| `tag_verifier.sv` | Membandingkan tag hasil core dengan tag diterima dan menghasilkan match/mismatch. |
| `authentication_guard.sv` | Menghasilkan accept/reject untuk dekripsi dan mengendalikan pelepasan plaintext setelah match. |
| `secure_tiny_top.sv` | Menghubungkan perintah, stream, status, core, verifier, dan guard pada satu clock domain. |
| Testbench/model/scripts | Testbench SystemVerilog menguji unit dan top-level; Python menjadi referensi independen; skrip mengotomasi simulasi, lint, sintesis generik dan build/ekstraksi metrik Quartus. |

Kontrak penting: reset sinkron aktif-rendah; byte indeks 0 berada pada `[7:0]`; AD dikirim sebelum data; setiap panjang dibatasi parameter `MAX_DATA_BYTES`; start saat sibuk diabaikan; overcapacity menghasilkan `command_error` dan bukan status reject autentikasi. Status autentikasi didefinisikan untuk dekripsi. Pemanggil wajib tidak menggunakan ulang nonce untuk key yang sama [1]. Detail port normatif berada di `docs/module_spec.md`.

#### 3.1.3 Algoritma Dasar

Desain menggunakan Ascon-AEAD128 sebagaimana distandardisasi NIST SP 800-232 [1], bukan varian lama yang memiliki parameter berbeda. Algoritma mempertahankan state 320-bit, memproses blok dengan rate 128-bit, memakai permutasi p[12] pada inisialisasi/finalisasi dan p[8] pada pemrosesan AD/pesan, serta menghasilkan tag 128-bit [1]. RTL melakukan satu ronde per siklus aktif dan controller mengatur absorb/padding, domain separation, pemrosesan pesan, serta verifikasi tag. KAT Ascon-C v1.3.0 dan sampel ACVP NIST digunakan sebagai sumber pembanding; referensi tidak disalin mentah ke RTL [9], [10].

#### 3.1.4 Potensi Kebaruan Algoritma dan Kontribusi Hardware

**Status klaim saat ini:** belum ada modifikasi algoritma kriptografi. Mengubah konstanta, padding, IV, jumlah ronde, atau urutan operasi Ascon akan menghasilkan algoritma yang tidak lagi sesuai SP 800-232 dan memerlukan analisis keamanan independen. Hal tersebut tidak diusulkan.

**Eksperimen algoritmik/control yang layak diuji:** bandingkan baseline satu-pass yang menghitung tag sambil menghasilkan calon plaintext ke buffer dengan alternatif dua-pass:

1. Pass pertama memproses key, nonce, AD, dan ciphertext memakai operasi dekripsi standar untuk menghitung/verifikasi tag, tetapi membuang byte plaintext hasil XOR dan tidak meneruskannya ke interface.
2. Jika tag cocok, pass kedua menginisialisasi ulang state dan memproses ulang AD/ciphertext yang sama untuk mengeluarkan plaintext.
3. Jika tag tidak cocok, pass kedua tidak dijalankan dan tidak ada plaintext yang keluar.

Ascon tetap tidak berubah. Input AD/ciphertext harus disimpan stabil selama kedua pass, dan key/nonce harus konsisten. Pendekatan dua-pass untuk memisahkan autentikasi dari keluaran dekripsi telah memiliki preseden pada konteks crypto engine FPGA [11]; karenanya pola tersebut bukan novelty yang dapat diklaim sebagai temuan pertama. Hipotesis khusus proyek yang dapat diuji ialah apakah pembuangan hasil plaintext pada pass pertama mengurangi kebutuhan buffer plaintext atau memudahkan invariant guard dibanding baseline pada profil DE10-Nano. Biayanya diperkirakan berupa pemrosesan kriptografi ulang, latency lebih besar, kontrol tambahan, dan buffer input yang tetap diperlukan. Untuk kapasitas saat ini yang hanya 16 byte, penghematan mungkin kecil atau nihil.

Eksperimen ini **belum diimplementasikan**. Kriteria lanjut: (a) KAT enkripsi/dekripsi tetap cocok; (b) perubahan satu bit pada AD, ciphertext atau tag tidak pernah menghasilkan transfer plaintext; (c) reset/error/backpressure tidak membuka output; (d) bandingkan register/ALM, siklus sampai hasil, Fmax dan bila tersedia daya pada tool/device/constraint yang sama; (e) dokumentasikan asumsi buffer input dan masa hidup key/calon plaintext. Jika tidak ada manfaat yang terukur atau trade-off tidak sesuai use case, desain baseline dipertahankan dan tidak dibuat klaim novelty algoritmik. Kontribusi paling dapat dipertanggungjawabkan saat ini adalah kontribusi integrasi guard dan bukti verifikasi, bukan algoritma baru.

#### 3.1.5 Estimasi Penggunaan Resource FPGA

| Metrik | Status dan nilai |
|---|---|
| Device/build | **Hasil aktual tercatat:** Cyclone V `5CSEBA6U23I7`, Quartus Prime Lite 25.1, parameter `MAX_DATA_BYTES=16` untuk AD dan data. |
| ALM | **Hasil aktual tercatat:** 2.464 ALM (6% dari 41.910 menurut report proyek). |
| LUT/LE | **Tidak dilaporkan sebagai angka LUT/LE mandiri pada ringkasan build ini.** Proposal menggunakan unit ALM yang dilaporkan Quartus dan tidak mengonversinya ke LUT/LE lintas device/tool. |
| Register | **Hasil aktual tercatat:** 2.800 register. |
| Memori/DSP | **Hasil aktual tercatat:** 0 M10K/RAM bits dan 0 DSP pada konfigurasi tersebut. |
| Timing | **Hasil aktual tercatat:** Fmax 79,72 MHz pada jalur clock yang dilaporkan; clock SDC 50 MHz, setup slack +7,456 ns, hold slack +0,338 ns. Sebanyak 616 port transaksi virtual/unconstrained membatasi interpretasi timing I/O. |
| Bitstream | **Hasil aktual tercatat:** `.sof` dibuat, ukuran 6.690.378 byte. Ini bukan bukti bitstream telah diprogram ke board. |
| Power/energy | **TBD — belum diukur.** |
| Perkiraan kandidat dua-pass | **Belum ada estimasi kuantitatif.** Harus disintesis setelah RTL dibuat; jumlah pass tidak dapat langsung diterjemahkan menjadi rasio resource/power. |

Angka di atas berasal dari build ulang 6 Oktober 2026 dan dicatat bersama versi tool serta konfigurasi di `docs/results.md` [13]. Persentase ALM tidak setara dengan logic element, LUT, tile, atau gate count pada device lain [6]. Quartus menggunakan Auto Fit dan analisis jalur I/O belum lengkap karena port transaksi virtual; hasil ini membuktikan compile FPGA, bukan sign-off board atau timing antarmuka fisik.

#### 3.1.6 Perangkat Lunak & Tools Perancangan

| Tool | Kegunaan | Status bukti |
|---|---|---|
| Intel Quartus Prime Lite 25.1 | Sintesis, fitter, timing, assembler Cyclone V. | Build ulang 6 Okt 2026: 0 error, 5 warning; hasil dan batas constraint dirinci di §3.1.5 [13]. |
| Icarus Verilog | Kompilasi dan simulasi testbench SystemVerilog. | Dipakai dalam regresi tercatat. |
| Verilator | Lint RTL. | Ulang 6 Okt 2026: Verilator 5.053, 9 modul, 0 warning; bukan bukti kebenaran fungsional. |
| GTKWave | Meninjau VCD. | VCD simulasi tersedia menurut catatan; lampiran capture perlu dipilih. |
| Python | Model pembanding dan pemeriksaan vector. | Dipakai untuk 1.089 KAT Ascon-C dan 14 sampel ACVP byte-aligned; bukan sertifikasi ACVP [9], [10]. |
| Yosys | Sintesis generik tambahan. | Ulang 6 Okt 2026: 20.937 sel generik dan `check` 0 masalah; angka ini bukan resource Cyclone V. Selisih +50 dari catatan historis 20.887 belum terjelaskan dan tidak dipakai untuk klaim peningkatan/kemunduran. |
| ModelSim/Questa | Alternatif simulator bila diperlukan. | Belum digunakan. |
| Platform Designer (Qsys) | Integrasi wrapper IP dengan interconnect/HPS bila jalur host dipilih [7]. | Rencana; belum ada komponen/wrapper proyek. |
| C | Driver/demo HPS setelah interface host tersedia. | Rencana; belum ada driver. |
| SignalTap Logic Analyzer | Pengamatan internal FPGA real-time [8]. | Belum dikompilasi untuk debug atau diuji di board; edisi/dukungan instalasi perlu dikonfirmasi. |

### 3.2 Rencana Pengujian

#### 3.2.1 Simulasi RTL, Testbench Otomatis, dan Functional Verification

Validasi ulang 6 Oktober 2026 menjalankan `scripts/run_all_tests.ps1`; seluruh 7/7 runner selesai dengan exit code 0. RTL core cocok dengan 1.089 KAT Ascon-C untuk setiap arah enkripsi dan dekripsi (2.178 transaksi, total 121.308 siklus, maksimum 88 siklus). Top-level mencakup 289 pasangan panjang AD/pesan 0–16 byte pada dua mode (578 transaksi, total 51.019 siklus, maksimum 150 siklus). Kasus terarah mencakup AD/ciphertext/tag yang dimodifikasi, penahanan plaintext sebelum autentikasi, backpressure, start saat sibuk, reset pada beberapa fase, serta penolakan kapasitas berlebih. Hasil membuktikan perilaku untuk testbench yang dijalankan, bukan bukti formal atau ketahanan terhadap serangan fisik.

Model Python cocok dengan 1.089 KAT Ascon-C dan 14 sampel ACVP byte-aligned [9], [10]. Checker tidak memvalidasi 226 dari 240 sampel ACVP non-byte-aligned; cakupan itu tetap belum diuji. Icarus mengeluarkan advisory `constant selects in always_* processes are not fully supported`, tetapi seluruh assertion berjalan dan runner berhasil. Log run terbaru: `sim/regression_20261006.log`; VCD yang dihasilkan ulang berada di `sim/`. VCD adalah bukti simulasi RTL, bukan capture DE10-Nano. Rincian versi tool dan hasil sebelum/sesudah ada di `docs/results.md` [13].

Lint Verilator juga diulang dan lulus tanpa warning untuk top-level 9 modul. Sintesis generik Yosys `check` melaporkan 0 masalah dan menghasilkan 20.937 sel; angka historis yang tercatat adalah 20.887. Karena log lama tidak ada untuk memeriksa konfigurasi rinci, selisih 50 sel belum terjelaskan dan tidak ditafsirkan sebagai peningkatan atau regresi. Resource Cyclone V yang dipakai proposal berasal dari laporan Quartus, bukan hitungan sel Yosys.
#### 3.2.2 Corner Case dan Invariant

| Kasus | Kriteria lulus | Bukti/status |
|---|---|---|
| KAT enkripsi dan dekripsi, panjang kosong/parsial | Ciphertext, plaintext dan tag sama dengan vector referensi. | Simulasi core tercatat lulus untuk 1.089 KAT per arah. |
| Panjang AD/data 0–16 byte | Hasil dan handshake sesuai kontrak. | 578 transaksi top-level tercatat lulus. |
| AD/ciphertext/tag diubah | `reject` pada dekripsi; nol transfer plaintext. | Skenario negatif terarah tercatat lulus. |
| Backpressure dan start saat busy | Data/status tertahan sesuai handshake; start baru tidak merusak transaksi. | Kasus terarah tercatat lulus. |
| Reset pada fase berbeda dan overcapacity | Transaksi dibatalkan/ditolak sesuai kontrak; tidak ada plaintext terbuka. | Kasus terarah tercatat lulus. |
| Urutan banyak transaksi dan lifecycle register | Key/state/calon plaintext dibersihkan sesuai kebijakan terdokumentasi. | Belum dibuktikan menyeluruh; inventaris dan pengujian diperlukan. |
| ACVP non-byte-aligned | Dukungan sesuai ruang lingkup bit-level. | Belum tercakup checker sekarang. |

#### 3.2.3 Timing/Latency Analysis dan Metrik Keberhasilan

| Metrik | Hasil saat ini | Kriteria/aksi berikutnya |
|---|---|---|
| Kebenaran fungsi | **Aktual:** 7/7 runner PASS, termasuk 2.178 transaksi KAT core dan 578 transaksi top-level pada panjang 0–16 byte. | Perluas vector byte-aligned/non-byte-aligned yang didukung dan jalankan kembali pada setiap perubahan RTL; bukan bukti formal. |
| Penolakan autentikasi | **Aktual simulasi:** perubahan AD/ciphertext/tag ditolak tanpa menawarkan plaintext. | Ulangi pada board setelah wrapper tersedia; tambahkan pemeriksaan invariant pada seluruh jalur keluaran. |
| Latency | **Aktual simulasi:** core maksimum 88 siklus; top-level maksimum 150 siklus di sweep. Contoh top-level enkripsi 16 byte tanpa AD: 96 siklus (KAT Count 529). | Catat beban spesifik, waktu transfer/stall dan titik ukur `start`→`done`; board tetap TBD. |
| Clock/timing | Fmax 79,72 MHz untuk jalur clock yang terlapor; target SDC 50 MHz. | Lengkapi pin dan input/output delay; ulangi STA, pastikan slack memenuhi semua constraint. Angka kini belum sign-off I/O. |
| Throughput | **Belum diukur sebagai throughput fisik.** Hitungan turunan 16 byte × 8 × 50 MHz / 96 siklus = 66,7 Mbit/s jika transaksi berulang tanpa jeda pada clock 50 MHz. Ini estimasi siklus ideal, bukan hasil board atau transaksi kontinu. | Ukur throughput end-to-end dan siklus idle/transfer pada board; bandingkan dengan software pada HPS yang sama. |
| Resource | 2.464 ALM, 2.800 register, 0 M10K, 0 DSP tercatat. | Build ulang source final; pisahkan overhead wrapper dan SignalTap; bandingkan hanya dengan konfigurasi setara. |
| Power/energi | TBD — belum diukur; Quartus Power Analyzer tidak dijalankan. | Tetapkan metode ukur board, kondisi idle/transaksi, workload, dan hitung energi/transaksi dari data aktual. |
| Real-time | Belum ada workload/deadline aplikasi yang divalidasi. | Tentukan use case dan deadline sebelum menetapkan klaim real-time atau ambang lulus. |

Nilai ambang resource, latency, throughput, dan power belum disepakati; tidak diisi dengan angka spekulatif.

#### 3.2.4 Bitstream DE10-Nano, SignalTap, dan Uji On-Board

Pengujian board fisik **belum dilakukan**. Setelah board dan interface tersedia:

1. Tetapkan jalur host (misalnya HPS/Avalon melalui Platform Designer atau pin transaksi khusus), protokol, clock/reset, pinout, dan driver.
2. Ganti port virtual dengan pin/constraint yang benar; build ulang dan periksa warning serta setup/hold seluruh interface.
3. Buat bitstream yang memuat SignalTap untuk menangkap `start`, state controller, `busy/done`, handshake stream, tag, `accept/reject`, dan `out_valid`; simpan project/capture serta versi source. SignalTap harus dimasukkan ke desain sebelum compile dan dapat mengonsumsi resource [8].
4. Program board melalui JTAG dan jalankan KAT valid, pesan kosong/parsial, serta AD/ciphertext/tag invalid. Catat output, status, byte count, latency siklus, dan bukti capture.
5. Ukur throughput dan daya hanya dengan workload, metode, alat, serta kondisi board yang dijelaskan. Sampai tahap itu, metrik tersebut tetap TBD.

### 3.3 State of the Art, Research Gap, dan Perbandingan Existing

Karya Ascon hardware sudah tersedia dalam bentuk RTL terbuka, implementasi dengan countermeasure fisik, dan accelerator yang terhubung ke prosesor [3], [4], [12]. Karena itu research gap proposal dibatasi: **mengevaluasi pilihan integrasi controller/buffer/guard pada IP byte-stream mandiri yang menjaga plaintext dekripsi tetap tertahan, di konfigurasi demonstrator Cyclone V dengan verifikasi dan bukti build yang dapat ditelusuri**. Ini gap rekayasa/benchmark yang diuji proyek, bukan klaim bahwa belum ada sistem lain yang memenuhi invariant tersebut.

| Solusi/publikasi | Fungsi dan arsitektur | Data yang dilaporkan sumber | Perbandingan objektif dan keterbatasan |
|---|---|---|---|
| Primas, Ascon RTL [4] | RTL Ascon SP 800-232; bus 32/64-bit, unrolling 1/2/4, interface valid/ready. README menyatakan plaintext dekripsi dapat keluar sebelum tag terverifikasi dan menyarankan buffer tambahan. | Varian 32-bit/1-round melaporkan 41, 99, 1.587 siklus untuk pasangan AD/pesan 0+0, 32+32, 1.024+1.024 byte. Angka dokumentasi repositori, bukan pengukuran SECURE-TINY. | Pembanding algoritma paling dekat. Interface, kapasitas, stall, device, dan definisi siklus berbeda; bukan benchmark head-to-head. SECURE-TINY menempatkan buffer/gate dalam top-level. |
| Kandi dkk., Ascon tahan side-channel/fault [3] | Ascon AEAD/hash dengan countermeasure side-channel dan fault, dievaluasi hardware. | Paper melaporkan beberapa konfigurasi ASIC/FPGA dengan overhead bergantung countermeasure/platform. | Menegaskan proteksi fisik merupakan sasaran terpisah. Guard SECURE-TINY hanya mengatur aliran digital; tidak boleh disamakan dengan mitigasi side-channel/fault. |
| OpenTitan AES HWIP/GCM [5] | Akselerator AES multibentuk dengan GCM opsional, register CSR dan opsi masking/key sideload; software mengatur fase GCM. | Dokumentasi memberi detail operasi/latency AES, bukan angka total AEAD yang sepadan dengan Ascon top-level. | Relevan sebagai integrasi crypto accelerator pada SoC, tetapi primitive, arsitektur, interface, dan threat model berbeda; tidak cocok untuk perbandingan resource langsung. |
| Ascon accelerator RISC-V [12] | Accelerator Ascon dikopel ke CPU RISC-V; paper mengevaluasi biaya/kecepatan implementasi. | Paper melaporkan estimasi sekitar 4,7 kGE dan sekitar 2 siklus/byte, atau 4 siklus/byte dengan proteksi pada konfigurasi penulis. | ASIC/gate-equivalent dan protokol CPU berbeda dari ALM Cyclone V dan stream SECURE-TINY; nilai mentah tidak disetarakan. |
| Tiny Tapeout bit-serial Ascon [14] | Ascon-AEAD128 bit-serial dengan state register berputar dan S-box bersama; host mengatur operasi/penjadwalan. | Dokumentasi proyek melaporkan satu ronde 128 siklus, p8 1.024 siklus dan p12 1.536 siklus, serta dua tile. | Contoh trade-off serialitas dan luas pada platform Tiny Tapeout, bukan FPGA Cyclone V; workload dan kontrol host berbeda. |
| RECO-HCON [17] | Prosesor Ascon kompak yang dapat dikonfigurasi ulang untuk IoT tepercaya. | Publikasi melaporkan arsitektur reconfigurable; angka tidak dipakai sebagai pembanding langsung karena platform dan profil berbeda. | Menunjukkan reconfigurability Ascon sudah pernah diteliti; bukan novelty tersendiri bagi proposal ini. |
| Mohamed dkk. [16] | Implementasi Ascon serial pada FPGA iCE40 serta evaluasi ASIC. | Paper 2026 melaporkan beberapa metrik area, frekuensi, dan daya untuk implementasi mereka. | Paper menguraikan trade-off serial; varian/versi Ascon, device, interface, dan metode ukur perlu dinormalisasi sebelum perbandingan kuantitatif dengan standar SP 800-232 dan Cyclone V. Tidak digunakan sebagai klaim head-to-head. |
| SECURE-TINY | Controller AEAD byte-stream, satu ronde/siklus aktif, input buffer terbatas, tag verifier dan plaintext guard. | Hasil internal: 2.464 ALM, 2.800 register, Fmax 79,72 MHz; core KAT maksimum 88 siklus dan top-level maksimum 150 siklus dalam pengujian tercatat. | Baseline proyek. I/O belum constrained lengkap dan board belum diuji; tidak ada klaim lebih cepat, lebih hemat daya, atau lebih aman secara fisik. |

Angka siklus/area/frekuensi di tabel berasal dari metode dan platform berbeda; cycle core, cycle transaksi penuh, ALM, kGE, tile, dan logic element bukan satuan yang langsung dapat dibandingkan. Benchmark adil memerlukan workload, tool/device, clock constraint, interface, serta batas pengukuran yang sama.

### 3.4 Use Case, Integrasi Sistem, dan Alasan Memakai Akselerator

**Use case utama yang diusulkan: telemetri meter ke gateway AMI.** NISTIR 7628 membahas kebutuhan keamanan smart grid, termasuk kerahasiaan dan integritas komunikasi meter [15]. Proposal tidak menyatakan semua implementasi AMI saat ini tidak aman dan tidak mengganti protokol meter yang berlaku. Demonstrator memakai payload ilustratif 16 byte: AD memuat identitas meter 8 byte serta nomor urut/jenis rekaman 8 byte; payload memuat nilai pembacaan 8 byte dan timestamp 8 byte. Panjang tersebut hanya pemetaan demonstrasi agar sesuai dengan konfigurasi MAX_DATA_BYTES=16, bukan format standar industri.

Alur integrasi yang direncanakan: meter/sensor dan protokol lapangan menghasilkan rekaman; HPS atau host memvalidasi format, memilih key dan nonce unik, lalu mengirim AD/payload ke IP melalui wrapper bus yang belum dibuat. FPGA mengeluarkan ciphertext dan tag; host membentuk paket nonce + AD + ciphertext + tag dan mengirimkannya ke gateway. Penerima memasukkan data ke jalur dekripsi, dan aplikasi hanya memakai plaintext setelah sinyal accept. Key provisioning, penyimpanan rahasia, pencatatan anti-replay/urutan pesan, framing jaringan, dan jaminan keunikan nonce berada di luar IP saat ini dan harus ditangani sistem.

**Contoh penggunaan lain:** (1) sensor kondisi mesin mengirim sampel suhu/tekanan/getaran ke PLC atau gateway edge; (2) sensor lingkungan atau pertanian mengirim pengukuran ke gateway lapangan; (3) perangkat bergerak mengamankan rekaman status ringkas saat koneksi ke gateway. Semua contoh adalah sasaran pengembangan, bukan deployment yang telah dilakukan. AMI dipilih sebagai fokus proposal karena relevansi keamanan smart grid didukung sumber institusi [15], sedangkan kebutuhan frekuensi transaksi, format data, protokol, dan latency dari calon pengguna masih harus dikonfirmasi.

Hardware accelerator dapat memberi jalur eksekusi khusus dengan jumlah siklus yang dapat diprediksi dan berpotensi mengurangi beban CPU saat banyak transaksi; untuk pesan pendek, transfer data, kontrol host, atau frekuensi rendah, software bisa lebih sederhana dan mungkin lebih efisien. Keunggulan belum dibuktikan pada proyek ini: tidak ada benchmark software Ascon pada HPS Cortex-A9 yang sama, tidak ada biaya transfer bus yang diukur, dan power analyzer/energi board belum dijalankan. Perbandingan yang sah perlu memakai vector, key/nonce workload, payload, clock, definisi latency end-to-end, serta konfigurasi software dan hardware yang setara. DE10-Nano menyediakan HPS Cortex-A9, Ethernet, dan FPGA fabric yang memungkinkan demonstrator HPS-ke-IP-ke-jaringan setelah adapter dikembangkan [6].

### 3.5 Skalabilitas: dari Ascon Tetap ke Akselerator Konfigurabel

Arsitektur saat ini adalah accelerator khusus Ascon-AEAD128. Bagian yang berpotensi dipertahankan untuk platform lebih umum adalah command/control, stream valid-ready, buffer/transaksi, bus wrapper yang kelak dibuat, pencatatan panjang, status selesai/error, dan kebijakan keluaran plaintext setelah `auth_valid`. Bagian yang khusus Ascon dan tidak dapat dipakai ulang begitu saja mencakup permutasi 320-bit, konstanta ronde, rate/padding, inisialisasi/finalisasi, jadwal ronde, panjang tag dan semantik key/nonce.

Roadmap yang realistis:

| Tahap | Pengembangan | Bagian yang dipertahankan/diubah | Bukti sebelum klaim |
|---|---|---|---|
| 1. Baseline Ascon (cakupan hackathon) | Selesaikan pengujian dan integrasi IP Ascon-AEAD128 tetap. | Pertahankan core, kontrol byte-stream, buffer, verifier, dan guard yang ada; tambahkan adapter host hanya bila waktu/perangkat tersedia. | KAT, kasus invalid, timing lengkap, build board dan transaksi fisik jika tersedia. |
| 2. Arsitektur configurable/reconfigurable | Parameterisasi lebar datapath/jumlah ronde per siklus, ukuran buffer, serta pemilihan konfigurasi inti saat elaborasi atau melalui wrapper. | Controller/buffer/guard dapat dikembangkan; datapath dan penjadwalan berubah menurut konfigurasi. Core Ascon tetap melalui KAT di setiap profil. | Sweep area, latency, Fmax dan energi pada platform/constraint/workload seragam. Serialisasi dan reconfigurability sendiri telah memiliki prior art [16], [17], sehingga bukan klaim novelty otomatis. |
| 3. Multi-algoritma standar | Buat antarmuka engine AEAD dengan parameter algoritma, key/nonce/tag, rate, dan handshake; tambahkan core standar lain hanya melalui spesifikasi tersendiri. | Bus, antrean transaksi dan sebagian guard dapat digunakan ulang; tiap primitive memerlukan core, formatter, verifier dan validasi khusus. | KAT resmi per algoritma, uji interoperability, analisis nonce/tag, biaya context switch dan benchmark bersama. |
| 4. Algoritma kriptografi rancangan sendiri | Tidak disarankan sebagai target kompetisi atau penggunaan produk saat ini. | Wrapper dapat menjadi platform eksperimen; datapath, konstanta, mode operasi, verifikasi, dan parameter keamanan harus dirancang ulang. | Definisi threat model dan bukti keamanan, implementasi referensi independen, cryptanalysis peer-reviewed, KAT/fuzzing, analisis side-channel/fault, dan evaluasi terbuka sebelum klaim aman. |

Membuat algoritma baru yang berbeda dari Ascon bukan novelty yang cukup dan membawa risiko keamanan tinggi. Untuk kompetisi, fokus yang dapat dipertanggungjawabkan adalah optimasi arsitektur dan evaluasi konfigurasi berdasarkan metrik, tanpa mengubah primitive standar. Istilah “reconfigurable” juga perlu dibatasi: parameter saat elaborasi bukan berarti algoritma dapat diganti saat runtime.

### 3.6 Informasi dan Bukti yang Masih Perlu Dilengkapi

Sebelum proposal diajukan, lengkapi NIM, program studi, kontak, pembimbing dan ejaan nama anggota; validasi dengan calon pengguna apakah AMI serta paket demonstrasi relevan. Tetapkan frekuensi pesan, batas latency, format interoperabilitas dan ancaman anti-replay. Untuk demo sistem, implementasikan wrapper HPS/Avalon atau adapter pin yang eksplisit, driver C, key/nonce lifecycle, framing paket, constraint I/O, uji board, serta capture SignalTap. Benchmark software-versus-hardware perlu mengukur baseline HPS yang sama dan memasukkan overhead transfer. Pengujian ACVP non-byte-aligned, power/energy, zeroization, side-channel dan fault injection masih belum dilakukan.

### 3.7 Kelayakan, Risiko, dan Dampak

| Risiko/keterbatasan | Dampak | Mitigasi |
|---|---|---|
| Belum ada akses board/interface host terdefinisi | Tidak dapat membuktikan transaksi real-time atau SignalTap fisik. | Konfirmasi board dan pilih protokol/pinout; pisahkan hasil simulasi dan build dari hasil board. |
| Port virtual belum memiliki constraint I/O penuh | Fmax internal tidak menunjukkan timing seluruh antarmuka. | Lengkapi constraint pin/IO delay dan ulangi STA. |
| Kapasitas 16 byte | Use case payload lebih besar belum didukung profil ini. | Validasi workload, lalu ukur varian kapasitas lain dan dampak buffer. |
| Zeroization dan serangan fisik belum diuji | Tidak layak membuat klaim lifecycle, side-channel, atau fault resistance. | Inventaris register, definisikan kebijakan clear dan threat model; evaluasi countermeasure sebagai pekerjaan tersendiri. |
| Kandidat dua-pass dapat menambah latency | Bisa tidak cocok bagi aplikasi dengan deadline ketat. | Prototipe sebagai eksperimen terpisah; ukur trade-off dan pertahankan baseline jika tidak memberi manfaat. |

**Dampak yang diharapkan:** menyediakan IP demonstrator Ascon-AEAD128 yang modular, testable, dan memiliki batas autentikasi plaintext yang terlihat pada interface; serta basis eksperimen untuk pendidikan dan pengembangan akselerator edge. Pengurangan latency, energi, biaya, atau risiko keamanan sistem belum dibuktikan dan tidak diklaim.

### 3.8 Catatan Konsolidasi Kedua Draft

| Bagian yang berbeda/kurang tegas | Keputusan dalam proposal final | Dasar keputusan |
|---|---|---|
| Draft awal membahas kebutuhan edge/IoT secara luas; draft berikutnya memusatkan isu pada plaintext sebelum autentikasi. | Problem statement dipusatkan pada keselamatan keluaran dekripsi dan kebutuhan mengukur IP; kebutuhan pengguna/industri tertentu masih harus divalidasi. | Klaim umum tidak disamakan dengan hasil survei atau workload PERURI. |
| Draft awal menekankan hardware guard; draft berikutnya menyebut novelty sebagai integrasi controller/buffer/guard. | Guard ditulis sebagai kontribusi integrasi yang dapat dibuktikan, bukan novelty algoritma atau klaim pertama. Dua-pass hanya hipotesis eksperimen dan presedennya disebut. | Konsisten dengan standar Ascon dan literatur implementasi yang sudah ada. |
| Draft berikutnya memiliki nama tim/anggota, sedangkan draft awal belum mencantumkannya. | Nama tim dan anggota dimasukkan sesuai draft berikutnya; ejaan, NIM, program studi, kontak, dan pembimbing ditandai untuk konfirmasi. | Mencegah mengarang data administratif. |
| Angka simulasi/build sebelumnya berasal dari run Oktober; perlu validasi ulang untuk proposal yang diperkuat. | Semua suite sim, lint, Yosys dan full Quartus build dijalankan ulang 6 Okt 2026. Baseline functional/Quartus sama; selisih Yosys 50 sel diungkap tanpa atribusi. | Rincian, command, log, artefak dan batasan ada di `docs/results.md` serta `sim/regression_20261006.log`. |
| Pembanding memakai device, unit resource, interface, dan definisi latency berbeda. | Data sumber dicantumkan dengan keterbatasan; tidak dibuat ranking numerik atau klaim superioritas SECURE-TINY. | ALM, kGE, tile, cycle dan MHz tidak langsung setara lintas implementasi. |

## Daftar Pustaka

[1] M. Sönmez Turan, K. McKay, J. Kang, J. Kelsey, and D. Chang, *Ascon-Based Lightweight Cryptography Standards for Constrained Devices: Authenticated Encryption, Hash, and Extendable Output Functions*, NIST SP 800-232, Aug. 2025, doi: 10.6028/NIST.SP.800-232.

[2] M. Fagan, K. Megas, K. Scarfone, and M. Smith, *IoT Device Cybersecurity Capability Core Baseline*, NISTIR 8259A, May 2020, doi: 10.6028/NIST.IR.8259A.

[3] A. Kandi et al., “Side-channel and fault resistant ASCON implementation: A detailed hardware evaluation,” in *Proc. IEEE Computer Society Annual Symposium on VLSI (ISVLSI)*, 2024, pp. 307–312, doi: 10.1109/ISVLSI61997.2024.00063.

[4] R. Primas, “Hardware Design of Ascon (SP 800-232),” `rprimas/ascon-verilog`, GitHub repository. [Online]. Available: https://github.com/rprimas/ascon-verilog. [Accessed: Oct. 6, 2026]. Angka siklus dan perilaku output yang disebut di proposal berasal dari dokumentasi repository.

[5] lowRISC, “AES HWIP Technical Specification” and “Programmer’s Guide: Galois/Counter Mode (GCM),” *OpenTitan Documentation*. [Online]. Available: https://opentitan.org/book/hw/ip/aes/ and https://opentitan.org/book/hw/ip/aes/doc/programmers_guide.html. [Accessed: Oct. 6, 2026].

[6] Terasic Technologies, “DE10-Nano Development and Education Board: Specifications.” [Online]. Available: https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=165&Language=English&No=1046&PartNo=2. [Accessed: Oct. 6, 2026].

[7] Intel, “Platform Designer,” *Quartus Prime Design Software*. [Online]. Available: https://www.altera.com/products/development-tools/quartus-prime/platform-designer. [Accessed: Oct. 6, 2026].

[8] Intel, *Quartus Prime Standard Edition User Guide: Debug Tools*, “Design Debugging with the Signal Tap Logic Analyzer.” [Online]. Available: https://www.intel.com/programmable/technical-pdfs/683552.pdf. [Accessed: Oct. 6, 2026]. Dukungan edisi SignalTap pada tool yang digunakan perlu dikonfirmasi sebelum uji board.

[9] Ascon Team, “Ascon-C v1.3.0,” file `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`. [Online]. Available: https://github.com/ascon/ascon-c/tree/v1.3.0. [Accessed: Oct. 6, 2026].

[10] NIST, “Ascon-AEAD128 SP 800-232 sample vectors,” *Automated Cryptographic Validation Protocol Server*. [Online]. Available: https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232. [Accessed: Oct. 6, 2026]. Penggunaan sampel pada proyek tidak merupakan sertifikasi ACVP.

[11] M. Unterstein, N. Jacob, N. Hanley, X. Gu, and M. Heyszl, “SCA secure and updatable crypto engines for FPGA SoC bitstream decryption,” *Journal of Cryptographic Engineering*, vol. 11, pp. 1–16, 2021, doi: 10.1007/s13389-020-00247-2.

[12] D. Steinegger and R. Primas, “An Ascon-based RISC-V instruction set extension for authenticated encryption,” *IACR Cryptology ePrint Archive*, Report 2020/1083, 2020. [Online]. Available: https://eprint.iacr.org/2020/1083. [Accessed: Oct. 6, 2026].

[13] Tim SECURE-TINY, *Catatan Hasil Simulasi dan Build FPGA*, `docs/results.md`, validasi ulang proyek 6 Okt. 2026. Dokumen proyek lokal yang mencatat konfigurasi, perintah, log, report Quartus, hasil aktual, dan batas interpretasinya.

[14] P. Ul, “Ascon AEAD128,” Tiny Tapeout project `tt_um_pranavUl_ascon_aead128`. [Online]. Available: https://tinytapeout.com/chips/ttsky26c/tt_um_pranavUl_ascon_aead128. [Accessed: Oct. 6, 2026]. Angka arsitektur/siklus berasal dari dokumentasi proyek, bukan benchmark independen.

[15] V. Pillitteri and T. Brewer, *Guidelines for Smart Grid Cybersecurity*, NISTIR 7628 Rev. 1, Sep. 2014, doi: 10.6028/NIST.IR.7628r1. [Online]. Available: https://doi.org/10.6028/NIST.IR.7628r1. Digunakan sebagai dasar relevansi umum keamanan komunikasi smart grid/AMI, bukan bukti kebutuhan produk tertentu.

[16] H. A. A. Mohamed, M. Taher, H. M. Shousha, Z. Mohsen, M. M. Abdelrazik, Y. Ismail, and A. Saeed, “An efficient serialized hardware implementation of the ASCON algorithm,” *Scientific Reports*, vol. 16, Art. no. 23197, 2026, doi: 10.1038/s41598-026-63223-6. [Online]. Available: https://www.nature.com/articles/s41598-026-63223-6. Metrik paper tidak dibandingkan langsung dengan SECURE-TINY karena perbedaan platform dan perlu normalisasi versi algoritma.

[17] X. Wei et al., “RECO-HCON: A High-Throughput Reconfigurable Compact ASCON Processor for Trusted IoT,” in *Proc. IEEE 35th International System-on-Chip Conference (SOCC)*, 2022, pp. 1–6, doi: 10.1109/SOCC56010.2022.9908100.
