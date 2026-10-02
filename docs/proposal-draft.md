# Draf Proposal SECURE-TINY

> **Catatan Tim:** Dokumen ini masih berstatus draf awal untuk ditinjau, dilengkapi, dan disesuaikan bersama oleh tim demi kelancaran proses finalisasi proposal.

Pilihan 3 (Satu Kalimat):

## 1. Ringkasan Ide / Executive Summary

### Judul

**SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman**

### Gagasan

Kami merancang SECURE-TINY sebagai IP core perangkat keras untuk enkripsi dan dekripsi terautentikasi menggunakan Ascon-AEAD128, algoritma yang ditetapkan NIST dalam SP 800-232 untuk perangkat dengan sumber daya terbatas [1]. IP ini menerima key, nonce, associated data (AD), serta data pesan; pada enkripsi, keluarannya berupa ciphertext dan tag autentikasi, sedangkan pada dekripsi, plaintext hanya boleh dikeluarkan setelah tag dinyatakan valid.

Masalah yang kami tangani adalah kebutuhan akan perlindungan kerahasiaan dan integritas data pada jalur komunikasi perangkat edge/tertanam. NIST membahas kebutuhan kapabilitas keamanan perangkat IoT sebagai bagian dari pengelolaan risiko perangkat dan datanya [5], [6]. Kami meneliti satu blok yang dapat diintegrasikan ke sistem lebih besar, bukan membangun perangkat edge lengkap atau menggantikan seluruh mekanisme keamanan sistem.

Solusi kami terdiri atas datapath Ascon iteratif, pengendali AEAD, penanganan data berkapasitas terbatas, pembentukan dan pemeriksaan tag, serta **Hardware Authentication Guard**. Guard menerapkan keputusan ACCEPT/REJECT pada keluaran dekripsi. Kontribusi yang kami ajukan berfokus pada integrasi IP yang dapat diuji, perilaku penolakan yang gagal secara tertutup, dan paket verifikasi/build yang memiliki bukti; kami **tidak** mengajukan algoritma kriptografi baru atau mengklaim sebagai implementasi Ascon pertama.

Baseline saat ini telah diuji pada simulasi dengan KAT Ascon-C dan sampel vektor NIST ACVP, serta telah melalui build Quartus untuk Cyclone V. Build menghasilkan 2.464 ALM, 2.800 register, dan berkas `.sof`; Fmax yang dilaporkan adalah 79,72 MHz pada jalur yang dianalisis. Karena antarmuka transaksi masih memakai virtual pins, constraint I/O belum lengkap dan belum ada pengujian transaksi pada board. Angka tersebut merupakan hasil build konfigurasi saat ini, bukan klaim keunggulan terhadap desain lain atau hasil uji DE10-Nano.

**Pengguna sasaran:** perancang sistem edge/embedded dan pengembang SoC/FPGA yang memerlukan blok AEAD untuk diintegrasikan dan diverifikasi. **Dampak yang dituju:** menyediakan baseline IP modular yang membantu tim mengevaluasi integrasi authenticated encryption pada sistem terbatas. Dampak kinerja, daya, dan penghematan biaya belum kami ukur.

**Kategori kompetisi:** tantangan utama *Hardware Cryptography Accelerator*; tantangan pendukung *Secure Communication*. **Target evaluasi:** Intel Cyclone V pada DE10-Nano. **Tahap implementasi:** RTL, simulasi, dan build Quartus selesai untuk konfigurasi baseline; integrasi host/pin fisik serta pengujian board belum dilakukan.

## 2. Latar Belakang & Rumusan Masalah / Problem Statement

### 2.1 Latar belakang

