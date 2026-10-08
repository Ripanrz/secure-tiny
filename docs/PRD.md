# Dokumen Persyaratan Produk (PRD)

> **Ringkasan untuk pembaca baru:** SECURE-TINY adalah blok perangkat keras yang membantu mengunci pesan dan memeriksa apakah pesan berubah. Bayangkan pesan sebagai paket dan tag sebagai segel: penerima hanya mendapat plaintext setelah segelnya cocok. AD (*Associated Data*, data terkait) ikut diperiksa, tetapi tetap terlihat. Istilah teknis dan kepanjangannya tersedia di [glosarium](glossary.md).

## 1. Identitas Proyek

**Nama proyek:** SECURE-TINY

**Judul lengkap:** SECURE-TINY: Perancangan dan Verifikasi IP Core Ascon-AEAD128 dengan Guard Keluaran Plaintext Berbasis Verifikasi Tag

**Kompetisi:** PERURI Chip Hackathon 2026

**Kategori proposal:** Perancangan Chip IC dan Implementasi FPGA

**Tantangan utama:** Hardware Cryptography Accelerator

**Tantangan pendukung:** Secure Communication

**Ranah penerapan:** Komunikasi edge yang aman

**Target evaluasi:** DE10-Nano FPGA/SoC

## 2. Ringkasan Eksekutif

### 2.1 Masalah

Kami melihat perangkat edge, simpul IoT, pengendali tertanam, dan sistem dengan sumber daya terbatas semakin sering memproses serta mengirimkan data sensitif. Karena itu, kami menargetkan perlindungan kerahasiaan, integritas, dan autentikasi informasi yang dikirim.

Pada penerapan berbasis perangkat lunak saja, prosesor host menjalankan komputasi kriptografi. Kami mengkaji apakah akselerator perangkat keras khusus dapat menyediakan pilihan integrasi lain bagi sistem komputasi edge dengan sumber daya terbatas; manfaat kinerja harus diukur sebelum kami mengklaim peningkatan.

### 2.2 Solusi yang Diusulkan

Kami mengusulkan SECURE-TINY sebagai IP core perangkat keras modular untuk enkripsi dan dekripsi terautentikasi berdasarkan Ascon-AEAD128.

Rancangan kami menggabungkan:

* core kriptografi Ascon;
* logika pengendali AEAD;
* penanganan data masukan dan keluaran;
* pembentukan tag autentikasi;
* verifikasi tag autentikasi; dan
* Hardware Authentication Guard.

Hardware Authentication Guard menghasilkan keputusan ACCEPT/REJECT pada tingkat perangkat keras berdasarkan hasil verifikasi autentikasi.

### 2.3 Konsep Utama

**Enkripsi:**

```text
Key + Nonce + Associated Data + Plaintext
→ Ciphertext + Authentication Tag
```

**Dekripsi:**

```text
Key + Nonce + Associated Data + Ciphertext + Authentication Tag
→ Plaintext + Authentication Status
```

**Autentikasi:** tag valid menghasilkan ACCEPT; tag tidak valid menghasilkan REJECT.

## 3. Pernyataan Masalah

Pertanyaan teknis yang kami kaji adalah: bagaimana menerapkan enkripsi terautentikasi sebagai IP core perangkat keras modular dengan perilaku keamanan yang dapat diverifikasi, penggunaan sumber daya terukur, dan latensi yang sesuai sasaran?

Rancangan perlu menyeimbangkan:

* fungsi keamanan;
* kerumitan RTL;
* penggunaan sumber daya perangkat keras;
* latensi;
* throughput;
* upaya verifikasi; dan
* kemampuan pengembangan lanjutan.

Kami menetapkan “hemat sumber daya” sebagai tujuan arsitektur, bukan hasil pengukuran. Rancangan kami menggunakan permutasi iteratif dan penyimpanan masukan/keluaran berkapasitas terbatas. Kami perlu memperoleh hasil penggunaan sumber daya dan timing dari Quartus sebelum membuat klaim efisiensi komparatif. Kami tidak menetapkan angka area, Fmax, throughput, atau daya yang belum kami ukur.

## 4. Sasaran Desain

Proyek harus:

