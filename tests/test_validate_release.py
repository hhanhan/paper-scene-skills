#!/usr/bin/env python3
"""Regression tests for release image, binary, and secret gates."""

from __future__ import annotations

import subprocess
import sys
import uuid
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
VALIDATOR = ROOT / "scripts" / "validate_release.py"


def run_validator() -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        [sys.executable, "-X", "utf8", str(VALIDATOR)],
        cwd=ROOT,
        capture_output=True,
        encoding="utf-8",
        check=False,
    )


def assert_rejected(payload: bytes, suffix: str, expected: str) -> None:
    path = ROOT / f"release-validation-probe-{uuid.uuid4().hex}{suffix}"
    try:
        path.write_bytes(payload)
        result = run_validator()
        output = result.stdout + result.stderr
        if result.returncode == 0 or expected not in output:
            raise AssertionError(
                f"validator did not reject {path.name!r} for {expected!r}: {output}"
            )
    finally:
        path.unlink(missing_ok=True)


def main() -> int:
    baseline = run_validator()
    if baseline.returncode != 0:
        raise AssertionError(baseline.stdout + baseline.stderr)

    source_png = (
        ROOT / "examples" / "country-house-sunset" / "input.png"
    ).read_bytes()
    for suffix in (".bin", "", ".png.txt"):
        assert_rejected(source_png, suffix, "image file is not in the release allowlist")

    for suffix in (".ppm", "", ".md"):
        assert_rejected(
            b"P6\n1 1\n255\nABC",
            suffix,
            "image file is not in the release allowlist",
        )
    assert_rejected(
        bytes((0xFF, 0xFE, 0xFD, 0xFC)),
        ".txt",
        "binary files are forbidden unless explicitly allowlisted",
    )
    assert_rejected(
        b"github" + b"_pat_" + (b"A" * 30),
        ".txt",
        "possible GitHub token detected",
    )

    print("validate_release.py regression tests passed.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