Perangkat edge mengolah data dekat dengan sumbernya dan dapat beroperasi dengan keterbatasan komputasi, memori, daya, atau konektivitas. Kebutuhan keamanannya tetap harus ditentukan menurut sistem dan ancaman yang dihadapi; tidak ada satu akselerator yang dengan sendirinya membuat keseluruhan perangkat aman. NISTIR 8259A menyajikan baseline kapabilitas keamanan perangkat IoT yang dapat dipakai sebagai titik awal identifikasi kebutuhan, sementara SP 800-213 memberi panduan menetapkan kebutuhan keamanan perangkat berdasarkan konteks organisasi dan sistem [5], [6].

Untuk melindungi pesan, enkripsi saja tidak cukup: penerima juga perlu mengetahui apakah ciphertext, AD, atau tag berubah. Authenticated Encryption with Associated Data (AEAD) menggabungkan kerahasiaan payload dengan autentikasi payload dan AD. Ascon dikembangkan sebagai keluarga primitif ringan; kajian Ascon menjelaskan konstruksi permutasi dan ragam implementasinya pada perangkat lunak maupun perangkat keras [2]. NIST kemudian menerbitkan SP 800-232 sebagai standar final yang mencakup Ascon-AEAD128 dan fungsi keluarga Ascon lainnya [1]. Implementasi perangkat keras Ascon telah diteliti jauh sebelum proyek ini; publikasi tentang implementasi yang disesuaikan untuk perangkat keras dan evaluasi side-channel/fault menunjukkan bahwa desain, trade-off, serta model ancaman terus menjadi ranah riset aktif [3], [4]. Karena itu, kami tidak menyamakan pemilihan Ascon dengan kebaruan proyek.

> Konteks PERURI kami gunakan sebatas relevansi aplikasi: PERURI memublikasikan layanan keamanan digital yang mencakup autentikasi, perlindungan integritas, dan kerahasiaan transaksi/dokumen [7]. Kami tidak menganggap layanan tersebut sebagai spesifikasi chip dan tidak menyatakan bahwa SECURE-TINY telah dipakai, diuji, atau disetujui PERURI.

### 2.2 Rumusan masalah

Pertanyaan rekayasa kami adalah: **bagaimana membangun IP core Ascon-AEAD128 modular yang dapat disintesis, memverifikasi hasil kriptografinya terhadap sumber vektor tepercaya, dan memastikan plaintext dekripsi tidak tersedia melalui antarmuka keluaran sebelum autentikasi berhasil?**

Pertanyaan tersebut dipecah menjadi kebutuhan berikut:

1. Bagaimana mengatur permutasi dan tahapan AEAD secara iteratif agar fungsi inti dapat diuji dan disintesis?
2. Bagaimana mengendalikan satu transaksi, aliran byte, reset, jeda/backpressure, dan batas kapasitas dengan kontrak antarmuka yang eksplisit?
3. Bagaimana membandingkan enkripsi/dekripsi terhadap KAT, lalu menguji kasus tag, ciphertext, atau AD yang salah?
4. Bagaimana melaporkan resource dan timing dari tool FPGA tanpa menyamakan hasil generik Yosys dengan hasil Cyclone V?
5. Bagaimana membatasi klaim keamanan supaya hanya mencakup properti yang benar-benar diimplementasikan dan diuji?

### 2.3 Posisi terhadap solusi yang tersedia dan kebaruan

Ascon bukan algoritma baru dari tim kami. Algoritma dan beberapa implementasi perangkat kerasnya telah dipublikasikan [1]–[4]. Dengan demikian, kebaruan SECURE-TINY **bukan** pada penciptaan primitif, klaim lebih aman daripada Ascon, atau klaim sebagai implementasi pertama.

Kontribusi rekayasa yang kami ajukan adalah:

