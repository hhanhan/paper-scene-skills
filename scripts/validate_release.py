#!/usr/bin/env python3
"""Validate the public release without third-party Python dependencies."""

from __future__ import annotations

import hashlib
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit


ROOT = Path(__file__).resolve().parents[1]
SKILLS = {
    "paper-scene-collage": ROOT / "paper-scene-collage",
    "paper-scene-recompose": ROOT / "paper-scene-recompose",
}
REQUIRED_ROOT_FILES = (
    "EXAMPLES_NOTICE.md",
    "README.md",
    "LICENSE",
    "LICENSES/UPSTREAM-MIT.txt",
    "THIRD_PARTY_NOTICES.md",
)
IMAGE_SUFFIXES = {
    ".ai",
    ".apng",
    ".avif",
    ".bmp",
    ".cr2",
    ".dng",
    ".eps",
    ".gif",
    ".heic",
    ".heif",
    ".ico",
    ".j2k",
    ".jp2",
    ".jxl",
    ".kra",
    ".nef",
    ".orf",
    ".jpeg",
    ".jpg",
    ".png",
    ".psd",
    ".raf",
    ".raw",
    ".rw2",
    ".svg",
    ".tif",
    ".tiff",
    ".webp",
    ".xcf",
}
EXPECTED_EXAMPLE_IMAGES = {
    "examples/country-house-sunset/input.png": {
        "sha256": "2027ecea4275be2eb7032d4e3a4e8feb858da14ec88cef00670bf4ea5c24afc4",
        "size": 786_068,
        "width": 850,
        "height": 478,
    },
    "examples/country-house-sunset/retained-photo-collage.png": {
        "sha256": "8f3afba5d36660a12643d9912e744392b462cb67412bfd1088c58cc713e61807",
        "size": 2_515_993,
        "width": 1536,
        "height": 1024,
    },
    "examples/country-house-sunset/source-free-recompose.png": {
        "sha256": "11208e938b329e283f98b216ef6421b746a9fe9b4f0f7c9fcc5f2b94bd7772b7",
        "size": 2_844_501,
        "width": 1672,
        "height": 941,
    },
}
BANNED_UPSTREAM_MARKERS = (
    "gathered scenes",
    "gathered-scenes",
    "scenes-gathered-zine",
    "scene-distillation-zine",
    "zeejay0",
    "拾景",
)
EXPECTED_LICENSE_SHA256 = (
    "2fed409745b33e60c3b68f15b12fde872c05496c4f224c0e39adc8979fe0ac3b"
)
EXPECTED_UPSTREAM_MIT_SHA256 = (
    "7d063a2fe4a45ac0adf349ab8d568de5bc93206aaa3982a243dd8d067a3e2f4a"
)
MARKDOWN_LINK_RE = re.compile(r"!?\[[^\]\n]*\]\(([^)\n]+)\)")
FRONTMATTER_FIELD_RE = re.compile(r"^([A-Za-z][A-Za-z0-9_-]*):\s*(.*)$")
PRIVATE_PATH_PATTERN = (
    rb"(?:[A-Za-z]:\\(?:Users|Pictures|Rtmp|\xe5\xba\x9f\xe5\x9c\x9f)\\|"
    + b"/Us"
    + b"ers/|/ho"
    + rb"me/[^/<\s]+/)"
)
SENSITIVE_TEXT_PATTERNS = {
    "GitHub token": re.compile(
        rb"(?:github_pat_[A-Za-z0-9_]{20,}|gh[pousr]_[A-Za-z0-9_]{20,})"
    ),
    "OpenAI-style secret": re.compile(rb"sk-[A-Za-z0-9_-]{20,}"),
    "AWS access key": re.compile(rb"AKIA[0-9A-Z]{16}"),
    "private key": re.compile(rb"-----BEGIN (?:RSA |EC |OPENSSH )?PRIVATE KEY-----"),
    "private absolute path": re.compile(PRIVATE_PATH_PATTERN),
}
ALLOWED_BINARY_FILES = set(EXPECTED_EXAMPLE_IMAGES)
ALLOWED_TEXT_SUFFIXES = {".md", ".ps1", ".py", ".txt", ".yaml", ".yml"}
ALLOWED_TEXT_FILENAMES = {".gitattributes", ".gitignore", "LICENSE"}


def display(path: Path) -> str:
    return path.relative_to(ROOT).as_posix()


