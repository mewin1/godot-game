#!/usr/bin/env python3
"""Собирает презентацию docs/presentation/index.html из данных игры (герои, постройки, мобы),
картинок assets/ (SVG встраиваются в HTML) и файла docs/presentation/content.json
(тексты слайдов, цифры баланса, список скриншотов). Запуск: python3 -I tools/build_presentation.py
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "docs" / "presentation"


def tres_fields(path: Path) -> dict:
    """Поля [resource] и подресурса навыка (skill_*) из .tres — только простые значения."""
    text = path.read_text(encoding="utf-8")
    fields, section = {}, ""
    for line in text.splitlines():
        if line.startswith("["):
            section = line
            continue
        match = re.match(r'(\w+) = (.*)', line)
        if not match:
            continue
        key, value = match.groups()
        value = value.strip()
        if value.startswith('"') or value.startswith('&"'):
            value = json.loads(value.lstrip("&"))
        prefix = "skill_" if 'id="skill"' in section else ""
        if section.startswith("[resource]") or prefix:
            fields[prefix + key] = value
    return fields


def svg(path: Path, size: int = 96) -> str:
    if not path.exists():
        return ""
    body = path.read_text(encoding="utf-8")
    return re.sub(r'width="\d+" height="\d+"', f'width="{size}" height="{size}"', body, count=1)


def shape_grid(shape: str) -> str:
    cells = [tuple(map(int, c)) for c in re.findall(r"Vector2i\((-?\d+), (-?\d+)\)", shape)]
    if not cells:
        return ""
    w = max(x for x, _ in cells) + 1
    h = max(y for _, y in cells) + 1
    rects = "".join(f'<rect x="{x*14+1}" y="{y*14+1}" width="12" height="12" rx="2"/>' for x, y in cells)
    return f'<svg class="shape" width="{w*14+2}" height="{h*14+2}">{rects}</svg>'


def card(image: str, title: str, lines: list[str], extra: str = "") -> str:
    body = "".join(f"<p>{line}</p>" for line in lines)
    return f'<div class="card">{image}<h3>{html.escape(title)}</h3>{extra}{body}</div>'


def heroes_html(order: list[str]) -> str:
    cards = []
    for hero_id in order:
        f = tres_fields(ROOT / "data" / "heroes" / f"{hero_id}.tres")
        lines = [f'<span class="hp">♥ {f["hp"]} HP</span> · <span class="style">{html.escape(f["style"])}</span>',
                 html.escape(f["description"])]
        if "skill_display_name" in f:
            timing = ["в подготовку", "в волну", "когда угодно"][int(f.get("skill_timing", 0))]
            lines.append(f'<b class="skill">Навык «{html.escape(f["skill_display_name"])}»</b> · '
                         f'{f["skill_cost"]} зол. · {timing}: {html.escape(f["skill_description"])}')
        cards.append(card(svg(ROOT / "assets" / "heroes" / f"{hero_id}.svg", 112), f["display_name"], lines,
                          f'<div class="epithet">{html.escape(f["epithet"])}</div>'))
    return "".join(cards)


def towers_html(ids: list[str]) -> str:
    cards = []
    for tower_id in ids:
        f = tres_fields(ROOT / "data" / "towers" / f"{tower_id}.tres")
        lines = [f'Тир {f["tier"]} · клетки: {shape_grid(f["shape"])}', html.escape(f.get("description", ""))]
        cards.append(card(svg(ROOT / "assets" / "towers" / f"{tower_id}.svg"), f["display_name"], lines))
    return "".join(cards)


def mobs_html(ids: list[str]) -> str:
    cards = []
    for mob_id in ids:
        f = tres_fields(ROOT / "data" / "mobs" / f"{mob_id}.tres")
        lines = [f'HP {f["hp"]}', html.escape(f.get("description", ""))]
        cards.append(card(svg(ROOT / "assets" / "mobs" / f"{mob_id}.svg"), f["display_name"], lines))
    return "".join(cards)


def bars_html(rows: list[list]) -> str:
    out = []
    for label, value in rows:
        width = min(100, value * 3)
        out.append(f'<div class="bar"><span>{html.escape(label)}</span><i style="width:{width}%"></i>'
                   f'<b>{value}%</b></div>')
    return "".join(out)


def main() -> None:
    content = json.loads((OUT / "content.json").read_text(encoding="utf-8"))
    sections = []
    for slide in content["slides"]:
        kind = slide.get("kind", "text")
        inner = ""
        if kind == "heroes":
            inner = f'<div class="grid">{heroes_html(slide["ids"])}</div>'
        elif kind == "towers":
            inner = f'<div class="grid">{towers_html(slide["ids"])}</div>'
        elif kind == "mobs":
            inner = f'<div class="grid">{mobs_html(slide["ids"])}</div>'
        elif kind == "shots":
            inner = "".join(f'<figure><img src="{s["file"]}" alt=""><figcaption>{html.escape(s["caption"])}'
                            f'</figcaption></figure>' for s in slide["shots"])
        elif kind == "bars":
            inner = bars_html(slide["rows"])
        items = "".join(f"<li>{item}</li>" for item in slide.get("items", []))
        lead = f'<p class="lead">{slide["lead"]}</p>' if slide.get("lead") else ""
        sections.append(f'<section><h2>{html.escape(slide["title"])}</h2>{lead}'
                        f'{"<ul>" + items + "</ul>" if items else ""}{inner}</section>')
    page = TEMPLATE.replace("{{TITLE}}", html.escape(content["title"])).replace(
        "{{SUBTITLE}}", content["subtitle"]).replace("{{SECTIONS}}", "\n".join(sections))
    (OUT / "index.html").write_text(page, encoding="utf-8")
    print("Готово:", OUT / "index.html")


TEMPLATE = """<!doctype html>
<html lang="ru"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>Застава: ночь героев</title>
<style>
:root { --bg:#14100d; --panel:#2a1f18; --panel2:#47362a; --text:#efe4cf; --muted:#b9aa90;
  --amber:#e8a64a; --red:#b4473a; --frost:#8fb8c9; --brass:#c49a52; }
* { box-sizing:border-box; }
body { margin:0; background:radial-gradient(circle at 50% 0%, #2a1f18 0%, var(--bg) 60%); color:var(--text);
  font-family:"PT Sans","Segoe UI",system-ui,sans-serif; line-height:1.45; }
header { text-align:center; padding:56px 16px 24px; }
header h1 { font-size:clamp(34px,6vw,64px); margin:0; color:var(--amber); letter-spacing:1px; }
header p { color:var(--muted); font-size:20px; margin:8px 0 0; }
section { max-width:1180px; margin:0 auto; padding:36px 16px; border-top:2px solid #3a2c22; }
h2 { font-size:clamp(26px,4vw,40px); color:var(--amber); margin:0 0 12px; }
h2::before { content:"◆ "; color:var(--red); font-size:.7em; vertical-align:middle; }
.lead { font-size:20px; color:var(--text); max-width:900px; }
ul { font-size:19px; padding-left:22px; } li { margin:6px 0; } li b { color:var(--amber); }
.grid { display:grid; grid-template-columns:repeat(auto-fill,minmax(230px,1fr)); gap:14px; margin-top:16px; }
.card { background:var(--panel); border:2px solid var(--panel2); border-radius:14px; padding:14px; }
.card svg:first-child { display:block; margin:0 auto 6px; }
.card h3 { margin:4px 0; text-align:center; font-size:22px; }
.card p { margin:6px 0; font-size:15.5px; } .epithet { text-align:center; color:var(--muted); font-size:13px; }
.hp { color:#e87f6e; font-weight:bold; } .style { color:var(--frost); } .skill { color:var(--amber); }
.shape { vertical-align:middle; fill:var(--brass); }
figure { margin:18px 0; } figure img { width:100%; border-radius:12px; border:2px solid var(--panel2); }
figcaption { color:var(--muted); font-size:17px; margin-top:6px; }
.bar { display:grid; grid-template-columns:200px 1fr 60px; align-items:center; gap:10px; margin:6px 0; font-size:17px; }
.bar i { display:block; height:18px; background:linear-gradient(90deg,var(--red),var(--amber)); border-radius:9px; }
.bar b { text-align:right; }
@media (max-width:600px) { .bar { grid-template-columns:120px 1fr 48px; font-size:15px; } }
</style></head><body>
<header><h1>{{TITLE}}</h1><p>{{SUBTITLE}}</p></header>
{{SECTIONS}}
</body></html>
"""

if __name__ == "__main__":
    main()