* satu IP RTL SystemVerilog dengan arsitektur iteratif dan batas kapasitas transaksi yang terdefinisi;
* pemisahan core, controller, pembentukan/verifikasi tag, dan guard agar alur autentikasi dapat ditinjau per blok;
* kebijakan dekripsi fail-closed pada tingkat antarmuka: plaintext baru dapat ditawarkan setelah verifikasi berhasil, sementara kegagalan autentikasi menghasilkan REJECT tanpa plaintext pada skenario yang diuji;
* verifikasi fungsional dengan KAT Ascon-C v1.3.0 untuk RTL dan sampel ACVP NIST SP 800-232 untuk model pembanding, ditambah pengujian integrasi dan build aktual Quartus Cyclone V; dan
* dokumentasi batasan, konfigurasi, serta sumber metrik agar hasil dapat ditinjau dan diulang.

Ini adalah klaim kontribusi integrasi dan proses verifikasi, bukan kebaruan algoritmik. Klaim bahwa desain kami lebih kecil, lebih cepat, lebih hemat daya, atau lebih aman daripada implementasi pembanding **belum dapat dibuat** tanpa benchmark yang disetarakan (algoritma/versi, parameter, device, tool, constraint, dan model ancaman).

## 3. Proposed Chip Design

### 3.1 Fungsi dan arsitektur chip

SECURE-TINY menerima satu transaksi pada satu waktu. Pemanggil memasok mode enkripsi/dekripsi, key 128-bit, nonce 128-bit, panjang AD, panjang data, byte AD/pesan, dan tag yang diterima saat dekripsi. IP menghasilkan ciphertext serta tag untuk enkripsi, atau status autentikasi serta plaintext hanya setelah tag valid untuk dekripsi. Panjang AD dan pesan dibatasi masing-masing oleh parameter `MAX_DATA_BYTES`; konfigurasi target yang dibangun memakai 16 byte.

```text
             key, nonce, mode, panjang, AD, data, tag masuk
                               |
                               v
                    +----------------------+
                    | AEAD Controller      |
                    | FSM + buffer terbatas|
                    +----------+-----------+
                               | state / permintaan operasi
                               v
                    +----------------------+
                    | Ascon-AEAD128 Core   |
                    | inisialisasi, AD,    |
                    | data, finalisasi     |
                    +----------+-----------+
                               | permintaan/hasil state
                               v
                    +----------------------+
                    | Ascon Permutation    |
                    | iteratif, satu ronde |
                    | per siklus aktif     |
                    +----------------------+

       tag core --> Tag Generator --> handshake tag ke pemanggil
       tag hitung + tag masuk --> Tag Verifier --> Authentication Guard
                                                    | ACCEPT / REJECT
                                                    v
                                      izin keluaran plaintext dekripsi
```

`tag_generator` menangkap dan menahan tag yang telah dibentuk core; modul ini tidak menghitung algoritma tag kedua. `tag_verifier` membandingkan tag yang dihitung dengan tag masukan. `authentication_guard` mengubah hasil verifikasi menjadi keputusan yang mengendalikan izin keluaran plaintext dekripsi. Pengujian menunjukkan perilaku ini untuk skenario yang tercakup; itu tidak membuktikan ketahanan terhadap seluruh serangan perangkat lunak atau fisik.

### 3.2 Input, output, dan komunikasi

Antarmuka sinkron menggunakan satu clock domain dan handshake `valid/ready` untuk aliran data. Satu transaksi dimulai saat `start` diterima ketika `busy=0`; permintaan baru saat sibuk diabaikan. Antarmuka board/host yang menghubungkan transaksi ini ke HPS, Avalon, atau pin DE10-Nano belum termasuk dalam top-level IP awal.

