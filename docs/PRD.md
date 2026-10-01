# Product Requirements Document (PRD)

## 1. Project Identity

**Project Name:** SECURE-TINY

**Full Title:**
SECURE-TINY: Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman

**Indonesian Title:**
Perancangan IP Core Authenticated Encryption Hemat Sumber Daya dengan Hardware Authentication Guard untuk Komunikasi Edge Aman

**Competition:** PERURI Chip Hackathon 2026

**Proposal Category:** IC Chip Design & FPGA Implementation

**Primary Challenge:** Hardware Cryptography Accelerator

**Supporting Challenge:** Secure Communication

**Application Domain:** Secure Edge Communication

**Target Evaluation Platform:** DE10-Nano FPGA/SoC

---

# 2. Executive Summary

## 2.1 Problem

Edge devices, IoT nodes, embedded controllers, and other resource-constrained systems increasingly process and transmit sensitive data. Secure communication requires not only confidentiality but also integrity and authenticity of transmitted information.

A software-only cryptographic implementation places cryptographic computation on the host processor. For resource-constrained systems, this can increase computational workload and processing latency.

The project therefore addresses the hardware-design problem of implementing authenticated encryption as a dedicated hardware accelerator that can be integrated into an edge computing system.

## 2.2 Proposed Solution

SECURE-TINY is a modular hardware IP core implementing authenticated encryption and decryption based on Ascon-AEAD128.

The design integrates:

* Ascon cryptographic core
* AEAD control logic
* input/output data handling
* authentication-tag generation
* authentication-tag verification
* Hardware Authentication Guard

The Hardware Authentication Guard produces a hardware-level ACCEPT/REJECT decision based on authentication verification.

## 2.3 Core Concept

Encryption:

Key + Nonce + Associated Data + Plaintext
→ Ciphertext + Authentication Tag

Decryption:

Key + Nonce + Associated Data + Ciphertext + Authentication Tag
→ Plaintext + Authentication Status

Authentication:

Valid Tag → ACCEPT

Invalid Tag → REJECT

---

# 3. Problem Statement

The project focuses on the following technical problem:

How can authenticated encryption be implemented as a modular hardware IP core that provides verifiable security behavior while maintaining reasonable hardware resource utilization and latency?

The design must balance:

* security functionality,
* RTL complexity,
* hardware resource utilization,
* latency,
* throughput,
* verification effort,
* and scalability.

“Resource-efficient” is an architectural objective, not a measured result. The initial candidate uses an iterative permutation and bounded input/output storage. Quartus resource and timing results must be reported before making comparative efficiency claims. This PRD does not assert an unmeasured area, Fmax, throughput, or power target.

---

# 4. Design Objectives

The project shall:

1. Implement an Ascon-AEAD128-based cryptographic hardware core.
2. Support authenticated encryption/decryption functionality.
3. Generate and verify authentication tags.
4. Reject invalid authentication results through a hardware authentication guard.
5. Use modular synthesizable SystemVerilog RTL.
6. Provide automated RTL testbenches.
7. Verify functionality against trusted reference/Known Answer Test material.
8. Produce simulation waveforms.
9. Measure latency in clock cycles.
10. Prepare the design for FPGA synthesis targeting DE10-Nano.
11. Evaluate resource utilization and timing when synthesis is available.
12. Keep the architecture modular so that future interface, buffering, or performance improvements can be added without redesigning the entire cryptographic core.

---

# 5. Scope

## 5.1 Mandatory Scope

The minimum working implementation shall contain:

* Ascon permutation
* Ascon core
* AEAD controller
* authentication-tag generation
* authentication-tag verification
* authentication guard
* top-level integration
* RTL testbench
* functional verification
* modified-ciphertext and invalid-tag functional testing (digital tamper cases)
* waveform generation
* Quartus compile for the DE10-Nano Cyclone V target
* actual FPGA resource and timing report for the configured build
* generation of the Quartus programming output (`.sof`)

## 5.2 Extended Scope

Physical board testing requires board access and a usable transaction interface; it is a separate hardware-validation result. The following remain later integration extensions and are not part of the initial board-independent IP:

* HPS/Avalon host wrapper and software driver;
* physical pin mapping for a transaction interface;
* DMA, queues, or overlapping transactions.

