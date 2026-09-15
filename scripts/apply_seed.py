#!/usr/bin/env python3
"""Apply a visual/industry seed to the workshop Starter project."""

from __future__ import annotations

import argparse
import json
import random
import re
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEMES_PATH = ROOT / "scripts" / "themes.json"


def load_themes() -> list[dict]:
    return json.loads(THEMES_PATH.read_text())["themes"]


def current_theme_id(starter: Path) -> str | None:
    """Theme id for this pair, from the last-seed file or SEED.md."""
    last_file = starter / ".session-last-theme"
    if last_file.exists():
        last = last_file.read_text().strip()
        if last:
            return last
    seed = starter / "SEED.md"
    if not seed.exists():
        return None
    match = re.match(r"# This session's look — (.+)", seed.read_text())
    if not match:
        return None
    name = match.group(1).strip()
    for theme in load_themes():
        if theme["name"] == name:
            return theme["id"]
    return None


def pick_theme(starter: Path, requested: str | None) -> dict:
    themes = load_themes()
    by_id = {t["id"]: t for t in themes}
    if requested:
        if requested not in by_id:
            raise SystemExit(f"Unknown theme {requested!r}. Choose from: {', '.join(by_id)}")
        return by_id[requested]

    last_file = starter / ".session-last-theme"
    last = last_file.read_text().strip() if last_file.exists() else ""
    choices = [t for t in themes if t["id"] != last] or themes
    return random.choice(choices)


def swift_color(rgb: list[float]) -> str:
    r, g, b = rgb
    return f"Color(red: {r:.2f}, green: {g:.2f}, blue: {b:.2f})"


def swift_string_literal(value: str) -> str:
    """A Swift `"..."` literal, with quotes and backslashes escaped."""
    return '"' + value.replace("\\", "\\\\").replace('"', '\\"') + '"'


def swift_multiline_contents(text: str, indent: str) -> str:
    """Inner lines of a Swift `\"\"\"` string, indented to match the closer.

    Swift requires every line between the opening and closing `\"\"\"` to be
    indented at least as far as the closing delimiter. That shared indent is
    then stripped from the string value.
    """
    escaped = text.replace("\\", "\\\\").replace('"""', r"\"\"\"")
    lines = escaped.rstrip("\n").split("\n")
    return "\n".join(indent + line for line in lines) + "\n"


def multiline_indent_errors(source: str) -> list[str]:
    """Return human-readable errors for Swift multiline strings in `source`."""
    errors: list[str] = []
    for match in re.finditer(r'"""\n(.*?)(^[ \t]*)"""', source, flags=re.S | re.M):
        body, close_indent = match.group(1), match.group(2)
        lines = body.split("\n")
        if lines and lines[-1] == "":
            lines = lines[:-1]
        for line in lines:
            prefix_len = len(line) - len(line.lstrip(" \t"))
            if prefix_len < len(close_indent):
                preview = line if line else "(empty)"
                errors.append(
                    f"line insufficiently indented vs closing {len(close_indent)}-space "
                    f"delimiter: {preview!r}"
                )
    return errors


def write_seed_md(starter: Path, theme: dict) -> None:
    body = f"""# This session's look — {theme["name"]}

The three panes and the three jobs stay the same: notes, structured key points,
follow-up email, then live recording. The personality below is what makes this
pair's screenshot different from the next pair's.

- **Title:** {theme["title"]}
- **Industry:** {theme["industry"]}
- **Accent:** SwiftUI `{swift_color(theme["accent"])}`
- **Empty-state symbol:** `{theme["symbol"]}`
- **How it should feel:** {theme["look"]}

Use the sample notes already in `ContentView.swift`. Do not replace them with
the healthcare laptop story unless this seed *is* healthcare.

When they ask to make it theirs, keep every control working (Use sample, Record
call, Build initiative, Copy, Open in Mail) and push the look further. Do not
flatten it back to default grey.

## Line to speak into Record call

{theme["say"]}
"""
    (starter / "SEED.md").write_text(body)


