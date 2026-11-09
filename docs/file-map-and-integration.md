# File Map and Integration

## Product path

```text
Host / future HPS interface
        │
        ▼
secure_tiny_top
        │
        ▼
aead_controller
        │
        ├──► ascon_core
        │       └──► ascon_permutation
        │
        ├──► tag_generator
        ├──► tag_verifier
        └──► authentication_guard
```

## Repository responsibilities

| Path | Responsibility |
|---|---|
| `rtl/` | Synthesizable SystemVerilog product RTL |
| `tb/` | Product verification testbenches |
| `python/` | Reference implementation and vector checkers |
| `vectors/` | Ascon-C KATs and NIST ACVP sample data |
| `scripts/` | Simulation, lint, synthesis and Quartus automation |
| `quartus/` | QPF/QSF/SDC project definition |
| `docs/` | Requirements, architecture, module contract, verification and results |
| `sim/` | Generated locally; intentionally not tracked |
| `quartus/output_files/` | Generated locally; intentionally not tracked |

## RTL

- `ascon_permutation.sv`: 320-bit Ascon permutation.
- `ascon_core.sv`: AEAD initialization, AD processing, message processing, finalization and tag.
- `aead_controller.sv`: transaction FSM, buffering and output/authentication sequencing.
- `tag_generator.sv`: authenticated tag output handling.
- `tag_verifier.sv`: 128-bit tag comparison.
- `authentication_guard.sv`: fail-closed plaintext release control.
- `secure_tiny_top.sv`: product-level synchronous interface.

## Integration boundary

The current IP is board-independent. The Quartus project targets Cyclone V and constrains the board clock/reset, while transaction ports remain virtual. HPS/Avalon, DMA, physical transaction pins and DE10-Nano software integration are future work.
