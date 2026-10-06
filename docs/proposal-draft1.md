# Proposal SECURE-TINY

**Status naskah:** draf teknis untuk dilengkapi identitas dan hasil demo board. Susunan mengikuti struktur template Proposal Peserta Hackathon CHIP 2026 yang diminta.

**Judul:** SECURE-TINY: IP Core Ascon-AEAD128 dengan Pengendali Transaksi dan Guard Keluaran Dekripsi untuk FPGA Cyclone V

**Tim:** Ngadu Nasib — Universitas Pendidikan Indonesia  
**Anggota:** Ripan (ketua), Andhika Pratama, Andra Vijatmi, Muhammad Iqbal Ridho.  
**Pembimbing/kontak/NIM:** perlu dilengkapi oleh tim.

## 1. Ringkasan Ide (Executive Summary)

### 1.1 Masalah yang Diangkat

Pesan digital perlu dijaga kerahasiaan dan integritasnya. Pada dekripsi AEAD, aplikasi harus memperlakukan plaintext sebagai belum sah sampai tag autentikasi cocok. Risiko antarmuka muncul bila perangkat keras mengeluarkan calon plaintext sebelum verifikasi selesai. Dokumentasi core Ascon terbuka yang kami jadikan pembanding juga secara eksplisit menyarankan buffer eksternal karena desain tersebut mengeluarkan plaintext dekripsi sebelum tag tervalidasi [4]. Kebutuhan keamanan perangkat tetap perlu diturunkan dari konteks penggunaan dan model ancamannya; SECURE-TINY tidak menganggap seluruh perangkat edge atau transaksi PERURI memiliki satu kebutuhan yang sama [2].

### 1.2 Solusi yang Ditawarkan

SECURE-TINY adalah IP SystemVerilog untuk Ascon-AEAD128 sesuai NIST SP 800-232 [1]. IP menerima key, nonce, Associated Data (AD), dan data pesan. Mode enkripsi menghasilkan ciphertext dan tag; mode dekripsi menghasilkan ACCEPT/REJECT dan hanya menawarkan plaintext setelah tag cocok. Pengendali RTL mengatur satu transaksi pada satu waktu, sementara buffer internal menampung AD dan pesan sampai proses core selesai. Parameter build saat ini membatasi masing-masing AD dan pesan sampai 16 byte.

Guard autentikasi adalah logika pengendali izin keluaran, bukan algoritma baru, sensor tamper, atau countermeasure side-channel. Kontribusi yang diajukan adalah integrasi fungsi tersebut dengan kontrak transaksi byte-level dan bukti uji fungsional yang dapat diulang.

### 1.3 Implementasi pada DE10-Nano

Target Quartus adalah Cyclone V `5CSEBA6U23I7` pada DE10-Nano; spesifikasi board menyebut perangkat tersebut dan menyediakan HPS ARM Cortex-A9 serta FPGA fabric [6]. Build Quartus Prime Lite 25.1 yang tercatat menggunakan `MAX_DATA_BYTES=16` dan clock 50 MHz. Fitter melaporkan 2.464 ALM, 2.800 register, nol M10K, dan nol DSP; Timing Analyzer melaporkan Fmax 79,72 MHz pada clock yang dianalisis; Assembler menghasilkan `.sof`. Angka tersebut adalah hasil build, bukan hasil uji board atau bukti keunggulan terhadap desain lain. Semua port transaksi masih virtual, sehingga timing I/O belum sepenuhnya constrained; interface HPS/Avalon, pemetaan pin transaksi, pemrograman board, serta pengujian fisik masih direncanakan. Detail konfigurasi dan keterbatasan tercatat di `docs/results.md`.

### 1.4 Kebaruan dan Keunggulan

Ascon telah distandardisasi NIST, dan implementasi perangkat keras Ascon serta countermeasure side-channel/fault telah dipublikasikan [1], [3]. Karena itu, SECURE-TINY tidak mengklaim algoritma baru, implementasi Ascon pertama, atau keamanan lebih tinggi.

Kebaruan yang diajukan bersifat **rekayasa integrasi**: satu IP demonstrator yang menangani transaksi AEAD, penyangga calon plaintext, dan keputusan autentikasi pada RTL, dengan pengujian negatif yang memeriksa tidak adanya handshake plaintext saat autentikasi gagal. Nilai lebih yang sudah dapat dibuktikan adalah adanya simulasi KAT, pengujian integrasi, serta build Quartus. Belum ada benchmark setara yang membuktikan desain ini lebih kecil, lebih cepat, lebih hemat energi, atau lebih aman daripada pembanding. Belum ada validasi board.