| Kelompok | Sinyal/isi | Fungsi |
|---|---|---|
| Clock/reset | `clk`, `rst_n` | Satu domain clock; reset sinkron aktif-rendah |
| Perintah | `start`, `decrypt`, `key[127:0]`, `nonce[127:0]`, `ad_length`, `data_length`, `received_tag[127:0]` | Memulai transaksi dan menetapkan parameter operasi |
| Masukan AD | `ad_valid`, `ad_ready`, `ad_data[7:0]` | Mengirim byte associated data |
| Masukan pesan | `data_valid`, `data_ready`, `data_in[7:0]` | Mengirim plaintext untuk enkripsi atau ciphertext untuk dekripsi |
| Keluaran pesan | `out_valid`, `out_ready`, `out_data[7:0]` | Mengalirkan ciphertext atau plaintext yang telah diizinkan |
| Keluaran tag | `tag_valid`, `tag_ready`, `tag_out[127:0]` | Menahan dan mentransfer tag hasil enkripsi |
| Status | `busy`, `done`, `command_error`, `auth_result_valid`, `accept`, `reject` | Menunjukkan kemajuan, kesalahan kapasitas, dan hasil autentikasi |

Nama serta lebar lengkap port mengikuti kontrak pada `docs/module_spec.md`. `MAX_DATA_BYTES` wajib ditentukan saat elaborasi; AD dan pesan yang melebihi kapasitas ditolak sebelum aliran data diterima. Nonce unik untuk setiap enkripsi dengan key yang sama adalah tanggung jawab pemanggil; IP ini tidak menghasilkan maupun melacak keunikan nonce.

### 3.3 Arsitektur pemrosesan dan memori

Kami menggunakan datapath Ascon iteratif, bukan membuka beberapa ronde secara paralel. Controller menampung AD dan pesan sampai panjang transaksi yang dideklarasikan, lalu mengatur pemrosesan core. Permutasi melakukan satu ronde pada setiap siklus aktif. Penyimpanan data transaksi dibentuk dari register/logika RTL pada konfigurasi yang diukur; build Quartus melaporkan nol bit RAM blok/M10K. Kami tidak mengklaim bahwa arsitektur ini optimal dari sisi area atau daya.

Tidak ada CPU atau ISA yang dirancang, sehingga ISA tidak relevan. Tidak ada IP kriptografi pihak ketiga di datapath; Ascon ditulis sebagai RTL proyek. Referensi eksternal dipakai untuk membandingkan keluaran uji, bukan disalin langsung ke implementasi.

### 3.4 Security-by-design, batas kepercayaan, dan batas klaim

**Aset:** key, state internal turunan key, plaintext/calon plaintext, serta integritas ciphertext, tag, dan AD. **Batas kepercayaan:** pemanggil memasok key, nonce, panjang, AD, data, serta tag; IP memproses transaksi pada satu domain clock. Integrasi HPS, pengelolaan/penyimpanan key, keamanan boot, sensor gangguan fisik, dan protokol jaringan berada di luar IP awal.

Invarian yang kami terapkan dan uji adalah: pada dekripsi, plaintext tidak ditawarkan melalui handshake keluaran sebelum autentikasi berhasil; tag/AD/ciphertext yang tidak cocok menghasilkan REJECT dan tidak menawarkan plaintext pada skenario yang diuji. Kami juga menguji reset, start saat sibuk, jeda handshake, dan masukan yang melampaui kapasitas. Dasar AEAD dan standar algoritma mengikuti NIST SP 800-232 [1].

**Batas keamanan:** kami belum membuktikan penghapusan key/calon plaintext pada semua jalur akhir transaksi, ketahanan side-channel daya/EM, fault injection, tampering fisik, keamanan nonce lifecycle, atau sertifikasi kriptografi. Hardware Authentication Guard adalah nama blok logika pengendali keluaran autentikasi; nama tersebut bukan sensor tamper dan tidak mendeteksi gangguan fisik. Uji fungsional digital tidak setara dengan evaluasi side-channel/fault yang dibahas pada riset implementasi terlindungi [4].

### 3.5 Pendekatan RTL, tools, dan strategi verifikasi

Kami menggunakan SystemVerilog sintetis modular. Testbench dan runner menggunakan Icarus Verilog/`vvp`; GTKWave dipakai untuk meninjau VCD; Python menjalankan pembanding vektor; Yosys digunakan untuk sintesis generik; Quartus Prime Lite 25.1 digunakan untuk target Cyclone V. Daftar lengkap sumber RTL/testbench dan perintah reproduksi terdapat di README serta dokumen verifikasi.

