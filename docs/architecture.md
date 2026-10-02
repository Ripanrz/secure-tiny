# Arsitektur RTL SECURE-TINY

> **Cara membaca alurnya:** bayangkan loket yang menerima semua bagian paket, memasukkannya ke baki sementara, lalu meminta mesin kriptografi memprosesnya. Pengendali mengatur urutan kerja, core menghitung hasil, dan guard menahan plaintext dekripsi sampai tag cocok. `valid/ready` seperti serah-terima barang: byte berpindah hanya ketika pengirim dan penerima sama-sama siap pada detak clock. Kepanjangan istilah seperti RTL (*Register Transfer Level*) dan FSM (*Finite State Machine*) ada di [glosarium](glossary.md).

## Identitas dan sumber kebenaran

Produk yang kami rancang adalah **SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman**.

Kami memilih **Hardware Cryptography Accelerator** sebagai tantangan utama dan **Secure Communication** sebagai tantangan pendukung. Kami menggunakan **Ascon-AEAD128 menurut NIST SP 800-232 final** dan menargetkan **DE10-Nano FPGA/SoC**. Hasil kami saat ini berupa IP RTL dengan antarmuka aliran data per byte; integrasi bus host dan pemetaan pin masih menjadi pekerjaan lanjutan.

## Arsitektur yang diterapkan

Kami memproses satu transaksi pada satu waktu. Antarmuka AD dan pesan memakai transfer satu byte dengan `valid/ready`. Pengendali kami mengumpulkan seluruh AD dan pesan di penyangga internal, lalu memulai core dengan penyangga tersebut. Core menjalankan AEAD dan menahan hasil di penyangga keluaran sampai pengendali mengirimkannya; isi penyangga masukan tetap stabil saat core sibuk.

```text
Perintah + key/nonce/panjang/tag
              |
              v
     Pengendali AEAD <----> Core Ascon <----> Permutasi Ascon
       |      ^                 |  
       |      |                 +---- hasil data + tag terhitung
       |      |                               |
 Aliran masukan AD/pesan              +------+------+
                                      Pembentuk Tag  Pemeriksa Tag
                                        (enkripsi)     (dekripsi)
                                                          |
                                                  Hardware Authentication Guard
                                                          |
                                             aliran byte keluaran + status
```

Kami memakai `tag_generator` untuk menangkap dan menyajikan tag akhir dari core serta `tag_verifier` untuk membandingkan seluruh 128 bit tag dengan tag masukan. Guard kami hanya mengizinkan keluaran plaintext setelah hasil dekripsi cocok. Kami belum menerapkan AXI, Avalon, DMA, atau protokol HPS pada antarmuka tingkat atas.

Kami menjelaskan aset, batas kepercayaan, invarian keamanan, dan batas klaim di bagian security-by-design pada [`PRD.md`](PRD.md). Guard membatasi pelepasan plaintext pada antarmuka, tetapi kami belum membuktikan penghapusan key, ketahanan side-channel, deteksi gangguan fisik, atau perlindungan terhadap fault injection.

## Kontrak transaksi

