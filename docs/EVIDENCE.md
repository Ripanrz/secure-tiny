# Evidence Index — SECURE-TINY

Dokumen ini adalah indeks bukti teknis historis yang sengaja **tidak bergantung pada generated artifacts yang disimpan di repository**. Waveform, simulator logs, Quartus reports, dan `.sof` dapat dibuat ulang dari source. Angka baseline yang penting dicatat di `docs/results.md`.

## Evidence matrix

| ID | Claim | Primary source | Status |
|---|---|---|---|
| EV-01 | Ascon-AEAD128 RTL matches 1,089 Ascon-C KATs in encryption and decryption | `tb/tb_ascon_core.sv`, `vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt`, `docs/results.md` | VERIFIED |
| EV-02 | Top-level sweep covers 289 AD/message length pairs in both directions | `tb/tb_secure_tiny_kat.sv`, `docs/results.md` | VERIFIED |
| EV-03 | Invalid tag, ciphertext, and AD are rejected without valid plaintext transfer in directed RTL tests | `tb/tb_secure_tiny_top.sv`, `rtl/authentication_guard.sv`, `rtl/aead_controller.sv` | VERIFIED for tested scenarios |
| EV-04 | Verilator top-level lint passes with zero warnings on the recorded run | `scripts/lint_verilator.ps1`, `docs/results.md` | VERIFIED |
| EV-05 | Yosys generic synthesis/check passes; 20,937 generic cells in the latest recorded run | `scripts/synth_yosys.ps1`, `docs/results.md` | VERIFIED |
| EV-06 | Quartus Cyclone V baseline: 2,464 ALM, 2,800 registers, 0 M10K, 0 DSP, Fmax 79.72 MHz | `quartus/secure_tiny.qsf`, `quartus/secure_tiny.sdc`, recorded Quartus result in `docs/results.md` | PARTIALLY VERIFIED: I/O timing is not fully constrained |
| EV-07 | Physical DE10-Nano validation | N/A | NOT CLAIMED |

## What is intentionally not committed

- `sim/*` generated waveforms and simulator logs
- `quartus/output_files/*` generated reports and `.sof`
- Quartus cache directories
- editor/OS temporary files
- competition proposal drafts
- other temporary learning artifacts that are not part of the repository source tree

## Evidence status

All numeric implementation results in this index refer to the recorded October 2026 baseline. The current repository snapshot does not claim a fresh rerun.

## Interpretation

**VERIFIED** means the claim is supported by source/testbench or a recorded result.

**PARTIALLY VERIFIED** means the measured part is real but the stated limitation matters.

**NOT CLAIMED** means the project deliberately makes no claim because the required evidence does not exist.