## 2. Latar Belakang & Rumusan Masalah (Problem Statement)

### 2.1 Latar Belakang

NIST SP 800-232 menetapkan Ascon-AEAD128 sebagai salah satu standar kriptografi ringan untuk perangkat terbatas [1]. Pada AEAD, ciphertext dan AD diautentikasi bersama; keberhasilan proses dekripsi harus bergantung pada verifikasi tag. Pedoman NIST untuk kapabilitas keamanan IoT juga menekankan penentuan kebutuhan keamanan menurut perangkat dan konteks sistem, bukan asumsi bahwa satu solusi cocok untuk semua perangkat [2].

Sudah ada beberapa pilihan implementasi perangkat keras. Kandi dkk. membandingkan implementasi Ascon biasa dengan varian yang menggunakan threshold implementation dan/atau triplikasi untuk menghadapi ancaman fisik [3]. Core SystemVerilog publik oleh Primas mendukung beberapa lebar bus dan jumlah ronde yang di-unroll, serta menyediakan sinyal `auth/auth_valid`; dokumentasinya menyebut perlunya buffer tambahan agar plaintext dekripsi tidak terpapar sebelum verifikasi tag [4]. OpenTitan menyediakan AES dengan GCM opsional, antarmuka register, masking opsional, dan urutan operasi GCM yang sebagian dikendalikan software [5]. Semua ini menunjukkan bahwa desain dan trade-off Ascon maupun AEAD hardware telah diteliti; pemilihan Ascon atau penambahan blok bernama “guard” bukan celah kebaruan dengan sendirinya.

DE10-Nano menyediakan Cyclone V SoC dengan FPGA fabric dan HPS, sehingga dapat dipakai untuk evaluasi IP dan integrasi host bila jalur sistem dibangun [6]. FPGA fabric memberi ruang untuk mengevaluasi datapath khusus, tetapi proyek ini belum membandingkan latency, throughput, atau energi dengan implementasi software; manfaat akselerasinya masih hipotesis rekayasa. Proyek saat ini baru menetapkan target perangkat, clock, dan pin virtual di Quartus. Penggunaan HPS/Platform Designer belum menjadi bagian dari bitstream baseline.

### 2.2 Rumusan Masalah & Perancangan

**Rumusan masalah:** bagaimana merancang dan memverifikasi IP Ascon-AEAD128 berkapasitas terbatas untuk transaksi pendek pada Cyclone V, dengan kontrak input/output yang eksplisit dan tanpa menawarkan plaintext dekripsi sebelum autentikasi berhasil?

**Pertanyaan perancangan:**

1. Bagaimana mengatur inisialisasi, pemrosesan AD/pesan, finalisasi, dan permutasi Ascon secara iteratif?
2. Bagaimana menangani urutan transfer byte, backpressure, reset, panjang nol, dan panjang yang melebihi kapasitas?
3. Bagaimana membuktikan keluaran kriptografi dengan KAT tepercaya dan membuktikan kasus gagal tidak melepas plaintext?
4. Bagaimana mengukur resource, timing, latency, throughput, dan energi pada konfigurasi yang jelas, tanpa menyamakan metrik yang tidak setara?
5. Bagaimana mengintegrasikan dan menguji transaksi melalui DE10-Nano setelah interface host/pin dipilih?

**Rancangan dan batas sistem:** versi IP saat ini satu clock domain, satu transaksi aktif, input AD lalu data melalui handshake byte `valid/ready`, dan kapasitas elaborasi terbatas. Pemanggil memberi nonce dan bertanggung jawab atas keunikannya untuk key yang sama. IP tidak menyediakan key manager, bus host, keamanan boot, atau protokol jaringan. Buffer RTL membatasi pelepasan plaintext melalui interface, tetapi belum membuktikan penghapusan khusus key/calon plaintext pada setiap akhir transaksi maupun mitigasi side-channel/fault.

## 3. Proposed Chip Design

### 3.1 Solusi & Arsitektur Sistem

#### Diagram Blok Sistem

```text
                  Pemanggil / host (belum diintegrasikan)
              perintah, key, nonce, AD, data, tag masukan
                                |
                                v
 +------------------+   +------------------------+   +------------------+
 | Antarmuka byte   |-->| AEAD Controller        |-->| Ascon-AEAD128    |
 | valid/ready      |   | FSM + buffer AD/data   |   | core + state     |
 +------------------+   +------------------------+   +--------+---------+
                                                              |
                                                              v
                                                    +--------------------+
                                                    | Ascon Permutation  |
                                                    | iteratif, 1 ronde/ |
                                                    | siklus aktif       |
                                                    +--------------------+
                                                              |
            tag enkripsi <--- Tag Generator <-----------------+
                                                              |
 tag hitung + tag masukan --> Tag Verifier --> Authentication Guard
                                                     |                  |
                                  ACCEPT: plaintext dibuka; REJECT: tidak ada
                                                     |
                                                     v
                                      output byte + status transaksi

 HPS/Avalon, pin fisik, SignalTap dan driver host: tahap integrasi berikutnya.
```

