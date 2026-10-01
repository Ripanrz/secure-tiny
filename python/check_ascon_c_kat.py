"""Cross-check the readable model against the upstream Ascon full-tag KAT file."""

from pathlib import Path

from ascon_aead128_reference import decrypt, encrypt


ROOT = Path(__file__).resolve().parents[1]
KAT_PATH = ROOT / "vectors/ascon_c_v1.3.0_ref/LWC_AEAD_KAT_128_128.txt"

records = []
record = {}
for line in KAT_PATH.read_text().splitlines():
    if "=" in line:
        name, value = line.split("=", 1)
        record[name.strip()] = value.strip()
    elif record:
        records.append(record)
        record = {}
if record:
    records.append(record)

for record in records:
    key = bytes.fromhex(record["Key"])
    nonce = bytes.fromhex(record["Nonce"])
    ad = bytes.fromhex(record["AD"])
    plaintext = bytes.fromhex(record["PT"])
    expected = bytes.fromhex(record["CT"])
    expected_ciphertext = expected[:len(plaintext)]
    expected_tag = expected[len(plaintext):]

    ciphertext, tag = encrypt(key, nonce, ad, plaintext)
    assert ciphertext == expected_ciphertext, f"KAT Count {record['Count']} ciphertext mismatch"
    assert tag == expected_tag, f"KAT Count {record['Count']} tag mismatch"
    recovered = decrypt(key, nonce, ad, ciphertext, tag)
    assert recovered == plaintext, f"KAT Count {record['Count']} decryption mismatch"

print(f"PASS: reference model matched all {len(records)} full-tag Ascon-C KAT cases")