def patch_content_view(path: Path, theme: dict) -> None:
    text = path.read_text()

    def replace_sample(match: re.Match[str]) -> str:
        indent = match.group("indent")
        inner = swift_multiline_contents(theme["sample"], indent)
        return f'{indent}private static let sample = """\n{inner}{indent}"""'

    text, n = re.subn(
        r'(?P<indent>[ \t]*)private static let sample = """\n.*?"""',
        replace_sample,
        text,
        count=1,
        flags=re.S,
    )
    if n != 1:
        raise SystemExit(f"Could not find sample string in {path}")

    text = re.sub(
        r'Text\("e\.g\. [^"]+"\)',
        f'Text({swift_string_literal(theme["placeholder"])})',
        text,
        count=1,
    )
    text = re.sub(
        r'\.navigationTitle\("[^"]+"\)',
        f'.navigationTitle({swift_string_literal(theme["title"])})',
        text,
        count=1,
    )
    text, n_sub = re.subn(
        r'(PaneHeader\(\s*title: "Conversation notes",\s*subtitle: )"[^"]+"',
        rf"\1{swift_string_literal(theme['subtitle'])}",
        text,
        count=1,
        flags=re.S,
    )
    if n_sub != 1:
        text, n_sub = re.subn(
            r'subtitle: "Paste or record rough notes from a channel sales conversation\."',
            f'subtitle: {swift_string_literal(theme["subtitle"])}',
            text,
            count=1,
        )
    if n_sub != 1:
        raise SystemExit(f"Could not find conversation-notes subtitle in {path}")

    text, n_sym = re.subn(
        r'(ContentUnavailableView\(\s*"No initiative yet",\s*systemImage: ")[^"]+"',
        rf'\1{theme["symbol"]}"',
        text,
        count=1,
        flags=re.S,
    )
    if n_sym != 1:
        text, n_sym = re.subn(
            r'systemImage: "sparkles\.rectangle\.stack"',
            f'systemImage: "{theme["symbol"]}"',
            text,
            count=1,
        )
    if n_sym != 1:
        raise SystemExit(f"Could not find empty-state symbol in {path}")

    tint = f"                .tint({swift_color(theme['accent'])})"
    if ".tint(" in text:
        text = re.sub(
            r"\.tint\(Color\([^)]+\)\)",
            f".tint({swift_color(theme['accent'])})",
            text,
            count=1,
        )
    else:
        text = text.replace(
            "            ContentView()\n                .frame(minWidth: 1120, minHeight: 600)",
            "            ContentView()\n"
            + tint
            + "\n                .frame(minWidth: 1120, minHeight: 600)",
            1,
        )

    errors = multiline_indent_errors(text)
    if errors:
        raise SystemExit(
            f"Seeded ContentView would not compile ({path}): " + "; ".join(errors)
        )
    path.write_text(text)


def ensure_gitignore(starter: Path) -> None:
    gitignore = starter / ".gitignore"
    line = ".session-last-theme"
    existing = gitignore.read_text() if gitignore.exists() else ""
    if line not in existing.splitlines():
        gitignore.write_text(existing.rstrip() + ("\n" if existing else "") + line + "\n")


def apply(starter: Path, theme: dict) -> None:
    starter.mkdir(parents=True, exist_ok=True)
    ensure_gitignore(starter)
    write_seed_md(starter, theme)
    content = starter / "Ambassadors26" / "ContentView.swift"
    if content.exists():
        patch_content_view(content, theme)
    (starter / ".session-last-theme").write_text(theme["id"] + "\n")


def check_all_themes(starter: Path) -> None:
    content = starter / "Ambassadors26" / "ContentView.swift"
    if not content.exists():
        raise SystemExit(f"No ContentView.swift under {starter}")
    source = content.read_text()
    failed: list[str] = []
    for theme in load_themes():
        with tempfile.TemporaryDirectory() as tmp:
            path = Path(tmp) / "ContentView.swift"
            path.write_text(source)
            try:
                patch_content_view(path, theme)
            except SystemExit as exc:
                failed.append(f"{theme['id']}: {exc}")
                continue
            errors = multiline_indent_errors(path.read_text())
            if errors:
                failed.append(f"{theme['id']}: " + "; ".join(errors))
    if failed:
        raise SystemExit("Theme indent/patch check failed:\n" + "\n".join(failed))
    print(f"ok\t{len(load_themes())} themes")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--starter", type=Path, required=True)
    parser.add_argument("--theme", default=None)
    parser.add_argument(
        "--keep-theme",
        action="store_true",
        help="Re-apply this pair's theme from .session-last-theme or SEED.md",
    )
    parser.add_argument("--print-json", action="store_true")
    parser.add_argument(
        "--print-current-id",
        action="store_true",
        help="Print this pair's theme id and exit",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Patch every theme onto a temp copy of ContentView and check indent",
    )
    args = parser.parse_args()
    starter = args.starter.expanduser().resolve()
    if args.check:
        check_all_themes(starter)
        return
    if args.print_current_id:
        tid = current_theme_id(starter)
        if not tid:
            raise SystemExit(1)
        print(tid)
        return
    requested = args.theme
    if args.keep_theme:
        requested = current_theme_id(starter)
        if not requested:
            raise SystemExit(
                f"No current theme in {starter} (.session-last-theme or SEED.md)"
            )
    theme = pick_theme(starter, requested)
    apply(starter, theme)
    if args.print_json:
        print(json.dumps({"id": theme["id"], "name": theme["name"], "title": theme["title"]}))
    else:
        print(f"{theme['id']}\t{theme['name']}\t{theme['title']}")


if __name__ == "__main__":
    main()