The owner-provided work deadline is **6 October 2026** (five calendar days from the current planning date, 1 October 2026). The schedule is milestone-gated rather than a completion promise: simulation, lint, generic synthesis, and static Quartus preflight have evidence; device-specific Quartus compile, 50 MHz timing, resource report, and `.sof` are still pending because Quartus is not installed in the current environment. This remaining FPGA build is the critical path; HPS integration and physical board testing are not assumed achievable or required by that deadline.

## 5.3 Optional Scope

If the mandatory and extended scope are already stable:

* LibreLane ASIC flow
* synthesis
* floorplanning
* placement
* clock-tree synthesis
* routing
* DRC/LVS
* layout/GDS generation

The optional ASIC flow must never delay completion of the mandatory RTL verification.

---

# 6. Proposed Architecture

The initial, board-independent IP dataflow is:

```text
Caller -- command/key/nonce/lengths/received tag --> AEAD Controller
Caller -- AD byte stream -------------------------> AEAD Controller
Caller -- message byte stream --------------------> AEAD Controller
                                                     | input buffers
                                                     v
                                               Ascon AEAD Core
                                                  |       |
                                   round request/state    | packed result bytes
                                                  v       v
                                          Ascon Permutation
                                                  ^
                                                  | round result/state

Ascon AEAD Core -- final tag --> Tag Generator -- held tag handshake --> Caller
Ascon AEAD Core -- calculated tag --+
Caller tag -- through controller --+--> Tag Verifier --> Authentication Guard
                                                     |             |
AEAD Controller <-- plaintext-release decision ------+             |
AEAD Controller <-- ciphertext/plaintext stream + status ----------+

HPS/Avalon wrapper and physical transaction pins are outside this initial IP.
```

The controller owns bounded AD/message input buffers and coordinates the core, tag modules, output handshakes, and guard. The core retains packed results while the controller streams them to the caller. The tag generator captures the core's final tag; it does not calculate a second tag. The verifier compares the calculated and received tags; it does not perform AEAD processing.

---

# 7. RTL Modules

## 7.1 ascon_permutation.sv

Purpose:

Implement the core Ascon permutation operation.

Responsibilities:

* maintain cryptographic state;
* perform round operations;
* update state synchronously;
* provide deterministic output for a given input state and round configuration.

This module must be independently testable.

---

## 7.2 ascon_core.sv

Purpose:

Provide the cryptographic datapath using the Ascon permutation.

Responsibilities:

* key/state handling;
* nonce handling;
* associated-data processing;
* plaintext/ciphertext processing;
* finalization;
* authentication-tag generation.

---

## 7.3 aead_controller.sv

Purpose:

Control the sequence of cryptographic operations.

Conceptual states:

IDLE
→ INIT
→ ABSORB
→ PROCESS
→ FINALIZE
→ TAG
→ DONE

FSM state encoding is internal. Its externally visible behavior must satisfy §8.1 and the port-level contract in `docs/module_spec.md`; changing transaction behavior requires an explicit requirement revision.

---

## 7.4 tag_generator.sv

Purpose:

Provide the authentication tag output generated by the cryptographic process.

The module captures the tag from the Ascon core and holds it with `tag_valid/tag_ready` until transfer. It is a handshake register, not a cryptographic tag calculator.

---

## 7.5 tag_verifier.sv

Purpose:

Compare the expected/generated authentication tag with the received tag.

Output:

* match
* mismatch

The comparison must not be assumed correct without simulation evidence.

---

## 7.6 authentication_guard.sv

Purpose:

Convert authentication status into a hardware-level security decision.

Valid authentication:

match = 1
→ accept = 1
→ reject = 0

Invalid authentication:

mismatch = 1
→ accept = 0
→ reject = 1

The guard must prevent invalid authenticated data from being treated as valid output.

The ACCEPT/REJECT decision applies to decryption authentication only. The guard gates decryption plaintext; encryption reports its ciphertext/tag transfers and does not assert an authentication decision.

---

## 7.7 secure_tiny_top.sv

Purpose:

Integrate all SECURE-TINY modules into one top-level hardware IP.

---

# 8. Interface Philosophy

The initial implementation should prioritize verification simplicity.

The first RTL milestone does not require a complete production-grade AXI/Avalon interface.

The internal functional interface may use simple synchronous control/data signals.

A more complete host interface can be added after cryptographic correctness has been established.

This prevents interface complexity from blocking cryptographic verification.

### 8.1 Initial RTL Contract

