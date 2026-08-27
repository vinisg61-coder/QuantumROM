"""Apply the verified SM-A528B F64EL camera validation workaround.

The native A52s CamX override deliberately calls raise(6) after logging
Unsupported HW Ver: F64EL / Bad CRC32 Data against the F64ES normal profile.
The patch replaces only that call with an AArch64 NOP, leaving all calibration,
EEPROM data, camera.qcom.so, kernel, donor files, and other vendor blobs intact.

This helper is intentionally strict and target-specific. It refuses to patch a
blob with a different SHA-256 or different instruction context.
"""

from __future__ import annotations

import hashlib
import sys
from pathlib import Path


DEVICE_NAMES = {"SM-A528B", "a52sxq"}
CAMERA_RELATIVE_PATH = Path("vendor/lib64/hw/com.qti.chi.override.so")
ORIGINAL_SHA256 = "08845f6a6defb8d29f8eb3ad33a11e680d85bc99403d5525db0a58c9a0cbafd0"
PATCH_OFFSET = 0x28B6CC
EXPECTED_BYTES = bytes.fromhex("a9a10a94")  # BL to PLT/GOT raise
REPLACEMENT_BYTES = bytes.fromhex("1f2003d5")  # AArch64 NOP
CONTEXT_BEFORE = bytes.fromhex("c0008052")  # mov w0, #6
CONTEXT_AFTER = bytes.fromhex("f52340f9")   # ldr x21, [sp, #0x40]


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def main() -> int:
    if len(sys.argv) != 3:
        print(f"Usage: {sys.argv[0]} <EXTRACTED_FIRMWARE_DIR> <STOCK_DEVICE>", file=sys.stderr)
        return 2

    root = Path(sys.argv[1]).resolve()
    device = sys.argv[2]
    if device not in DEVICE_NAMES:
        print(f"[A52SXQ-CAMERA-BINARY] skipped for {device}")
        return 0
    if not root.is_dir():
        print(f"[A52SXQ-CAMERA-BINARY] extracted firmware directory not found: {root}", file=sys.stderr)
        return 1

    path = root / CAMERA_RELATIVE_PATH
    if not path.is_file():
        print(f"[A52SXQ-CAMERA-BINARY] required native blob not found: {path}", file=sys.stderr)
        return 1

    data = bytearray(path.read_bytes())
    actual_sha = sha256(data)
    patched_sha = "c51dbeb3eb68db1757934645f9ea074fc1148320eb397fa93e012e840b53afff"
    if actual_sha == patched_sha:
        print(f"[A52SXQ-CAMERA-BINARY] already patched: {path}")
        return 0
    if actual_sha != ORIGINAL_SHA256:
        print(
            "[A52SXQ-CAMERA-BINARY] refusing unexpected blob: "
            f"{path} sha256={actual_sha} expected={ORIGINAL_SHA256}",
            file=sys.stderr,
        )
        return 1

    if PATCH_OFFSET < 4 or PATCH_OFFSET + 8 > len(data):
        print("[A52SXQ-CAMERA-BINARY] patch offset outside blob", file=sys.stderr)
        return 1
    if data[PATCH_OFFSET - 4:PATCH_OFFSET] != CONTEXT_BEFORE:
        print(
            "[A52SXQ-CAMERA-BINARY] instruction context before patch does not match: "
            f"{data[PATCH_OFFSET - 4:PATCH_OFFSET].hex()}",
            file=sys.stderr,
        )
        return 1
    if data[PATCH_OFFSET:PATCH_OFFSET + 4] != EXPECTED_BYTES:
        print(
            "[A52SXQ-CAMERA-BINARY] instruction at patch offset does not match: "
            f"{data[PATCH_OFFSET:PATCH_OFFSET + 4].hex()}",
            file=sys.stderr,
        )
        return 1
    if data[PATCH_OFFSET + 4:PATCH_OFFSET + 8] != CONTEXT_AFTER:
        print("[A52SXQ-CAMERA-BINARY] instruction context after patch does not match", file=sys.stderr)
        return 1

    data[PATCH_OFFSET:PATCH_OFFSET + 4] = REPLACEMENT_BYTES
    path.write_bytes(data)
    patched_sha = sha256(data)
    print(
        f"[A52SXQ-CAMERA-BINARY] patched {path}: offset=0x{PATCH_OFFSET:x}, "
        f"bytes={EXPECTED_BYTES.hex()}->{REPLACEMENT_BYTES.hex()}, "
        f"sha256={patched_sha}"
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
