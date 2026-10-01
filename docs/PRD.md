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
* tamper/invalid-tag testing
* waveform generation

## 5.2 Extended Scope

If time permits:

* Quartus synthesis
* FPGA resource estimation
* timing analysis
* throughput calculation
* DE10-Nano implementation preparation
* HPS/FPGA interface prototype

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

High-level architecture:

Host / HPS
|
v
Control & Data Interface
|
v
Input Buffer / Registers
|
v
AEAD Controller
|
v
Ascon Cryptographic Core
|
+--------------------+
|                    |
v                    v
Tag Generator       Tag Verifier
|
v
Authentication Guard
/           
/             
ACCEPT            REJECT
|
v
Output Buffer

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

Exact states may be modified by the RTL engineer if functionally justified.

---

## 7.4 tag_generator.sv

Purpose:

Provide the authentication tag output generated by the cryptographic process.

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

The initial RTL is a single-transaction, iterative accelerator with a byte-wide valid/ready input and output stream. It has separate associated-data and message input phases, explicit 32-bit byte lengths, a 128-bit key, a 128-bit nonce, and a 128-bit tag. Message capacity is a required elaboration parameter `MAX_DATA_BYTES`; it has no assumed default. The same configured capacity bounds associated data. Inputs are accepted only for the declared number of bytes. The current controller buffers the declared AD and message before launching the packed-vector core; this implementation profile is bounded to 16 bytes for each in the DE10-Nano project configuration.

The command interface provides `start`, `busy`, and a one-cycle `done` pulse. The command supplies encrypt/decrypt mode, key, nonce, associated-data length, message length, and (for decryption) received tag. A command is accepted only while idle. Synchronous active-low reset aborts the current command and returns the interface to idle. No command queue or overlapping transaction is required.

`MAX_DATA_BYTES` must be positive and its `8*MAX_DATA_BYTES` packed-vector width must be supported by the HDL elaborator and target. The 32-bit command length does not imply that every possible length can be allocated in hardware. The DE10-Nano build profile sets `MAX_DATA_BYTES=16`; other capacities require a separate resource and synthesis evaluation. A command whose AD or message length exceeds the configured value is rejected before data acceptance, raises a one-cycle `command_error` pulse and a one-cycle `done` pulse, and does not assert an authentication decision. `command_error` is separate from authentication `reject`.

Encryption produces ciphertext bytes and then a 128-bit tag. Decryption buffers recovered plaintext internally until the received tag has been fully checked. It asserts output `valid` only after successful authentication. On completion, `auth_result_valid` indicates that the decision is available and exactly one of `accept` or `reject` is asserted. On failure, no plaintext byte is emitted. Consumers must use `valid/ready` as the sole indication that an output byte is usable. This buffer is bounded by `MAX_DATA_BYTES`.

The Ascon permutation is iterative and processes one round per active clock cycle. No throughput, latency, or FPGA resource target is asserted before measurement. This is the initial functional contract; a host bus and board-specific wrapper are deferred.

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

The intended conceptual mapping is:

HPS ARM Cortex-A9
→ host/control interface
→ FPGA fabric
→ SECURE-TINY accelerator

The initial development does not depend on physical possession of a DE10-Nano.

RTL simulation can be performed without physical hardware.

Quartus synthesis can be performed as a separate stage.

Physical board testing is an additional validation stage when hardware access is available.

The DE10-Nano remains the target for later Quartus synthesis and optional board testing. The RTL contract does not require HPS integration. Select `MAX_DATA_BYTES` explicitly for each elaboration and record that value with synthesis results.

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

The entire project is considered RTL-verified only when:

* top-level RTL compiles;
* integration simulation passes;
* cryptographic results match trusted reference/KAT data;
* valid authentication is accepted;
* invalid authentication is rejected;
* relevant waveforms have been inspected.

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