1. Menerapkan core kriptografi berbasis Ascon-AEAD128.
2. Mendukung fungsi enkripsi dan dekripsi terautentikasi.
3. Membentuk dan memverifikasi tag autentikasi.
4. Menolak hasil autentikasi yang tidak valid melalui Hardware Authentication Guard.
5. Menggunakan RTL SystemVerilog modular yang dapat disintesis.
6. Menyediakan rangkaian uji RTL otomatis (testbench).
7. Memverifikasi fungsi menggunakan referensi tepercaya atau bahan Known Answer Test (KAT).
8. Menghasilkan waveform simulasi.
9. Mengukur latensi dalam siklus clock.
10. Menyiapkan desain untuk sintesis FPGA dengan target DE10-Nano.
11. Mengevaluasi penggunaan sumber daya dan timing setelah perangkat lunak sintesis tersedia.
12. Menjaga arsitektur tetap modular agar antarmuka, penyangga, atau kinerja dapat dikembangkan tanpa merancang ulang seluruh core kriptografi.

## 5. Ruang Lingkup

### 5.1 Ruang Lingkup Wajib

Untuk capaian minimum, kami menetapkan bahwa implementasi harus mencakup:

* permutasi Ascon;
* core Ascon;
* pengendali AEAD;
* pembentukan tag autentikasi;
* verifikasi tag autentikasi;
* authentication guard;
* integrasi tingkat atas;
* rangkaian uji RTL (testbench);
* verifikasi fungsional;
* pengujian fungsional terhadap AD/ciphertext yang diubah dan tag tidak valid (kasus gangguan digital);
* pembuatan waveform;
* kompilasi Quartus untuk target Cyclone V DE10-Nano;
* laporan aktual penggunaan sumber daya FPGA dan timing untuk konfigurasi build; serta
* pembuatan berkas keluaran pemrograman Quartus (`.sof`).

### 5.2 Ruang Lingkup Lanjutan

Pengujian fisik pada board memerlukan akses board dan antarmuka transaksi yang dapat digunakan; hasil tersebut dicatat sebagai validasi perangkat keras yang terpisah. Hal-hal berikut merupakan pengembangan integrasi berikutnya dan tidak termasuk dalam IP awal yang tidak bergantung pada board:

* pembungkus host HPS/Avalon dan driver perangkat lunak;
* pemetaan pin fisik untuk antarmuka transaksi; dan
* DMA, antrean, atau transaksi yang saling tumpang tindih.

Tenggat pengerjaan yang kami catat adalah **6 Oktober 2026** (lima hari kalender dari tanggal perencanaan 1 Oktober 2026). Jadwal kami kendalikan berdasarkan capaian dan bukan janji bahwa seluruh pekerjaan pasti selesai. Kami telah memasang Quartus Prime Lite 25.1 beserta dukungan Cyclone V di `C:\altera_lite\25.1std` dan pada 1 Oktober 2026 menjalankan kompilasi penuh untuk `5CSEBA6U23I7`: Analysis & Synthesis, Fitter, Assembler, dan Timing Analyzer lulus; Fitter melaporkan 2.464 ALM/2.800 register, Fmax 79,72 MHz, dan Assembler membuat `.sof`. Timing Analyzer tetap memperingatkan analisis I/O belum sepenuhnya constrained karena pin transaksi virtual. Integrasi HPS dan pengujian fisik board tetap terpisah dan belum dilakukan.

### 5.3 Ruang Lingkup Opsional

Jika ruang lingkup wajib dan lanjutan sudah stabil, pekerjaan opsional dapat mencakup:

* alur ASIC LibreLane;
* sintesis;
* perencanaan lantai (floorplanning);
* penempatan;
* pembentukan pohon clock;
* perutean;
* DRC/LVS; dan
* pembuatan layout/GDS.

Alur ASIC opsional tidak boleh menunda penyelesaian verifikasi RTL wajib.

## 6. Arsitektur yang Diusulkan

Berikut aliran data IP awal kami yang tidak bergantung pada board:

