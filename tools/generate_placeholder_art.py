"""Writes the map viewer's placeholder art (specs/18-map-viewer.md).

    python tools/generate_placeholder_art.py

Output: assets/placeholder/map/<name>.svg. Shapes are light grey so MapView can tint
them with the owner's colour. These are committed, replaceable files: edit or replace
them freely (or point assets/placeholder/map/map_art_set.tres at other textures) -
re-running this script overwrites them with the defaults.
"""

from __future__ import annotations

from pathlib import Path

OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "placeholder" / "map"
SIZE = 64
FILL = "#ece8df"
STROKE = "#3a352b"


def _svg(body: str) -> str:
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" width="{SIZE}" height="{SIZE}" '
        f'viewBox="0 0 {SIZE} {SIZE}">\n{body}\n</svg>\n'
    )


def _shape(element: str) -> str:
    return f'  <{element} fill="{FILL}" stroke="{STROKE}" stroke-width="3"/>'


def _points(pairs) -> str:
    return " ".join(f"{x},{y}" for x, y in pairs)


SHAPES = {
    # A player/faction home: a disc with an inner ring.
    "origin": _svg(
        _shape('circle cx="32" cy="32" r="26"')
        + f'\n  <circle cx="32" cy="32" r="14" fill="none" stroke="{STROKE}" stroke-width="3"/>'
    ),
    # A resource node: a diamond.
    "resource": _svg(_shape(f'polygon points="{_points([(32, 5), (59, 32), (32, 59), (5, 32)])}"')),
    # A fort: a square with crenellations.
    "fort": _svg(
        _shape(
            'polygon points="'
            + _points(
                [(8, 18), (8, 6), (18, 6), (18, 12), (27, 12), (27, 6), (37, 6), (37, 12),
                 (46, 12), (46, 6), (56, 6), (56, 18), (56, 58), (8, 58)]
            )
            + '"'
        )
    ),
    # A neutral node: a hexagon.
    "neutral": _svg(
        _shape(f'polygon points="{_points([(32, 5), (55, 18), (55, 46), (32, 59), (9, 46), (9, 18)])}"')
    ),
    # A waypoint: a small dot.
    "waypoint": _svg(_shape('circle cx="32" cy="32" r="12"')),
    # Hidden-from-some-faction badge: an eye with a slash.
    "hidden_badge": _svg(
        f'  <circle cx="32" cy="32" r="29" fill="#211d15"/>\n'
        f'  <path d="M10 32 Q32 12 54 32 Q32 52 10 32 Z" fill="none" stroke="#f2ecdf" stroke-width="4"/>\n'
        f'  <circle cx="32" cy="32" r="7" fill="#f2ecdf"/>\n'
        f'  <line x1="14" y1="50" x2="50" y2="14" stroke="#e06b5a" stroke-width="6" stroke-linecap="round"/>'
    ),
}


def write_all(out_dir: Path = OUT_DIR) -> list:
    out_dir.mkdir(parents=True, exist_ok=True)
    written = []
    for name, text in SHAPES.items():
        path = out_dir / f"{name}.svg"
        with open(path, "w", encoding="utf-8", newline="\n") as handle:
            handle.write(text)
        written.append(path)
    return written


if __name__ == "__main__":
    for written_path in write_all():
        print(f"wrote {written_path}")