def read_utf8(path: Path, errors: list[str]) -> str | None:
    try:
        return path.read_text(encoding="utf-8-sig")
    except (OSError, UnicodeError) as exc:
        errors.append(f"{display(path)}: cannot read as UTF-8 ({exc})")
        return None


def validate_required_files(errors: list[str]) -> None:
    for name in REQUIRED_ROOT_FILES:
        path = ROOT / name
        if not path.is_file():
            errors.append(f"{name}: required root file is missing")
        elif path.stat().st_size == 0:
            errors.append(f"{name}: required root file is empty")


def validate_license(errors: list[str]) -> None:
    expected_files = {
        ROOT / "LICENSE": (
            EXPECTED_LICENSE_SHA256,
            "the unchanged current upstream v1.0 license",
        ),
        ROOT / "LICENSES" / "UPSTREAM-MIT.txt": (
            EXPECTED_UPSTREAM_MIT_SHA256,
            "the unchanged historical upstream MIT notice",
        ),
    }
    for path, (expected_digest, description) in expected_files.items():
        if not path.is_file():
            continue
        try:
            text = path.read_bytes().decode("utf-8")
        except (OSError, UnicodeError) as exc:
            errors.append(f"{display(path)}: cannot read exact UTF-8 text ({exc})")
            continue

        normalized = text.replace("\r\n", "\n")
        if "\r" in normalized:
            errors.append(
                f"{display(path)}: contains unsupported carriage-return line endings"
            )
            continue
        digest = hashlib.sha256(normalized.encode("utf-8")).hexdigest()
        if digest != expected_digest:
            errors.append(f"{display(path)}: text differs from {description}")


def parse_frontmatter(path: Path, text: str, errors: list[str]) -> dict[str, str]:
    lines = text.splitlines()
    if not lines or lines[0].strip() != "---":
        errors.append(f"{display(path)}: missing opening frontmatter delimiter")
        return {}

    try:
        end = next(i for i in range(1, len(lines)) if lines[i].strip() == "---")
    except StopIteration:
        errors.append(f"{display(path)}: missing closing frontmatter delimiter")
        return {}

    fields: dict[str, str] = {}
    for line_number, line in enumerate(lines[1:end], start=2):
        if not line.strip() or line.lstrip().startswith("#"):
            continue
        match = FRONTMATTER_FIELD_RE.match(line)
        if not match:
            errors.append(
                f"{display(path)}:{line_number}: unsupported frontmatter syntax"
            )
            continue
        key, value = match.groups()
        if key in fields:
            errors.append(f"{display(path)}:{line_number}: duplicate '{key}' field")
            continue
        value = value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        fields[key] = value
    return fields


def validate_skill_frontmatter(errors: list[str]) -> None:
    for expected_name, skill_dir in SKILLS.items():
        path = skill_dir / "SKILL.md"
        if not path.is_file():
            errors.append(f"{display(path)}: required Skill manifest is missing")
            continue
        text = read_utf8(path, errors)
        if text is None:
            continue
        fields = parse_frontmatter(path, text, errors)
        extra_fields = sorted(set(fields) - {"name", "description"})
        if extra_fields:
            errors.append(
                f"{display(path)}: unsupported frontmatter fields: "
                + ", ".join(extra_fields)
            )
        if fields.get("name") != expected_name:
            errors.append(
                f"{display(path)}: frontmatter name must be '{expected_name}'"
            )
        if not fields.get("description", "").strip():
            errors.append(f"{display(path)}: frontmatter description is required")


def validate_agent_metadata(errors: list[str]) -> None:
    required_fields = ("display_name", "short_description", "default_prompt")
    for expected_name, skill_dir in SKILLS.items():
        path = skill_dir / "agents" / "openai.yaml"
        if not path.is_file():
            errors.append(f"{display(path)}: required agent metadata is missing")
            continue
        text = read_utf8(path, errors)
        if text is None:
            continue
        if not re.search(r"(?m)^interface:\s*$", text):
            errors.append(f"{display(path)}: missing top-level 'interface' mapping")
        for field in required_fields:
            if not re.search(rf"(?m)^\s{{2}}{field}:\s*\S", text):
                errors.append(f"{display(path)}: missing interface.{field}")
        if f"${expected_name}" not in text:
            errors.append(
                f"{display(path)}: default_prompt must name '${expected_name}'"
            )


