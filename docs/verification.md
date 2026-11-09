# Rencana Verifikasi

## Verification layers

> Hasil verifikasi yang didokumentasikan di sini merupakan bukti baseline historis. Tidak ada fresh simulation yang diklaim untuk cleanup repositori saat ini.

Repositori juga menjalankan unit test kecil untuk modul counter. Modul ini dipertahankan untuk pembelajaran RTL dan regression hygiene, tetapi bukan bukti untuk cryptographic datapath.

| Layer | Yang diuji | Bukti |
|---|---|---|
| Counter learning/unit | Basic synchronous RTL reset/enable/hold/wrap behavior | `tb/tb_counter.sv` |
| Ascon permutation | Perilaku round yang digunakan oleh AEAD core | `tb/tb_ascon_permutation.sv` |
| Ascon core | Empty/partial inputs dan seluruh KAT set pada kedua arah | `tb/tb_ascon_core.sv`, KAT vectors |
| Tag/authentication | Tag generation, full tag comparison, dan accept/reject behavior | `tb/tb_tag_auth_modules.sv` |
| Uji terarah tingkat atas | Authentication failures, plaintext suppression, reset, stalls, busy/start, capacity | `tb/tb_secure_tiny_top.sv` |
| Sapuan tingkat atas | 0–16 byte AD/message combinations in both directions | `tb/tb_secure_tiny_kat.sv` |
| Model referensi Python | Subset sampel ACVP byte-aligned dan KAT Ascon-C | `python/` |
| Lint RTL | Elaboration/lint top-level | `scripts/lint_verilator.ps1` |
| Sintesis generik | Structural check dan sintesis generik | `scripts/synth_yosys.ps1` |
| Implementasi FPGA | Build Cyclone V, resource dan timing baseline | `quartus/`, `scripts/build_quartus.ps1` |

## Cakupan yang Tercatat

- 1.089 KAT Ascon-C untuk encryption
- 1.089 KAT Ascon-C untuk decryption
- 289 pasangan panjang AD/message pada setiap arah
- 14 kasus sampel ACVP byte-aligned pada Python checker
- Negative authentication scenarios
- Control-path stress scenarios

## Security Invariant

Untuk decryption, kontrak yang ditetapkan adalah:

```text
plaintext_valid -> authentication_success
```

Bukti saat ini menunjukkan invarian tersebut pada skenario RTL yang diuji. Bukti ini tidak menetapkan resistance terhadap physical attack atau implementation-level attack.

## Di Luar Cakupan

- official ACVP certification
- side-channel resistance
- fault-injection resistance
- physical tamper resistance
- secure-element certification
- HPS/Avalon integration
- board-level performance and power characterization
