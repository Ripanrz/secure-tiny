# Glosarium SECURE-TINY

Dokumen ini menerangkan singkatan dan istilah chip yang sering muncul di README dan dokumen proyek. Nama sinyal, nama file, perintah, serta nama standar tetap ditulis persis seperti di kode agar mudah dicocokkan.

## Cara membayangkan SECURE-TINY

Bayangkan sebuah meja layanan yang menerima paket kecil. Pengirim menyerahkan label dan isi paket; mesin mengunci isi paket dan membuat segel pemeriksa (tag). Saat paket dibuka, mesin memeriksa segelnya lebih dulu. Jika segel tidak cocok, isi tidak diserahkan sebagai hasil yang sah. Dalam SECURE-TINY, “mesin” itu adalah rangkaian RTL, sedangkan sinyal `valid/ready` seperti serah-terima barang: byte berpindah pada detak clock saat kedua pihak menyatakan siap.

Analogi ini hanya membantu memahami alur. Ia bukan klaim bahwa chip memverifikasi identitas orang, mendeteksi gangguan fisik, atau melindungi dirinya dari semua serangan.

## Kriptografi dan aliran data

| Istilah/singkatan | Kepanjangan | Arti sederhana |
|---|---|---|
| AEAD | *Authenticated Encryption with Associated Data* (enkripsi terautentikasi dengan data terkait) | Mengunci isi pesan sekaligus membuat tag untuk memeriksa apakah isi atau data terkait berubah. AD ikut diperiksa, tetapi tidak ikut dienkripsi. |
| Ascon-AEAD128 | Nama resmi algoritma Ascon-AEAD128 | Algoritma AEAD yang dipakai proyek. Angka `128` bagian nama standar; detail parameter normatif mengikuti NIST SP 800-232. |
| AD | *Associated Data* (data terkait) | Informasi yang harus diperiksa keasliannya tetapi tetap terlihat, misalnya jenis pesan atau nomor versi. Contoh ini hanya ilustrasi, bukan format proyek yang diwajibkan. |
| Tag autentikasi | *Authentication tag* | Nilai pemeriksa yang dihitung memakai key. Tag cocok menunjukkan bahwa data yang diperiksa sesuai dengan key dan masukan tersebut; tag bukan tanda tangan digital atau identitas personal. |
| Nonce | *Number used once* (nilai yang seharusnya dipakai sekali untuk key terkait) | Nilai masukan yang pemanggil harus jaga agar tidak digunakan ulang untuk enkripsi dengan key yang sama. IP ini tidak membuat atau melacak nonce. |
| KAT | *Known Answer Test* (uji dengan jawaban yang sudah diketahui) | Contoh input beserta keluaran rujukan. Seperti soal dengan kunci jawaban tepercaya untuk mengecek hasil mesin. |
| ACVP | *Automated Cryptographic Validation Protocol* | Protokol NIST untuk pengujian algoritma kriptografi. Sampel yang dipakai proyek bukan sertifikasi atau validasi resmi ACVP. |
| Keluaran terautentikasi | — | Pada dekripsi, plaintext hanya ditawarkan setelah tag cocok. Data sementara tetap dapat tersimpan di dalam rangkaian sebelum tahap itu. |

## Desain perangkat keras

| Istilah/singkatan | Kepanjangan | Arti sederhana |
|---|---|---|
| RTL | *Register Transfer Level* | Cara menjelaskan rangkaian digital melalui register, operasi data, dan perpindahan nilainya pada clock. Seperti gambar kerja yang menjelaskan bagian mana menyimpan nilai dan kapan nilainya berpindah. |
| IP / IP core | *Intellectual Property* core | Blok rangkaian yang dapat dipakai kembali di dalam desain chip lebih besar; mirip satu komponen Lego dengan sambungan yang ditentukan. |
| FSM | *Finite State Machine* (mesin keadaan terbatas) | Pengendali yang berpindah melalui langkah-langkah bernama, seperti menerima data, memproses, memeriksa tag, lalu mengirim hasil. |
| Clock | — | Detak acuan rangkaian. Register biasanya mengambil atau memperbarui nilai pada tepi detak yang ditentukan. |
| Reset sinkron | — | Perintah untuk mengembalikan rangkaian ke keadaan awal, yang diproses pada tepi clock. |
| `valid/ready` | — | Cara dua blok menyepakati transfer. Data berpindah pada tepi clock saat `valid` dan `ready` sama-sama aktif. |
| Buffer / penyangga | — | Tempat simpan sementara. Di SECURE-TINY, AD dan pesan dikumpulkan sebelum core mulai bekerja. |
| FPGA | *Field-Programmable Gate Array* | Chip logika yang rangkaiannya dapat dikonfigurasi ulang. Cocok untuk mencoba desain sebelum membuat chip khusus. |
| SoC | *System-on-Chip* | Satu chip yang menggabungkan beberapa bagian sistem, misalnya prosesor dan logika yang dapat diprogram. |
| HPS | *Hard Processor System* | Prosesor dan komponen sistem tetap pada DE10-Nano. Top-level SECURE-TINY saat ini belum memiliki pembungkus komunikasi HPS. |
| DMA | *Direct Memory Access* | Mekanisme pemindahan data antarperangkat dan memori tanpa prosesor menyalin setiap byte satu per satu. Belum diterapkan di proyek ini. |
| ASIC | *Application-Specific Integrated Circuit* | Chip yang dibuat untuk fungsi tertentu. SECURE-TINY belum memiliki hasil desain fisik atau fabrikasi ASIC. |

