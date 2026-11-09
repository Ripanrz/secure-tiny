# Hasil

> **Status bukti:** baseline historis. Hasil ini dicatat pada Oktober 2026 dan dipertahankan sebagai bukti proyek. Hasil tersebut tidak dibuat ulang pada saat cleanup repositori saat ini.

## Baseline

Baseline yang tercatat saat ini:

| Item | Result |
|---|---:|
| Ascon-C KATs | 1,089 encryption + 1,089 decryption = **2,178 transactions** |
| Core latency suite | **121,308 cycles total**, maximum **88 cycles/transaction** |
| Top-level length sweep | **289 pairs × 2 directions = 578 transactions** |
| Sapuan tingkat atas latency | **51,019 cycles total**, maximum **150 cycles/transaction** |
| Python ACVP sample check | **14 kasus byte-aligned LULUS**; 226/240 sample cases are outside the current byte-oriented checker |
| Verilator | **5.053, 0 warnings** on the recorded top-level lint run |
| Yosys | **20,937 generic cells**, check LULUS |
| FPGA | Cyclone V `5CSEBA6U23I7` |
| ALM | **2,464** |
| Registers | **2,800** |
| M10K | **0** |
| DSP | **0** |
| Fmax | **79.72 MHz** |
| Target clock | **50 MHz** |
| Setup slack | **+7.456 ns** |
| Hold slack | **+0.338 ns** |
| Quartus | **25.1 full compile LULUS** |
| DE10-Nano fisik | **belum diuji** |

## Interpretation

Angka FPGA merupakan baseline untuk konfigurasi saat ini, bukan klaim efisiensi komparatif. Fmax merupakan hasil timing untuk clock/path yang dianalisis. Antarmuka transaksi masih menggunakan virtual pins, sehingga hasil ini bukan I/O timing sign-off.

Angka 20.937 dari Yosys merupakan generic-cell count dan tidak boleh dibandingkan langsung dengan 2.464 ALM dari Quartus.

Sebanyak 2.178 transaksi KAT dan 578 transaksi top-level berasal dari suite yang berbeda dan tidak boleh dijumlahkan sebagai unique test cases.

## Cakupan verifikasi kriptografi

RTL diperiksa terhadap material KAT Ascon-C v1.3.0. Model referensi Python juga memeriksa 14 kasus sampel ACVP byte-aligned. Perbandingan ACVP tersebut **bukan official ACVP validation atau certification**.

## Cakupan verifikasi keamanan

Uji terarah RTL mencakup invalid tag, modified ciphertext, modified AD, stalls/backpressure, reset pada active phases, start-while-busy, dan capacity-overrun behavior. Invarian utamanya adalah:

```text
decryption plaintext_valid => authentication_success
```

Ini merupakan bukti simulasi, bukan proof terhadap side-channel, fault-injection, physical-tamper, atau glitch attacks.

## Cakupan Validasi Perangkat Keras

Hal-hal berikut belum dilakukan pada baseline yang tercatat:

- Programming dan transaction test pada DE10-Nano fisik
- HPS/Avalon integration
- Throughput fisik
- Power/energy measurement
- Board-level I/O timing sign-off
- side-channel characterization
- fault-injection experiments
- formal verification
