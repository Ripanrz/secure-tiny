# Arsitektur RTL SECURE-TINY

## Identitas dan sumber kebenaran

Produk: **SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman**.

Tantangan utama: **Hardware Cryptography Accelerator**. Tantangan pendukung: **Secure Communication**. Algoritma: **Ascon-AEAD128 menurut NIST SP 800-232 final**. Target: **DE10-Nano FPGA/SoC**. Hasil saat ini berupa IP RTL dengan antarmuka aliran data per byte. Integrasi bus host dan pemetaan pin pengguna masih menjadi pekerjaan integrasi board.

## Arsitektur yang diterapkan

Satu transaksi diproses pada satu waktu. Antarmuka AD dan pesan memakai transfer satu byte dengan `valid/ready`. Pengendali mengumpulkan seluruh AD dan pesan di penyangga internal, lalu memulai core dengan penyangga. Core menjalankan AEAD dan menahan hasil di penyangga keluaran sampai pengendali mengirimkannya. Isi penyangga masukan tetap stabil saat core sibuk.

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

`tag_generator` menangkap dan menyajikan tag akhir yang dihitung core. `tag_verifier` membandingkan seluruh 128 bit tag hasil hitung dengan tag masukan. Guard hanya mengizinkan keluaran plaintext setelah hasil dekripsi cocok. Antarmuka tingkat atas tidak menerapkan AXI, Avalon, DMA, atau protokol HPS.

Model aset, batas kepercayaan, invarian keamanan, dan batas klaim normatif dijelaskan di bagian security-by-design pada [`PRD.md`](PRD.md). Guard membatasi pelepasan plaintext pada antarmuka; hal itu tidak membuktikan penghapusan key, ketahanan side-channel, deteksi gangguan fisik, atau keamanan terhadap fault injection.

## Kontrak transaksi

1. `start` diterima ketika `busy=0`; perintah, key, nonce, panjang, mode, dan tag masukan disimpan. `start` saat sibuk diabaikan.
2. Setelah perintah diterima, pengendali menerima tepat `ad_length` byte AD, lalu `data_length` byte pesan/ciphertext. Transfer terjadi hanya ketika `valid && ready` pada tepi naik clock. Panjang nol tidak memerlukan transfer.
3. Byte pertama ditempatkan pada `[7:0]` dalam vektor packed penyangga. `MAX_DATA_BYTES` membatasi masing-masing panjang AD dan pesan, bukan jumlah gabungannya.
4. Core menjalankan inisialisasi, absorpsi AD, pemrosesan pesan, dan finalisasi NIST SP 800-232. Permutasi berjalan secara iteratif satu ronde per siklus aktif; urutan ronde dan transformasi mengikuti standar.
5. Enkripsi mengeluarkan ciphertext melalui handshake terlebih dahulu. `tag_valid` baru ditawarkan setelah byte ciphertext terakhir diterima (atau sesudah core selesai untuk pesan kosong), lalu tag menunggu handshake `tag_ready`. Dekripsi menahan seluruh calon plaintext sampai verifikasi tag berakhir. Jika tag salah, tidak ada byte plaintext yang dikeluarkan.
6. `done` adalah pulsa satu siklus setelah hasil enkripsi diterima atau setelah seluruh byte plaintext terautentikasi diterima. Penolakan dekripsi dan perintah di luar kapasitas juga mengakhiri transaksi dengan pulsa `done`. Panjang di luar kapasitas menghasilkan `command_error`.

## Konfigurasi kapasitas dan biaya

`MAX_DATA_BYTES` adalah parameter positif wajib tanpa nilai bawaan. Implementasi menyusun vektor dengan lebar `8*MAX_DATA_BYTES`; kapasitas praktis dibatasi oleh elaborator, memori, dan sumber daya FPGA. Konfigurasi build awal DE10-Nano adalah **16 byte per AD dan 16 byte per pesan**. Parameter ini adalah batas desain, bukan ukuran blok kriptografi. Penyangga membuat konsumsi register bertambah seiring kapasitas; konfigurasi 16 byte dipilih sebagai nilai awal agar desain dapat diuji, tetapi belum membuktikan klaim hemat sumber daya. Nilai resource Cyclone V dan timing berstatus `TBD — belum diukur` sampai build Quartus berhasil.

Tidak ada klaim area, Fmax, latensi, throughput, atau daya sebelum pengukuran pada perangkat dan sasaran yang sesuai. Angka sintesis generik Yosys dicatat sebagai jumlah sel generik saja, bukan resource Cyclone V.

## Reset dan tahap target

`rst_n` adalah reset aktif-rendah sinkron terhadap `clk`. Reset membatalkan transaksi dan menurunkan seluruh sinyal `valid`/status sesuai kontrak RTL.

Pemanggil bertanggung jawab memakai nonce yang unik untuk setiap enkripsi dengan key yang sama. IP menerima nonce dari pemanggil dan tidak membuat atau menyimpan riwayat nonce. Hardware Authentication Guard hanya meloloskan plaintext dekripsi setelah tag cocok; guard ini bukan sensor gangguan fisik atau mitigasi side-channel.

Modul tingkat atas tidak bergantung pada board. Proyek Quartus menetapkan perangkat DE10-Nano, clock 50 MHz, reset board, serta pin virtual untuk seluruh antarmuka IP. Konfigurasi itu menyiapkan elaborasi/sintesis FPGA; pin virtual tidak menyediakan jalur host untuk mengirim transaksi pada board. Integrasi Avalon/HPS atau pemetaan antarmuka ke pin ekspansi dan pengujian board merupakan tahapan tersendiri.

## Diagnosis dan agenda eksperimen — belum diterapkan

Bagian ini mencatat hipotesis pengembangan, bukan requirement baru atau fitur RTL yang sudah tersedia. PRD tetap menjadi sumber kebenaran produk.

### Batas desain sekarang

- Controller menyimpan seluruh AD dan pesan sebelum memulai core. Konfigurasi Quartus yang direncanakan membatasi masing-masing AD dan pesan hingga 16 byte per transaksi; build Quartus belum dijalankan.
- Permutasi berjalan satu ronde per siklus aktif. Ini adalah pilihan iteratif; belum terbukti lebih hemat dibanding baseline alternatif pada Cyclone V.
- Pada dekripsi, guard mencegah calon plaintext keluar sebelum tag cocok. Pemeriksaan RTL menunjukkan register key dan calon plaintext tidak memiliki pembersihan khusus pada setiap jalur akhir transaksi; reset membersihkan register yang dicakup reset. Hal ini belum diuji sebagai properti lifecycle dan tidak boleh disebut secure zeroization.
- Parameter kapasitas, hitungan siklus simulasi, dan 20.887 sel generik Yosys bukan bukti ALM, Fmax, daya, atau efisiensi Cyclone V.

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
