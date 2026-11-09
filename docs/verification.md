# Rencana Verifikasi

## Verification layers

> The verification Hasil documented here are recorded baseline bukti. No fresh simulation is claimed for the current repository cleanup.

The repository also runs a small counter learning/unit test. It is tracked for RTL learning and regression hygiene, but it is not bukti for the cryptographic datapath.

| Layer | What is tested | bukti |
|---|---|---|
| Counter learning/unit | Basic synchronous RTL reset/enable/hold/wrap behavior | `tb/tb_counter.sv` |
| Ascon permutation | Round behavior used by the AEAD core | `tb/tb_ascon_permutation.sv` |
| Ascon core | Empty/partial inputs and full KAT set in both directions | `tb/tb_ascon_core.sv`, KAT vectors |
| Tag/authentication | Tag generation, full tag comparison, accept/reject behavior | `tb/tb_tag_auth_modules.sv` |
| Uji terarah tingkat atas | Authentication failures, plaintext suppression, reset, stalls, busy/start, capacity | `tb/tb_secure_tiny_top.sv` |
| Sapuan tingkat atas | 0–16 byte AD/message combinations in both directions | `tb/tb_secure_tiny_kat.sv` |
| Model referensi Python | ACVP byte-aligned sample subset and Ascon-C KATs | `python/` |
| Lint RTL | Top-level elaboration/lint | `scripts/lint_verilator.ps1` |
| sintesis generik | Structural check and sintesis generik | `scripts/synth_yosys.ps1` |
| Implementasi FPGA | Cyclone V build, resource and timing baseline | `quartus/`, `scripts/build_quartus.ps1` |

## Cakupan yang tercatat

- 1,089 Ascon-C KATs for encryption
- 1,089 Ascon-C KATs for decryption
- 289 AD/message length pairs in each direction
- 14 byte-aligned ACVP sample cases in the Python checker
- Negative authentication scenarios
- Control-path stress scenarios

## Security invariant

For decryption, the intended contract is:

```text
plaintext_valid -> authentication_success
```

The current bukti demonstrates this invariant for the tested RTL scenarios. It does not establish resistance to physical or implementation-level attacks.

## Di luar cakupan

- official ACVP certification
- side-channel resistance
- fault-injection resistance
- physical tamper resistance
- secure-element certification
- HPS/Avalon integration
- board-level performance and power characterization
