# Dokumen Persyaratan Produk (PRD)

## 1. Identitas Proyek

**Nama Proyek:** SECURE-TINY

**Judul Lengkap:**
Resource-Efficient Authenticated Encryption IP Core with Hardware Authentication Guard for Secure Edge Communication

**Judul Bahasa Indonesia:**
Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman

**Kompetisi:** PERURI Chip Hackathon 2026

**Kategori Proposal:** Desain Chip IC & Implementasi FPGA

**Tantangan Utama:** Akselerator Kriptografi Perangkat Keras

**Domain Aplikasi:** Komunikasi Aman

**Platform Evaluasi Target:** FPGA/SoC DE10-Nano

---

# 2. Ringkasan Eksekutif

## 2.1 Masalah

Perangkat edge, simpul IoT, pengontrol tertanam (embedded controllers), dan sistem terbatas sumber daya lainnya semakin banyak memproses dan mentransmisikan data sensitif. Komunikasi yang aman membutuhkan tidak hanya kerahasiaan (*confidentiality*), tetapi juga integritas (*integrity*) dan otentisitas (*authenticity*) dari informasi yang ditransmisikan.

Implementasi kriptografi berbasis perangkat lunak saja (*software-only*) membebankan komputasi kriptografi pada prosesor utama (*host processor*). Untuk sistem dengan sumber daya terbatas, hal ini dapat meningkatkan beban kerja komputasi dan latensi pemrosesan.

Oleh karena itu, proyek ini menyelesaikan masalah desain perangkat keras dengan mengimplementasikan enkripsi terotentikasi sebagai akselerator perangkat keras khusus yang dapat diintegrasikan ke dalam sistem *edge computing*.

## 2.2 Solusi yang Diusulkan

SECURE-TINY adalah IP core perangkat keras modular yang mengimplementasikan enkripsi dan dekripsi terotentikasi berbasis Ascon-AEAD128.

Desain ini mengintegrasikan:

* Inti kriptografi Ascon
* Logika kontrol AEAD
* Penanganan data input/output
* Pembuatan tag otentikasi (*tag generation*)
* Verifikasi tag otentikasi (*tag verification*)
* Hardware Authentication Guard

Hardware Authentication Guard menghasilkan keputusan tingkat perangkat keras berupa DITERIMA (ACCEPT) / DITOLAK (REJECT) berdasarkan verifikasi otentikasi.

## 2.3 Konsep Utama

Enkripsi:

Kunci + Nonce + Data Terkait (*Associated Data*) + Plaintext
→ Ciphertext + Tag Otentikasi

Dekripsi:

Kunci + Nonce + Data Terkait (*Associated Data*) + Ciphertext + Tag Otentikasi
→ Plaintext + Status Otentikasi

Otentikasi:

Tag Valid → DITERIMA (ACCEPT)

Tag Tidak Valid → DITOLAK (REJECT)

---

# 3. Pernyataan Masalah

Proyek ini berfokus pada masalah teknis berikut:

Bagaimana enkripsi terotentikasi dapat diimplementasikan sebagai IP core perangkat keras modular yang menyediakan perilaku keamanan terverifikasi sambil mempertahankan penggunaan sumber daya perangkat keras dan latensi yang wajar?

Desain harus menyeimbangkan:

* fungsionalitas keamanan,
* kompleksitas RTL,
* penggunaan sumber daya perangkat keras,
* latensi,
* throughput,
* upaya verifikasi,
* dan skalabilitas.

---

# 4. Tujuan Desain

Proyek ini harus:

1. Mengimplementasikan inti perangkat keras kriptografi berbasis Ascon-AEAD128.
2. Mendukung fungsionalitas enkripsi/dekripsi terotentikasi.
3. Menghasilkan dan memverifikasi tag otentikasi.
4. Menolak hasil otentikasi yang tidak valid melalui *hardware authentication guard*.
5. Menggunakan SystemVerilog RTL modular yang dapat disintesis.
6. Menyediakan *testbench* RTL terotomatisasi.
7. Memverifikasi fungsionalitas terhadap referensi tepercaya / materi Known Answer Test (KAT).
8. Menghasilkan bentuk gelombang simulasi (*simulation waveforms*).
9. Mengukur latensi dalam siklus *clock*.
10. Menyiapkan desain untuk sintesis FPGA yang menargetkan DE10-Nano.
11. Mengevaluasi penggunaan sumber daya dan *timing* ketika sintesis tersedia.
12. Menjaga arsitektur tetap modular sehingga antarmuka, *buffering*, atau peningkatan kinerja di masa mendatang dapat ditambahkan tanpa merancang ulang seluruh inti kriptografi.

---

# 5. Cakupan Proyek

## 5.1 Cakupan Wajib

Implementasi kerja minimum harus mencakup:

* Permutasi Ascon
* Ascon core
* Pengontrol AEAD
* Pembuatan tag otentikasi
* Verifikasi tag otentikasi
* Authentication guard
* Integrasi tingkat atas (*top-level*)
* Testbench RTL
* Verifikasi fungsional
* Pengujian manipulasi/tag tidak valid (*tamper testing*)
* Pembuatan bentuk gelombang (*waveform*)

## 5.2 Cakupan Lanjutan

Jika waktu memungkinkan:

* Sintesis Quartus
* Estimasi sumber daya FPGA
* Analisis timing
* Perhitungan throughput
* Persiapan implementasi DE10-Nano
* Prototip antarmuka HPS/FPGA

## 5.3 Cakupan Opsional

Jika cakupan wajib dan lanjutan sudah stabil:

* Alur ASIC LibreLane
* Sintesis
* Floorplanning
* Placement
* Clock-tree synthesis
* Routing
* DRC/LVS
* Pembuatan layout/GDS

Alur ASIC opsional tidak boleh memperlambat penyelesaian verifikasi RTL wajib.

---

# 6. Arsitektur yang Diusulkan

Arsitektur tingkat tinggi:

Host / HPS
|
v
Antarmuka Kontrol & Data
|
v
Buffer Input / Register
|
v
Pengontrol AEAD
|
v
Inti Kriptografi Ascon
|
+--------------------+
|                    |
v                    v
Pembuat Tag       Verifikator Tag
|
v
Authentication Guard
/            \
/              \
DITERIMA (ACCEPT)  DITOLAK (REJECT)
|
v
Buffer Output

---

# 7. Modul-Modul RTL

## 7.1 ascon_permutation.sv

Tujuan:

Mengimplementasikan operasi permutasi utama Ascon.

Tanggung Jawab:

* mempertahankan *state* kriptografi;
* menjalankan operasi *round*;
* memperbarui *state* secara sinkron;
* menyediakan output deterministik untuk input *state* dan konfigurasi *round* tertentu.

Modul ini harus dapat diuji secara independen.

---

## 7.2 ascon_core.sv

Tujuan:

Menyediakan *datapath* kriptografi menggunakan permutasi Ascon.

Tanggung Jawab:

* penanganan kunci/*state*;
* penanganan *nonce*;
* pemrosesan data terkait (*associated data*);
* pemrosesan *plaintext/ciphertext*;
* finalisasi;
* pembuatan tag otentikasi.

---

## 7.3 aead_controller.sv

Tujuan:

Mengontrol urutan operasi kriptografi.

State konseptual:

IDLE
→ INIT
→ ABSORB
→ PROCESS
→ FINALIZE
→ TAG
→ DONE

State eksak dapat diubah oleh insinyur RTL jika terjustifikasi secara fungsional.

---

## 7.4 tag_generator.sv

Tujuan:

Menyediakan output tag otentikasi yang dihasilkan oleh proses kriptografi.

---

## 7.5 tag_verifier.sv

Tujuan:

Membandingkan tag otentikasi yang diharapkan/dihasilkan dengan tag yang diterima.

Output:

* valid
* tidak valid

Perbandingan tidak boleh dianggap benar tanpa bukti simulasi.

---

## 7.6 authentication_guard.sv

Tujuan:

Mengubah status otentikasi menjadi keputusan keamanan tingkat perangkat keras.

Otentikasi valid:

auth_valid = 1
→ accept = 1
→ reject = 0

Otentikasi tidak valid:

auth_valid = 0
→ accept = 0
→ reject = 1

Guard harus mencegah data terotentikasi yang tidak valid diperlakukan sebagai output yang valid.

---

## 7.7 secure_tiny_top.sv

Tujuan:

Mengintegrasikan seluruh modul SECURE-TINY ke dalam satu IP perangkat keras tingkat atas (*top-level*).

---

# 8. Filosofi Antarmuka

Implementasi awal harus memprioritaskan kesederhanaan verifikasi.

Milestone RTL pertama tidak memerlukan antarmuka AXI/Avalon tingkat produksi yang lengkap.

Antarmuka fungsional internal dapat menggunakan sinyal kontrol/data sinkron yang sederhana.

Antarmuka host yang lebih lengkap dapat ditambahkan setelah kebenaran kriptografi dipastikan.

Hal ini mencegah kompleksitas antarmuka menghambat verifikasi kriptografi.

---

# 9. Persyaratan Verifikasi

Verifikasi adalah hal yang wajib.

Sebuah modul tidak dianggap selesai hanya karena dapat dikompilasi.

Tahapan verifikasi yang diperlukan:

1. Kompilasi RTL
2. Testbench tingkat unit
3. Testbench integrasi
4. Perbandingan Known Answer Test / referensi
5. Pengujian enkripsi/dekripsi valid
6. Pengujian tag otentikasi tidak valid
7. Pengujian ciphertext yang dimodifikasi
8. Pengujian perilaku reset
9. Pengujian urutan start/busy/done
10. Pemeriksaan bentuk gelombang (*waveform*)

---

# 10. Filosofi Verifikasi

Gunakan implementasi perangkat lunak/referensi yang tepercaya sebagai oracle independen.

Alur:

Input
→ Python/model referensi
→ hasil yang diharapkan

Input
→ RTL DUT
→ hasil perangkat keras

Bandingkan:

Hasil RTL == hasil yang diharapkan

Jika sama:

PASS

Jika berbeda:

FAIL dan lakukan debugging.

Hasil kriptografi yang diharapkan tidak boleh dibuat-buat; gunakan vector referensi tepercaya.

---

# 11. Metrik Kinerja

Metrik berikut harus diukur hanya setelah implementasi nyata:

### Fungsional

* kebenaran enkripsi
* kebenaran dekripsi
* kebenaran otentikasi
* tingkat penolakan manipulasi (*tamper rejection rate*)

### Perangkat Keras

* Logic Elements / ALM
* Flip-Flops
* M10K
* Blok DSP

### Timing

* frekuensi clock / Fmax
* latensi dalam siklus clock
* estimasi waktu pemrosesan

### Kinerja

* throughput
* hubungan sumber daya/kinerja

Tidak ada hasil angka yang boleh dibuat-buat sebelum pengukuran.

---

# 12. Target FPGA

Platform evaluasi target adalah DE10-Nano.

Pemetaan konseptual yang dimaksud adalah:

HPS ARM Cortex-A9
→ antarmuka host/kontrol
→ FPGA fabric
→ akselerator SECURE-TINY

Pengembangan awal tidak bergantung pada kepemilikan fisik DE10-Nano.

Simulasi RTL dapat dilakukan tanpa perangkat keras fisik.

Sintesis Quartus dapat dilakukan sebagai tahap terpisah.

Pengujian papan fisik adalah tahap validasi tambahan ketika akses perangkat keras tersedia.

---

# 13. Posisi Kebaruan (Novelty)

SECURE-TINY tidak mengklaim menemukan algoritma kriptografi baru.

Kebaruan proyek diposisikan pada tingkat arsitektur perangkat keras / sistem:

1. integrasi pemrosesan enkripsi terotentikasi dan logika keputusan otentikasi;
2. Hardware Authentication Guard eksplisit;
3. arsitektur IP modular yang dapat digunakan kembali;
4. eksplorasi sumber daya/kinerja;
5. offloading pemrosesan enkripsi terotentikasi ke perangkat keras;
6. perilaku keamanan terukur melalui skenario otentikasi valid/tidak valid.

Proyek harus menghindari klaim tanpa bukti seperti:

* implementasi perangkat keras Ascon pertama;
* implementasi Ascon FPGA pertama;
* algoritma kriptografi baru;
* dijamin area terendah;
* dijamin throughput tertinggi.

---

# 14. Skalabilitas

Arsitektur harus memungkinkan ekstensi di masa mendatang:

* antarmuka data yang lebih lebar;
* antarmuka streaming;
* buffering FIFO;
* antarmuka AXI/Avalon;
* pemrosesan multi-blok;
* paralelisme berorientasi kinerja;
* implementasi serial berorientasi area;
* integrasi dengan protokol komunikasi aman;
* implementasi ASIC melalui alur physical-design open-source.

Implementasi pertama harus sengaja dibuat cukup kecil agar dapat diverifikasi dalam jadwal hackathon.

---

# 15. Alat Perkakas (Toolchain)

Pengembangan utama:

* VS Code
* SystemVerilog
* Icarus Verilog / Verilator
* GTKWave
* Python
* Git

Implementasi FPGA:

* Intel Quartus Prime
* Platform Designer jika diperlukan

Alur ASIC opsional:

* LibreLane
* PDK open-source yang didukung oleh alur yang dipilih

---

# 16. Strategi Pengembangan

Pengembangan harus bertahap (inkremental).

Fase 1:
Dasar-dasar RTL

Fase 2:
Permutasi Ascon

Fase 3:
Ascon core

Fase 4:
Kontrol AEAD

Fase 5:
Verifikasi tag

Fase 6:
Authentication Guard

Fase 7:
Integrasi tingkat atas (*top-level*)

Fase 8:
Verifikasi dan kasus batas (*corner cases*)

Fase 9:
Sintesis FPGA / analisis sumber daya

Fase 10:
Desain fisik ASIC opsional

Pengembangan dilakukan bertahap; verifikasi setiap fase sebelum memulai fase berikutnya.

---

# 17. Definisi Selesai (Definition of Done)

Sebuah modul dinyatakan SELESAI (DONE) hanya jika:

* kode sumber tersedia;
* kode dapat dikompilasi;
* testbench tersedia;
* simulasi berjalan;
* perilaku yang diharapkan diperiksa;
* hasil dicatat;
* tidak ada kegagalan yang tidak dapat dijelaskan yang tersisa.

Seluruh proyek dianggap terverifikasi RTL hanya ketika:

* RTL tingkat atas dapat dikompilasi;
* simulasi integrasi berhasil (PASS);
* hasil kriptografi cocok dengan data referensi/KAT tepercaya;
* otentikasi valid diterima;
* otentikasi tidak valid ditolak;
* bentuk gelombang (*waveform*) relevan telah diperiksa.

---

# 18. Keselarasan Proposal

Proposal akhir harus memetakan proyek ke struktur proposal resmi:

1. Ringkasan Eksekutif
2. Latar Belakang & Pernyataan Masalah
3. Desain Chip yang Diusulkan
4. Solusi & Arsitektur Sistem
5. Modul-Modul RTL
6. Estimasi Sumber Daya FPGA
7. Perangkat Lunak & Alat Desain
8. Rencana Pengujian
9. Metrik Keberhasilan
10. Referensi
11. Lampiran

Semua klaim proposal harus membedakan antara:

* target yang direncanakan,
* hasil simulasi,
* hasil sintesis,
* hasil perangkat keras.

Jangan menyajikan nilai yang direncanakan sebagai hasil pengukuran.