#### Rincian Modul RTL

| Modul | Fungsi pada sistem | Status/bukti saat ini |
|---|---|---|
| `ascon_permutation.sv` | Menyimpan state 320-bit dan menjalankan ronde permutasi p8/p12 mengikuti standar [1]. | RTL dan testbench unit tersedia; p8/p12 diuji simulasi. |
| `ascon_core.sv` | Mengatur proses AEAD Ascon: inisialisasi, AD, data, finalisasi dan tag. | 1.089 KAT Ascon-C diuji untuk enkripsi dan dekripsi. |
| `aead_controller.sv` | Mengatur transaksi, fase input/output, buffer AD/data, core, dan urutan handshake. | Uji terarah dan sweep panjang 0–16 byte tersedia. |
| `tag_generator.sv` | Menahan tag hasil core sampai `tag_ready`; tidak menghitung tag kedua. | Unit handshake diuji. |
| `tag_verifier.sv` | Membandingkan 128-bit tag hasil core dengan tag yang dikirim pemanggil. | Unit cocok/tidak cocok diuji. |
| `authentication_guard.sv` | Mengizinkan keluaran plaintext hanya setelah verifikasi cocok dan menetapkan ACCEPT/REJECT. | Skenario valid dan negatif diuji pada simulasi. |
| `secure_tiny_top.sv` | Menghubungkan modul menjadi IP transaksi independen dari board. | Menjadi top-level Quartus; belum memiliki pembungkus bus/host. |

#### Estimasi Penggunaan Resource FPGA

Angka di bawah adalah **hasil pengukuran Quartus baseline**, bukan perkiraan dan bukan pembanding PPA. Spesifikasi board menyebut kapasitas perangkat sekitar 110.000 logic elements (LE); ALM dan LE adalah istilah resource yang berbeda, sehingga persentase/angka keduanya tidak dicampur [6].

| Metrik | Hasil build baseline | Interpretasi/batas |
|---|---:|---|
| ALM | 2.464 / 41.910 (6%) | Hasil Fitter untuk konfigurasi ini. |
| Register | 2.800 | Hasil Fitter. |
| RAM blok / M10K | 0 bit / 0 | Buffer saat ini terealisasi sebagai logika/register. |
| DSP | 0 | Hasil Fitter. |
| Fmax clock `FPGA_CLK1_50` | 79,72 MHz | Jalur yang dianalisis; bukan sign-off timing seluruh I/O. |
| Setup / hold slack terburuk | +7,456 ns / +0,338 ns | Laporan Quartus; 616 port transaksi virtual belum memiliki constraint I/O fisik. |
| Bitstream `.sof` | Dibuat, 6.690.378 byte | Assembler sukses; belum berarti board sudah diprogram/diuji. |

Konfigurasi tersebut memakai `MAX_DATA_BYTES=16` untuk AD dan pesan secara terpisah, periode clock 20 ns, Quartus Prime Lite 25.1, dan device `5CSEBA6U23I7`. Semua metrik di atas terikat pada konfigurasi tersebut. Daya dan energi belum diukur; penggunaan 16 byte bukan klaim bahwa kapasitas tersebut mewakili workload industri.

#### Perangkat Lunak & Tools Perancangan