1. `start` diterima ketika `busy=0`; perintah, key, nonce, panjang, mode, dan tag masukan disimpan. `start` saat sibuk diabaikan.
2. Setelah perintah diterima, pengendali menerima tepat `ad_length` byte AD, lalu `data_length` byte pesan/ciphertext. Transfer terjadi hanya ketika `valid && ready` pada tepi naik clock. Panjang nol tidak memerlukan transfer.
3. Byte pertama ditempatkan pada `[7:0]` dalam vektor packed penyangga. `MAX_DATA_BYTES` membatasi masing-masing panjang AD dan pesan, bukan jumlah gabungannya.
4. Core menjalankan inisialisasi, absorpsi AD, pemrosesan pesan, dan finalisasi NIST SP 800-232. Permutasi berjalan secara iteratif satu ronde per siklus aktif; urutan ronde dan transformasi mengikuti standar.
5. Enkripsi mengeluarkan ciphertext melalui handshake terlebih dahulu. `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau sesudah core selesai untuk pesan kosong), lalu tag menunggu handshake `tag_ready`. Dekripsi menahan seluruh calon plaintext sampai verifikasi tag berakhir. Jika AD, tag, atau ciphertext salah, tidak ada byte plaintext yang dikeluarkan pada kasus yang diuji.
6. `done` adalah pulsa satu siklus setelah hasil enkripsi diterima atau setelah seluruh byte plaintext terautentikasi diterima. Penolakan dekripsi dan perintah di luar kapasitas juga mengakhiri transaksi dengan pulsa `done`. Panjang di luar kapasitas menghasilkan `command_error`.

## Konfigurasi kapasitas dan biaya

`MAX_DATA_BYTES` adalah parameter positif wajib tanpa nilai bawaan. Implementasi menyusun vektor dengan lebar `8*MAX_DATA_BYTES`; kapasitas praktis dibatasi oleh elaborator, memori, dan sumber daya FPGA. Konfigurasi Quartus DE10-Nano yang kami build adalah **16 byte per AD dan 16 byte per pesan**. Parameter ini adalah batas desain, bukan ukuran blok kriptografi. Fitter Quartus 25.1 melaporkan 2.464 ALM dan 2.800 register; Timing Analyzer melaporkan Fmax 79,72 MHz untuk `FPGA_CLK1_50` dan setup slack terburuk +7,456 ns pada model slow 1100 mV 100°C. Angka tersebut adalah baseline satu konfigurasi dan belum membuktikan klaim hemat dibanding desain lain.

Kami kini memiliki angka area logika FPGA dan Fmax dari Quartus. Daya dan throughput fisik belum kami ukur; hitungan siklus simulasi bukan timing atau throughput pada board. Angka sintesis generik Yosys kami catat sebagai jumlah sel generik saja, bukan resource Cyclone V. Laporan timing Quartus menyatakan I/O belum sepenuhnya constrained karena interface transaksi memakai virtual pins.

## Reset dan tahap target

`rst_n` adalah reset aktif-rendah sinkron terhadap `clk`. Reset membatalkan transaksi dan menurunkan seluruh sinyal `valid`/status sesuai kontrak RTL.

Pemanggil bertanggung jawab memakai nonce yang unik untuk setiap enkripsi dengan key yang sama. IP menerima nonce dari pemanggil dan tidak membuat atau menyimpan riwayat nonce. Hardware Authentication Guard hanya meloloskan plaintext dekripsi setelah tag cocok; guard ini bukan sensor gangguan fisik atau mitigasi side-channel.

Modul tingkat atas tidak bergantung pada board. Proyek Quartus menetapkan perangkat DE10-Nano, clock 50 MHz, reset board, serta pin virtual untuk seluruh antarmuka IP. Konfigurasi itu menyiapkan elaborasi/sintesis FPGA; pin virtual tidak menyediakan jalur host untuk mengirim transaksi pada board. Integrasi Avalon/HPS atau pemetaan antarmuka ke pin ekspansi dan pengujian board merupakan tahapan tersendiri.

## Diagnosis dan agenda eksperimen — belum diterapkan

Bagian ini mencatat hipotesis pengembangan, bukan requirement baru atau fitur RTL yang sudah tersedia. PRD tetap menjadi sumber kebenaran produk.

### Batas desain sekarang

- Controller menyimpan seluruh AD dan pesan sebelum memulai core. Konfigurasi Quartus yang kami build membatasi masing-masing AD dan pesan hingga 16 byte per transaksi; pengujian transaksi pada board belum dilakukan.
- Permutasi berjalan satu ronde per siklus aktif. Ini adalah pilihan iteratif; belum terbukti lebih hemat dibanding baseline alternatif pada Cyclone V.
- Pada dekripsi, guard mencegah calon plaintext keluar sebelum tag cocok. Pemeriksaan RTL menunjukkan register key dan calon plaintext tidak memiliki pembersihan khusus pada setiap jalur akhir transaksi; reset membersihkan register yang dicakup reset. Hal ini belum diuji sebagai properti lifecycle dan tidak boleh disebut secure zeroization.
- Kami memperoleh baseline 2.464 ALM dan 79,72 MHz dari Quartus untuk konfigurasi ini. Hitungan siklus simulasi dan 20.887 sel generik Yosys tetap bukan bukti daya, throughput board, atau efisiensi komparatif Cyclone V.

### Urutan kerja pengembangan

1. **Bekukan dan ukur baseline:** jangan ubah datapath sebelum compile Quartus pertama. Simpan commit, hasil regresi, versi Quartus, konfigurasi device/clock, log, laporan Fitter/Timing Analyzer, dan `.sof` jika compile penuh berhasil.
2. **Buat satu pertanyaan eksperimen:** contoh: “Apakah pengolahan AD per blok mengurangi register pada kapasitas pesan 256 byte tanpa mengubah hasil KAT?” Tetapkan baseline, kandidat, konfigurasi yang sama, dan metrik sebelum coding.
3. **Ubah satu aspek pada satu waktu:** perubahan buffering, jadwal permutasi, interface, dan lifecycle kunci tidak digabung dalam satu eksperimen awal.
4. **Jalankan regresi dan pengukuran target:** KAT, handshake, kasus reject/reset, lint, sintesis Quartus, timing, dan resource.
5. **Perbarui dokumentasi hasil hanya setelah ada bukti run.** Hasil kandidat harus dibandingkan pada device, versi tool, SDC, parameter kapasitas, dan kondisi yang setara.

### Hipotesis arsitektur berikutnya

**Streaming AD/enkripsi** dapat menghilangkan kebutuhan menyimpan seluruh AD/pesan di controller. Namun, dekripsi AEAD baru mengetahui validitas autentikasi setelah pemrosesan tag selesai. Karena itu, implementasi streaming tidak boleh mengirim plaintext calon ke konsumen sebelum verifikasi. Pilihan staging yang perlu dievaluasi adalah:

- staging privat yang dibuka hanya setelah tag cocok, lalu dibatalkan/dibersihkan saat reject; atau
- verifikasi dan dekripsi dua tahap dengan sumber ciphertext yang sama persis dan tidak berubah.

Staging eksternal memerlukan interface dan trust boundary baru; dua tahap menambah latensi dan mensyaratkan input stabil. Kapasitas saat ini 16 byte terlalu kecil untuk mengasumsikan penghematan buffer yang besar. Manfaat streaming harus diukur pada kapasitas yang lebih besar dan konfigurasi yang sama dengan baseline.

Perubahan jadwal ronde (misalnya satu atau beberapa ronde per siklus), serialisasi datapath, memory mapping, deteksi fault, dan proteksi side-channel merupakan pendekatan yang sudah dikenal dalam literatur. Jika dipertimbangkan, kontribusi SECURE-TINY harus dinyatakan sebagai hasil implementasi dan pengukuran khusus, bukan klaim bahwa teknik umumnya baru. Lihat [`docs/proposal-draft.md`](proposal-draft.md) untuk positioning proposal dan batas klaim.
