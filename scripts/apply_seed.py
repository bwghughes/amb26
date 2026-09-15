#!/usr/bin/env python3
"""Apply a visual/industry seed to the workshop Starter project."""

from __future__ import annotations

import argparse
import json
import random
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
THEMES_PATH = ROOT / "scripts" / "themes.json"


def load_themes() -> list[dict]:
    return json.loads(THEMES_PATH.read_text())["themes"]


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
    sample = theme["sample"].rstrip() + "\n"
    text = re.sub(
        r'private static let sample = """\n.*?"""',
        'private static let sample = """\n' + sample + '    """',
        text,
        count=1,
        flags=re.S,
    )
    text = re.sub(
        r'Text\("e\.g\. [^"]+"\)',
        f'Text("{theme["placeholder"]}")',
        text,
        count=1,
    )
    text = re.sub(
        r'\.navigationTitle\("[^"]+"\)',
        f'.navigationTitle("{theme["title"]}")',
        text,
        count=1,
    )
    text = re.sub(
        r'subtitle: "Paste or record rough notes from a channel sales conversation\."',
        f'subtitle: "{theme["subtitle"]}"',
        text,
        count=1,
    )
    text = re.sub(
        r'systemImage: "sparkles\.rectangle\.stack"',
        f'systemImage: "{theme["symbol"]}"',
        text,
        count=1,
    )

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


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--starter", type=Path, required=True)
    parser.add_argument("--theme", default=None)
    parser.add_argument("--print-json", action="store_true")
    args = parser.parse_args()
    starter = args.starter.expanduser().resolve()
    theme = pick_theme(starter, args.theme)
    apply(starter, theme)
    if args.print_json:
        print(json.dumps({"id": theme["id"], "name": theme["name"], "title": theme["title"]}))
    else:
        print(f"{theme['id']}\t{theme['name']}\t{theme['title']}")


if __name__ == "__main__":
    main()