| Tool | Kegunaan | Status pada proyek |
|---|---|---|
| Intel Quartus Prime Lite 25.1 | Elaborasi, sintesis, fitting, timing, dan pembuatan `.sof` Cyclone V. | **Sudah digunakan**; build baseline selesai. |
| Icarus Verilog + `vvp` | Simulasi RTL/testbench dan keluaran VCD. | **Sudah digunakan**; 7/7 runner pada regresi 2 Okt 2026 lulus. |
| Verilator | Lint/elaborasi untuk menemukan masalah RTL statis [11]. | **Sudah digunakan**; lint historis 1 Okt 2026 lulus, tidak diulang pada regresi 2 Okt. |
| GTKWave | Meninjau sinyal pada VCD simulasi. | VCD dibuat; catatan verifikasi menyebut pemeriksaan waveform, tangkapan layar proposal perlu disiapkan. |
| Python | Model pembanding dan pemeriksaan KAT/ACVP byte-aligned. | **Sudah digunakan**; bukan validasi sertifikasi ACVP. |
| Yosys | Sintesis generik tambahan. | **Sudah digunakan**; 20.887 sel generik bukan angka ALM Cyclone V. |
| ModelSim/Questa | Alternatif simulasi bila diwajibkan/tersedia di lingkungan kompetisi. | **Belum digunakan**; jangan menyatakan hasilnya. |
| Platform Designer (Qsys) | Mengintegrasikan wrapper IP ke subsistem HPS/Avalon bila dipilih. Intel menjelaskan tool ini menghasilkan interconnect untuk menghubungkan IP/subsistem [7]. | **Rencana**, belum ada komponen SECURE-TINY di Qsys. |
| C (opsional) | Driver/demo di HPS untuk mengirim transaksi dan memeriksa output setelah wrapper tersedia. | **Rencana**, belum ada driver. |
| SignalTap Logic Analyzer | Mengambil sinyal internal secara real-time setelah analyzer dimasukkan, dikompilasi, dan board diprogram [8]. | **Rencana uji board**; belum ada capture atau bitstream SignalTap. |

#### State of the Art, Research Gap, dan Novelty

| Pendekatan relevan | Arsitektur/fungsi yang terdokumentasi | Data pembanding yang tersedia | Batas dan posisi SECURE-TINY |
|---|---|---|---|
| Ascon SystemVerilog, R. Primas [4] | Core NIST SP 800-232 dengan bus 32/64-bit, unrolling 1/2/4 ronde, interface LWC `valid/ready`, dan output `auth/auth_valid`. Dokumentasi menyebut desain mengeluarkan plaintext dekripsi segera dan menyarankan buffer eksternal sampai tag tervalidasi. | Untuk varian 32-bit/1-round, README melaporkan 41 siklus untuk AD/data kosong, 99 siklus untuk 32B+32B, dan 1.587 siklus untuk 1.024B+1.024B. Tidak ada resource FPGA/clock setara yang dipakai di sini. | Pembanding paling dekat secara algoritma. SECURE-TINY mengintegrasikan buffer dan gate plaintext dalam top-level berkapasitas kecil. Ini diferensiasi fungsi antarmuka, bukan klaim pertama atau keunggulan performa. |
| Hardware Ascon dengan countermeasure, Kandi dkk. [3] | Implementasi AEAD/hash termasuk threshold-based side-channel countermeasure serta triplikasi/majority untuk deteksi fault; paper melaporkan evaluasi ASIC/FPGA. | Hasil bergantung pada varian dan platform penelitian. Tidak dibandingkan angka mentahnya dengan Cyclone V SECURE-TINY. | Menunjukkan perlindungan fisik adalah arah riset tersendiri. Guard SECURE-TINY hanya mengendalikan pelepasan plaintext digital dan belum memberi proteksi tersebut. |
| OpenTitan AES HWIP/GCM [5] | AES multi-mode dengan GCM opsional, antarmuka register, opsi masking dan key sideload; dokumentasi menyebut software mengatur sejumlah fase GCM. | Spesifikasi OpenTitan melaporkan latensi per blok AES, bukan latency AEAD yang setara; karenanya tidak dibandingkan numerik di sini. | Contoh akselerator AEAD lain pada SoC; primitive, interface, threat model, dan integrasi berbeda. Bukan pembanding resource langsung. |
| SECURE-TINY baseline | Ascon-AEAD128, satu ronde permutasi per siklus aktif; byte-stream 8-bit; satu transaksi; input dibuffer sampai core mulai; kandidat plaintext ditahan sampai verifikasi. | Quartus: 2.464 ALM, 2.800 register, 79,72 MHz jalur analisis. Simulasi: 2.178 core KAT transactions, maksimum 88 siklus; 578 top-level KAT transactions, maksimum 150 siklus. | Hasil internal proyek dan simulasi, bukan pengukuran board atau perbandingan setara. Batas panjang saat ini 16 byte untuk masing-masing AD dan pesan. |

**Research gap yang dibatasi:** bukti pembanding [4] menunjukkan bahwa buffering plaintext untuk mencegah keluaran sebelum verifikasi dapat diletakkan di wrapper eksternal. Proyek ini menguji pilihan integrasi buffer/guard tersebut dalam IP mandiri dengan interface byte-level dan urutan transaksi dikelola RTL. Kami belum membuktikan bahwa kebutuhan ini belum dipenuhi desain lain, belum melakukan survei pengguna, serta belum menguji keunggulan kinerja/resource. Maka novelty diklaim sebagai **kontribusi implementasi dan verifikasi pada konfigurasi demonstrator**, bukan kebaruan algoritmik atau prior art pertama.

