#!/usr/bin/env bash
# Кадры «до/после» правки по плейтесту автора 19 ноября одной командой: shots.sh <папка> [фильтр]
# Каждая строка — один запуск tools/ritual_view_probe.gd; кадры критика повторяются теми же камерами.
set -u
cd "$(dirname "$0")/../../.."
export XDG_CONFIG_HOME="$PWD/.godot/local-config" XDG_DATA_HOME="$PWD/.godot/local-data"
OUT="$(realpath -m "$1")"; FILTER="${2:-}"
mkdir -p "$OUT"
run() {
	local name="$1"; shift
	if [[ -n "$FILTER" && "$name" != *$FILTER* ]]; then return; fi
	echo "== $name"
	timeout 180 godot --path . --screen 1 -s res://tools/ritual_view_probe.gd -- --out="$OUT" "$@" 2>&1 \
		| grep -E '^(VIEW|FRAME|TOAST|MASK|  DOCK|WALLS|IDOL|HERO|UI:|FONTS|DOCK|GRASS|  OUTSIDE|  SMALL|SCRIPT ERROR|ERROR|DEFEAT)' | grep -v 'leaked'
}
run l1eve   --size=1920x1080 --level=1 --moment=evening --shots=ui,game,gatehouse,plazatop,idols,plaza,terem,gatewest,westwall,south --dump
run l1day   --size=1920x1080 --level=1 --moment=day --shots=ui,stream,bridge,top
run l1d1280 --size=1280x720 --level=1 --moment=day --shots=ui --dump
run l1night --size=1920x1080 --level=1 --moment=night --shots=game,trailend,enemy,enemy2,spawn
run l1spawn --size=1280x720 --level=1 --moment=spawn --shots=ui,game,spawn,gates
run l1dusk  --size=1920x1080 --level=1 --moment=dusk --shots=game,gates
run l1boss  --size=1920x1080 --level=1 --moment=boss --shots=game
run l2eve   --size=1920x1080 --level=2 --moment=evening --shots=pond,pondclose,pier,machines,house
run l2night --size=1920x1080 --level=2 --moment=night --shots=game,pondnight,pier
run l4night --size=1920x1080 --level=4 --moment=night --shots=ui,game,northrow --dump
run l4n2520 --size=2520x1080 --level=4 --moment=night --shots=ui --dump
run l3n1280 --size=1280x720 --level=3 --moment=night --shots=ui --dump
run l4n1440 --size=1440x1080 --level=4 --moment=night --shots=ui --dump
run l4day   --size=1920x1080 --level=4 --moment=day --shots=top,ui
run portr   --size=607x1080 --level=1 --moment=day --shots=ui --dump
run heroes  --size=1920x1080 --state=heroes --shots=ui
run select  --size=1920x1080 --level=2 --moment=day --state=select --shots=ui --dump
run alt     --size=1920x1080 --level=2 --moment=day --state=select,alt --shots=ui
run damaged --size=1920x1080 --level=2 --moment=day --state=damaged --shots=ui
run place   --size=1920x1080 --level=1 --moment=day --state=place --shots=ui
run idol    --size=1920x1080 --level=1 --moment=day --state=idol --shots=ui
run legend  --size=1920x1080 --level=1 --moment=day --state=legend --shots=ui
run tier2   --size=1920x1080 --level=1 --moment=day --state=tier2 --shots=ui
run tier3   --size=1920x1080 --level=1 --moment=day --state=tier3 --shots=ui
run tooltip --size=1920x1080 --level=1 --moment=day --state=tooltip --shots=ui
run dawn    --size=1920x1080 --level=1 --moment=dawn --shots=ui
run defeat  --size=1920x1080 --level=1 --moment=night --state=defeat --shots=ui
run banner  --size=1920x1080 --level=1 --moment=spawn --state=banner --shots=ui
run smoke   --size=1920x1080 --level=2 --moment=night --state=live --run=1.5 --shots=game,enemy2
# Добавлено для critique_4: портрет в режиме постройки с тостом, ночь с выбранным домом, постройка на
# половине участков, вечер города 2 с игровой камеры, ворота и площадь крупно, ночь босса крупно.
run portpl  --size=607x1080 --level=1 --moment=day --state=place,toast --shots=ui --dump
run nsel    --size=1920x1080 --level=3 --moment=night --state=select --shots=ui --dump
run nsel1280 --size=1280x720 --level=3 --moment=night --state=select --shots=ui --dump
run nsel1440 --size=1440x1080 --level=4 --moment=night --state=select --shots=ui --dump
run halfpl  --size=1920x1080 --level=2 --moment=day --state=place,half --shots=ui
run l2evgame --size=1920x1080 --level=2 --moment=evening --shots=game,machines
run l4eve   --size=1920x1080 --level=4 --moment=evening --shots=game,plazatop,terem,idols,gatehouse
run l1nhero --size=1280x720 --level=1 --moment=night --shots=game,hero
run toast1440 --size=1440x1080 --level=4 --moment=night --state=toast --shots=ui
run l2bossg --size=1920x1080 --level=2 --moment=boss --shots=game,gatewest
