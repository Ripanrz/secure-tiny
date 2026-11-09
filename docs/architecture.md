# Arsitektur

## System boundary

SECURE-TINY is an Ascon-AEAD128 hardware accelerator with a synchronous byte-oriented transaction interface.

```text
Key / Nonce / AD / Data
          │
          ▼
┌──────────────────────────────┐
│ secure_tiny_top              │
│                              │
│  aead_controller             │
│      │                       │
│      ├── buffers             │
│      ├── Ascon core          │
│      │     └── permutation   │
│      ├── tag generator       │
│      ├── tag verifier        │
│      └── authentication guard│
└──────────────┬───────────────┘
               │
        ACCEPT / REJECT
        + authenticated output
```

## Data path

1. The caller supplies key and nonce and starts a transaction.
2. AD and message/ciphertext bytes are accepted through `valid/ready`.
3. The controller buffers the configured transaction.
4. The Ascon core performs initialization, AD processing, message processing and finalization.
5. Encryption returns ciphertext and tag.
6. Decryption verifies the received tag before asserting authenticated plaintext output.

## Security boundary

The central contract is:

```text
decryption plaintext_valid -> authentication_success
```

An authentication failure produces REJECT and must not produce a valid plaintext transfer.

## Configuration

- Algorithm: Ascon-AEAD128
- Key: 128 bit
- Nonce: 128 bit
- Tag: 128 bit
- Current Quartus baseline: `MAX_DATA_BYTES=16` per AD/message field
- Permutation: iterative, one round per active cycle

`MAX_DATA_BYTES=16` is an implementation capacity, not an Ascon algorithmic limit.

## Hardware baseline

The recorded Quartus baseline is 2,464 ALM, 2,800 registers, 0 M10K, 0 DSP and 79.72 MHz Fmax at a 50 MHz target clock. The transaction ports are virtual, so the result is not board-level I/O timing sign-off.

## Security limitations

The current architecture does not claim side-channel resistance, fault-injection resistance, physical tamper resistance, secure-element behavior, or complete secure zeroization.

## Future architecture work

- Compare guarded and unguarded decryption baselines.
- Quantify guard/buffering area and timing overhead.
- Add a physical transaction interface.
- DE10-Nano fisik validation is pekerjaan lanjutan and is tidak diklaim in the current bukti.
- Add formal checking for the plaintext-release invariant.