```text
Pemanggil -- perintah/key/nonce/panjang/tag masuk --> Pengendali AEAD
Pemanggil -- aliran byte AD -----------------------> Pengendali AEAD
Pemanggil -- aliran byte pesan --------------------> Pengendali AEAD
                                                     | penyangga masukan
                                                     v
                                                Core AEAD Ascon
                                                  |       |
                                   permintaan ronde/state | byte hasil packed
                                                  v       v
                                          Permutasi Ascon
                                                  ^
                                                  | hasil ronde/state

Core AEAD Ascon -- tag akhir --> Pembentuk Tag -- handshake tag tertahan --> Pemanggil
Core AEAD Ascon -- tag hitung --+
Tag pemanggil -- via pengendali +--> Pemeriksa Tag --> Authentication Guard
                                                     |             |
Pengendali AEAD <-- keputusan pelepasan plaintext ---+             |
Pengendali AEAD <-- aliran ciphertext/plaintext + status ----------+

Pembungkus HPS/Avalon dan pin transaksi fisik berada di luar IP awal ini.
```

Pengendali memiliki penyangga masukan AD/pesan berkapasitas terbatas dan mengatur core, modul tag, handshake keluaran, serta guard. Core mempertahankan hasil packed saat pengendali mengirimkannya kepada pemanggil. Pembentuk tag menangkap tag akhir dari core; modul ini tidak menghitung tag kedua. Pemeriksa membandingkan tag hasil hitung dengan tag yang diterima; modul ini tidak menjalankan pemrosesan AEAD.

### 6.1 Dasar keamanan rancangan (security-by-design)

Keamanan harus menjadi batasan arsitektur sejak awal, bukan fitur tempelan. Persyaratan dan klaim keamanan mengikuti model berikut:

**Aset yang dilindungi:** key, state internal yang diturunkan dari key, plaintext/calon plaintext, serta integritas ciphertext, tag, dan Associated Data (AD). Nonce bukan rahasia, tetapi keunikannya untuk setiap enkripsi dengan key yang sama merupakan tanggung jawab pemanggil.

**Batas kepercayaan:** pemanggil memasok key, nonce, panjang, AD, data, dan tag. IP memproses transaksi satu clock-domain. IP awal tidak mencakup host/HPS, pertukaran key, penyimpanan key tahan gangguan, sensor fisik, atau protokol jaringan. Model awal mencakup masukan digital yang salah/berubah dan autentikasi yang gagal; serangan fisik, fault injection, side-channel daya/EM, dan keamanan board berada di luar ruang lingkup yang telah diverifikasi.

**Invarian keamanan wajib:**

1. Dekripsi tidak boleh menampilkan plaintext sebagai keluaran sah sebelum verifikasi tag berhasil.
2. AD/tag/ciphertext yang tidak valid harus gagal secara tertutup: tidak ada handshake plaintext dan status dekripsi menunjukkan REJECT.
3. Perintah di luar kapasitas, reset, atau error kendali tidak boleh membuka keluaran plaintext yang belum terautentikasi.
4. Setiap register/buffer yang menyimpan key atau calon plaintext dan lama penyimpanannya harus didokumentasikan sebelum mengklaim perlindungan lifecycle. Penghapusan aman tidak boleh diklaim hanya karena reset RTL menulis nol.
5. Setiap perubahan streaming, memori, atau interface harus mempertahankan invarian di atas atau merevisi requirement dan rencana verifikasi secara eksplisit.

RTL/testbench saat ini mendukung dan menguji penahanan plaintext pada dekripsi sebelum autentikasi serta penolakan AD/tag/ciphertext yang salah pada kasus yang tercakup. RTL belum memiliki bukti clear khusus semua key/state/calon plaintext pada setiap akhir transaksi. Tidak ada mitigasi side-channel atau gangguan fisik yang diimplementasikan atau diuji; semua itu tetap di luar klaim keamanan proyek.

## 7. Modul RTL

### 7.1 `ascon_permutation.sv`

**Tujuan:** menerapkan operasi permutasi inti Ascon.

**Tanggung jawab:** mempertahankan state kriptografi, menjalankan operasi ronde, memperbarui state secara sinkron, dan memberikan keluaran yang deterministik untuk state masukan serta konfigurasi ronde tertentu. Modul ini harus dapat diuji secara mandiri.

### 7.2 `ascon_core.sv`

**Tujuan:** menyediakan jalur data kriptografi yang menggunakan permutasi Ascon.

**Tanggung jawab:** menangani key dan state, nonce, pemrosesan associated data, plaintext/ciphertext, finalisasi, serta pembentukan tag autentikasi.

