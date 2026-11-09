# Results

## Baseline

The current recorded baseline uses:

| Item | Result |
|---|---:|
| Ascon-C KATs | 1,089 encryption + 1,089 decryption = **2,178 transactions** |
| Core latency suite | **121,308 cycles total**, maximum **88 cycles/transaction** |
| Top-level length sweep | **289 pairs × 2 directions = 578 transactions** |
| Top-level sweep latency | **51,019 cycles total**, maximum **150 cycles/transaction** |
| Python ACVP sample check | **14 byte-aligned cases PASS**; 226/240 sample cases are outside the current byte-oriented checker |
| Verilator | **5.053, 0 warnings** on the recorded top-level lint run |
| Yosys | **20,937 generic cells**, check PASS |
| FPGA | Cyclone V `5CSEBA6U23I7` |
| ALM | **2,464** |
| Registers | **2,800** |
| M10K | **0** |
| DSP | **0** |
| Fmax | **79.72 MHz** |
| Target clock | **50 MHz** |
| Setup slack | **+7.456 ns** |
| Hold slack | **+0.338 ns** |
| Quartus | **25.1 full compile PASS** |
| Physical DE10-Nano | **Not tested** |

## Interpretation

The FPGA figures are a baseline for the current configuration, not a comparative efficiency claim. Fmax is a timing result for the analyzed clock/path. The transaction interface still uses virtual pins, so this is not I/O timing sign-off.

The 20,937 Yosys figure is a generic-cell count and must not be compared directly with the 2,464 Quartus ALM figure.

The 2,178 KAT transactions and 578 top-level transactions are separate suites and must not be summed as unique test cases.

## Cryptographic verification scope

The RTL is checked against Ascon-C v1.3.0 KAT material. The Python reference additionally checks 14 byte-aligned ACVP sample cases. The ACVP comparison is **not official ACVP validation or certification**.

## Security verification scope

Directed RTL tests cover invalid tag, modified ciphertext, modified AD, stalls/backpressure, reset in active phases, start-while-busy, and capacity-overrun behavior. The key invariant is:

```text
decryption plaintext_valid => authentication_success
```

This is simulation evidence, not proof against side-channel, fault-injection, physical-tamper, or glitch attacks.

## Hardware validation scope

Not yet performed:

- physical DE10-Nano programming/transaction test
- HPS/Avalon integration
- physical throughput
- power/energy measurement
- board-level I/O timing sign-off
- side-channel characterization
- fault-injection experiments
- formal verification
