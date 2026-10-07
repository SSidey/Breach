"""The content library the designer's Library page browses (Decision 128).

Reads the registry - content/registry/{tags,traits,statuses}.json - and finds where each
tag and trait is used across the repo's content (.tres definitions under content/, and the
designer's own libraries), so the page can show, search and filter them. A trait's
targets - the kinds of thing it may sit on - follow the same rule as Godot's
ContentRegistry: where all its tags' targets agree, narrowed by its "only". A trait with a
"default" is implicit: every unit has it at that level without listing it.
"""

from __future__ import annotations

import json
import re
from pathlib import Path

KINDS = ("tags", "traits", "statuses")
_DICT = re.compile(r"^(traits|grants) = \{(.*?)^\}", re.M | re.S)
_KEY = re.compile(r'"([a-z_]+)"\s*:')
_TAGS = re.compile(r"^tags = Array\[String\]\(\[(.*?)\]\)", re.M)
_WORD = re.compile(r'"([a-z_]+)"')


def read_registry(root: Path) -> dict:
    """{"tags": [...], "traits": [...], "statuses": [...], "usage": {id: [paths]},
    "implicit": {id: level}}, each trait with its "targets" worked out; "implicit" holds the
    traits with a "default" level every unit has without listing them (climber 0)."""
    out = {}
    for kind in KINDS:
        path = root / "content" / "registry" / f"{kind}.json"
        out[kind] = json.loads(path.read_text(encoding="utf-8"))[kind] if path.exists() else []
    tags = {tag["id"]: tag for tag in out["tags"]}
    for entry in out["traits"]:
        entry["targets"] = targets(entry, tags)
    out["usage"] = usage(root)
    out["implicit"] = {t["id"]: int(t["default"]) for t in out["traits"] if "default" in t}
    return out


def targets(entry: dict, tags: dict) -> list:
    """The kinds of thing a trait may sit on."""
    reach = None
    for tag in entry.get("tags", []):
        kinds = tags.get(tag, {}).get("targets", [])
        reach = list(kinds) if reach is None else [k for k in reach if k in kinds]
    reach = reach or []
    if "only" in entry:
        reach = [k for k in reach if k in entry["only"]]
    return reach


def usage(root: Path) -> dict:
    """Tag or trait id -> the content files (repo-relative) that use it."""
    found: dict = {}
    content = root / "content"
    for path in sorted(content.rglob("*.tres")):
        text = path.read_text(encoding="utf-8", errors="replace")
        ids = set()
        for block in _DICT.finditer(text):
            ids.update(_KEY.findall(block.group(2)))
        for block in _TAGS.finditer(text):
            ids.update(_WORD.findall(block.group(1)))
        for used in ids:
            found.setdefault(used, []).append(path.relative_to(root).as_posix())
    for path in sorted((content / "designer").glob("*.json")):
        text = path.read_text(encoding="utf-8")
        for used in set(_designer_traits(json.loads(text))):
            found.setdefault(used, []).append(path.relative_to(root).as_posix())
    return found


def _designer_traits(value) -> list:
    """Trait ids under any "traits" object in a designer library."""
    out = []
    if isinstance(value, dict):
        for key, inner in value.items():
            if key == "traits" and isinstance(inner, dict):
                out.extend(inner.keys())
            else:
                out.extend(_designer_traits(inner))
    elif isinstance(value, list):
        for inner in value:
            out.extend(_designer_traits(inner))
    return out