### 7.3 `aead_controller.sv`

**Tujuan:** mengendalikan urutan operasi kriptografi.

State konseptual:

```text
IDLE → INIT → ABSORB → PROCESS → FINALIZE → TAG → DONE
```

Pengodean state FSM bersifat internal. Perilaku yang tampak dari luar harus memenuhi §8.1 serta kontrak tingkat port pada `docs/module_spec.md`. Perubahan perilaku transaksi memerlukan revisi persyaratan secara eksplisit.

### 7.4 `tag_generator.sv`

**Tujuan:** menyediakan keluaran tag autentikasi yang dihasilkan proses kriptografi.

Modul menangkap tag dari core Ascon dan menahannya menggunakan `tag_valid/tag_ready` sampai terjadi transfer. Modul ini merupakan register handshake, bukan penghitung tag kriptografi.

### 7.5 `tag_verifier.sv`

**Tujuan:** membandingkan tag autentikasi yang diharapkan/dihitung dengan tag yang diterima.

Keluaran menunjukkan `match` atau `mismatch`. Kebenaran perbandingan harus dibuktikan melalui simulasi.

### 7.6 `authentication_guard.sv`

**Tujuan:** mengubah status autentikasi menjadi keputusan keamanan pada tingkat perangkat keras.

Jika autentikasi valid (`match = 1`), guard menghasilkan `accept = 1` dan `reject = 0`. Jika autentikasi tidak valid (`mismatch = 1`), guard menghasilkan `accept = 0` dan `reject = 1`.

Guard harus mencegah data yang autentikasinya tidak valid diperlakukan sebagai keluaran yang sah. Keputusan ACCEPT/REJECT hanya berlaku untuk autentikasi dekripsi. Guard membatasi plaintext dekripsi; enkripsi melaporkan transfer ciphertext/tag dan tidak menyatakan keputusan autentikasi.

### 7.7 `secure_tiny_top.sv`

**Tujuan:** mengintegrasikan seluruh modul SECURE-TINY menjadi satu IP perangkat keras tingkat atas.

## 8. Prinsip Antarmuka

Implementasi awal harus mengutamakan kemudahan verifikasi. Capaian RTL pertama tidak memerlukan antarmuka AXI/Avalon lengkap untuk produksi. Antarmuka fungsional internal dapat memakai sinyal kendali dan data sinkron sederhana. Antarmuka host yang lebih lengkap dapat ditambahkan setelah kebenaran kriptografi dibuktikan, agar kerumitan antarmuka tidak menghambat verifikasi kriptografi.

### 8.1 Kontrak RTL Awal

IP awal menggunakan satu clock, satu transaksi pada satu waktu, dan akselerator iteratif. Port tingkat atas mencakup `clk`, reset sinkron aktif-rendah `rst_n`, perintah (`start`, `decrypt`, `key[127:0]`, `nonce[127:0]`, `ad_length[31:0]`, `data_length[31:0]`, `received_tag[127:0]`), aliran byte AD/pesan yang terpisah, aliran byte keluaran, handshake tag, dan status. Arah serta nama port yang menjadi acuan tercantum pada `docs/module_spec.md`. Profil IP ini tidak memiliki bus AXI/Avalon/HPS, antrean, sinyal `last`, atau perintah yang saling tumpang tindih.

Perintah diterima pada tepi naik clock ketika `start=1` dan `busy=0`; masukan perintah disimpan pada tepi tersebut. Sinyal start saat sibuk diabaikan. Setelah perintah diterima, pemanggil mengirim tepat `ad_length` byte AD, lalu tepat `data_length` byte pesan (plaintext untuk enkripsi, ciphertext untuk dekripsi). Byte berpindah hanya pada tepi naik ketika `valid && ready`; pengirim mempertahankan `valid` dan `data` sampai transfer terjadi. Pengendali tidak menerima byte pesan sebelum seluruh AD diterima. Panjang nol melewati fase aliran tersebut. Tidak ada penanda `last`; batas fase ditentukan oleh panjang yang diumumkan. Dalam vektor internal packed, byte indeks nol menempati `[7:0]`.

