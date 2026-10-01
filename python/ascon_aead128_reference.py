"""Small, readable Ascon-AEAD128 model derived from NIST SP 800-232.

This is test tooling, not RTL or a production cryptographic implementation.
NIST ACVP vectors remain the expected-result source.
"""

MASK64 = (1 << 64) - 1
ROUND_CONSTANTS = (
    0x3C, 0x2D, 0x1E, 0x0F, 0xF0, 0xE1, 0xD2, 0xC3,
    0xB4, 0xA5, 0x96, 0x87, 0x78, 0x69, 0x5A, 0x4B,
)
IV = 0x00001000808C0001


def _ror(value: int, amount: int) -> int:
    return ((value >> amount) | (value << (64 - amount))) & MASK64


def permute(state: list[int], rounds: int) -> list[int]:
    if not 1 <= rounds <= 16:
        raise ValueError("rounds must be from 1 through 16")
    s0, s1, s2, s3, s4 = state
    for constant in ROUND_CONSTANTS[16 - rounds:]:
        s2 ^= constant

        x0, x1, x2, x3, x4 = s0, s1, s2, s3, s4
        y0 = (x4 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ (x1 & x0) ^ x1 ^ x0
        y1 = x4 ^ (x3 & x2) ^ (x3 & x1) ^ x3 ^ (x2 & x1) ^ x2 ^ x1 ^ x0
        y2 = (x4 & x3) ^ x4 ^ x2 ^ x1 ^ MASK64
        y3 = (x4 & x0) ^ x4 ^ (x3 & x0) ^ x3 ^ x2 ^ x1 ^ x0
        y4 = (x4 & x1) ^ x4 ^ x3 ^ (x1 & x0) ^ x1

        s0 = (y0 ^ _ror(y0, 19) ^ _ror(y0, 28)) & MASK64
        s1 = (y1 ^ _ror(y1, 61) ^ _ror(y1, 39)) & MASK64
        s2 = (y2 ^ _ror(y2, 1) ^ _ror(y2, 6)) & MASK64
        s3 = (y3 ^ _ror(y3, 10) ^ _ror(y3, 17)) & MASK64
        s4 = (y4 ^ _ror(y4, 7) ^ _ror(y4, 41)) & MASK64
    return [s0, s1, s2, s3, s4]


def _word(block: bytes) -> int:
    return int.from_bytes(block, "little")


def _padded_word(block: bytes) -> int:
    return _word(block) ^ (1 << (8 * len(block)))


def _absorb_ad(state: list[int], ad: bytes) -> None:
    if ad:
        full_blocks, tail_size = divmod(len(ad), 16)
        for index in range(full_blocks):
            block = ad[index * 16:(index + 1) * 16]
            state[0] ^= _word(block[:8])
            state[1] ^= _word(block[8:])
            state[:] = permute(state, 8)

        tail = ad[full_blocks * 16:]
        if len(tail) < 8:
            state[0] ^= _padded_word(tail)
        else:
            state[0] ^= _word(tail[:8])
            if len(tail) == 8:
                state[1] ^= _padded_word(b"")
            else:
                state[1] ^= _padded_word(tail[8:])
        state[:] = permute(state, 8)

    # Domain-separation bit is state bit 319.
    state[4] ^= 1 << 63


def encrypt(
    key: bytes,
    nonce: bytes,
    ad: bytes,
    plaintext: bytes,
    second_key: bytes | None = None,
) -> tuple[bytes, bytes]:
    if len(key) != 16 or len(nonce) != 16:
        raise ValueError("key and nonce must each contain 16 bytes")

    if second_key is not None:
        if len(second_key) != 16:
            raise ValueError("second key must contain 16 bytes")
        nonce = bytes(a ^ b for a, b in zip(nonce, second_key))

    k0, k1 = _word(key[:8]), _word(key[8:])
    n0, n1 = _word(nonce[:8]), _word(nonce[8:])
    state = permute([IV, k0, k1, n0, n1], 12)
    state[3] ^= k0
    state[4] ^= k1
    _absorb_ad(state, ad)

    full_blocks, tail_size = divmod(len(plaintext), 16)
    ciphertext = bytearray()
    for index in range(full_blocks):
        block = plaintext[index * 16:(index + 1) * 16]
        state[0] ^= _word(block[:8])
        state[1] ^= _word(block[8:])
        ciphertext.extend(state[0].to_bytes(8, "little"))
        ciphertext.extend(state[1].to_bytes(8, "little"))
        state[:] = permute(state, 8)

    tail = plaintext[full_blocks * 16:]
    if tail_size < 8:
        state[0] ^= _padded_word(tail)
    else:
        state[0] ^= _word(tail[:8])
        if tail_size == 8:
            state[1] ^= _padded_word(b"")
        else:
            state[1] ^= _padded_word(tail[8:])
    partial_state = state[0].to_bytes(8, "little") + state[1].to_bytes(8, "little")
    ciphertext.extend(partial_state[:tail_size])

    state[2] ^= k0
    state[3] ^= k1
    state[:] = permute(state, 12)
    tag = (state[3] ^ k0).to_bytes(8, "little") + (state[4] ^ k1).to_bytes(8, "little")
    return bytes(ciphertext), tag


def decrypt(
    key: bytes,
    nonce: bytes,
    ad: bytes,
    ciphertext: bytes,
    tag: bytes,
    tag_bits: int = 128,
    second_key: bytes | None = None,
) -> bytes | None:
    if len(key) != 16 or len(nonce) != 16:
        raise ValueError("key and nonce must each contain 16 bytes")
    if not 1 <= tag_bits <= 128:
        raise ValueError("tag length must be from 1 through 128 bits")
    if len(tag) != (tag_bits + 7) // 8:
        raise ValueError("tag byte length does not match tag_bits")
    if second_key is not None:
        if len(second_key) != 16:
            raise ValueError("second key must contain 16 bytes")
        nonce = bytes(a ^ b for a, b in zip(nonce, second_key))

    k0, k1 = _word(key[:8]), _word(key[8:])
    n0, n1 = _word(nonce[:8]), _word(nonce[8:])
    state = permute([IV, k0, k1, n0, n1], 12)
    state[3] ^= k0
    state[4] ^= k1
    _absorb_ad(state, ad)

    full_blocks, tail_size = divmod(len(ciphertext), 16)
    plaintext = bytearray()
    for index in range(full_blocks):
        block = ciphertext[index * 16:(index + 1) * 16]
        c0, c1 = _word(block[:8]), _word(block[8:])
        plaintext.extend((state[0] ^ c0).to_bytes(8, "little"))
        plaintext.extend((state[1] ^ c1).to_bytes(8, "little"))
        state[0], state[1] = c0, c1
        state[:] = permute(state, 8)

    tail = ciphertext[full_blocks * 16:]
    c0 = _word(tail[:8])
    p0 = state[0] ^ c0
    plaintext.extend(p0.to_bytes(8, "little")[:min(tail_size, 8)])
    if tail_size < 8:
        state[0] = (state[0] & ~((1 << (8 * tail_size)) - 1)) | c0
        state[0] ^= 1 << (8 * tail_size)
    elif tail_size == 8:
        state[0] = c0
        state[1] ^= 1
    else:
        c1 = _word(tail[8:])
        p1 = state[1] ^ c1
        plaintext.extend(p1.to_bytes(8, "little")[:tail_size - 8])
        state[0] = c0
        state[1] = (state[1] & ~((1 << (8 * (tail_size - 8))) - 1)) | c1
        state[1] ^= 1 << (8 * (tail_size - 8))

    state[2] ^= k0
    state[3] ^= k1
    state[:] = permute(state, 12)
    calculated_tag = (state[3] ^ k0).to_bytes(8, "little") + (state[4] ^ k1).to_bytes(8, "little")
    tag_bytes = (tag_bits + 7) // 8
    mask = (1 << (tag_bits % 8)) - 1 if tag_bits % 8 else 0xFF
    if calculated_tag[:tag_bytes - 1] != tag[:tag_bytes - 1]:
        return None
    if calculated_tag[tag_bytes - 1] & mask != tag[tag_bytes - 1] & mask:
        return None
    return bytes(plaintext)