def without_fenced_code(text: str) -> str:
    output: list[str] = []
    fence_char = ""
    fence_length = 0
    for line in text.splitlines():
        stripped = line.lstrip()
        fence = re.match(r"(`{3,}|~{3,})", stripped)
        if fence and not fence_char:
            fence_char = fence.group(1)[0]
            fence_length = len(fence.group(1))
            continue
        if fence_char and re.match(
            rf"{re.escape(fence_char)}{{{fence_length},}}(?:\s.*)?$", stripped
        ):
            fence_char = ""
            fence_length = 0
            continue
        if not fence_char:
            output.append(line)
    return "\n".join(output)


def link_destination(raw: str) -> str:
    raw = raw.strip()
    if raw.startswith("<") and ">" in raw:
        return raw[1 : raw.index(">")]
    return raw.split(maxsplit=1)[0]


def validate_markdown_links(errors: list[str]) -> None:
    markdown_files = [
        ROOT / "README.md",
        ROOT / "THIRD_PARTY_NOTICES.md",
        ROOT / "EXAMPLES_NOTICE.md",
    ]
    for skill_dir in SKILLS.values():
        markdown_files.extend(sorted(skill_dir.rglob("*.md")))

    for path in markdown_files:
        if not path.is_file():
            continue
        text = read_utf8(path, errors)
        if text is None:
            continue
        prose = re.sub(r"`[^`\n]*`", "", without_fenced_code(text))
        for match in MARKDOWN_LINK_RE.finditer(prose):
            destination = link_destination(match.group(1))
            if not destination or destination.startswith(("#", "/", "//")):
                continue
            parsed = urlsplit(destination)
            if parsed.scheme or parsed.netloc or not parsed.path:
                continue

            relative_path = Path(unquote(parsed.path.replace("\\", "/")))
            target = (path.parent / relative_path).resolve()
            try:
                target.relative_to(ROOT)
            except ValueError:
                errors.append(
                    f"{display(path)}: relative link escapes repository: {destination}"
                )
                continue
            if not target.exists():
                errors.append(
                    f"{display(path)}: relative link target does not exist: {destination}"
                )


def validate_skill_contents(errors: list[str]) -> None:
    for skill_dir in SKILLS.values():
        if not skill_dir.is_dir():
            errors.append(f"{display(skill_dir)}: required Skill directory is missing")
            continue
        for path in sorted(skill_dir.rglob("*")):
            if not path.is_file():
                continue
            text = read_utf8(path, errors)
            if text is None:
                continue
            folded = text.casefold()
            for marker in BANNED_UPSTREAM_MARKERS:
                index = folded.find(marker.casefold())
                if index < 0:
                    continue
                line_number = folded.count("\n", 0, index) + 1
                errors.append(
                    f"{display(path)}:{line_number}: forbidden upstream marker '{marker}'"
                )


