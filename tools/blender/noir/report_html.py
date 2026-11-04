"""HTML-отчёт ночной 3D-сессии: new_concept/final/report.html (картинки рядом, относительные пути).

python3 -I tools/blender/noir/report_html.py
Берёт сравнения new_concept/final/<id>.jpg (final_sheet.py), IoU старого и нового метода, кадры игры
new_concept/final/game_*.jpg и арену. Текст «что сделано / что проверить» — в SUMMARY ниже.
"""
import html
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import final_sheet as fs  # noqa: E402

FINAL = fs.FINAL

SUMMARY = {
    "done": [
        "Новый метод: форма модели — нейросеть Hunyuan3D-2 (локально в ComfyUI), покраска — проекция самого концепта. "
        "Совпадение силуэта выше старого почти у всех моделей.",
        "Переделаны все 22 постройки, юниты, идолы, герои, терем; старые модели не тронуты (assets/noir), новые — assets/noir_h3d.",
        "Арена «нуар»: мощёный двор, дорога, частокол с воротами у входа дороги, жаровни, терем в конце дороги, лес — "
        "всё из моделей того же метода по новым концептам реквизита.",
        "Значки идолов в интерфейсе — рендеры новых моделей; своя плита постройки под всеми клетками фигуры; "
        "срубы-башенки по углам стены и факелы вдоль неё; юниты со скелетом на плавных весах.",
        "Картинка больше не мыльная: 3D рисуется в разрешении экрана (раньше — 1600×900 и растяжение).",
        "Интерфейс: дымчатое почти чёрное стекло, тонкая светлая кромка, янтарные акценты.",
    ],
    "todo": [
        "Обе арены в одном мире с плавной камерой подготовка → бой (нужна переделка экрана матча, его параллельно правит Codex).",
        "Сборка: нет пресета и шаблонов экспорта (open_questions.md); игра запускается godot --path .",
        "Дух (spirit): нейросеть превратила огоньки вокруг него в бесформенные куски (IoU 0,44 при трёх сидах) — "
        "в игре пока прежняя модель; нужен концепт без летающих огней или ручная доводка.",
        "Анимации кроме походки; идолы-варианты и герои пока не показываются в 3D-матче (модели готовы).",
    ],
    "check": [
        "Оставить новые модели (Hunyuan3D) или вернуть старые — по сравнениям ниже; можно по одной.",
        "Ракурс камеры арены (ниже и с угла, как на концепте) и терем у частокола в конце дороги.",
        "Обратная сторона моделей — рисунок с соседних сторон (постройки) или размытый (персонажи).",
    ],
}

CSS = """
:root{--bg:#07090b;--panel:rgba(18,22,26,.82);--edge:rgba(255,245,230,.12);--text:#ece3d2;--muted:#9aa4a8;--amber:#dca253}
*{box-sizing:border-box}body{margin:0;background:radial-gradient(1200px 600px at 70% -10%,#13202a 0,var(--bg) 60%);
color:var(--text);font:16px/1.55 "Inter","Noto Sans",system-ui,sans-serif}
main{max-width:1280px;margin:0 auto;padding:32px 16px 64px}
h1{font:600 34px "Noto Serif",Georgia,serif;margin:0 0 6px;color:var(--amber)}h2{font:600 24px "Noto Serif",Georgia,serif;
margin:40px 0 12px;color:var(--amber)}.sub{color:var(--muted);margin:0 0 24px}
.panel{background:var(--panel);border:1px solid var(--edge);border-radius:12px;padding:16px 20px;backdrop-filter:blur(8px)}
.cols{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:16px}
ul{margin:6px 0 0 18px;padding:0}li{margin:4px 0}
img{max-width:100%;border-radius:8px;border:1px solid var(--edge);display:block}
.grid{display:grid;grid-template-columns:repeat(auto-fill,minmax(380px,1fr));gap:14px}
figure{margin:0}figcaption{color:var(--muted);font-size:14px;margin-top:6px}
.iou b{color:var(--amber)}.better{color:#9fd39a}.worse{color:#e59a8a}
table{border-collapse:collapse;width:100%;font-size:14px}td,th{padding:4px 8px;border-bottom:1px solid var(--edge);text-align:left}
th{color:var(--amber);font-weight:600}
"""


def iou_pair(mid: str):
    _, old = fs.old_render(mid)
    p = fs.R / f"{mid}_h3d.iou"
    new = float(p.read_text()) if p.exists() else None
    return old, new


def main() -> None:
    ids = sorted(p.stem for p in FINAL.glob("*.jpg") if not p.stem.startswith(("game_", "all", "arena")))
    rows, figs = [], []
    for mid in ids:
        old, new = iou_pair(mid)
        cls = ""
        if old is not None and new is not None:
            cls = "better" if new > old + 0.005 else "worse" if new < old - 0.005 else ""
        o = f"{old:.2f}" if old is not None else "—"
        n = f"{new:.2f}" if new is not None else "—"
        rows.append(f"<tr><td>{html.escape(mid)}</td><td>{o}</td><td class='{cls}'>{n}</td></tr>")
        figs.append(f"<figure><img loading='lazy' src='{mid}.jpg' alt='{mid}'><figcaption class='iou'>{mid}: "
                    f"старый <b>{o}</b> → Hunyuan3D <b>{n}</b></figcaption></figure>")
    games = "".join(f"<figure><img src='{p.name}' alt='{p.stem}'><figcaption>{p.stem}</figcaption></figure>"
                    for p in sorted(FINAL.glob("game_*.jpg")))

    def ul(items):
        return "<ul>" + "".join(f"<li>{html.escape(t)}</li>" for t in items) + "</ul>"

    page = f"""<!doctype html><html lang="ru"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>Застава — 3D нуар</title>
<style>{CSS}</style></head><body><main>
<h1>Застава — ночная 3D-сессия</h1><p class="sub">Славянский нуар: модели по концептам, арена, интерфейс · 4 ноября 2026</p>
<div class="cols"><div class="panel"><h3>Сделано</h3>{ul(SUMMARY['done'])}</div>
<div class="panel"><h3>Не успели</h3>{ul(SUMMARY['todo'])}</div>
<div class="panel"><h3>Проверить автору</h3>{ul(SUMMARY['check'])}</div></div>
<h2>Игра</h2><div class="grid">{games}</div>
<h2>Модели: референс | старый метод | Hunyuan3D</h2>
<p class="sub">IoU — совпадение силуэта модели с концептом (1 — полное). Зелёным — новый метод лучше.</p>
<div class="panel"><table><tr><th>модель</th><th>старый</th><th>Hunyuan3D</th></tr>{''.join(rows)}</table></div>
<h2>Сравнения</h2><div class="grid">{''.join(figs)}</div>
</main></body></html>"""
    out = FINAL / "report.html"
    out.write_text(page)
    print(out, len(ids))


if __name__ == "__main__":
    main()