Vektor kriptografi berasal dari dua sumber berbeda. Pertama, kami menggunakan KAT `ascon-c` tag `v1.3.0`, file `LWC_AEAD_KAT_128_128.txt`, untuk membandingkan core RTL. Kedua, model Python dibandingkan terhadap 14 kasus sampel ACVP NIST berukuran kelipatan byte untuk revisi SP 800-232. Sumber dan hash lokal dicatat di `docs/results.md`. Uji ACVP ini bukan validasi/sertifikasi ACVP.

| Tingkat | Pemeriksaan yang dilakukan | Hasil terakhir yang tercatat |
|---|---|---|
| Core kriptografi RTL | Seluruh 1.089 rekaman KAT untuk enkripsi dan dekripsi | 2.178 transaksi lulus; kapasitas uji 32 byte |
| Integrasi top-level | 289 pasangan panjang AD/pesan 0–16 byte pada kedua mode | 578 transaksi lulus |
| Kasus keamanan digital | Tag salah, ciphertext berubah, AD berubah; tidak ada plaintext yang ditawarkan saat ditolak pada kasus tersebut | Lulus di simulasi RTL |
| Kontrol transaksi | Stall/backpressure, start saat sibuk, reset di fase transaksi, masukan melebihi kapasitas | Skenario terarah lulus |
| Pembanding Python | 14 sampel byte-aligned ACVP dan 1.089 KAT Ascon-C | Cocok dengan keluaran yang diharapkan |
| Lint dan sintesis generik | Verilator pada 9 modul; Yosys generik dengan `check` | Lulus; Yosys mencatat 20.887 sel generik yang bukan metrik ALM Cyclone V |

Hasil di atas adalah bukti run yang dicatat pada 1 Oktober 2026 di `docs/results.md`. Pengujian menunjukkan kesesuaian fungsi untuk data dan kondisi uji tersebut; pengujian tidak membuktikan seluruh ruang masukan atau keamanan implementasi.

### 3.6 Target FPGA, build, dan hasil resource/timing

Target build adalah DE10-Nano dengan perangkat Cyclone V `5CSEBA6U23I7`, Quartus Prime Lite Edition `25.1std.0 Build 1129`, `MAX_DATA_BYTES=16`, dan clock `FPGA_CLK1_50` dengan periode constraint 20 ns. Tidak ada target ASIC/node proses fabrikasi untuk proposal ini.

| Hasil Quartus konfigurasi baseline | Nilai yang dilaporkan |
|---|---:|
| ALM | 2.464 / 41.910 (6%) |
| Register | 2.800 |
| RAM blok/M10K | 0 bit / 0 M10K |
| DSP | 0 |
| Fmax jalur clock yang dianalisis | 79,72 MHz |
| Setup slack terburuk | +7,456 ns |
| Hold slack terburuk | +0,338 ns |
| `.sof` | Dibuat, 6.690.378 byte; SHA-256 dicatat di `docs/results.md` |

Analysis & Synthesis, Fitter, Assembler, dan Timing Analyzer selesai dengan kode keluar 0, 0 error, dan 5 warning. Namun, 616 port transaksi menggunakan virtual pins. Timing Analyzer menyatakan constraint setup/hold belum lengkap untuk I/O; oleh karena itu Fmax/slack di atas hanya hasil jalur yang dianalisis, bukan sign-off timing antarmuka board. Build `.sof` juga bukan bukti fungsional board. Kami belum mengukur daya, throughput nyata, perbandingan terhadap software, atau hasil pada DE10-Nano. Metrik dan batasnya dirinci di `docs/results.md`.

### 3.7 Pertimbangan daya, trade-off, dan kelayakan