The initial IP is a single-clock, single-transaction, iterative accelerator. Its top-level ports are `clk`, synchronous active-low `rst_n`, command (`start`, `decrypt`, `key[127:0]`, `nonce[127:0]`, `ad_length[31:0]`, `data_length[31:0]`, `received_tag[127:0]`), separate AD/message byte streams, a byte output stream, tag handshake, and status. The authoritative port directions and names are listed in `docs/module_spec.md`. There is no AXI/Avalon/HPS bus, queue, `last` signal, or overlapping command in this IP profile.

A command is accepted on a rising clock edge when `start=1` and `busy=0`; command inputs are latched on that edge. A start while busy is ignored. After acceptance, the caller sends exactly `ad_length` AD bytes, then exactly `data_length` message bytes (plaintext for encryption, ciphertext for decryption). For each stream, a byte transfers only on a rising edge with `valid && ready`; the producer holds `valid` and `data` stable until transfer. The controller does not accept message bytes until AD is complete. A zero length skips that stream phase. There is no `last` marker; declared lengths determine phase boundaries. For packed internal vectors, byte index zero occupies `[7:0]`.

`MAX_DATA_BYTES` is a required positive elaboration parameter with no default. It independently bounds AD length and message length. The DE10-Nano project profile uses 16 bytes for each. A value above capacity is rejected before accepting stream data: `command_error` and `done` pulse for one cycle, `busy` stays low, and authentication status is not asserted. `command_error` is not an authentication `reject`. No resource or timing claim is inferred from the configured capacity.

For encryption, the core's ciphertext is transferred byte-by-byte through `out_valid/out_ready`. After the final ciphertext byte is accepted (or immediately after core completion for an empty message), the tag is presented through `tag_valid/tag_ready` and held stable until transfer. `done` pulses and `busy` deasserts after the tag handshake. For decryption, the complete candidate plaintext remains internal until the calculated tag has been checked. On match, `auth_result_valid` and `accept` assert, `reject` remains low, and plaintext may then transfer through `out_valid/out_ready`; `done` pulses after the final plaintext byte is accepted (immediately after successful verification for an empty message). On mismatch, `auth_result_valid` and `reject` assert, `accept` remains low, no plaintext byte is emitted, and the transaction completes with a one-cycle `done` pulse. Authentication status is defined for decryption only and is held until a new idle `start` or reset; encryption does not assert `auth_result_valid`, `accept`, or `reject`.

`busy` covers an accepted transaction through its output handshakes. `done` is a one-cycle pulse indicating transaction completion as defined above. Synchronous active-low reset aborts the current operation and clears `busy`, stream/tag valid, authentication status, `command_error`, and `done`. No command is queued. Exact signal directions and module boundaries are defined in `docs/module_spec.md`.

The controller buffers declared AD and message before launching the packed-vector core. The permutation processes one round per active clock. Caller software/system is responsible for supplying a nonce that is unique for each encryption under a given key; the IP neither generates nor tracks nonces. The bus wrapper and board-specific transaction pin mapping are later integration work. FPGA-build readiness requires a successful Quartus compile for the DE10-Nano target, with actual resource/timing reports and generated programming output recorded; physical board testing is a separate result.

---

# 9. Verification Requirements

Verification is mandatory.

A module is not considered complete merely because it compiles.

Required verification stages:

1. RTL compilation
2. Unit-level testbench
3. Integration testbench
4. Known Answer Test/reference comparison
5. Valid encryption/decryption test
6. Invalid authentication-tag test
7. Modified ciphertext test
8. Reset behavior test
9. Start/busy/done sequencing test
10. Waveform inspection

---

# 10. Verification Philosophy

Use a trusted software/reference implementation as an independent oracle.

Flow:

Input
→ Python/reference model
→ expected result

Input
→ RTL DUT
→ hardware result

Compare:

RTL result == expected result

If equal:

PASS

If different:

FAIL and debug.

Expected cryptographic outputs must never be fabricated; use trusted reference vectors.

---

# 11. Performance Metrics

The following metrics should be measured only after actual implementation:

### Functional

* encryption correctness
* decryption correctness
* authentication correctness
* tamper rejection rate

### Hardware

* Logic Elements / ALM
* Flip-Flops
* M10K
* DSP Blocks

### Timing

* clock frequency / Fmax
* latency in clock cycles
* estimated processing time

### Performance

* throughput
* resource/performance relationship

No numerical result may be invented before measurement.

---

# 12. FPGA Target

The target evaluation platform is DE10-Nano.