`MAX_DATA_BYTES` adalah parameter elaborasi positif yang wajib diberikan dan tidak memiliki nilai bawaan. Parameter ini membatasi panjang AD dan pesan secara terpisah. Profil proyek DE10-Nano menggunakan 16 byte untuk masing-masing. Nilai yang melebihi kapasitas ditolak sebelum data aliran diterima: `command_error` dan `done` berpulsa selama satu siklus, `busy` tetap rendah, dan status autentikasi tidak dinyatakan. `command_error` bukan `reject` autentikasi. Kapasitas yang dikonfigurasi tidak membuktikan klaim penggunaan sumber daya atau timing.

Pada enkripsi, ciphertext dari core ditransfer per byte melalui `out_valid/out_ready`. Setelah byte ciphertext terakhir diterima (atau segera setelah core selesai untuk pesan kosong), tag disajikan melalui `tag_valid/tag_ready` dan ditahan hingga transfer. `done` berpulsa dan `busy` turun setelah handshake tag. Pada dekripsi, seluruh calon plaintext tetap di dalam sampai tag hasil hitung diperiksa. Jika cocok, `auth_result_valid` dan `accept` aktif, `reject` tetap rendah, lalu plaintext dapat ditransfer melalui `out_valid/out_ready`. `done` berpulsa setelah byte plaintext terakhir diterima (atau segera setelah verifikasi berhasil untuk pesan kosong). Jika tidak cocok, `auth_result_valid` dan `reject` aktif, `accept` tetap rendah, tidak ada byte plaintext yang dikeluarkan, dan transaksi berakhir dengan pulsa `done` satu siklus. Status autentikasi hanya didefinisikan untuk dekripsi dan dipertahankan sampai perintah `start` baru diterima saat idle atau reset; enkripsi tidak mengaktifkan `auth_result_valid`, `accept`, atau `reject`.

`busy` aktif sejak transaksi diterima sampai seluruh handshake keluaran selesai. `done` adalah pulsa satu siklus yang menunjukkan penyelesaian transaksi sesuai ketentuan di atas. Reset sinkron aktif-rendah membatalkan operasi dan membersihkan `busy`, sinyal valid aliran/tag, status autentikasi, `command_error`, dan `done`. Perintah tidak diantrekan. Arah sinyal dan batas modul ditetapkan dalam `docs/module_spec.md`.

Pengendali menampung AD dan pesan yang dideklarasikan sebelum menjalankan core dengan vektor packed. Permutasi menjalankan satu ronde pada setiap siklus aktif. Perangkat lunak atau sistem pemanggil bertanggung jawab memberikan nonce yang unik untuk setiap enkripsi dengan key yang sama; IP tidak membuat ataupun mencatat riwayat nonce. Pembungkus bus dan pemetaan pin transaksi khusus board merupakan pekerjaan integrasi berikutnya. Kesiapan build FPGA memerlukan kompilasi Quartus yang berhasil untuk target DE10-Nano, laporan resource/timing aktual, serta keluaran pemrograman yang tercatat. Pengujian fisik board merupakan hasil terpisah.

## 9. Persyaratan Verifikasi

Verifikasi wajib dilakukan. Modul belum dianggap selesai hanya karena berhasil dikompilasi.

Tahapan verifikasi yang diwajibkan:

1. Kompilasi RTL.
2. Testbench tingkat unit.
3. Testbench integrasi.
4. Perbandingan dengan Known Answer Test/referensi.
5. Pengujian enkripsi dan dekripsi valid.
6. Pengujian tag autentikasi tidak valid.
7. Pengujian ciphertext yang diubah.
8. Pengujian AD yang diubah dengan ciphertext dan tag KAT tetap.
9. Pengujian perilaku reset.
10. Pengujian urutan start/busy/done.
11. Pemeriksaan waveform.

## 10. Prinsip Verifikasi

Gunakan implementasi perangkat lunak/referensi tepercaya sebagai pembanding independen:

```text
Masukan → model referensi Python → hasil yang diharapkan
Masukan → RTL DUT                 → hasil perangkat keras
```

Bandingkan hasil RTL dengan hasil yang diharapkan. Jika sama, catat PASS; jika berbeda, catat FAIL dan lakukan penelusuran masalah. Keluaran kriptografi yang diharapkan tidak boleh dibuat-buat; gunakan vektor referensi tepercaya.