def validate_no_symlinks(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*")):
        if ".git" not in path.parts and path.is_symlink():
            errors.append(f"{display(path)}: symlinks are forbidden in this release")


def has_image_signature(path: Path, errors: list[str]) -> bool:
    try:
        with path.open("rb") as stream:
            header = stream.read(8192)
    except OSError as exc:
        errors.append(f"{display(path)}: cannot inspect file signature ({exc})")
        return False

    prefixes = (
        b"\x89PNG\r\n\x1a\n",
        b"\xff\xd8\xff",
        b"GIF87a",
        b"GIF89a",
        b"BM",
        b"II*\x00",
        b"MM\x00*",
        b"\x00\x00\x01\x00",
        b"8BPS",
        b"\xff\x0a",
        b"\x00\x00\x00\x0cJXL \r\n\x87\n",
        b"\x00\x00\x00\x0cjP  \r\n\x87\n",
        b"gimp xcf ",
        b"%!PS-Adobe",
    )
    if header.startswith(prefixes):
        return True
    if len(header) >= 12 and header[:4] == b"RIFF" and header[8:12] == b"WEBP":
        return True
    if len(header) >= 12 and header[4:8] == b"ftyp":
        brands = header[8:32]
        if any(brand in brands for brand in (b"avif", b"avis", b"heic", b"heif", b"mif1", b"msf1")):
            return True
    if re.match(rb"P[1-7][\x09\x0a\x0b\x0c\x0d\x20]", header):
        return True
    markup = header.lstrip(b"\xef\xbb\xbf\x00\x09\x0a\x0d\x20").lower()
    return re.search(rb"<svg(?:\s|>)", markup) is not None


def validate_sensitive_text(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*")):
        if ".git" in path.parts or not path.is_file() or path.is_symlink():
            continue
        try:
            payload = path.read_bytes()
        except OSError as exc:
            errors.append(f"{display(path)}: cannot inspect for sensitive text ({exc})")
            continue
        if b"\x00" in payload[:8192]:
            continue
        for label, pattern in SENSITIVE_TEXT_PATTERNS.items():
            if pattern.search(payload):
                errors.append(f"{display(path)}: possible {label} detected")


def validate_no_unknown_binary_files(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*")):
        if ".git" in path.parts or not path.is_file() or path.is_symlink():
            continue
        relative_path = display(path)
        if relative_path in ALLOWED_BINARY_FILES:
            continue
        if path.name not in ALLOWED_TEXT_FILENAMES and path.suffix.casefold() not in ALLOWED_TEXT_SUFFIXES:
            errors.append(
                f"{relative_path}: release files must use an allowlisted text type or exact binary path"
            )
            continue
        try:
            payload = path.read_bytes()
        except OSError as exc:
            errors.append(f"{relative_path}: cannot inspect binary status ({exc})")
            continue
        try:
            payload.decode("utf-8")
        except UnicodeDecodeError:
            errors.append(
                f"{relative_path}: binary files are forbidden unless explicitly allowlisted"
            )
            continue
        if b"\x00" in payload:
            errors.append(
                f"{relative_path}: NUL bytes are forbidden outside allowlisted binaries"
            )
            continue
        disallowed_controls = [
            byte for byte in payload if byte < 0x20 and byte not in (0x09, 0x0A, 0x0D)
        ]
        if disallowed_controls:
            errors.append(
                f"{relative_path}: disallowed control bytes detected in text file"
            )


def validate_example_images(errors: list[str]) -> None:
    discovered: set[str] = set()
    for path in sorted(ROOT.rglob("*")):
        if ".git" in path.parts or not path.is_file() or path.is_symlink():
            continue
        if path.suffix.casefold() in IMAGE_SUFFIXES or has_image_signature(path, errors):
            discovered.add(display(path))

    expected = set(EXPECTED_EXAMPLE_IMAGES)
    for unexpected in sorted(discovered - expected):
        errors.append(f"{unexpected}: image file is not in the release allowlist")
    for missing in sorted(expected - discovered):
        errors.append(f"{missing}: required pinned example image is missing")

    png_signature = b"\x89PNG\r\n\x1a\n"
    for relative_path, manifest in EXPECTED_EXAMPLE_IMAGES.items():
        path = ROOT / relative_path
        if path.is_symlink():
            errors.append(f"{relative_path}: pinned example image must not be a symlink")
            continue
        if not path.is_file():
            continue
        try:
            actual_size = path.stat().st_size
            if actual_size != manifest["size"]:
                errors.append(
                    f"{relative_path}: expected {manifest['size']} bytes, got {actual_size}"
                )
                continue
            payload = path.read_bytes()
        except OSError as exc:
            errors.append(f"{relative_path}: cannot read pinned example image ({exc})")
            continue

        if len(payload) < 24 or payload[:8] != png_signature or payload[12:16] != b"IHDR":
            errors.append(f"{relative_path}: pinned example is not a valid PNG header")
            continue
        width = int.from_bytes(payload[16:20], "big")
        height = int.from_bytes(payload[20:24], "big")
        if (width, height) != (manifest["width"], manifest["height"]):
            errors.append(
                f"{relative_path}: expected {manifest['width']}x{manifest['height']}, "
                f"got {width}x{height}"
            )
        digest = hashlib.sha256(payload).hexdigest()
        if digest != manifest["sha256"]:
            errors.append(f"{relative_path}: pinned example SHA-256 differs from manifest")


def main() -> int:
    errors: list[str] = []
    validate_required_files(errors)
    validate_license(errors)
    validate_skill_frontmatter(errors)
    validate_agent_metadata(errors)
    validate_markdown_links(errors)
    validate_skill_contents(errors)
    validate_no_symlinks(errors)
    validate_sensitive_text(errors)
    validate_no_unknown_binary_files(errors)
    validate_example_images(errors)

    if errors:
        print(f"Release validation failed with {len(errors)} error(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print(
        "Release validation passed: 2 Skills, root notices, links, contents, "
        "and 3 pinned example images OK."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
