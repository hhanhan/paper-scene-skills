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
    "README.md",
    "LICENSE",
    "LICENSES/UPSTREAM-MIT.txt",
    "THIRD_PARTY_NOTICES.md",
)
BITMAP_SUFFIXES = {
    ".bmp",
    ".gif",
    ".heic",
    ".heif",
    ".jpeg",
    ".jpg",
    ".png",
    ".tif",
    ".tiff",
    ".webp",
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
    markdown_files = [ROOT / "README.md", ROOT / "THIRD_PARTY_NOTICES.md"]
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


def validate_no_bitmap_files(errors: list[str]) -> None:
    for path in sorted(ROOT.rglob("*")):
        if not path.is_file() or ".git" in path.parts:
            continue
        if path.suffix.casefold() in BITMAP_SUFFIXES:
            errors.append(f"{display(path)}: bitmap files are forbidden in this release")


def main() -> int:
    errors: list[str] = []
    validate_required_files(errors)
    validate_license(errors)
    validate_skill_frontmatter(errors)
    validate_agent_metadata(errors)
    validate_markdown_links(errors)
    validate_skill_contents(errors)
    validate_no_bitmap_files(errors)

    if errors:
        print(f"Release validation failed with {len(errors)} error(s):", file=sys.stderr)
        for error in errors:
            print(f"- {error}", file=sys.stderr)
        return 1

    print("Release validation passed: 2 Skills, root notices, links, and contents OK.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
