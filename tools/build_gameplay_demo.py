#!/usr/bin/env python3
"""Собирает локальный интерактивный отчёт из проверенных Godot-снимков, без сети."""
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DATA = ROOT / "docs/presentation/gameplay-demo.json"
TARGET = ROOT / "docs/presentation/2026-10-31-gameplay.html"
snapshots = json.loads(DATA.read_text())
assert len(snapshots["lessons"]) == 12
assert all(len(lesson["steps"]) == 4 for lesson in snapshots["lessons"])
encoded = json.dumps(snapshots, ensure_ascii=False).replace("</", "<\\/")
page = '''<!doctype html><html lang="ru"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Застава · Понять, испытать, сразиться</title>
<style>
:root{color-scheme:dark}*{box-sizing:border-box}body{margin:0;background:#151d23;color:#ece8df;font:17px/1.55 system-ui,sans-serif}main{max-width:1080px;margin:auto;padding:40px 24px}h1{font-size:clamp(34px,5vw,58px);line-height:1.12;color:#efcd83}h2{margin-top:36px;color:#efcd83}p{max-width:950px}.muted{color:#b7c4ca}.cards{display:grid;grid-template-columns:repeat(3,1fr);gap:14px}.card,.demo{background:#202e36;border:1px solid #3a4c55;border-radius:12px;padding:20px}.card b{font-size:22px;color:#efcd83}button,select{background:#2c414e;color:#f4eee0;border:1px solid #647987;border-radius:7px;padding:10px 14px;font:inherit;cursor:pointer;margin:4px}button.active{background:#725a2c;border-color:#e9c46a}.targets{display:grid;grid-template-columns:1fr 1fr;gap:16px}.hp{height:9px;background:#111b20;border-radius:5px;margin:12px 0}.hp span{display:block;height:100%;background:#8fc5a2;border-radius:5px}.target{padding:14px;background:#18252d;border-radius:8px}.tag{display:inline-block;padding:3px 8px;margin:3px;background:#344b59;border-radius:5px}.result{color:#efcd83;min-height:30px}table{border-collapse:collapse;width:100%;margin:20px 0}td,th{padding:10px;text-align:left;border-bottom:1px solid #3a4c55}a{color:#efcd83}code{color:#b4dfeb}.note{padding:14px 18px;border-left:3px solid #efcd83;background:#202e36}footer{font-size:14px;color:#b7c4ca;margin-top:35px}@media(max-width:720px){.cards,.targets{grid-template-columns:1fr}main{padding:24px 15px}}
</style><main>
<p class="muted">31 октября 2026 · продолжение после твоего матча</p>
<h1>Понять сочетание.<br>Проверить защиту.<br>Нажать «Готов».</h1>
<div class="cards"><div class="card"><b>Без спешки</b><p>Подготовка и выбор героя без таймера. Бой запускаешь сам.</p></div><div class="card"><b>Проба защиты</b><p>Настоящий бой на копии поля: прорывы и реакции видны до ставки HP. RNG, золото и HP матча сохраняются.</p></div><div class="card"><b>Понятные комбо</b><p>План драфта, собранные сочетания, общая зона на дороге и счётчик настоящих реакций.</p></div></div>
<h2>Попробуй здесь</h2><p class="muted">Это экспорт реальных снимков Godot, а не выдуманные числа. В самой игре тот же стенд доступен из главного меню. Шаги можно возвращать.</p>
<section class="demo"><select id="lesson" aria-label="Сочетание"></select><p id="explanation"></p><div id="steps"></div><div id="targets" class="targets"></div><p id="result" class="result"></p></section>
<h2>Баг, который портил твою комбинацию</h2><p>В твоём драфте Перун + Чернобог → Война должны были давать Добивание. Но финишер съедал сильное проклятие ради небольшого бонуса удара. Теперь накопленный взрыв и оставшийся огонь превращаются в физический урон.</p>
<table><tr><th>Контроль 12 секунд, те же башни</th><th>Урон</th></tr><tr><td>Реакция выключена</td><td>1500</td></tr><tr><td>Старое Добивание</td><td>1009</td></tr><tr><td>Исправленное Добивание</td><td>2269</td></tr></table>
<p>Щит сохраняет метки, двойного взрыва нет. Пар получил короткое замедление, чтобы его роль контроля проявлялась в движении. Обычная сухая цепь Перуна больше не раздувает счётчик реакций.</p>
<h2>Утренний маршрут</h2><ol><li>Запусти игру и открой <b>«Стенд реакций»</b>. Выбери Добивание: метки → реакция → последствия.</li><li>Начни матч. Спокойно прочитай героев и план своего драфта.</li><li>Собери пару/тройку. Выбери башню: золотая дорога показывает совместную зону. Нажми <b>«Проба»</b>, переставь башни и повтори.</li><li>Когда доволен защитой, нажми <b>«Готов»</b>. После боя посмотри, какие реакции действительно сработали.</li></ol>
<div class="note"><b>Проверки и ограничения.</b> Полные результаты — в <a href="../20_gameplay_overnight.md">журнале геймплейной итерации</a>. Учебный стенд проверен: 12 примеров × 4 шага × 2 размера окна. Настоящий графический дисплей в среде недоступен. Проба не учитывает активные навыки и последующие действия соперников. Финальный визуал отложен; карта и экономика не менялись без доказательств.</div>
<footer>Локальная сборка, без публикации и внешних зависимостей. <a href="../CURRENT_RULES.md">Актуальные правила</a>. Экспорт: <code>godot --headless --path . -s res://tools/export_gameplay_demo.gd</code>, затем <code>python3 -I tools/build_gameplay_demo.py</code>.</footer>
<script id="snapshots" type="application/json">SNAPSHOT_DATA</script>
<script>
const lessons=JSON.parse(document.getElementById('snapshots').textContent).lessons;
const names={steam:'Пар',roast:'Прожарка',melt:'Таяние',freeze:'Заморозка',chain:'Цепь',infection:'Зараза',conservation:'Консервация',shatter:'Раскол',execute:'Добивание',surge:'Разгон',wildfire:'Пылающий ветер',blizzard:'Стужа',frozen_wind:'Стужа'};
let current=0,step=0;const select=document.getElementById('lesson');
lessons.forEach((l,i)=>{const o=document.createElement('option');o.value=i;o.textContent=l.title;select.append(o)});
select.onchange=()=>{current=Number(select.value);step=0;render()};
function tags(t){let a=[];if(t.wet)a.push('Мокрота');if(t.charge)a.push('Заряд');if(t.burn)a.push('Горение '+t.burn_damage+'/с');if(t.frozen)a.push('Заморозка '+(t.frozen/20).toFixed(1)+'с');else if(t.cold)a.push('Холод');if(t.curse)a.push('Проклятие '+t.curse_damage+' через '+(t.curse/20).toFixed(1)+'с');if(t.slow_ticks)a.push('Замедление '+t.slow+'%');if(t.stun)a.push('Стан');return a.length?a:['Без меток']}
function render(){const l=lessons[current],s=l.steps[step];document.getElementById('explanation').textContent=l.explanation;const bar=document.getElementById('steps');bar.replaceChildren();['0 · Мишени','1 · Метки','2 · Реакция','3 · Последствия'].forEach((label,i)=>{const b=document.createElement('button');b.textContent=label;b.className=i===step?'active':'';b.onclick=()=>{step=i;render()};bar.append(b)});const cards=document.getElementById('targets');cards.replaceChildren();s.targets.forEach((t,i)=>{const d=document.createElement('div');d.className='target';const h=document.createElement('b');h.textContent='Мишень '+(i+1)+' · HP '+t.hp+'/'+t.max_hp;d.append(h);const bg=document.createElement('div');bg.className='hp';const fill=document.createElement('span');fill.style.width=Math.max(0,t.hp/t.max_hp*100)+'%';bg.append(fill);d.append(bg);tags(t).forEach(tag=>{const x=document.createElement('span');x.className='tag';x.textContent=tag;d.append(x)});cards.append(d)});document.getElementById('result').textContent=Object.entries(s.reactions).map(([id,n])=>(names[id]||id)+' ×'+n).join(' · ')||'Реакции ещё не сработали'}
render();
</script></main></html>'''
TARGET.write_text(page.replace("SNAPSHOT_DATA", encoded))
print(TARGET)