### 3.2 Rencana Pengujian

#### Simulasi RTL, Testbench Otomatis, dan Functional Verification

Regresi yang tercatat terakhir dijalankan 2 Oktober 2026 menggunakan `scripts/run_all_tests.ps1`: 7/7 runner selesai dengan kode keluar 0. Testbench memakai KAT Ascon-C v1.3.0 untuk RTL dan model Python diuji pada 14 sampel ACVP yang byte-aligned [9], [10]. Checker tidak menjalankan 226/240 sampel ACVP yang tidak byte-aligned; hasil ini bukan sertifikasi ACVP. Regresi meliputi counter, permutasi, modul tag/guard, core, top-level, sapuan panjang, dan pemeriksa Python; bukti terinci ada di `docs/results.md` dan VCD/log lokal di `sim/`.

#### Corner Case dan Invarian yang Diperiksa

| Kasus | Kriteria lulus | Status bukti |
|---|---|---|
| Enkripsi/dekripsi KAT, termasuk panjang nol/parsial dan rentang core sampai 32 byte | Ciphertext, plaintext, dan tag cocok dengan vector tepercaya. | Lulus pada simulasi core; 1.089 KAT per arah. |
| Top-level panjang AD dan pesan 0–16 byte | Output cocok pada transaksi aliran byte. | Lulus; 289 pasangan panjang x enkripsi/dekripsi = 578 transaksi. |
| AD, ciphertext, atau tag diubah | `reject` aktif; tidak ada transfer plaintext pada kasus uji. | Lulus pada skenario negatif terarah. |
| Backpressure, start saat sibuk, reset pada beberapa fase, panjang melebihi kapasitas | Tidak deadlock; handshake/status sesuai kontrak; perintah berlebih ditolak. | Skenario terarah lulus. |
| Power-up, reset berulang, urutan banyak transaksi sukses/reject, key/data lifecycle | Status awal/akhir dan kebersihan register memenuhi properti yang ditentukan. | Belum lengkap sebagai properti lifecycle; perlu uji/inventaris register. |
| Bit-level ACVP non-byte-aligned | Model/reference dan RTL mendukung panjang bit sesuai vector. | Belum dijalankan oleh checker saat ini. |

#### Timing/Latency Analysis dan Metrik Keberhasilan

| Metrik | Baseline atau target | Rencana pengukuran / kriteria |
|---|---|---|
| Akurasi fungsi | Bukti simulasi saat ini: seluruh kasus suite yang dijalankan cocok. | Re-run regresi pada source final; target proposal: semua KAT/kasus terdefinisi lulus dan nol plaintext transfer saat reject. Jangan menyebut seluruh ruang masukan tervalidasi. |
| Latency RTL | Core KAT maksimum 88 siklus; top-level sweep maksimum 150 siklus, termasuk transfer input/output testbench. | Ukur ulang dengan definisi mulai `start` diterima sampai `done`; pisahkan latency core/top-level dan pengaruh stall. Board latency masih TBD. |
| Clock/timing | Quartus Fmax 79,72 MHz untuk jalur teranalisis; clock board constraint 50 MHz. | Lengkapi input/output delay/assignment setelah interface fisik dipilih, lalu ulangi STA. Syarat awal: slack setup/hold memenuhi constraint lengkap pada 50 MHz; nilai sekarang belum sign-off I/O. |
| Throughput | TBD — belum diukur pada board. | Ukur byte authenticated payload per detik pada beberapa panjang dan stall tetap; laporkan protokol/interface serta satuan. |
| Resource FPGA | 2.464 ALM, 2.800 register, 0 M10K, 0 DSP untuk konfigurasi build. | Rekam ulang Quartus final termasuk overhead SignalTap/wrapper; bandingkan hanya dengan konfigurasi/device/tool/constraint yang setara. |
| Daya/energi | TBD — belum diukur. | Ukur daya board baseline dan saat transaksi pada metode serta sensor yang didokumentasikan; hitung energi/transaksi hanya setelah daya/waktu terukur. |
| Penolakan autentikasi | Skenario negatif AD/tag/ciphertext sudah lulus simulasi. | On-board, ulangi valid dan invalid cases, catat status ACCEPT/REJECT serta jumlah transfer output. Target invalid case: nol byte plaintext. |

Angka target throughput, batas maksimum latency, batas resource, dan batas power belum ditetapkan tim; tidak diisi dengan asumsi sebelum kebutuhan demonstrasi disepakati.