Arsitektur satu ronde per siklus dan satu transaksi aktif dipilih agar alur kendali dapat ditinjau dan diverifikasi dengan kapasitas tetap. Pilihan iteratif menukar jumlah logika paralel dengan jumlah siklus; pada proyek ini kami belum mengukur pembanding paralel dengan tool, device, dan constraint yang sama, sehingga kami tidak mengklaim desain lebih hemat atau lebih cepat. Daya dinyatakan **TBD — belum diukur**. Build memakai clock target 50 MHz; Fmax laporan tidak boleh ditafsirkan sebagai hasil konsumsi daya maupun throughput aplikasi.

Jadwal proyek mencatat tenggat 6 Oktober 2026. Pekerjaan sampai RTL, simulasi, serta build Quartus baseline sudah memiliki bukti. Tahap lanjutan yang membutuhkan board dan antarmuka host—pemetaan pin transaksi atau wrapper HPS/Avalon dan demonstrasi fisik—kami tandai sebagai pekerjaan terpisah. Proposal software dapat menyertakan hasil simulasi dan build, dengan keterbatasan tersebut dinyatakan jelas.

## 4. Referensi

[1] M. Sönmez Turan, K. McKay, J. Kang, J. Kelsey, and D. Chang, *Ascon-Based Lightweight Cryptography Standards for Constrained Devices: Authenticated Encryption, Hash, and Extendable Output Functions*, NIST Special Publication 800-232, Aug. 2025, doi: 10.6028/NIST.SP.800-232. [Online]. Available: https://doi.org/10.6028/NIST.SP.800-232. [Accessed: Oct. 1, 2026].

[2] C. Dobraunig, M. Eichlseder, F. Mendel, and M. Schläffer, “Ascon v1.2: Lightweight authenticated encryption and hashing,” *Journal of Cryptology*, vol. 34, no. 3, Art. no. 33, 2021, doi: 10.1007/s00145-021-09398-9.

[3] H. Groß, E. Wenger, C. Dobraunig, and C. Ehrenhöfer, “Suit up!—made-to-measure hardware implementations of Ascon,” in *Proc. 18th Euromicro Conf. Digital System Design (DSD)*, 2015, pp. 645–652, doi: 10.1109/DSD.2015.14.

[4] H. Groß, E. Wenger, C. Dobraunig, and C. Ehrenhöfer, “Side-channel and fault resistant ASCON implementation: A detailed hardware evaluation,” in *Proc. IEEE Computer Society Annual Symposium on VLSI (ISVLSI)*, 2024, doi: 10.1109/ISVLSI61997.2024.00063.

[5] M. Fagan, K. Megas, K. Scarfone, and M. Smith, *IoT Device Cybersecurity Capability Core Baseline*, NIST Interagency/Internal Report 8259A, May 2020, doi: 10.6028/NIST.IR.8259A.

[6] M. Fagan *et al*., *IoT Device Cybersecurity Guidance for the Federal Government: Establishing IoT Device Cybersecurity Requirements*, NIST Special Publication 800-213, Nov. 2021, doi: 10.6028/NIST.SP.800-213.

[7] PERURI, “Security Solutions for Guaranteed Electronic Transactions.” [Online]. Available: https://www.peruri.co.id/en/business-pillar/digital-security/digital-product. [Accessed: Oct. 1, 2026]. Digunakan hanya untuk konteks relevansi sektor, bukan sebagai persyaratan atau dukungan resmi terhadap SECURE-TINY.

[8] NIST, “Ascon-AEAD128 SP 800-232 sample vectors,” *Automated Cryptographic Validation Protocol (ACVP) Server*, [Online]. Available: https://github.com/usnistgov/ACVP-Server/tree/master/gen-val/json-files/Ascon-AEAD128-SP800-232. [Accessed: Oct. 1, 2026]. Sampel lokal dan batas penggunaannya dijelaskan di `docs/results.md`.