## Pengujian dan hasil

| Istilah/singkatan | Kepanjangan | Arti sederhana |
|---|---|---|
| Testbench | — | Program uji yang memberi masukan ke RTL dan memeriksa keluaran yang dihasilkan. |
| Simulasi | — | Menjalankan model rangkaian dengan perangkat lunak untuk melihat perilaku logikanya. Ini bukan pengujian pada chip fisik. |
| VCD | *Value Change Dump* | File rekaman perubahan sinyal yang dapat dibuka dengan GTKWave. Seperti rekaman detak dan perpindahan sinyal dari waktu ke waktu. |
| Sintesis | — | Mengubah RTL menjadi susunan logika yang dapat dipetakan ke perangkat target. Lulus sintesis tidak sendirinya membuktikan fungsi benar. |
| Fitter | — | Tahap Quartus yang menempatkan logika hasil sintesis ke sumber daya FPGA yang tersedia. |
| ALM | *Adaptive Logic Module* | Satuan blok logika yang dipakai Intel FPGA. Angka ALM dari Quartus hanya bermakna untuk perangkat dan konfigurasi laporan tersebut. |
| Register | — | Penyimpan kecil yang mengingat nilai dari satu detak clock ke detak berikutnya. Banyak register bukan ukuran langsung kualitas atau keamanan desain. |
| M10K | Blok memori tertanam sekitar 10 kilabit pada keluarga FPGA terkait | Memori di dalam FPGA. Laporan Quartus SECURE-TINY saat ini mencatat penggunaan nol M10K. |
| DSP | *Digital Signal Processing* block | Blok FPGA untuk operasi hitung tertentu, seperti perkalian. Laporan Quartus SECURE-TINY saat ini mencatat penggunaan nol DSP. |
| Fmax | Frekuensi maksimum yang dilaporkan | Perkiraan frekuensi tertinggi untuk jalur yang dianalisis Quartus. Bukan jaminan bahwa semua pin board memenuhi timing. |
| Slack | Sisa waktu terhadap batas timing | Nilai positif berarti jalur yang dianalisis selesai sebelum batas pada kondisi laporan tersebut. Constraint yang tidak lengkap membatasi makna hasil. |
| Latensi | — | Lama dari perintah dimulai sampai hasil selesai. Di laporan simulasi, nilainya dihitung dalam siklus clock. |
| Throughput | — | Banyaknya data yang dapat diproses dalam satuan waktu. Belum diukur pada board SECURE-TINY. |
| PPA | *Power, Performance, Area* (daya, kinerja, luas/resource) | Tiga ukuran yang sering dipakai untuk menilai trade-off desain chip. Daya belum diukur pada proyek ini. |
| TBD | *To Be Determined* (akan ditentukan) | Nilai belum tersedia atau belum diukur. |

## Tool dan alur ASIC

| Istilah/singkatan | Kepanjangan | Arti sederhana |
|---|---|---|
| OSS CAD Suite | *Open-Source Software Computer-Aided Design Suite* | Paket alat desain perangkat keras sumber terbuka yang dipakai proyek untuk simulasi, sintesis, dan pemeriksaan. |
| NIST | *National Institute of Standards and Technology* | Lembaga Amerika Serikat yang menerbitkan NIST SP 800-232, standar yang menjadi acuan Ascon-AEAD128 di proyek ini. |
| Quartus Prime | Nama perangkat lunak Intel/Altera | Alat untuk membangun dan memetakan desain ke FPGA Intel. |
| Yosys | Nama perangkat lunak sintesis | Alat sintesis terbuka; jumlah sel generik Yosys bukan angka ALM Cyclone V. |
| SCA | *Side-Channel Analysis* (analisis saluran samping) | Upaya menebak rahasia dari gejala samping, misalnya konsumsi daya atau pancaran elektromagnetik. Belum diuji di proyek ini. |
| DPA | *Differential Power Analysis* (analisis daya diferensial) | Teknik analisis saluran samping yang membandingkan banyak pengukuran daya. Belum diuji di proyek ini. |
| FI | *Fault Injection* (penyuntikan gangguan) | Upaya sengaja mengganggu operasi chip, misalnya dengan tegangan atau clock. Belum diuji di proyek ini. |
| PDK | *Process Design Kit* | Kumpulan model dan aturan proses fabrikasi yang diperlukan untuk menyiapkan ASIC pada teknologi tertentu. |
| DRC | *Design Rule Check* | Pemeriksaan apakah layout mengikuti aturan proses fabrikasi. |
| LVS | *Layout Versus Schematic* | Pemeriksaan apakah layout sesuai dengan rangkaian yang dirancang. |

## Format proyek Quartus

| Singkatan | Kepanjangan | Arti sederhana |
|---|---|---|
| QPF | *Quartus Project File* | File utama yang menunjuk proyek Quartus. |
| QSF | *Quartus Settings File* | File pengaturan proyek, seperti perangkat target dan sumber RTL. |
| SDC | *Synopsys Design Constraints* | File batasan waktu, seperti clock yang dipakai untuk analisis timing. |
| `.sof` | *SRAM Object File* | Berkas konfigurasi untuk memuat desain ke FPGA; keberadaannya bukan bukti board telah diuji. |

Jika istilah atau metrik di tabel hasil terasa asing, baca bagian hasil di [`results.md`](results.md) dan kontrak sinyal di [`module_spec.md`](module_spec.md).