#### Bitstream pada DE10-Nano, SignalTap, dan Pengujian Real-Time

Tahap ini **belum dilakukan**. Setelah tersedia board dan interface transaksi, rencana kerja:

1. Pilih jalur komunikasi (HPS/Avalon melalui Platform Designer, atau interface pin yang terdefinisi); tentukan format perintah/data, clock domain, reset, dan driver.
2. Ganti seluruh virtual pins dengan koneksi/constraint nyata, build ulang Quartus, dan periksa warning, resource, serta setup/hold timing.
3. Tambahkan SignalTap untuk `start`, fase controller, `busy/done`, handshake input/output, `tag_valid`, `accept/reject`, dan `out_valid`; compile bitstream debug, program board melalui JTAG, lalu simpan capture. SignalTap adalah logic analyzer internal yang harus disertakan pada compile dan mengonsumsi resource FPGA [8].
4. Jalankan transaksi KAT valid, pesan kosong/panjang parsial, AD atau ciphertext berubah, dan tag salah. Bandingkan hasil capture/status/output dengan testbench; ukur cycle latency dan throughput menggunakan clock/count yang tercatat.
5. Untuk klaim real-time, tentukan workload dan deadline aplikasi terlebih dahulu. Saat ini belum ada workload industri/PERURI atau target deadline yang tervalidasi.

#### Feasibility dan Risiko

| Risiko | Dampak | Mitigasi/rencana |
|---|---|---|
| Board atau jalur host tidak tersedia/terdefinisi | Demo fisik dan SignalTap tidak dapat dilakukan. | Konfirmasi akses board; gunakan simulasi dan build yang ada sebagai bukti terpisah, tanpa mengklaim uji board. |
| Antarmuka HPS/Avalon dan software belum dibuat | HPS belum dapat mengirim transaksi ke IP. | Tetapkan register/stream interface minimum, gunakan Platform Designer hanya bila dibutuhkan; implementasi bus bukan bagian RTL baseline. |
| Constraint I/O virtual | Timing antarmuka board belum diketahui. | Pemetaan pin dan constraint nyata sebelum sign-off; ulangi STA untuk seluruh input/output. |
| Kapasitas 16 byte terlalu kecil untuk use case | Relevansi aplikasi dan performa untuk payload nyata terbatas. | Minta workload/use case; ukur kapasitas kandidat lebih besar dan dampak buffer sebelum klaim. |
| Penghapusan key/calon plaintext dan serangan fisik belum ditangani | Klaim security lifecycle/side-channel tidak didukung. | Dokumentasikan batas; jadikan zeroization dan countermeasure sebagai pekerjaan terpisah dengan threat model dan pengujian. |

**Dampak yang diharapkan:** menyediakan baseline IP dan contoh alur verifikasi authenticated encryption di Cyclone V yang dapat dikembangkan lebih lanjut. Potensi dampak pada latency, energi, biaya, atau keamanan sistem belum terukur dan tidak dinyatakan sebagai hasil.

## B. Tabel Perubahan/Perbaikan Draft

| Area | Perubahan | Alasan |
|---|---|---|
| Struktur | Disusun sesuai urutan template: Executive Summary; Problem Statement; Proposed Chip Design 3.1 dan 3.2. | Memudahkan reviewer menemukan komponen wajib. |
| Problem statement | Dibatasi ke perlindungan ciphertext/AD dan pelepasan plaintext setelah verifikasi, tanpa generalisasi kebutuhan industri. | Klaim konteks edge/PERURI sebelumnya belum didukung workload atau wawancara pengguna. |
| Novelty | Ditulis sebagai kontribusi integrasi buffer/guard dan evidence flow, bukan algoritma baru atau “pertama”. | Literatur dan core yang ada menunjukkan implementasi Ascon dan mitigasi plaintext-before-auth sudah diketahui [3], [4]. |
| Perbandingan | Menggunakan Ascon RTL yang relevan, hardware Ascon terlindungi, dan OpenTitan AES-GCM sebagai pendekatan SoC; batas keterbandingan dijelaskan. | Menghindari menyandingkan angka ALM, LUT, kGE, MHz, dan siklus yang berasal dari platform berbeda. |
| Hasil hardware | Memisahkan hasil Quartus, hasil simulasi, rencana board, dan TBD. | `.sof`/Fmax bukan bukti pengujian DE10-Nano. |
| Tools | Menandai Icarus, Verilator, Python, Yosys, Quartus sebagai digunakan; ModelSim/Questa, Platform Designer, C, SignalTap sebagai belum digunakan/rencana. | Menghindari kesan bahwa seluruh tool pada template sudah dipakai. |
| Pengujian dan metrik | Memisahkan bukti yang sudah ada dari target uji board dan menetapkan cara ukur; angka ambang yang belum disepakati diberi TBD. | Tidak mengarang latency, throughput, daya, atau target performa. |
| Referensi | Menambahkan sitasi IEEE konsisten dan bibliografi yang digunakan oleh klaim dalam naskah. | Klaim standard, board, tools, dan pembanding dapat ditelusuri ke sumbernya. |