## 11. Metrik Kinerja

Metrik berikut hanya boleh diukur setelah implementasi terkait benar-benar dijalankan.

**Fungsional:** kebenaran enkripsi, kebenaran dekripsi, kebenaran autentikasi, dan tingkat penolakan gangguan data.

**Perangkat keras:** Logic Elements/ALM, flip-flop, M10K, dan blok DSP.

**Timing:** frekuensi clock/Fmax, latensi dalam siklus clock, dan perkiraan waktu pemrosesan.

**Kinerja:** throughput dan hubungan antara resource dengan kinerja.

Hasil numerik tidak boleh dikarang sebelum pengukuran.

## 12. Target FPGA

Platform evaluasi yang dituju adalah DE10-Nano. Alur berikut merupakan konsep integrasi sistem mendatang, bukan jalur RTL yang sudah diterapkan atau prasyarat build FPGA:

```text
HPS ARM Cortex-A9 → antarmuka host/kendali → fabric FPGA → akselerator SECURE-TINY
```

Pengembangan awal tidak mensyaratkan kepemilikan fisik DE10-Nano. Simulasi RTL dapat dilakukan tanpa perangkat keras. Kompilasi Quartus, laporan resource/timing khusus perangkat, dan pembuatan berkas pemrograman merupakan tahapan wajib untuk menyatakan build FPGA siap; semuanya berbeda dari simulasi RTL.

Pengujian fisik board merupakan tahap validasi tambahan ketika perangkat keras tersedia. DE10-Nano menjadi target kompilasi Quartus khusus perangkat, pelaporan resource/timing, dan pembuatan berkas pemrograman. Pengujian fisik membutuhkan board dan antarmuka transaksi yang dapat digunakan. Kontrak RTL awal tidak mencakup integrasi HPS; HPS/Avalon dan pemetaan pin transaksi fisik tetap menjadi pekerjaan integrasi selanjutnya. Tetapkan `MAX_DATA_BYTES` secara eksplisit pada setiap elaborasi dan catat nilainya bersama hasil sintesis.

## 13. Posisi Kebaruan dan Kontribusi yang Diusulkan

Kami tidak mengklaim algoritma kriptografi baru atau kebaruan yang sudah terbukti. Implementasi hardware Ascon dan guard autentikasi telah ada dalam prior-art; kami menjadikan integrasi modular, penahanan plaintext sebelum autentikasi, serta verifikasi yang dapat diulang sebagai fokus rekayasa. Fokus tersebut belum membuktikan bahwa desain kami baru, lebih kecil, lebih cepat, atau lebih aman daripada karya terdahulu.

Kami menguji implementasi Ascon-AEAD128 yang mengikuti NIST SP 800-232 dan kontrak keluaran dekripsi fail-closed. Kami telah memperoleh baseline Quartus Cyclone V yang dapat diulang; klaim kontribusi komparatif masih memerlukan tinjauan prior-art dan pengukuran pembanding pada konfigurasi setara. Kami tidak mengklaim sebagai implementasi Ascon hardware pertama, algoritma baru, desain dengan area terendah atau throughput tertinggi, maupun desain dengan ketahanan keamanan yang belum kami uji.

Dalam ruang lingkup kami, Hardware Authentication Guard bertindak sebagai gerbang digital yang dikendalikan hasil verifikasi tag AEAD. Guard kami tidak mendeteksi gangguan fisik, mengurangi kebocoran side-channel, atau menghapus key secara aman. Kami belum menerapkan atau mengevaluasi sifat-sifat tersebut dalam profil IP ini, sehingga tidak mengklaimnya.

## 14. Kemampuan Pengembangan

Arsitektur sebaiknya memungkinkan pengembangan berikutnya berupa antarmuka data lebih lebar, antarmuka streaming, penyangga FIFO, antarmuka AXI/Avalon, pemrosesan multi-blok, paralelisasi untuk kinerja, implementasi terserialisasi untuk penghematan area, integrasi protokol komunikasi aman, dan implementasi ASIC melalui alur desain fisik sumber terbuka.

Implementasi pertama harus cukup kecil agar dapat diverifikasi dalam jadwal hackathon.

## 15. Perangkat Pengembangan