The following is a future system-integration concept, not an implemented RTL path or an FPGA-build prerequisite:

HPS ARM Cortex-A9
→ host/control interface
→ FPGA fabric
→ SECURE-TINY accelerator

The initial development does not depend on physical possession of a DE10-Nano.

RTL simulation can be performed without physical hardware. Quartus compile, device-specific resource/timing reporting, and programming-file generation are required project stages for FPGA-build readiness; they are distinct from RTL simulation.

Physical board testing is an additional validation stage when hardware access is available.

The DE10-Nano is the target for device-specific Quartus compile, resource/timing reporting, and programming-file generation. Physical board testing requires the board and a usable transaction interface. The initial RTL contract does not include HPS integration; HPS/Avalon and physical transaction-pin mapping remain later integration work. Select `MAX_DATA_BYTES` explicitly for each elaboration and record that value with synthesis results.

---

# 13. Novelty Positioning

SECURE-TINY does not claim to invent a new cryptographic algorithm.

The project novelty is positioned at the hardware architecture/system level:

1. integration of authenticated-encryption processing and authentication decision logic;
2. explicit Hardware Authentication Guard;
3. modular reusable IP architecture;
4. resource/performance exploration;
5. hardware offloading of authenticated-encryption processing;
6. measurable security behavior through valid/invalid authentication scenarios.

The project must avoid unsupported claims such as:

* first Ascon hardware implementation;
* first FPGA Ascon implementation;
* new cryptographic algorithm;
* guaranteed lowest area;
* guaranteed highest throughput.

The Hardware Authentication Guard in this scope is a digital gate controlled by the AEAD tag-verification result. It does not detect physical tampering, mitigate side-channel leakage, or securely erase keys. Those properties are not implemented or evaluated by this IP profile and must not be claimed.

---

# 14. Scalability

The architecture should allow future extensions:

* wider data interface;
* streaming interface;
* FIFO buffering;
* AXI/Avalon interface;
* multi-block processing;
* performance-oriented parallelism;
* area-oriented serialized implementation;
* integration with secure communication protocol;
* ASIC implementation through an open-source physical-design flow.

The first implementation should remain intentionally small enough to be verified within the hackathon schedule.

---

# 15. Toolchain

Primary development:

* VS Code
* SystemVerilog
* Icarus Verilog / Verilator
* GTKWave
* Python
* Git

FPGA implementation:

* Intel Quartus Prime
* Platform Designer if required

Optional ASIC flow:

* LibreLane
* open-source PDK supported by the selected flow

---

# 16. Development Strategy

Development must be incremental.

Phase 1:
RTL fundamentals

Phase 2:
Ascon permutation

Phase 3:
Ascon core

Phase 4:
AEAD control

Phase 5:
Tag verification

Phase 6:
Authentication Guard

Phase 7:
Top-level integration

Phase 8:
Verification and corner cases

Phase 9:
FPGA synthesis/resource analysis

Phase 10:
Optional ASIC physical design

Development is incremental; verify each phase before beginning the next.

---

# 17. Definition of Done

A module is DONE only if:

* source code exists;
* code compiles;
* testbench exists;
* simulation runs;
* expected behavior is checked;
* results are recorded;
* no unexplained failure remains.

The project is considered RTL-verified only when:

* top-level RTL compiles;
* integration simulation passes;
* cryptographic results match trusted reference/KAT data;
* valid authentication is accepted;
* invalid authentication is rejected;
* relevant waveforms have been inspected.

The DE10-Nano FPGA build is considered ready only when Quartus compiles the configured Cyclone V project, the Fitter and Timing Analyzer reports are saved, timing meets the 50 MHz project constraint, and the `.sof` programming file is generated. Resource values must be reported from Quartus output; no fabricated utilization threshold or comparative efficiency claim is allowed. Board-level functionality is a distinct status that requires an actual DE10-Nano and a documented physical/host transaction path.

---

# 18. Proposal Alignment

The final proposal must map the project to the official proposal structure:

1. Executive Summary
2. Background & Problem Statement
3. Proposed Chip Design
4. Solution & System Architecture
5. RTL Modules
6. FPGA Resource Estimation
7. Software & Design Tools
8. Testing Plan
9. Success Metrics
10. References
11. Appendix

All proposal claims must distinguish between:

* planned targets,
* simulation results,
* synthesis results,
* hardware results.

Do not present planned values as measured results.