[9] Ascon Team, “Ascon-C v1.3.0,” *GitHub repository*, file `crypto_aead/ascon128av13/LWC_AEAD_KAT_128_128.txt`. [Online]. Available: https://github.com/ascon/ascon-c/tree/v1.3.0. [Accessed: Oct. 1, 2026]. Digunakan sebagai sumber tambahan KAT; implementasi C tidak disalin ke RTL.

[10] Terasic Technologies, “DE10-Nano Development Kit.” [Online]. Available: https://www.terasic.com.tw/cgi-bin/page/archive.pl?CategoryNo=204&Language=English&No=1046. [Accessed: Oct. 1, 2026].

## 5. Lampiran

Lampiran berikut adalah daftar berkas dan bukti yang perlu disertakan pada naskah final. Kami tidak menyatakan tangkapan layar atau artefak yang belum diambil sebagai bukti yang sudah tersedia. Log dan waveform di `sim/` serta laporan Quartus lokal dapat dibuat ulang dari source; simpan salinan yang akan dikirim agar reviewer menerima bukti yang sama dengan hasil yang dirujuk.

### 5.1 Daftar bukti teknis yang perlu dikumpulkan

| Kode | Bukti/lampiran | Isi minimum yang harus terlihat |
|---|---|---|
| A | Ringkasan regresi simulasi | Screenshot terminal yang memperlihatkan perintah `scripts/run_all_tests.ps1`, status akhir PASS, jumlah KAT core 2.178 transaksi, sapuan top-level 578 transaksi, dan kode keluar sukses. Simpan pula log mentah. |
| B | Identitas vektor | Nama sumber KAT/ACVP, revisi standar, versi/tag sumber, jumlah kasus yang dijalankan, serta SHA-256 berkas vektor sebagaimana dicatat di `docs/results.md`. Tegaskan bahwa ini bukan sertifikasi ACVP. |
| C | Waveform enkripsi | Screenshot GTKWave dari `sim/secure_tiny_top.vcd` yang menampilkan `clk`, `rst_n`, `start`, `busy`, handshake data (`data_valid/data_ready`, `out_valid/out_ready`), `tag_valid/tag_ready`, `done`, dan `tag_out` pada transaksi enkripsi valid. |
| D | Waveform dekripsi valid | Screenshot GTKWave yang menampilkan `decrypt`, status verifier (`verifier_done`, `verifier_match` bila tersedia), `accept`, `reject`, `out_valid`, dan `out_data`; tunjukkan plaintext baru ditawarkan setelah ACCEPT. |
| E | Waveform dekripsi ditolak | Screenshot kasus tag/ciphertext/AD diubah yang memperlihatkan REJECT dan tidak adanya handshake plaintext (`out_valid` tetap tidak menawarkan data plaintext). Cantumkan kasus uji yang sedang ditampilkan. |
| F | Waveform kontrol | Bila ruang lampiran cukup, sertakan satu bukti backpressure atau reset. Tampilkan `valid/ready`, `busy`, `done`, dan fase controller agar jeda/reset dapat dipahami. |
| G | Hasil Quartus | Salinan/screenshot `secure_tiny.flow.rpt`, `secure_tiny.fit.summary`, dan `secure_tiny.sta.rpt`/`.sta.summary`; pastikan perangkat, versi Quartus, parameter, ALM, register, RAM/DSP, Fmax/slack, jumlah warning, dan caveat virtual pins terbaca. |
| H | Berkas pemrograman | Nama `.sof`, ukuran, SHA-256, serta keterangan bahwa Assembler membuat file tetapi belum ada pengujian board. Jangan tampilkan sebagai bukti pengujian fisik. |
| I | Konfigurasi build | QPF/QSF/SDC dan parameter `MAX_DATA_BYTES=16`; sertakan clock target 50 MHz dan jelaskan bahwa pin transaksi masih virtual sehingga I/O belum sepenuhnya constrained. |
| J | Reproduksibilitas | Versi Icarus, Verilator, Yosys, Quartus, Python, sistem operasi/toolchain yang dipakai, perintah build/test, dan tautan commit/tag repository yang bersesuaian. |
| K | Bukti board (opsional untuk tahap proposal saat ini) | Hanya jika pengujian DE10-Nano benar-benar dilakukan: foto board dengan identitas board, cara `.sof` dimuat, jalur antarmuka transaksi, langkah uji, dan log/sinyal input-output. Saat ini belum tersedia; jangan dibuat atau diklaim. |