**Pengembangan utama:** VS Code, SystemVerilog, Icarus Verilog/Verilator, GTKWave, Python, dan Git.

**Implementasi FPGA:** Intel Quartus Prime; Platform Designer jika diperlukan.

**Alur ASIC opsional:** LibreLane dan PDK sumber terbuka yang didukung alur terpilih.

## 16. Strategi Pengembangan

Pengembangan harus dilakukan bertahap dan setiap tahap diverifikasi sebelum tahap berikutnya dimulai:

1. dasar RTL;
2. permutasi Ascon;
3. core Ascon;
4. kendali AEAD;
5. verifikasi tag;
6. Authentication Guard;
7. integrasi tingkat atas;
8. verifikasi dan kasus tepi;
9. sintesis FPGA dan analisis resource; dan
10. desain fisik ASIC opsional.

## 17. Kriteria Penyelesaian

Satu modul hanya dinyatakan selesai jika kode sumber tersedia, dapat dikompilasi, memiliki testbench, berhasil disimulasikan, perilaku yang diharapkan telah diperiksa, hasil telah dicatat, dan tidak ada kegagalan tanpa penjelasan.

Proyek dinyatakan terverifikasi pada tingkat RTL hanya jika RTL tingkat atas dapat dikompilasi, simulasi integrasi lulus, hasil kriptografi cocok dengan referensi/KAT tepercaya, autentikasi valid diterima, autentikasi tidak valid ditolak, serta waveform terkait telah diperiksa.

Build FPGA DE10-Nano hanya dinyatakan siap setelah Quartus berhasil mengompilasi proyek Cyclone V yang dikonfigurasi, laporan Fitter dan Timing Analyzer disimpan, timing memenuhi constraint proyek 50 MHz, dan berkas pemrograman `.sof` berhasil dibuat. Nilai resource harus berasal dari keluaran Quartus; ambang penggunaan resource atau klaim efisiensi komparatif tidak boleh dikarang. Status fungsi pada board terpisah dan memerlukan DE10-Nano sungguhan serta jalur transaksi fisik/host yang terdokumentasi.

**Status baseline 1 Oktober 2026:** kami telah memenuhi kompilasi penuh dan pembuatan `.sof` untuk profil Cyclone V yang ditetapkan. Laporan mencatat setup slack positif pada clock 50 MHz, tetapi belum sepenuhnya membatasi timing I/O karena port transaksi menggunakan virtual pins. Karena itu, kami menyatakan **build Quartus profil saat ini berhasil**, sedangkan **sign-off timing I/O dan demonstrasi fisik DE10-Nano masih pending**.

## 18. Penyesuaian Proposal

Proposal mengikuti lima bagian wajib secara berurutan:

1. **Ringkasan Ide / Executive Summary:** masalah, solusi, chip, target pengguna, dan dampak; target pengguna atau dampak yang belum divalidasi harus disebut sebagai sasaran, bukan hasil.
2. **Latar Belakang & Rumusan Masalah / Problem Statement:** kebutuhan chip, rumusan masalah, serta gap terhadap solusi yang tersedia dengan batas bukti yang jelas.
3. **Proposed Chip Design:** fungsi, arsitektur dan diagram blok, input/output, pemrosesan, memori, interface/komunikasi, pertimbangan daya, security-by-design, pendekatan RTL, ISA jika relevan, IP yang digunakan, strategi verifikasi/simulasi/pengujian, target FPGA/ASIC, technology node jika relevan, serta metrik target yang belum diukur.
4. **Referensi:** standar, publikasi, dokumentasi, desain chip, dan sumber vektor yang benar-benar dipakai.
5. **Lampiran:** rencana perubahan/pengembangan selama bootcamp tiga hari, identitas dan peran anggota tim, bukti pendukung, dan informasi tambahan yang diminta panitia. Data identitas tim yang belum diserahkan harus dibiarkan sebagai isian, tidak dikarang.

Security-by-design harus menjadi bagian awal Section 3, mencakup aset, batas kepercayaan, asumsi, invarian, serta keterbatasan. Semua klaim proposal harus membedakan target yang direncanakan, hasil simulasi, hasil sintesis Quartus, estimasi daya, dan hasil perangkat keras. Nilai yang direncanakan tidak boleh disajikan seolah-olah sudah diukur.