## C. Informasi/Data/Eksperimen yang Masih Perlu Dilengkapi

1. Template resmi dalam bentuk file, jika format aslinya mengandung aturan panjang, layout, atau bagian tambahan yang tidak tercakup di instruksi.
2. Identitas final tim: nama resmi, NIM/program studi, kontak, pembimbing, dan pembagian kontribusi yang disetujui.
3. Akses board DE10-Nano dan versi/revisi board yang akan diuji.
4. Keputusan interface demo: HPS/Avalon, UART/USB, GPIO, atau interface lain; protokol transaksi, pinout, clock/reset, serta software driver.
5. Workload yang relevan, panjang AD/payload, frekuensi transaksi, deadline, dan alasan batas 16 byte memadai atau perlu diperbesar.
6. Build Quartus final sesudah pin/interface nyata; laporan constraint lengkap, timing, resource, dan `.sof` yang terkait source revision final.
7. Bukti load bitstream, foto/setup board, log transaksi, SignalTap capture, KAT board valid dan kasus reject invalid.
8. Target numerik latency, throughput, resource, power/energy yang disepakati sebelum eksperimen; baseline software dan metode perbandingan yang fair.
9. Pengujian panjang bit non-byte-aligned dari ACVP, jika memang masuk lingkup interface; saat ini checker Python tidak menjalankannya.
10. Inventaris register key/state/calon plaintext dan uji lifecycle clearing jika ingin membuat klaim pembersihan data; evaluasi side-channel/fault memerlukan threat model dan metode terpisah.
11. Gambar waveform dan laporan Quartus yang boleh dibagikan; artefak lokal belum otomatis menjadi lampiran proposal.

## D. Tabel Perbandingan dengan Solusi Existing

| Aspek | Primas Ascon RTL [4] | Kandi dkk. [3] | OpenTitan AES HWIP/GCM [5] | SECURE-TINY |
|---|---|---|---|---|
| Algoritma/fungsi | Ascon SP 800-232: AEAD128, Hash256, XOF128, CXOF128. | Ascon AEAD dan hash dengan varian countermeasure. | AES-128/192/256 dan GCM opsional. | Ascon-AEAD128. |
| Integrasi/protokol | Core memakai LWC-style block interface, 32/64-bit bus. | Paper menyajikan core hardware untuk fungsi crypto; interface sistem bukan target perbandingan proposal. | Peripheral CSR pada SoC; software mengatur fase GCM. | Controller mandiri, stream byte 8-bit, satu transaksi aktif; belum ada bus host. |
| Proteksi pelepasan plaintext | README menyebut plaintext dekripsi keluar sebelum tag verifikasi, dan menyarankan buffer tambahan. | Fokus paper adalah side-channel/fault countermeasure; bukan baseline interface yang sama. | Produk SoC dengan key sideload/masking/countermeasure; alur GCM software-controlled. | Buffer calon plaintext internal dan guard menahan output sampai ACCEPT, diuji pada skenario simulasi. |
| Siklus/latency | Varian 32-bit/1-round: 41 / 99 / 1.587 siklus pada pesan+AD 0+0 / 32+32 / 1.024+1.024 byte. | Beragam varian; hasil tergantung countermeasure, device, dan implementasi. | 12/14/16 siklus per blok AES unmasked untuk 128/192/256-bit; angka bukan latency GCM total. | Core KAT max 88 siklus; top-level sweep max 150 siklus untuk payload hingga 16 byte, termasuk transaksi/stall testbench. |
| Resource/frekuensi/power | Tidak digunakan di sini sebagai angka setara Quartus Cyclone V. | Paper memuat benchmark ASIC/FPGA, tetapi platform/metrik berbeda. | Dokumen fungsi mencantumkan latensi, bukan PPA pembanding yang sepadan. | Quartus: 2.464 ALM, 2.800 register, 0 M10K/DSP; Fmax 79,72 MHz pada constraint saat ini; power TBD. |
| Fleksibilitas/batas | Lebar bus dan unrolling dapat dikonfigurasi; interface integrasi blok. | Varian dapat mengaktifkan proteksi dengan overhead resource/performa. | Multi-mode AES, GCM compile-time optional, integrasi bus/key manager. | Kapasitas elaborasi; konfigurasi saat ini 16 byte AD dan 16 byte data; tidak ada queue, DMA, atau host. |
| Perbandingan yang sah | Paling relevan secara fungsi Ascon, namun implementasi dan interface berbeda. | Relevan untuk menjelaskan keamanan fisik yang belum disediakan SECURE-TINY; PPA tidak dibandingkan mentah. | Relevan sebagai pola integrasi accelerator AEAD di SoC; primitive berbeda. | Belum ada benchmark head-to-head. Klaim superioritas ditunda sampai device/tool/constraint/workload disetarakan. |

