# Verification Plan

## Verification layers

| Layer | What is tested | Evidence |
|---|---|---|
| Ascon permutation | Round behavior used by the AEAD core | `tb/tb_ascon_permutation.sv` |
| Ascon core | Empty/partial inputs and full KAT set in both directions | `tb/tb_ascon_core.sv`, KAT vectors |
| Tag/authentication | Tag generation, full tag comparison, accept/reject behavior | `tb/tb_tag_auth_modules.sv` |
| Top-level directed | Authentication failures, plaintext suppression, reset, stalls, busy/start, capacity | `tb/tb_secure_tiny_top.sv` |
| Top-level sweep | 0–16 byte AD/message combinations in both directions | `tb/tb_secure_tiny_kat.sv` |
| Python reference | ACVP byte-aligned sample subset and Ascon-C KATs | `python/` |
| RTL lint | Top-level elaboration/lint | `scripts/lint_verilator.ps1` |
| Generic synthesis | Structural check and generic synthesis | `scripts/synth_yosys.ps1` |
| FPGA implementation | Cyclone V build, resource and timing baseline | `quartus/`, `scripts/build_quartus.ps1` |

## Recorded coverage

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

The current evidence demonstrates this invariant for the tested RTL scenarios. It does not establish resistance to physical or implementation-level attacks.

## Out of scope

- official ACVP certification
- side-channel resistance
- fault-injection resistance
- physical tamper resistance
- secure-element certification
- HPS/Avalon integration
- board-level performance and power characterization