Untuk tangkapan layar GTKWave, tampilkan nama sinyal dan skala waktu, perbesar satu transaksi yang mudah diikuti, serta beri keterangan kasus dan hasil. Screenshot waveform harus berasal dari VCD yang dihasilkan testbench; jangan menggambar ulang waveform sebagai pengganti data simulasi.

### 5.2 Identitas tim dan pembagian peran

**Nama tim:** Ngadu Nasib; **perguruan tinggi:** Universitas Pendidikan Indonesia

| Nama | Peran dan tanggung jawab |
|---|---|
| Ripan (Ketua) | RTL Designer (Verilog) |
| Andhika Pratama | RTL Designer (Verilog) |
| Andra Vijatmi | Security Analyst |
| Muhammad Iqbal Ridho | System/Business Analyst |
| Dosen pembimbing | *(dikosongkan sementara sesuai arahan tim)* |

NIM, program studi, surel/kontak resmi, dan data personal lain **belum diberikan**. Tim perlu melengkapinya hanya sesuai format panitia dan dengan persetujuan anggota. Jangan mengisi data identitas berdasarkan perkiraan.

### 5.3 Rencana perubahan selama bootcamp tiga hari

| Hari | Fokus | Bukti keluaran yang disiapkan |
|---|---|---|
| 1 | Memahami baseline RTL, alur AEAD, threat boundary, kontrak port, serta hasil simulasi/Quartus | Diagram arsitektur final, daftar invarian dan batas klaim, salinan baseline log dan laporan |
| 2 | Menetapkan satu perubahan/eksperimen yang disetujui tim dan dapat diukur; bila tidak ada hipotesis yang aman dan terukur, gunakan hari ini untuk memperkuat penjelasan desain | Catatan perubahan, alasan, sumber yang dirujuk, hasil sebelum/sesudah; jangan mengubah KAT yang diharapkan |
| 3 | Menjalankan ulang regresi yang relevan dan menyiapkan materi demo/paparan | Log baru, waveform, pembaruan tabel hasil, keputusan eksplisit apakah perubahan dipertahankan atau dibatalkan |

Setiap perubahan bootcamp dicatat dengan hash commit, daftar file berubah, konfigurasi dan versi tool, perintah, hasil PASS/FAIL, serta dampaknya pada metrik. Hasil yang tidak sempat diverifikasi dilabeli belum diverifikasi.

### 5.4 Informasi yang masih harus dilengkapi sebelum pengiriman

1. Lengkapi identitas yang benar-benar diminta panitia: NIM, program studi, kontak, serta status mahasiswa bila menjadi syarat.
2. Masukkan nama dosen pembimbing hanya setelah ditetapkan; untuk draf ini bagian tersebut sengaja kosong.
3. Ambil bukti terminal, waveform, dan laporan Quartus langsung dari hasil lokal; cocokkan konfigurasi dan tanggal dengan `docs/results.md`.
4. Periksa ulang format proposal, batas halaman, format nama tim, serta aturan penggunaan/atribusi referensi dari panitia.
5. Pertahankan kalimat keterbatasan: virtual pins membuat constraint I/O belum lengkap, belum ada transaksi host/board, belum ada pengukuran daya, dan tidak ada klaim side-channel/tamper resistance.