**Catatan:** nilai cycle dari core Primas bukan perbandingan langsung dengan cycle top-level SECURE-TINY karena kapasitas, interface, stall, dan definisi transaksi berbeda. ALM Quartus tidak disetarakan dengan LUT, tile, atau kGE; MHz bukan throughput; spesifikasi fitur bukan hasil pengukuran daya.

## E. Daftar Pustaka (IEEE)

[1] M. Sönmez Turan, K. McKay, J. Kang, J. Kelsey, and D. Chang, *Ascon-Based Lightweight Cryptography Standards for Constrained Devices: Authenticated Encryption, Hash, and Extendable Output Functions*, NIST SP 800-232, Aug. 2025, doi: 10.6028/NIST.SP.800-232.

[2] M. Fagan, K. Megas, K. Scarfone, and M. Smith, *IoT Device Cybersecurity Capability Core Baseline*, NISTIR 8259A, May 2020, doi: 10.6028/NIST.IR.8259A.

[3] A. Kandi, A. Baksi, P. Gan, S. Guilley, T. Gerlich, J. Breier, A. Chattopadhyay, R. R. Shrivastwa, Z. Martinásek, and S. Bhasin, “Side-channel and fault resistant ASCON implementation: A detailed hardware evaluation,” in *Proc. IEEE Computer Society Annual Symposium on VLSI (ISVLSI)*, 2024, pp. 307–312, doi: 10.1109/ISVLSI61997.2024.00063.

[4] R. Primas, “Hardware Design of Ascon (SP 800-232),” GitHub repository, `rprimas/ascon-verilog`. [Online]. Available: https://github.com/rprimas/ascon-verilog. [Accessed: Oct. 6, 2026]. Kinerja dan perilaku output yang dikutip berasal dari dokumentasi repository; bukan evaluasi independen.

[5] lowRISC, “AES HWIP Technical Specification” and “Programmer’s Guide: Galois/Counter Mode (GCM),” *OpenTitan Documentation*. [Online]. Available: https://opentitan.org/book/hw/ip/aes/ and https://opentitan.org/book/hw/ip/aes/doc/programmers_guide.html. [Accessed: Oct. 6, 2026].

[6] Terasic Technologies, “DE10-Nano Development and Education Board: Specifications,” *Terasic*. [Online]. Available: https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=165&Language=English&No=1046&PartNo=2. [Accessed: Oct. 6, 2026].

[7] Intel, “Platform Designer,” *Quartus Prime Design Software*. [Online]. Available: https://www.altera.com/products/development-tools/quartus-prime/platform-designer. [Accessed: Oct. 6, 2026].

[8] Intel, *Quartus Prime Standard Edition User Guide: Debug Tools*, section “Design Debugging with the Signal Tap Logic Analyzer.” [Online]. Available: https://www.intel.com/programmable/technical-pdfs/683552.pdf. [Accessed: Oct. 6, 2026]. Fitur SignalTap pada instalasi/edisi yang tersedia untuk tim harus dikonfirmasi sebelum tahap board.

[9] Ascon Team, “Ascon-C v1.3.0,” file `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`, GitHub. [Online]. Available: https://github.com/ascon/ascon-c/tree/v1.3.0. [Accessed: Oct. 6, 2026]. Dipakai sebagai sumber KAT tambahan; kode C tidak disalin ke RTL.

[10] NIST, “Ascon-AEAD128 SP 800-232 sample vectors,” *Automated Cryptographic Validation Protocol (ACVP) Server*. [Online]. Available: https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232. [Accessed: Oct. 6, 2026]. Hanya 14 kasus byte-aligned yang dijalankan model Python; bukan hasil validasi/sertifikasi ACVP.

[11] Verilator Project, “Verilator User’s Guide,” *Verilator Documentation*. [Online]. Available: https://verilator.org/guide/latest/. [Accessed: Oct. 6, 2026].
