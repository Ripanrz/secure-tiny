"""Bandingkan model lokal dengan sample ACVP NIST SP 800-232.

Checker hanya menangani panjang AD/payload kelipatan byte; kasus bit-level
dilewati secara eksplisit dan jumlah yang diuji dilaporkan. Ini bukan validasi
atau sertifikasi ACVP.
"""

import json
from pathlib import Path

from ascon_aead128_reference import decrypt, encrypt


ROOT = Path(__file__).resolve().parents[1]
prompt = json.loads((ROOT / "vectors/ascon_aead128_prompt.json").read_text())
expected = json.loads((ROOT / "vectors/ascon_aead128_expected.json").read_text())
expected_groups = {group["tgId"]: group for group in expected["testGroups"]}

# Pasangkan expected result berdasarkan ID test, lalu uji tiap arah operasi.
checked = 0
for group in prompt["testGroups"]:
    expected_tests = {test["tcId"]: test for test in expected_groups[group["tgId"]]["tests"]}
    for test in group["tests"]:
        data_field = "pt" if group["direction"] == "encrypt" else "ct"
        ad_bits = test.get("adLen", len(test["ad"]) * 4)
        data_bits = test.get("payloadLen", len(test[data_field]) * 4)
        # API model ini bekerja dalam byte; jangan klaim bit parsial diuji.
        if (ad_bits % 8) or (data_bits % 8):
            continue

        key = bytes.fromhex(test["key"])
        nonce = bytes.fromhex(test["nonce"])
        ad = bytes.fromhex(test["ad"])
        data = bytes.fromhex(test[data_field])
        ad = ad[:ad_bits // 8]
        data = data[:data_bits // 8]
        second_key = bytes.fromhex(test["secondKey"]) if "secondKey" in test else None
        tag_bits = test.get("tagLen", 128)
        result = expected_tests[test["tcId"]]
        if group["direction"] == "encrypt":
            ciphertext, tag = encrypt(key, nonce, ad, data, second_key)
            assert ciphertext.hex().upper() == result["ct"], f"encrypt tcId={test['tcId']} ciphertext"
            tag_bytes = (tag_bits + 7) // 8
            tag_mask = (1 << (tag_bits % 8)) - 1 if tag_bits % 8 else 0xFF
            assert tag[:tag_bytes - 1].hex().upper() == result["tag"][:(tag_bytes - 1) * 2], (
                f"encrypt tcId={test['tcId']} tag"
            )
            assert tag[tag_bytes - 1] & tag_mask == int(result["tag"][-2:], 16) & tag_mask, (
                f"encrypt tcId={test['tcId']} tag tail"
            )
        elif result.get("testPassed", False):
            plaintext = decrypt(key, nonce, ad, data, bytes.fromhex(test["tag"]), tag_bits, second_key)
            assert plaintext is not None, f"decrypt tcId={test['tcId']} rejected valid tag"
            assert plaintext.hex().upper() == result["pt"], f"decrypt tcId={test['tcId']} plaintext"
        else:
            assert decrypt(key, nonce, ad, data, bytes.fromhex(test["tag"]), tag_bits, second_key) is None, (
                f"decrypt tcId={test['tcId']} accepted invalid tag"
            )
        checked += 1

print(f"PASS: reference model matched {checked} byte-aligned NIST ACVP sample cases")
