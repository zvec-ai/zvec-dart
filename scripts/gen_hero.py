#!/usr/bin/env python3
"""Generate hero-light.svg and hero-dark.svg for zvec-dart README.

Run once after fetching the raw logos to /tmp:
    curl -fsSL https://raw.githubusercontent.com/devicons/devicon/master/icons/flutter/flutter-original.svg -o /tmp/flutter.svg
    curl -fsSL https://raw.githubusercontent.com/devicons/devicon/master/icons/dart/dart-original.svg -o /tmp/dart.svg
    curl -fsSL https://zvec.oss-cn-hongkong.aliyuncs.com/logo/github_logo_1.svg -o /tmp/zvec-light.svg
    curl -fsSL https://zvec.oss-cn-hongkong.aliyuncs.com/logo/github_log_2.svg  -o /tmp/zvec-dark.svg
    python3 scripts/gen_hero.py
"""
import base64
import pathlib

SRC = pathlib.Path("/tmp")
DST = pathlib.Path(__file__).resolve().parent.parent / "assets"
DST.mkdir(parents=True, exist_ok=True)


def b64(name: str) -> str:
    return base64.b64encode((SRC / name).read_bytes()).decode("ascii")


flutter = b64("flutter.svg")
dart = b64("dart.svg")
zvec_light = b64("zvec-light.svg")
zvec_dark = b64("zvec-dark.svg")


def render(zvec_b64: str, label_fill: str, op_fill: str) -> str:
    return (
        '<svg xmlns="http://www.w3.org/2000/svg" '
        'xmlns:xlink="http://www.w3.org/1999/xlink" '
        'viewBox="0 0 610 230" width="610" height="230" '
        'font-family="-apple-system,BlinkMacSystemFont,Segoe UI,Helvetica,Arial,sans-serif">'
        f'<image x="20" y="30" width="281" height="140" xlink:href="data:image/svg+xml;base64,{zvec_b64}"/>'
        f'<text x="320" y="118" font-size="34" font-weight="600" fill="{op_fill}" text-anchor="middle">×</text>'
        f'<image x="350" y="50" width="100" height="100" xlink:href="data:image/svg+xml;base64,{flutter}"/>'
        f'<text x="470" y="114" font-size="34" font-weight="600" fill="{op_fill}" text-anchor="middle">+</text>'
        f'<image x="490" y="50" width="100" height="100" xlink:href="data:image/svg+xml;base64,{dart}"/>'
        f'<text x="160" y="200" font-size="16" font-weight="600" fill="{label_fill}" text-anchor="middle">Zvec Engine</text>'
        f'<text x="400" y="200" font-size="16" font-weight="600" fill="{label_fill}" text-anchor="middle">Flutter</text>'
        f'<text x="540" y="200" font-size="16" font-weight="600" fill="{label_fill}" text-anchor="middle">Dart</text>'
        '</svg>\n'
    )


(DST / "hero-light.svg").write_text(
    render(zvec_light, label_fill="#1f2328", op_fill="#8b949e"),
    encoding="utf-8",
)
(DST / "hero-dark.svg").write_text(
    render(zvec_dark, label_fill="#e6edf3", op_fill="#6e7681"),
    encoding="utf-8",
)

for name in ("hero-light.svg", "hero-dark.svg"):
    p = DST / name
    print(f"{name}: {p.stat().st_size} bytes")
