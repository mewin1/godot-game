# 37 — Gorodishche (endless "Obryad") overhaul spec

Date: 2026-11-12. Updated: 2026-11-13. Status: P0/P1/P2 implemented; P5 dock + idols on the plaza
implemented (rest of P5 open, phase order changed by the author: P5 before P3/P4); author playtest pending.
Language: English (author's request). Author-facing summary is given in Russian in chat.
Review edits (2026-11-12): BLD-10 and RX-9 acceptance reworded; reaction changes in endless-only
data (RX-12); BUG-28 moved from P0 to P4; minimal UI in P2 and a playable game after every phase;
expert target lowered to night 20-22 with decision D14.
Implementation: P0/P1 implemented, P2 catalogue/plots/upgrades/specialisations are playable in the
current panel. Author playtest and visual validation remain pending. Commits are authorised but
blocked by read-only `.git`. VIS-1d skipped: `project.godot` holds the author's uncommitted change.
Details: decisions.md, sections of 12-13 November. All D1-D14 have author answers; D9 is deferred.
Technical checks (2026-11-13): all nine `check_project.py` stages pass, GUT 597/597, 30-night curve,
15-night catalogue bot and strict replay (15/15 dawns and final hash match), solo/support/pair bench,
night-15 what-if variants. Live balance, captures and the author's full mouse run remain pending.

Source material:
- Author's live playtest of 2026-11-12 (seed 915701, hero Solovey, died on night 15 at 28:42 game
  clock; record `.godot/ritual/attempt_1794504716_1207263375_1_final.json`) and the author's verbal
  feedback (quoted in §1.2).
- Deterministic replay of that run (all 236 commands re-applied, every dawn matches the record
  exactly), screenshots of the real `RitualTrialPanel` at nights 1–15 (last 3 s of each capture run
  at live speed), synthetic input tests,
  headless mechanics probes and the night-generator curve for 3 seeds (§2).
- Code audit of `src/sim/ritual/*`, `src/sim/data/ritual_*`, `src/ui/ritual_*`, `src/view/ritual_*`,
  `data/ritual/endless.tres`.

Evidence screenshots: `docs/reports/2026-11-12_gorodishche_audit/` (01–07, 1920×1080 captures of the
real panel, replayed state).

Requirement IDs (`ECO-3`, `UI-7`, `BUG-11`…) are referenced by the phases in §13. Every number marked
*(placeholder)* is a starting value for the author to tune — the author owns economy numbers
(memory: design-sessions format). Items marked **DECISION** need the author's confirmation before
implementation; the recommended option is listed first.

---

## 0. Table of contents

1. Summary: what is wrong and what we change
2. Evidence from the playtest and probes (§2.7 — independent findings F1–F16)
3. Design pillars and measurable targets
4. Building model: catalogue, plots, click-upgrades, tiers (replaces random shop + merging)
5. Economy and difficulty curve
6. City growth, entrances, alleys
7. Elemental statuses and reactions (cooldowns, readability, planning)
8. Idols in the world (replace UI idols and the fire bowls)
9. Hero, palisade, supplies, bosses, gifts, omens, night/day rules
10. UI/UX: compact bottom dock, selection, feedback
11. Visual: sharpness, lighting, readability, camera, scene art direction (§11.5)
12. Audio
13. Bug list (with reproduction)
14. Implementation phases and acceptance criteria
15. Decisions for the author
16. Appendices (data tables, tooling, file map)

---

## 1. Summary

### 1.1 Core diagnosis (one paragraph)
The mode is fun for ~10 nights, then collapses into "hoard gold, reroll the shop, buy idol rites",
and finally the player dies within two nights from full health. Root causes: (a) **power is gated
by shop RNG and by merge copies, not by gold** — so gold piles up while the board is already full;
(b) **the difficulty generator hides a cliff**: once packs hit the 20-enemy cap (≈ night 13), all
extra night budget turns into enemy HP *without any extra gold*, and "Heavy" omens double a night's
HP; (c) **too many small buildings** (43 at death, 10 types, 1–3 levels) plus **cooldown-free
statuses and reactions** (~20 reactions per second late) make placement and reactions irrelevant
after the opening; (d) **the screen is hard to read**: oversized fire bowls, weak selection, no
same-type highlight, invisible wear, unreadable scout icons, stale messages, soft (TAA) image, no
sound.

Beyond the author's feedback, the deeper pass (§2.7, F1–F16) found: wards immune to 6 of 10
buildings; most reaction pairs *reduce* damage; enemy statuses not drawn at all; erratic upgrade value
(some levels add nothing, some ×4); support cards describing the wrong effect; nights 14–15 that no
purchase could change; late hero skills worth ≤ 4%; a dark first evening and a day that is barely
brighter than night; sunken roads hiding enemies; no gatehouse model; scene far from the author's
concepts (§11.5).

### 1.2 Author feedback covered by this spec (all items)
| # | Author's point | Where |
|---|---|---|
| A1 | Mid-game: too much money, nothing to spend it on | §2.2, §5 (ECO-*) |
| A2 | Late game: map full, lots of money; only rerolling the shop and idol rites left | §4, §5 |
| A3 | Can't cancel a building chosen in the shop until you place it or pick another | BUG-01, UI-6 |
| A4 | All entrances on one side — boring | §6 (MAP-*) |
| A5 | Enemies turning into alleys doesn't make it harder; it makes them easier to kill | §6.3 (ALY-*) |
| A6 | Late game enemy power rises sharply, mine doesn't | §2.3, §5.3 |
| A7 | No tier-3 buildings | §2.4, §4.4 (BLD-6) |
| A8 | Very hard to upgrade: can't see where each building type is → highlight all same-type buildings on selection | UI-8, UI-9 |
| A9 | Balance needs a lot of work | §3, §5, §14 P7 |
| A10 | Lighting braziers are huge and block the map | VIS-4, §8 |
| A11 | Buildings don't read (will be regenerated later) | VIS-6 (requirements for the future models) |
| A12 | Graphics look blurry; anti-aliasing works poorly | VIS-1 |
| A13 | Reactions fire instantly and statuses apply with no cooldown | §7 (RX-*) |
| A14 | Reaction planning only matters at the start; later it's mush | §7, §4.2 |
| A15 | Maybe fewer buildings and more distance between them | §4.2 (plots) |
| A16 | Maybe drop merging for upgrades; show all buildings, widening choice with city level; upgrade by clicking a building | §4 |
| A17 | UI is bad; shop on the left is too big; move all UI compactly to the bottom | §10 |
| A18 | Remove idols from UI, place them on the map around the terem instead of the braziers | §8 |

---

## 2. Evidence

### 2.1 The run, dawn by dawn (replayed; matches the record exactly)
| Dawn | Gold at dawn | Earned (cum.) | Spent (cum.) | Buildings | Cells used / open | Idol dmg % (3 idols) | Worn / silent houses |
|---|---|---|---|---|---|---|---|
| 1 | 55 | 50 | 70 | 5 | 7/36 | – | 0/0 |
| 3 | 46 | 174 | 203 | 9 | 14/36 | – | 0/0 |
| 5 | 164 | 423 | 334 | 16 | 25/36 | – (boss 1 killed, gift "Fury") | 0/0 |
| 6 | 122 | 554 | 507 | 24 | 37/56 (street 1) | – | 0/0 |
| 8 | 101 | 931 | 905 | 34 | 53/76 (street 2) | first rite on night 8 | 1/0 |
| 10 | 375 | 1582 | 1282 | 39 | 59/76 | 0/10/0 (boss 2, gift "Might") | 8/0 |
| 11 | 491 | 1949 | 1533 | 42 | 63/76 | 20/20/20 | 9/1 |
| 13 | 290 | 2715 | 2500 | 43 | 65/76 | 40/70/50 | 12/4 |
| 14 | **900** | 3325 | 2500 | 43 | 65/76 | 40/70/50 | **16/8** |
| death (night 15) | **1027 unspent** | 3496 | 2580 | 45 | 66/76 | | 17/8 |

- HP stayed 45/45 for **13 nights** (no leaks at all), then 45 → 37 (night 14) → 0 (night 15, 7.8 s
  after HP 9). Every single night ended with "early dawn": the player killed everything with
  32–53 s of the night still left (skipped 645–1058 ticks per night). The defence was ~2× overpowered
  for 13 nights and ~2.5× underpowered on night 15 — a **×5 swing in two nights**.
- **Rerolls were the biggest gold sink: 1011 of 2580 gold (39%)**, 100 rerolls total, 32 in one day
  (night 11, 377 gold) and 25 the day after (350 gold) — the author was fishing for rite cards.
  29 rites bought, first one only on night 8 (the rite card is 1 random slot of 7 gods).
- Never used: repair (8 houses silent at night 14 — wear is invisible on the map), hero heal, tar,
  rain bowl. Hero skill (Whistle, 40 s cooldown) used **4 times in 28 minutes**.
- Max building level reached: 3 (brick), only 3 buildings; no level 4. 21 distinct (type, level)
  groups among 43 buildings — power spread thin.
- Damage share: Bolt 27%, Furnace 18%, Thunder 15%, Spark 13%, Rime 8%, hero 6%, Brazier 5%,
  Plague 5%, Hex 3%, Water 0.1%, Wind 0 (support). Damage kinds: plain hits 90%, burn 6%,
  chain 3.5%, curse 0.4%.
- Reactions: 4,800+ over the run; **~1,190 during night 14 alone (~20 per second)**: Execute 1350,
  Chain 603, Melt-reverse 412, Conservation 393, Infection 378, Steam 350…
- 1/3 of building purchases happened at night despite +50% price and 12 s install (day is 25 s).

### 2.2 Why gold piles up (A1, A2)
- Buildings come only from a 3-card random shelf: P(specific building per card) = 1/7 for single
  buildings of a god, **1/14** for gods with two buildings; a fresh shelf shows a given two-per-god
  building only 20% of the time. Merging needs 2/4/8 copies of the *same type and level*.
- Idol rites come only from 1 random card; when all 3 idols are dedicated, 4 of 7 gods' rite cards
  are dead slots.
- Free cells exist (11 of 76 at death) but are scattered single cells; most shapes are 2–3 cells.
- Therefore the only reliable sink late is the escalating reroll (2, 3, 4… gold per reroll per
  day) → the author's "only reroll and buy rites" experience.

### 2.3 Why enemies outgrow the player (A6)
Night generator (`RitualNightPlan`, seed 915701; other seeds similar):

| Night | Mobs | Total enemy HP | Gold from kills | HP per gold | Max pack HP % | Omen |
|---|---|---|---|---|---|---|
| 1 | 25 | 1,325 | 50 | 26 | 100 | – |
| 5 | 54 | 8,932 | 158 | 57 | 172 | boss |
| 10 | 115 | 42,310 | 379 | 112 | 325 | boss |
| 12 | 80 | 73,579 | 372 | 198 | 418 | banners |
| 13 | 160 | 87,557 | 379 | 231 | 846 | horde |
| 14 | 115 | **176,051** (×2.01) | 618 | 285 | 548 | **heavy** |
| 15 | 161 | 233,820 | 541 | 432 | **2370** | boss |
| 20 | 201 | 1,332,492 | 721 | 1,848 | 8,994 | boss |
| 30 | 201 | 36,865,385 | 668 | 55,188 | 292,846 | boss |

- Budget grows +23%/night, HP +14%/night ⇒ total HP ×~1.40/night, gold ×~1.23/night.
- **From night ~13 packs hit `pack_max_size` = 20 and packs_max = 8–9**: kill gold plateaus at
  600–900 per night while HP keeps growing ×1.4 (overflow budget → `hp_percent`, `_compose`).
- Omen variance: "Heavy" nights carry ~2× the HP of the previous night, "Horde" nights ~1.0×.
- Player power per gold is ~linear (merge L2 = 2× throughput per copy, L3 = 3×, L4 = 3× — L4 adds
  nothing per copy except armor pierce), rites +10% damage each at ×1.25 cost.

### 2.4 Tier 3 (A7)
The endless catalogue (`combat_endless.tres`) has 10 buildings: tier I — Bolt, Brazier, Wind, Rime,
Spark, Hex; tier II — Furnace, Water, Thunder, Plague; **tier III — none**. Tier-III data already
exists from PvP: Cinder (Svarog), Ice Lance (ice), Storm grid (Perun), Black Obelisk (curse), Rain
circle (water), Vortex (Stribog); war: only "Ракетница" (rejected as anachronism) / Tsar-cannon.

### 2.5 Input tests (real input events pushed through the window)
| Action in buy mode | Result |
|---|---|
| LMB on shop card | enters buy mode; **the chosen card is not highlighted** |
| Esc | cancels (works) — **but no hint anywhere says so**; message text stays "Выберите свободные клетки…" |
| LMB on the same card again | stays in buy mode (no toggle) |
| RMB on board / on card | rotates the preview, never cancels |
| LMB on forest outside the city | stays in buy mode |
| "Отмена" button in the left column | does **not** cancel; it is "cancel move" and shows "Нет незавершённого переноса" |

### 2.6 Other probes
- RMB on a 2-cell building at night = a "rotate" MOVE → building **offline for 20 s** (400 ticks);
  by day 3 s. Easy misclick, no warning.
- Selling a building right after buying it (even in the evening) refunds 50%.
- Navi shield ward takes 200% from fire, 25% from physical, **0% from ice, lightning, curse, water,
  wind** — invisible rule.
- `state_hash()` of the same final state differs between a pure replay (474912854), a replay with
  the panel attached (699626009) and the live record (234756395) while the full typed snapshots are
  identical (BUG-20).

### 2.7 Independent findings (not in the author's feedback)
Method: (a) **building bench** — each building alone (and in pairs) on the same plot next to the main
road, 75 s against identical streams: "stream" (30 Mertvyak, 2100 HP, 1 s apart), "clump" (same,
0.2 s apart), "armor4" (20 Latniks), "ward" (20 Navi shields); damage per gold of the copies it
costs. (b) **What-if forks** of the author's real state at the dusk before nights 14 and 15 (replay →
snapshot → branch → change one thing → play the night without commands). (c) Luminance and 1:1 crops
of the real render. Scripts are listed in appendix E.

**F1. Navi shield's ward is immune to 6 of 10 buildings.** Ward takes 200% from fire, 25% from
physical, **0% from Rime, Spark, Thunder, Hex, Plague, Water** (bench "ward": all zeros). On
"Навьи знамёна" nights a Perun/curse/ice city has nothing that can break a ward. The rule is shown
nowhere.

**F2. Most reaction pairs *lower* damage.** Pair synergy = pair damage ÷ sum of solos − 1 (L1):
| Pair | stream | clump | Why |
|---|---|---|---|
| Water + Spark (Chain) | **+40%** | **+26%** | the only clearly positive pair |
| Water + Rime (Freeze) | +2% | 0% | freeze only stops; nobody shatters |
| Brazier + Rime (Melt) | −3% | −1% | melt eats the burn DoT |
| Brazier + Spark (Roast) | −2% | −2% | roast eats the burn DoT |
| Hex + Rime (Conservation) | −8% | −4% | |
| Water + Brazier (Steam) | **−47%** | −22% | steam consumes wet *and* burn every time water re-wets |
| Water + Hex (Infection) | **−59%** | **−52%** | infection consumes wet and suppresses the curse status, so the curse never lands |
| Wind + Brazier | −19% | −25% | wind pushes burning enemies out of the brazier's reach; 0 wildfires |
Cause: a reaction consumes the second element's status and `suppress_status` stops it from being
applied; an enabler that re-applies its status every shot therefore permanently blocks the other
building's own effect (burn, curse explosion).

**F3. In the author's real mixed city, reactions were noise-but-necessary.** Disabling reactions on
night 14: damage 173.8k → 150.5k (−13%) and the author dies (45 → 0 HP, 14 enemies left). So 1,201
reactions in that night were worth ~19 damage each, yet that 15% was the margin of survival. Neither
"reactions matter, plan them" nor "ignore them" is readable to the player.

**F4. Enemy statuses are not drawn at all in this mode.** `RitualBattleLayer._draw_mobs()` is empty,
which skips `BattleLayer._draw_mob_overlay` (wet ring, burn dot, charge ring, cold ring, curse) that
PvP uses. Reaction planning is literally blind.

**F5. Upgrade value is erratic and invisible** (damage per gold, L1 → L4):
| Building | stream | clump | armor4 | Anomaly |
|---|---|---|---|---|
| Bolt | 50 / 96 / 144 / 144 | 15 / 28 / 46 / 46 | 28 / 61 / 98 / 104 | L4 = L3 (8 copies buy only "pierce 4") |
| Brazier | 80 / 80 / 80 / 156 | 22 / 91 / 108 / 148 | | L2–L3 give nothing vs single file |
| Furnace | 72 / 143 / 143 / 288 | 21 / 40 / 166 / 247 | | L3 = L2 vs single file |
| Rime | 33 / 64 / **38** / 154 | 10 / 18 / 44 / 162 | | **L3 worse than L2** (loses its 2nd target in data) |
| Spark | 72 / 138 / 139 / 202 | 22 / 41 / 169 / 292 | 32 / 78 / 88 / 275 | L3 jumps ×4 in crowds |
| Thunder | 61 / **61** / 245 / 275 | 18 / 77 / 198 / 267 | 43 / 43 / 171 / 189 | **L2 = L1** single file, then ×4 at L3 |
| Hex | 50 / 66 / 82 / 96 | 14 / 26 / 38 / 48 | | weakest damage dealer at every level |
| Plague | 34 / 74 / 74 / 113 | 54 / 66 / 78 / 131 | | L3 = L2 |
| Water | 0 / 0 / 6 / 26 | 0 / 0 / 13 / 27 | | deals damage only from L3 |
The selection panel shows none of this; the player cannot tell a dead upgrade from a ×4 jump.

**F6. Support buildings are mislabelled and weak by their stated effect.** Next to a Bolt, Wind
L1/L2/L3/L4 adds +12/+18/+27/+36% (12/24/48/96 gold) = 6→2 extra damage per gold, while a second
Bolt gives 50 per gold. Water L1/L2 adds +6% (2 per gold). Yet removing the author's 5 Winds on night
14 kills him: Wind's real value is the **push-back** (time in range), not the advertised "соседям
темп +10%". The card text describes the minor effect and hides the major one.

**F7. Nights 14–15 had no decision that could change the outcome.** Fork before night 15: each of
the 12 untaken gifts alone, or all 875 gold into Perun / Svarog / Chernobog damage rites (11–13
rites), or +5 charm — **every variant dies** with 20–28 enemies alive. Fork before night 14 (the
author survived with −8 HP): removing *any* building group — 5 Winds, 2 Hexes, 3 Plagues or 5 Rimes —
is death. There was no slack and nothing to buy that mattered; the run ended by arithmetic, not by a
mistake.

**F8. Hero skills don't matter late.** Auto-casting the skill at the densest point on nights 14–15
(Ilya 13 strikes, Solovey 8–10 whistles, Yaga 1–2 brews) changes neither outcome; Ilya's strike
(capped at 500) is ≤ 4% of a late night's damage.

**F9. The sim is chaotic.** One extra action shifts a night's result by ±8 hero HP (e.g. casting the
skill made night 14 *worse* by 6–8 HP in one fork). Balance must be measured over many forks/seeds,
never one replay.

**F10. The first evening starts in night darkness.** `RitualNightRules.cycle_view` returns a
negative local time while the first evening (900 ticks) is longer than `day_ticks` (500), so
`RitualDaylight.sun_phase` puts the sun below the horizon for the first ~20 s of every run (playfield
luminance 42 — darker than night, 47).

**F11. Day is barely brighter than night.** Mean playfield luminance (0–255): first evening 42 → 65,
mid-day 56–69, dusk 45, night 47. Full daylight lasts ~15 of the 25 s day (dawn ramp 5 s, dusk 5 s);
fires keep burning at 30%. The "build by day, fight by night" rhythm is not visible on screen
(evidence 10).

**F12. Sunken roads hide the fight.** Build platforms are raised stone boxes with walls and arches;
roads run in the trench between them. At the current camera pitch the near-side walls occlude enemies
and the platform rims shade the buildings (evidence 11). Enemies are ~15 px tall at 1:1.

**F13. The gatehouse doesn't exist.** docs/34 §4 puts the run's HP in Ilya's gatehouse; there is no
gatehouse model — the hero is a ~20 px figure on an empty plaza. The right third of the city (last
road stretch + plaza) has no plots: dead space in the most-watched area.

**F14. Aspect ratios.** At 1920×800 the city keeps its width and the extra space is forest; at 4:3
the shop panel reaches the west gate; at 1280×720 all text is ~10 px (evidence 12, 13).

**F15. Element identity is missing in the render.** In the author's own concepts
(`new_concept/arena/arena_battle_25.png`, `new_concept/06_battle_ui.jpg`) buildings are free-standing
pylons with strong element-coloured glow, roads are light and wide, only 2–3 fire bowls sit at the
edges, the field fills ~70% of the frame, the palisade is dark wood and the terem's warm windows are
the focal point. In the game: buildings are dark brown huts/poles with tiny accents, roads are dark
stone like the plots, 10+ identical bright bowls are the brightest objects, the city fills ~45% of
the frame and the palisade is lit orange.

**F16. Simulation cost is fine.** 0.78 ms per tick at night 13 with 43 buildings (×3 speed ≈ 47 ms
of CPU per real second on the author's PC) — keep an eye on it for phones (docs/33).

---

## 3. Design pillars and measurable targets

Pillars (keep from docs/34): a growing city around the terem; material = level; every run ends in
defeat, the question is how long; no hard artificial limits — gold is the limiter; the fight must be
visible and readable.

New pillars from this playtest:
- **P1. Gold always converts into power through a choice.** Never "nothing to buy"; never "the only
  sink is RNG".
- **P2. Few, meaningful buildings.** Each placement and each upgrade is a decision you can see on
  the map.
- **P3. Pressure ramps smoothly.** First leaks are a warning, not a death sentence; death comes over
  several nights, not one.
- **P4. Reactions are events, not noise.** Rarer, stronger, readable, plannable.
- **P5. The map is the interface.** Idols, plots and buildings live in the world; the HUD is a thin
  frame.

Targets (measured with the replay tool + bot + live play, §14 P7):
| Metric | Target |
|---|---|
| Run length, first-time player | death on night 6–8 (≈10 min) |
| Run length, experienced (author) | death on night 14–18 (≈30 min) |
| Run length, expert | night 20-22 (about 40 min), approved by the author 2026-11-13 (D14); a balance target for endless runs |
| Unspent gold at dawn (reasonable bot) | ≤ 25% of the night's income, every night ≥ 3 |
| Nights from first real leak (≥10% hero HP) to death | ≥ 3 for the reasonable bot |
| Night-to-night total enemy EHP change | within ×1.10–×1.30 (boss night ≤ ×1.45) |
| Night clear time (reasonable bot), nights 1–5 / 6–12 / 13+ | 45–60% / 60–80% / 75–100% of night length |
| Buildings on the map at night 15 | 14–24 |
| Visible reactions per second, late game | ≤ 4 average, ≤ 8 peak |
| Share of damage from reactions/statuses (reaction-aware bot) | ≥ 25% |
| Damage share of the best building type | ≤ 35% (no single dominant type) |
| Gold on rerolls (if any reroll remains) | ≤ 10% of total spend |

---

## 4. Building model (A2, A7, A8, A15, A16)

**DECISION D1 (recommended):** replace the random building shelf and copy-merging with a **fixed
catalogue + plots + click-upgrades**. Alternatives in §15.

### 4.1 Catalogue (BLD-1…BLD-4)
- BLD-1. All unlocked buildings are always buyable from the catalogue in the bottom dock (§10).
  No random shelf for buildings, no reroll for buildings.
- BLD-2. Buildings are grouped by god (7 columns/tabs) and by tier (I/II/III). Locked tiers are
  shown dimmed with the unlock condition ("Город 2-го уровня").
- BLD-3. Price is fixed per building *(placeholders: tier I 12–18, tier II 30–40, tier III 70–90)*,
  modified by own-element discount (§5.5) and the night surcharge (§9.7).
- BLD-4. Remove: `RitualCommand.Action.MERGE`, BUY-into-twin, `market_*` for buildings, reroll of
  buildings, `install_until` move-merges. Keep the code paths only for `trial.tres`/PvP if tests need
  them; the endless config must not use them.

### 4.2 Plots instead of a free grid (BLD-5)
- **D8 approved by the author (2026-11-12):** buildings use fixed plots along streets, one building
  per plot, with at least one empty cell (yard, fence, tree, lantern) between plots. Start: **10 plots**.
  Initial progression for playtesting: 10/16/22/26 plots at city levels 1/2/3/4, adding 6 at levels
  2 and 3 and 4 inner plots at level 4 (current: 76 cells, 43 buildings).
- All buildings occupy exactly one plot; shapes and rotation are removed for the endless mode
  (rotation was the RMB trap, BUG-03). Directional buildings (Wind, Vortex) blow **against enemy
  movement along the nearest road segment** automatically; optional "flip direction" button in the
  selection panel (costs nothing, 3 s install).
- Because buildings are fewer, base stats of endless buildings are scaled *(placeholder: damage ×2,
  range +0.5 cell)* in endless data only (`combat_catalogue.tres` and `buildings/` copies).
  `combat_endless.tres` remains unchanged for historical replay rules.
- Plot visuals: raised stone pad with a clear rim; free plot shows a small stake/lantern marker;
  plots glow when a catalogue card is hovered or in placement mode.

### 4.3 Upgrades by clicking (BLD-6, BLD-7)
- BLD-6. Select a building → selection panel shows **"Улучшить → Каменный · N золота"** with the
  next level's behaviour text. Levels: 1 Wood → 2 Stone → 3 Brick → 4 White stone (keep
  `level_names`).
- Upgrade cost *(placeholder)*: L2 = 1.5 × base, L3 = 3 × base, L4 = 6 × base (cumulative 11.5×).
  Damage multiplier *(placeholder)*: L2 ×2.2, L3 ×4.6, L4 ×9.5, plus the level behaviours from
  `RitualBuildingLevels` (extra targets, splash, pierce…). Upgrades are slightly less DPS-per-gold
  than new buildings, but plots are limited — so mid/late gold flows into upgrades by design.
- Level gates: L3 requires city level 2, L4 requires city level 3 (§6.1).
- Upgrade takes the install time (day 3 s, night 12 s), building inactive meanwhile (shown).
- BLD-7 **(DECISION D2, recommended yes):** at L3 the player chooses one of two **specialisations**
  per building (docs/29 §5 idea), e.g. Bolt: "Залп" (+2 targets) or "Бронебой" (pierce 4, ×1.5
  damage vs heavy); Rime: "Стужа" (area cold) or "Ледяной кол" (single-target freeze). Data-driven
  (`RitualLevelBehavior` gets `branch` variants). This creates late-game decisions and run variety.
- BLD-10. **Every level must be an improvement in the building's role** (F5): in its intended
  scenario (single file for single-target, clump for area) damage grows at every level, and damage
  per invested gold stays within 0.8-1.0 of L1; no flat steps, no ×4 surprise jumps. A small dip in
  damage per gold is intended: upgrades are a bit less efficient than new buildings (above; with the
  placeholders 1.0 / 0.88 / 0.84 / 0.83 for L1-L4). Fix data now: Rime L3 keeps its 2nd target;
  Thunder L2 gains a real benefit; Bolt L4 gets more than "pierce 4"; Brazier/Furnace/Plague L3.
  Bench acceptance: the solo table of §2.7 F5, regenerated for the new model (cost = cumulative
  invested gold, not merge copies), shows damage growing at every level and damage per gold inside
  the 0.8-1.0 band of L1.
- BLD-11. The selection panel shows **"DPS now → after upgrade"** and the role tag (single, area,
  control, support), computed from sim formulas, not hand-written text.
- BLD-12. **Support buildings say what they really do** (F6): Wind's card/tooltip leads with
  push-back/slow ("отбрасывает врагов назад — дольше под обстрелом"), the neighbour tempo is
  secondary; Water L1/L2 either get a real neighbour bonus (*placeholder +20%/+30%*) or are tier-I
  "enablers" with an explicit reaction role. Support value per gold must be within ×0.7–×1.3 of a
  damage building of the same tier when placed next to 2 damage buildings (bench).
- Sell: refund **100% within 10 s after placing/upgrading or while never fired** (undo a misclick),
  otherwise 60% of invested *(placeholder)*. Selling an upgraded building refunds the upgrade share
  the same way.

### 4.4 Tier III buildings (BLD-8)
- Add one tier-III building per god, unlocked at city level 3. Use existing PvP data as placeholders
  (copy into `data/ritual/buildings/`, re-tune for endless):
  Svarog — Cinder «Огненный венец»; Ice — Ice Lance «Ледяное копьё»; Perun — Storm grid «Грозовая
  решётка»; Curse — Black Obelisk «Чёрный обелиск»; Water — Rain circle «Дождевой круг»; Stribog —
  Vortex «Ветряной круг»; War — new **«Порок» (stone thrower)** using Tsar-cannon numbers (splash
  0.9 cell, slow, heavy damage). No rockets/cannons (docs/34 anachronism rule).
- Fill the tier gaps so each god has I/II/III: War II «Осадный станок» (war_engine), Ice II «Ледник»
  (glacier), Stribog II «Свистящий столб» (gale), Water I — a cheap single-target "wetting" building
  (new, placeholder from water.tres at 60% numbers) so water can be started early.
- Tier III buildings should be *build-arounds* with a distinct role (finisher, group control,
  chain amplifier), not just bigger numbers. Each needs a one-line role tag in the card tooltip
  ("Финишер", "Контроль толпы", "Усилитель цепи").

### 4.5 Wear and repair (BLD-9) — DECISION D3
- **Author decision (2026-11-12): keep wear in endless**, with clearly visible building condition
  and convenient repair from the selected building.
- Required feedback: cracks/smoke as condition worsens, a conspicuous impaired/silent icon when
  applicable, a dawn warning about buildings needing repair, and repair from the selection panel.
  Show current condition, its penalty and repair cost. No hidden penalty is acceptable.
- Wear thresholds, penalties and repair costs stay in resources and are tuned during P2 and live play.

---

## 5. Economy and difficulty

### 5.1 Income (ECO-1…ECO-3)
- ECO-1. **Remove "overflow budget → HP"** (`RitualNightPlan._compose`). When a pack is full, extra
  budget becomes: (1) an extra pack if the night window allows (`packs_max` raised to 12
  *(placeholder)*), else (2) **elite affix** on random members: ×3 HP, ×3 bounty, crown marker,
  visible in the scout queue. Bounty must stay proportional to threat: total kill gold per night grows
  every night.
- ECO-2. Income curve target: total gold per night (kills + tribute) grows **+12–15% per night**
  *(placeholder)* with no plateau through night 30.
- ECO-3. Dawn bonus for a clean night: +X gold if no leaks *(placeholder 10 + night)*; and keep
  street tribute (§6.1). No interest mechanics.

### 5.2 Gold sinks (ECO-4)
Ordered by when they matter; every dawn the player must have ≥ 2 sensible options:
1. New buildings on free plots (early).
2. Upgrades L2–L4 and specialisations (mid).
3. City levels: street + entrance + plots + tier unlock + scout depth (mid), §6.1.
4. Idol rites — infinite, decaying effects / growing cost (late), §8.
5. Hero ranks **deferred by the author (2026-11-12)** until after P7; revisit only if gold still
   piles up. Draft rank effects (+5 max HP / -10% skill cooldown, cost x1.5 per rank) remain placeholders.
6. Supplies: buy at dawn, max 3 in stock *(placeholder 15/15/25 gold)*, §9.4.
No sink may be a pure lottery. If any reroll survives (e.g. for dawn boons, §5.6) it must have a
small cap per day (≤ 2 rerolls).

### 5.3 Enemy growth model (ECO-5…ECO-7)
- ECO-5. Replace "budget +23% & HP +14%" with an explicit **pressure curve**: total enemy EHP of
  night n = `E(n) = E1 × g^(n−1)` with g ≈ 1.18–1.22 *(placeholder)*, split into count growth
  (≈ +10%/night until the pack cap) and per-enemy HP growth (the rest). Boss nights ×1.3 on top.
  Rationale: income grows ~13%/night, cumulative power ~linear in cumulative gold, so a 5–7%
  per-night gap makes the run end gradually around night 15–18 for a good player (a ~2× buffer at
  night 5 is eaten in ≈ 10–12 nights), with gifts and reactions as the expert's extra headroom.
  Expert headroom: with a ~6%/night gap every night past the author's ~16 needs ~6% more effective
  power for the same gold. Night 22 needs ~1.4× (1.06^6), night 28 ~2× (1.06^12). Reactions (target
  ≥ 25% damage share) and better placement can plausibly give the first, not the second; hence the
  expert target of night 20-22 in §3. Nights 25-30 need a late multiplicative lever (e.g. idol
  milestones, D7) or a smaller late gap (D14).
- ECO-6. **Omens change composition, not total EHP**: each omen's night EHP is normalised to within
  ±10% of `E(n)`. "Heavy" = fewer, tougher enemies; "Horde" = many weak; "Flock" = fast; "Banners" =
  wards + banners. Remove the ×2 "Heavy" spikes.
- ECO-7. Armor/ward rules must be counterable by more than one element: ward takes 200% fire,
  100% physical *(was 25%)*, 50% lightning, 25% others *(placeholders)*; show the rule in the scout
  tooltip and as an icon on the mob.
- ECO-7b. **There is always a decision that matters** (F7): for the reasonable bot's city at the dusk
  before any night ≤ the target night, at least one affordable purchase (or skill/supply use) must
  change the night's outcome by ≥ 20% of hero HP. Measured with the what-if harness (appendix E):
  fork, try every affordable option, compare.
- ECO-7c. **Measure over forks, not single runs** (F9): every balance number is the mean of ≥ 20
  forks (different seeds, or ±1-tick command jitter) with a spread reported.
- ECO-8. Add a balance test: `test_endless_curve_is_smooth` — for 5 seeds × nights 1–30, total EHP
  ratio night/night within the target band and kill gold monotonic non-decreasing.

### 5.4 Idol rites pricing (ECO-9)
- Keep decay curves (`RitualRiteCurve`) for non-damage effects. Damage rites: +10% per rite, cost ×1.25
  (unchanged) — but rites are bought **directly at the idol**, not from a random card (§8).

### 5.5 Element discount (ECO-10)
- Keep (from docs/34 §7), applies to buildings, upgrades and (if kept) repairs; show the current
  discount on the idol and on every affected card ("−14% Сварог").

### 5.6 Roguelike variety without shop RNG (ECO-11) — DECISION D4
- **Author decision (2026-11-12): dawn boon draft at every dawn.** Choose 1 of 3 small boons
  (e.g. "Самострелы +1 цель", "Ремесло: улучшения −15% эту ночь",
  "Ветер несёт искры", "Сторожка +5 HP", "+1 смола"). Pool filtered by relevance (only boons for
  gods/buildings the player owns or can build). Boss gifts stay as the big step (§9.5).
- Run variety also comes from: hero choice, boss resistances, omens, entrance order (§6.1) and L3
  specialisations.

---

## 6. City growth, entrances, alleys (A4, A5)

### 6.1 City levels (MAP-1…MAP-4)
- MAP-1. Replace "Новая улица" with **"Укрепить город" (city level)** in the bottom dock and on the
  terem (clicking the terem opens the city panel). Levels *(placeholder costs 60 / 150 / 320)*:
  | Level | Gives |
  |---|---|
  | 1 (start) | main west road, 10 plots, tier I, upgrades to L2, scout: next night |
  | 2 | north street + **north entrance**, +6 plots, tier II, upgrades to L3, tribute +10/dawn |
  | 3 | south street + **south entrance**, +6 plots, tier III, upgrades to L4, tribute +15/dawn |
  | 4 "Белокаменный детинец" | no new entrance; +4 inner plots near the terem, +10 hero max HP, 4th idol pedestal *(D5 approved 2026-11-12; numbers are placeholders)* |
- MAP-2. A new entrance is announced in the scout strip from the moment of purchase and opens at the
  next night (keep current rule).
- MAP-3. **Entrances from three sides** (A4): west gate (main road), north forest road, south river
  ford. All routes converge on the terem plaza from different directions; each route has at least
  one 90° turn inside the city so coverage differs along the path. Suggested layout (cells are
  illustrative; final grid by the implementer):
  ```
            N gate
              ║
   ┌──────────╫──────────────┐
   │  p  p    ║   p  p   p   │      p = plot, ═/║ = road
   W═══════╗  ║   p          │
   gate p  ║  ╚═════╗   TEREM│
   │  p    ╚════════╬═══▶ ◆  │
   │   p  p   p     ║   p    │
   └────────────────╫────────┘
                    ║
                 S ford
  ```
- MAP-4. The cape/river setting (docs/34 §3) stays: the river bounds the south (ford entrance) and
  the east behind the terem; the forest/cursed land is west and north.

### 6.2 Board data (MAP-5)
- New board resource `data/ritual/board_city2.tres` with plots (`Array[Vector2i]` per city level),
  routes per entrance, and plaza. `RitualStreetData` gains `plots` and `entrance_side`; `build_regions`
  stops being used by the endless mode. Old `board_city.tres` stays for tests.

### 6.3 Alleys (ALY-1…ALY-3) — DECISION D6
Problem: packs split round-robin into alleys that run *through* the centre of town, so split enemies
pass more buildings and the front is less dense → easier.
- ALY-1 **Approved by the author (2026-11-12):** alleys become **shortcuts** that skip a long stretch of the main kill zone, and
  only some enemies take them: fast enemies (Upyr, Volkodlak) always prefer an open alley; others
  take it only when the main road ahead is blocked (palisade) or slowed (tar). The player can
  **barricade an alley** at a plot-like slot (cheap, *placeholder 15 gold*, removable). Decision:
  leave it open (fast enemies shortcut past your defence) or close it (spend gold, lose that
  coverage trick).
- ALY-2 Rejected alternative: remove alleys entirely (simpler; loses a mechanic).
- ALY-3. The scout tooltip and the route preview show which enemies will use the alley.

---

## 7. Statuses and reactions (A13, A14)

### 7.1 Cooldowns (RX-1…RX-4)
- RX-1. **Status application cooldown:** a building applies its status to the same enemy at most
  once per `status_apply_cooldown_ticks` *(placeholder 40 = 2 s)*; other hits still deal damage.
  New field on `TowerData` (endless copies) or on the level behaviour.
- RX-2. **Reaction internal cooldown per enemy per reaction:** `ReactionData.cooldown_ticks`
  *(placeholder 40–60)*. While on cooldown the incoming element only applies/refreshes its own status
  (subject to RX-1).
- RX-3. **Global per-enemy reaction gate:** at most one reaction per enemy per 10 ticks
  *(placeholder)*, so stacked towers can't chain-proc.
- RX-4. Make reactions **rarer but stronger** (data only; placeholders): Melt ×2.0; Steam ×1.6 +
  40% slow 1.5 s; Freeze 2.5 s; Shatter ×2.0 + 0.6 s stun; Execute ×2.0 + stored damage (needs 2
  statuses, ICD 3 s); Chain +100% chain chance; Infection jumps to 2 neighbours; Wildfire area 1.5
  cell; Roast ×1.5 + 0.4 s stun. Tune with `tools/reaction_audit.gd`-style A/B on endless data
  (endless-only copies, RX-12).
- Determinism: all cooldowns are integer ticks in `RitualMob`/`MobState`, included in the snapshot
  and hash; tests in `test_reactions` (new cases for ICD) and `test_ritual_endless`.
- RX-9. **No reaction may lower damage** (F2). When a reaction consumes a DoT status (burn, curse
  explosion), the remaining DoT damage is paid out immediately (or the reaction keeps the DoT); a
  reaction never suppresses the incoming element's own status while that reaction is on cooldown.
  Acceptance: the pair bench (appendix E) shows synergy ≥ +10% for every listed reaction pair and
  never below 0 for any pair whose elements react. Pairs without a reaction are outside this rule:
  e.g. Wind + Brazier (−19…−25%, F2) loses damage because push-back moves enemies out of the
  brazier's reach, not because of a reaction; that is checked by the support bench of BLD-12.
- RX-10. **Statuses visible on enemies** (F4): restore the status overlay for the endless mode (wet,
  burn, charge, cold/frozen, curse) as small readable marks under the HP bar; colour-blind-safe
  shapes, not only colour.
- RX-11. The ward rule (F1) and element immunities are shown on the enemy, in the scout tooltip and
  in each building's tooltip ("не пробивает оберег").
- RX-12. **Reaction changes stay in the endless mode.** Today the reaction resources are shared:
  `data/reactions/*.tres` are referenced by `data/ritual/combat_endless.tres`,
  `data/ritual/combat.tres` (4-day trial) and `data/game_config.tres` (PvP). Data changes of RX-2,
  RX-4 and RX-9 go into endless-only copies (`data/ritual/reactions/`, referenced only from
  `combat_endless.tres`); the shared files stay as they are. New sim rules in
  `src/sim/divine_combat.gd` (cooldowns, DoT payout instead of suppression) are switched on by fields
  of the copies, with defaults equal to today's behaviour. Acceptance: PvP and `trial.tres` tests
  pass without edits.

### 7.2 Planning (RX-5, RX-6)
- RX-5. With plots (§4.2) reaction pairs become *places*: show **combo links** when placing or
  selecting a building — thin coloured arcs to buildings in range that it reacts with, with the
  reaction icon in the middle (e.g. Water ⟶ Spark: "Цепь").
- RX-6. Selection panel shows "Реакции за ночь: Цепь ×34, Пар ×12" for the building (counter per
  tower in sim reports, already partly in `reaction_counts`).

### 7.3 Readability (RX-7, RX-8)
- RX-7. Replace floating reaction **text** labels with a single small **icon burst** above the enemy
  (element-pair glyph), max one per enemy per 0.8 s; text only in tooltips/legend.
- RX-8. **D11 approved by the author (2026-11-12):** default to important damage numbers only:
  reaction hits above a threshold, crits and boss damage. Tune the threshold during implementation.
  Aggregate per enemy per 0.5 s; hard cap ~12 numbers on screen. Settings toggle
  "Числа урона: нет / важные / все".

---

## 8. Idols in the world (A10, A17, A18)

- IDL-1. Remove the idol slots from the HUD. Place **3 idol pedestals on the terem plaza** (front
  left, front right, back) where the porch/corner fire bowls stand now. Each pedestal has its own
  small built-in fire (the light source that the bowls provided) — light grows with the idol's
  rites (fire size / glow) so the player *sees* investment.
- IDL-2. Interaction: click an idol (or hotkeys 4/5/6) → compact popup anchored to the idol:
  - empty idol: choose a god (7 god symbols with one-line description) — dedication is permanent;
  - dedicated: list of that god's rites with current/next bonus, cost, and "Купить" (no random
    card); god's element discount; tooltip with totals.
- IDL-3. Idol model changes by dedication (god symbol/colour carved, banner) and by rite count tiers
  (1 / 5 / 10 / 15 rites: new ornaments). Placeholder: tint + emissive symbol until the author's
  models.
- IDL-4. **Approved by the author (2026-11-12):** each idol grants a free god-specific effect
  at each of 5/10/15 invested rites. Exact effects and strength remain to be designed and balanced.
- IDL-5. AGENTS.md rule "Три пустых идола развиваются заговорами без слияния копий" stays; the layout
  rule "идолы под картой" changes for the endless mode (update AGENTS.md after approval).

---

## 9. Hero, palisade, supplies, bosses, gifts, omens, day/night

### 9.1 Hero (HER-1…HER-5)
- HER-1. Breach feedback (missing today): red flash and shake on the gatehouse, edge vignette pulse,
  hero HP bar flashes, "−8" floats from the gatehouse, sound (§12). Low-HP state (≤ 30%) keeps a slow
  red pulse.
- HER-2. Skill readiness is salient: cooldown ring on the skill button, glow + soft sound when ready,
  key hint. (Whistle was used 4 times in 28 min.)
- HER-3. Ilya's strike cap (500) scales with the night (*placeholder: cap = 500 × 1.12^(n−1)*) or
  becomes uncapped with ×0.5 against bosses — otherwise it is irrelevant after night 12.
- HER-4. Hero select: show HP, skill cooldown and a one-line play-style tag; remember the last pick;
  "Ещё забег" keeps the hero, "Сменить героя" opens the picker.
- HER-5. Hero portrait in the dock is small (§10); hero model stands at the gatehouse in the world
  (already in the scene).

### 9.2 Palisade (PAL-1)
- Keep; show remaining count on the dock button; placed palisade is visible on the road with a
  "ready" glint; hint which heavy enemy will hit it first (already drawn — keep).

### 9.3 Speed and pause (SPD-1)
- Speed ×1/×2/×3 persists across nights; pause shows a clear "ПАУЗА" overlay; Space/X keys stay.

### 9.4 Supplies (SUP-1, SUP-2)
- SUP-1. Supplies in the dock as 3 icon buttons with counts and keys 1/2/3; targeting supplies
  (tar, rain) show the radius ghost and cancel with RMB/Esc (same rules as UI-6).
- SUP-2. Besides the free random one per dawn, supplies can be bought at dawn (sink, §5.2).

### 9.5 Bosses and gifts (BOS-1…BOS-4)
- BOS-1. Boss arrival banner + sound; boss HP bar at the top while alive; immunity element shown as an
  icon on the boss and in the queue (exists in queue; add on the boss).
- BOS-2. Gift pool **filtered by relevance**: elemental gifts only for gods with ≥ 2 owned buildings
  (or an idol of that god); hero gifts named generically ("Двойной приём героя"), not "Два удара
  Ильи" for Solovey/Yaga.
- BOS-3. Taken gifts and boons are shown as small icons in the top bar with tooltips (today they are
  invisible after the choice).
- BOS-4. Gift cards with icon, name, effect and a "why it fits your city" hint.

### 9.6 Omens (OMN-1)
- Announced at dawn with a banner (not only in the toast); shown in the scout strip; EHP normalised
  (ECO-6).

### 9.7 Night building rules (NGT-1…NGT-3)
- NGT-1. **D10 approved by the author (2026-11-12):** keep night surcharge (+50%) and longer
  install (12 s). Night catalogue prices are yellow with a red upward-arrow badge. Hovering
  the arrow explains the night surcharge with a short lore-based tooltip and the install time.
  Working copy: "Мастера спят. Ночной вызов: +50% к цене, стройка 12 с."
- NGT-2. Remove the RMB "rotate" on placed buildings (no rotation with plots). If any rotation stays,
  it must never lock a building at night without confirmation.
- NGT-3. Early dawn stays, with a banner "Ночь отбита" and the clean-night bonus (ECO-3).

---

## 10. UI/UX (A3, A8, A17)

Base canvas 1600×900 (`canvas_items` stretch), must also fit the phone plan (docs/33). The map
takes everything between a thin top bar and a compact bottom dock. Replaces the endless-mode part of
the AGENTS.md rule "лавка/армия слева, карта справа, идолы под ней" (update after approval).

### 10.1 Layout (UI-1…UI-5)
```
┌ top bar 40px ────────────────────────────────────────────────────────────────────────┐
│ Ночь 7 · до рассвета 0:42 │ scout strip: [→ ☠×12 +3] [↑ ⚔×6] … │ gifts │ ⏸ ×2 ⚙ │
├──────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                      │
│                       MAP (city, idols on the plaza, hero at gate)                   │
│                    toasts: top-centre, auto-fade, max 3 stacked                      │
│                                                                                      │
├ bottom dock ~132px ──────────────────────────────────────────────────────────────────┤
│[hero 56px HP▮▮▮ 45][Q skill][F palisade][1][2][3] │ catalogue: god tabs + cards 72×88 │ selection │
│ gold 332                                         │ (tier I/II/III, locked dimmed)    │ panel     │
└──────────────────────────────────────────────────────────────────────────────────────┘
```
- UI-1. **Top bar:** phase + **countdown** ("День · до ночи 0:18", "Ночь 7 · до рассвета 0:42"),
  not total elapsed time (BUG-10); compact scout strip; gifts/boons icons; pause, speed, settings.
- UI-2. **Bottom dock left:** hero (small portrait, HP bar, number), gold, skill (Q) with cooldown
  ring, palisade (F) with count, supplies (1/2/3), heal-hero button (if kept) as a small "+".
- UI-3. **Bottom dock centre:** building catalogue (§4.1). Card: icon, short name, price, element
  colour stripe, tier badge, role tag on hover. Cards never reflow when bought (BUG-17). A city-level
  button sits at the end of the catalogue row (also reachable by clicking the terem).
- UI-4. **Bottom dock right:** context panel — selected building (name, level pips, behaviour, DPS
  this night, reactions, Upgrade / Specialise / Sell / Flip wind), selected idol (§8), selected enemy
  (HP, armor/ward, statuses), or the city panel.
- UI-5. Remove from the player UI: "Проверки" dev row (move behind a debug flag/F10), FPS counter
  (settings toggle, off by default), "Запись: .godot/…" message, separate "Перенести/Продать/Отмена"
  row (actions live in the context panel).

### 10.2 Placement and cancel (UI-6, UI-7)
- UI-6. Cancel placement/targeting by **any of**: RMB anywhere, Esc, clicking the same card again,
  clicking empty ground outside plots, the "✕" on the placement hint. The hint reads
  "ЛКМ — поставить · ПКМ/Esc — отмена".
- UI-7. Chosen card is highlighted (raised, gold frame) while in placement mode. Placement ghost
  shows the building model, **range ring**, and combo links (RX-5). Invalid plots are not
  highlighted at all (no red spam); valid plots pulse softly.

### 10.3 Selection and "where is what" (UI-8…UI-11) — author request A8
- UI-8. **Selecting a building outlines all buildings of the same type** on the map with their level
  pips; buildings that can be upgraded right now get a gold ↑ chevron, those lacking gold a grey ↑.
- UI-9. **Hovering a catalogue card** outlines all buildings of that type and pulses free plots.
- UI-10. Hold **Alt** (and a toggle in settings) to show level pips + element icon above *every*
  building. Level pips must show 4 levels (BUG-12).
- UI-11. Selected building: strong outline (not the thin 1-px tile rectangle), range ring, its
  wind/aura area. Clicking empty ground deselects; Tab cycles through same-type buildings.

### 10.4 Messages and feedback (UI-12…UI-15)
- UI-12. Toasts: auto-fade after 4 s, max 3, newest on top; important events (omen, boss, new
  entrance, gift) use banners; the old full-width message bar is removed (BUG-08).
- UI-13. Scout strip: readable enemy tokens — distinct silhouette or coloured role glyph per enemy
  type (fast/armored/ward/banner/boss), count, entrance arrow, element-immunity badge, elite crown.
  "Осталось пачек: 0" while enemies are alive is replaced by "Пачек: 0 · врагов на улицах: 17"
  (BUG-09). Optional mini-timeline of the night with pack markers.
- UI-14. Defeat screen: nights, time, bosses, record, **gold breakdown** (buildings / upgrades /
  city / rites / supplies), **damage by building type** (top 5), leaks by enemy type, best reaction;
  buttons "Ещё забег" (same hero), "Сменить героя", "В меню".
- UI-15. Tooltips everywhere (cards, idols, enemies, statuses, reactions) with numbers; a "?" legend
  of reactions reachable from the dock.

---

## 11. Visual (A10, A11, A12)

### 11.1 Sharpness (VIS-1) — author's "blurry, AA works poorly"
Current: `RenderQuality.setup_viewport` → TAA on, MSAA off, no sharpening (`noir_post.gdshader`
`clarity = 0`), anisotropic 4×, the 3D SubViewport is drawn as a texture into a Control
(`ArenaStage3D._draw`) with default linear filtering. Crop 07 shows soft edges at 1:1.
Required:
- VIS-1a. Add sharpening after TAA: enable the post shader's clarity (*start 0.3, radius 1.0 px*)
  or a CAS pass; expose "Резкость" in settings.
- VIS-1b. Guarantee 1:1 pixel mapping of the SubViewport: integer pixel size and pixel-snapped
  position of the stage control; use nearest filtering when the scale is exactly 1.
- VIS-1c. A/B the AA modes on the author's 2560×1440 screen: (1) TAA + sharpen, (2) FSR2 at
  scale 1.0 with sharpness 0.2–0.4 (native AA), (3) MSAA 4× + SMAA (foliage would need
  alpha-to-coverage instead of hashed alpha). **D12 approved by the author (2026-11-13): FSR2
  is the default**, selected from the saved P0 comparison crops. Keep other modes in settings.
- VIS-1d. Anisotropic filtering 16× (project setting) — check the uncommitted `project.godot`
  change of the author first.
- Acceptance: 1:1 crops of the same frame for each mode in a report; the author chooses.

### 11.2 Lighting and fire bowls (VIS-2…VIS-4)
- VIS-2. Remove the corner fire bowls and the porch bowls from the playfield (`RitualArena3D.
  _build_fires`, `_corner_bowls`). Lighting comes from idol fires on the plaza (§8), small torches
  on palisade posts (outside plots/roads) and small lanterns at plot corners (≤ 0.3 cell).
- VIS-3. Night readability floor: roads, plots and units keep a minimum luminance (fill light /
  emissive rims); enemies get a subtle rim light at night.
- VIS-4. Any remaining bowl/torch: ≤ 60% of today's scale, never on a plot or a road cell, no
  bloom flare over buildings.

### 11.3 Readability (VIS-5…VIS-9)
- VIS-5. Roads read as roads: lighter packed earth/planks, distinct from plot stone; entrance arrows
  painted at gates at dusk for the next night's entrances.
- VIS-6. Requirements for the author's future building models: one unique silhouette per type
  readable at gameplay zoom; element colour accent (banner/roof/glow) consistent with
  `GodSymbols` colours; material = level (wood/stone/brick/white stone) visible from above; tier III
  visibly bigger/taller. Until then: element-coloured banner + level pips as placeholders.
- VIS-7. Enemies ×1.3–1.5 scale at gameplay zoom, distinct silhouettes per role; HP bar only when
  damaged; elites/bosses with a thicker bar.
- VIS-8. Wind arrows and auras only on hover/selection/placement (today 5 wind towers draw
  permanent cyan arrows across the map, some through the palisade).
- VIS-9. Level marks: 4 distinct levels (BUG-12); material texture swap per level when models exist.

### 11.4 Camera (VIS-10)
- **D13 approved by the author (2026-11-13): fixed camera**, with a tighter full-city view and
  no user-controlled zoom or pan. The author is likely to target phones; layout and controls
  must account for this. Keep every city level visible on one screen, with automatic fitting
  on city growth where needed. The bottom dock must not cover plots.

### 11.5 Scene art direction (SCN-*) — findings F10–F15
North star: the author's own concepts `new_concept/arena/arena_battle_25.png` and
`new_concept/06_battle_ui.jpg`. Every item below has a measurable acceptance; the author approves the
look.

**SCN-1 Composition.** The city fills 65–75% of the 16:9 frame between the top bar and the dock;
terem + gatehouse sit on the right third as the focal anchor, the west gate on the left third, the
north/south gates at the top/bottom edges. The forest is a dark frame, not content. Camera pitch and
height are chosen so that ≥ 90% of every road cell is visible (occlusion test: project each road cell's
centre and check depth against the rendered depth or raycast).

**SCN-2 Value hierarchy (light budget).** Three tiers at night: frame (forest, outside the palisade)
mean luminance ≤ 30; field (roads, plots, yards) 50–90; bright accents **only for gameplay** —
building element cores, projectiles, enemy eyes/rims, idols, terem windows, gatehouse. Rule: no
decorative object may be brighter than the brightest gameplay element. Today the 10+ fire bowls are
the brightest objects in the frame (F15). Acceptance: luminance histogram of a capture per phase.

**SCN-3 Colour script per phase** (fix F10, F11):
| Phase | Look | Target playfield luminance |
|---|---|---|
| First evening (45 s) | low warm sun, long shadows, amber sky — **not night** | 80–100 |
| Day (25 s) | full daylight within 2 s of dawn: sunlit stone, cool-green forest, fires **out** | ≥ 100 |
| Dusk (5 s) | orange → blue; lamps are lit one by one (a visible "lighting the lamps" beat) | 60–80 |
| Night | moonlit blue key, warm accents; element glows dominate | 45–60, road vs plot contrast ≥ 20 |
| Boss night | red-tinted moon and fog, heavier mist at the boss's gate | 40–55 |
| Night cleared (early dawn) | short pink-gold sunrise flash with the banner | — |
Fix `cycle_view` for evenings longer than `day_ticks` (BUG-24).

**SCN-4 Ground and geometry** (F12). Roads flush with the ground, light packed earth with plank/log
edging (as in the concepts), clearly lighter than plots. Plots are low stone pads (≤ 0.15 cell high);
no tall platform walls or arches between road and plots. Yards between plots: grass, wattle fences,
woodpiles, carts — low (≤ 0.4 cell) and dark so they never occlude enemies.

**SCN-5 Buildings.** Requirements for the author's future models (VIS-6) plus a placeholder pass now:
each existing model gets an element-coloured emissive core/orb or banner (GodSymbols colour, the only
saturated colour on it) and an element-coloured ring on its plot; models are lifted out of the pits;
level = material + height + roof ornament (4 distinct steps); tier III ×1.3 height. Small idle loops
(wind sails turn, flame flickers, water drips, sparks crackle) and a firing flash.

**SCN-6 Enemies.** ×1.4 scale at gameplay zoom; dark body with role-coloured eyes/rim (fast green,
heavy bronze, ward cyan shield, banner purple flag, boss red); walk cycle speed matched to movement;
0.5 s ash/smoke death; status marks (RX-10); the letter glyphs over enemies hidden by default (Alt).

**SCN-7 Focal structures** (F13). Terem larger with warm windows and a banner. **New gatehouse model**
where the roads converge in front of the terem; the hero stands at it; it shows damage (sparks/cracks
at 50% and 25% HP) and flashes on every breach (HER-1). Palisade dark wood — clamp warm light range
near the palisade so it is not orange. Each entrance has its own gate design (west main gate, north
forest gate with dead trees, south ford with a wooden landing), one lantern each; at dusk the gates
that will be used tonight pulse red.

**SCN-8 Environment storytelling** (docs/34 §3 TODO). Beyond the gates: dead/black trees, bone
totems, ground mist — the cursed land; the mist thickens with the night number. River with mist to the
south/east. The city looks warmer with city level (more lit windows, banners on the palisade).
The dead space between the last plots and the terem (F13) becomes the plaza with the idols (§8) and
inner plots of city level 4.

**SCN-9 Props and lights budget.** At most 3 decorative flames in frame besides the idols; real
lights: moon key, sky fill, 3 idol fires, terem windows, ≤ 3 gate lanterns; element cores are
emissive only; small lights cast no shadows.

**SCN-10 VFX language.** One projectile style per element (bolt arrow, fire-pot arc, ice shard,
lightning arc, curse wisp, water splash, wind streaks); hit flash in the element colour; reaction
burst = both colours + icon (RX-7), strong reactions add a small shockwave; boss rush leaves a dust
trail; breach = red shockwave at the gatehouse. All VFX ≤ 0.6 s except DoT marks.

**SCN-11 World-space UI.** HP bars, level pips, plot markers and range rings use the HUD palette;
no 1-px lines (rings 2–3 px with a soft glow); range rings fade at the edge instead of a hard line.

**SCN-12 Aspect ratios** (F14). The camera fits the city's bounding box into the free map area for
any aspect from 4:3 to 21:9; HUD anchors to the edges and never covers a gate or plot; minimum text
size 14 px at 1280×720 (scale UI by height).

**SCN-13 Acceptance.** (1) A side-by-side sheet: concept vs game at the same camera, per phase;
(2) the luminance targets of SCN-2/3 met on captures; (3) the road-occlusion test passes;
(4) the author approves.

---

## 12. Audio (AUD-1…AUD-3)
- AUD-1. The endless mode is silent today: `RitualBattleLayer.sound_requested` is emitted but never
  connected (only `FieldView`/`MatchScreen` own a `SoundBank`). Connect a `SoundBank` in
  `RitualTrialPanel`: shots (per projectile type, throttled), deaths, breach, merge/upgrade, buy,
  boss arrival, dawn/night stingers, UI clicks.
- AUD-2. Throttle: max N same sounds per 100 ms; reactions get one sound per burst.
- AUD-3. Ambience day/night and the settings volume sliders apply to this mode.

---

## 13. Bug list
| ID | Bug | Repro / evidence | Fix direction |
|---|---|---|---|
| BUG-01 | Can't cancel the chosen shop building with the mouse; Esc works but is undocumented; the "Отмена" button only cancels a move and prints "Нет незавершённого переноса" | §2.5 (input test) | UI-6, UI-7 |
| BUG-02 | Selected shop card not highlighted | screenshot 02 | UI-7 |
| BUG-03 | RMB on a building at night = rotate-move → building offline 20 s (400 ticks), by day 3 s | probe §2.6; `RitualTrialPanel._on_cell` → `RitualTrial._move` + `_lock(moving)` | NGT-2 |
| BUG-04 | Selling right after buying in the evening refunds only 50% | probe §2.6; `_sell` uses `sell_percent` in RUNNING | §4.3 undo window |
| BUG-05 | Rite cards in the shop carry the chip "чары" although enchantments are removed | screenshots 01/02 | label "заговор" / §8 |
| BUG-06 | Rite card for a god without a free idol still occupies a slot (dead card) | screenshot 08 ("Вольный ветер" with 3 idols dedicated) | §8 removes rite cards |
| BUG-07 | Idol name truncated ("Чернобо") | screenshot 04 | §8 removes HUD idols |
| BUG-08 | Message bar never expires; stale hints (buy hint after cancel/purchase; "Примета ночи 3" on night 5; dawn tribute text in the middle of night 15; record path on defeat) | screenshots 05, 06, 08, 09 | UI-12 |
| BUG-09 | "Осталось пачек: 0" while enemies are alive; scout icons are identical placeholder sprites | screenshots 04, 09 | UI-13 |
| BUG-10 | Clock shows total elapsed run time ("Ночь 15 · 28:42"), no countdown | all screenshots | UI-1 |
| BUG-11 | `reaction_flash.gd:55` draws a degenerate polygon when `t → 1` (`side` = 0) → "Invalid polygon data, triangulation failed" — 59 errors in the author's session log | `user://logs/godot.log` | skip the polygon when `1 − t` < ε or draw a line |
| BUG-12 | Level marks clamp at 3 (`arena_tower_3d.gd` `_add_level_rings`, `_add_level_marks`: `clampi(level, 1, 3)`) → L4 White stone indistinguishable from L3 | code | VIS-9 |
| BUG-13 | No sound in the endless mode (`sound_requested` not connected) | code | AUD-1 |
| BUG-14 | No breach feedback at all | live | HER-1 |
| BUG-15 | Wear invisible on the map; silent houses not signalled (8 silent at night 14) | replay | BLD-9 |
| BUG-16 | Dev UI exposed to the player: "Проверки", FPS counter, record path toast | screenshots | UI-5 |
| BUG-17 | Shop panel shrinks/reflows when cards are bought (layout jump) | screenshots 09 vs 01 | UI-3 |
| BUG-18 | Wind arrows always drawn, extend through the palisade | screenshots 03, 04 | VIS-8 |
| BUG-19 | Boss warning duplicates the god: "неуязвим: Война · Бог войны" | screenshot 04 | text fix |
| BUG-20 | `state_hash()` differs for the same state: pure replay 474912854, replay with the panel attached 699626009, live record 234756395, while typed snapshots (`var_to_str`) are identical. Likely cause: `RitualStateCodec.hash_value` sorts dictionary keys with `Array.sort()`; for `StringName` keys (e.g. `reaction_counts`, idol `purchases`) Variant `<` compares by pointer, so key order depends on allocation order | replay tool | sort keys by `str(key)` (+ type tag); add a test hashing a dictionary whose StringName keys were created in different orders; add "record → replay → equal hash" test |
| BUG-21 | Gifts can be irrelevant (elemental gift with no such buildings; "Два удара Ильи" for Solovey/Yaga) | data | BOS-2 |
| BUG-22 | Preview rotation persists after cancel | input test (`rot=1` after Esc) | reset on cancel (moot with plots) |
| BUG-23 | Floating damage numbers/reaction labels pile into unreadable clusters | screenshots 04, 05 | RX-7, RX-8 |
| BUG-24 | First ~20 s of every run are night-dark: `RitualNightRules.cycle_view` gives negative local time when the first evening (900 ticks) is longer than `day_ticks` (500) | F10, evidence 10 | SCN-3 |
| BUG-25 | Enemy statuses never drawn in the endless mode (`RitualBattleLayer._draw_mobs` is empty → `_draw_mob_overlay` skipped) | F4 | RX-10 |
| BUG-26 | Rime L3 is weaker per gold than L2 (data: `lvl_rime_3.extra_targets = 0`); Thunder L2 and Bolt L4 add nothing per gold | F5 | BLD-10 |
| BUG-27 | Wind/Water cards advertise the minor effect ("соседям темп +10%") and hide the major one (push-back) | F6 | BLD-12 |
| BUG-28 | Reactions suppress the second element's status while its enabler re-applies every shot (Infection blocks curse, Steam/Melt/Roast eat burn) → pairs deal less than solos | F2 | RX-9 |

---

## 14. Implementation phases (each phase: tests, full check, screenshot, decisions.md entry, commit)

Rules for every phase: `src/sim` stays node-free, integer, deterministic, command-driven; all
numbers in `.tres`; GUT tests for sim changes (bug first reproduced by a test); visuals verified by
capture (`--screen 1`); the old 4-day `trial.tres` and PvP keep working (their tests stay green).
After every phase the endless mode stays playable end to end with a mouse, so the author can
playtest it: balance is judged by live play, bots are only a guide (AGENTS.md).

**P0 — Tooling and quick fixes (no design decisions needed)**
- Add `tools/ritual_replay.gd` (appendix B): replays any `attempt_*.json`, prints per-dawn state,
  optional `--capture` of panel screenshots at given nights, `--hash` check.
- BUG-20 (hash), BUG-11 (polygon), BUG-01/02/22 (cancel + highlight), BUG-08 (toast expiry), BUG-10
  (countdown), BUG-16 (dev UI hidden), BUG-19, BUG-13 (sound hookup), BUG-14 (breach feedback),
  BUG-12 (4 level marks), BUG-18 (wind arrows on hover), VIS-1 (sharpen + 1:1 + A/B report),
  BUG-24 (first-evening darkness), BUG-25 (status marks on enemies), BUG-26/27 (level data and card
  texts). BUG-28 changes the reaction rules, so it is not a quick fix: it moves to P4.
- Add `tools/ritual_bench.gd` and `tools/ritual_whatif.gd` (appendix E) — every later phase reports
  their tables.
- Acceptance: replay of the 2026-11-12 record gives equal hashes with and without the panel; no
  errors in a 30-min autoplay log; author confirms cancel/countdown/sound.

**P1 — Difficulty and income model (sim only)**
- ECO-1, ECO-2, ECO-5, ECO-6, ECO-7, ECO-8; boss/omen normalisation.
- Acceptance: curve test passes for 5 seeds; kill gold per night monotonic; old tests updated.

**P2 — Building model** (after D1–D3)
- BLD-1…BLD-9, tier fill-in and tier III data, plots in sim (`RitualField` plots instead of regions),
  upgrade command (`RitualCommand.Action.UPGRADE`, `SPECIALISE`), sell undo window, remove
  merge/market for endless.
- Minimal UI in the current panel, so the new model can be played right after P2: the left shop
  column lists the fixed catalogue instead of the random shelf, free plots glow in placement mode,
  the current selection row gets "Улучшить · N" and "Продать". The full bottom dock stays in P5.
- Acceptance: tests for plot placement, upgrade costs/levels/gates, sell refunds, determinism; a
  bot can play 15 nights with the new commands; the author plays a full run with the mouse.

**P3 — City levels, entrances from 3 sides, alleys** (after D5, D6)
- MAP-1…MAP-5, ALY-1…ALY-3, new board resource, routes with turns, announcements.
- Acceptance: `test_ritual_streets` rewritten for city levels; capture of each city level.

**P4 — Reactions and statuses** (RX-1…RX-9, RX-12, BUG-28)
- Acceptance: reaction rate ≤ 4/s average in a late-night capture; reaction-aware vs
  reaction-blind bot A/B ≥ 25% damage difference; pair bench per RX-9; determinism tests; PvP and
  `trial.tres` tests pass without edits (RX-12).

**P5 — UI relayout and idols in the world** (UI-*, IDL-*, HER-1/2, BOS-1/3/4, SUP-1, NGT-1)
- Replaces the minimal UI of P2 with the bottom dock.
- Acceptance: one screen, no scrolling, at 1600×900, 1920×1080, 2560×1440 and the phone
  profile; every action reachable by mouse; screenshots for author review.

**P6 — Visual polish and scene art direction** (VIS-2…VIS-10, SCN-1…SCN-13, AUD-2/3)
- Order: SCN-3 lighting by phase → SCN-4 ground/geometry → SCN-2 light budget (bowls out, idols in)
  → SCN-1 camera → SCN-5/6 placeholder pass on buildings/enemies → SCN-7 gatehouse/gates → SCN-8
  storytelling → SCN-10 VFX. Each step: capture per phase + luminance numbers + side-by-side with the
  concept.

**P7 — Balance pass**
- Update `tools/ritual_endless_probe.gd` to the new commands with 3 policies (passive, reasonable,
  reaction-aware), 10 seeds × 3 heroes; report the §3 targets table; then live playtests by the
  author with the replay tool reading his records. Numbers are tuned by the author.

---

## 15. Decisions for the author

Author status (2026-11-12 to 2026-11-13): **D1 approved** - fixed catalogue, plots and click-upgrades for gold;
no random building shelf or copy merging in endless. **D2 approved** - two specialisations for
every building, chosen at level 3. **D3 approved** - keep wear with visible condition and convenient
repair. **D4 approved** - choose 1 of 3 small boons at every dawn; boss gifts stay separate.
**D5 approved** - city level 4 with inner plots, more hero max HP and a fourth idol pedestal;
numbers remain placeholders. **D6 approved** - shortcut alleys, fast-enemy route preference and
player barricades; scout shows alley users. **D7 approved** - a free god-specific effect for each
idol at each of 5/10/15 invested rites; exact effects and strength remain open.
**D8 approved** - 10 starting plots with at least one empty cell between buildings; initial
progression for playtesting is 10/16/22/26 plots. D1/D2/D3 and the first three city levels' plots
are implemented in P2; the fourth city level belongs to P3. D4/D5/D6/D7 await their phases.
**D9 deferred by the author** - revisit paid hero ranks after P7 only if gold still piles up.
**D10 approved** - keep +50% night surcharge and 12 s install; yellow price, red upward arrow,
hover tooltip with a short explanation about calling builders at night. Implemented for catalogue
prices and upgrades. **D11 approved** - important damage numbers only by default: strong reactions,
crits and boss damage. New display mode is not implemented. **D12 approved (2026-11-13)** -
FSR2 by default, option C from the saved P0 crops. The new endless desktop profile uses FSR2;
motion validation remains pending. Legacy/PvP and the mobile rendering profile keep their defaults.
**D13 approved (2026-11-13)** - fixed camera, full city visible on one screen; phones are the likely
target. The current camera stays fixed; new city framing belongs to P6. **D14 approved (2026-11-13)** -
expert balance target of night 20-22, with no forced ending. All D1-D14 have author answers;
D9 remains deferred until after P7 if gold still piles up. P2 and subsequent phases may proceed.

| ID | Question | Recommended | Alternatives |
|---|---|---|---|
| D1 | How are buildings acquired? | Fixed catalogue + plots + click-upgrades; no merge, no building shop RNG (§4) | B: keep random shelf but upgrades by click (copies not needed); C: keep current merge with a "pity" guarantee |
| D2 | Specialisation choice at L3? | Yes, two branches per building | No branches (fewer data/tests) |
| D3 | Wear and repair? | Approved: keep wear, visible condition and convenient repair (§4.5) | Earlier proposal: remove wear |
| D4 | Roguelike variety source | Approved: every dawn choose 1 of 3 small boons; boss gifts stay separate | Every 2nd dawn / small random boon market with 2 rerolls/day |
| D5 | City level 4 | Approved: "Белокаменный детинец", inner plots, hero HP, 4th idol | Only 3 levels |
| D6 | Alleys | Approved: shortcuts used by fast enemies + player barricades | Remove alleys |
| D7 | Idol milestones at 5/10/15 rites | Approved: a free god-specific effect at each milestone for each idol | Plain infinite rites |
| D8 | Plot count and spacing | Approved: 10 at start, minimum 1-cell gaps; initial progression 10/16/22/26 | Denser (14 at start) |
| D9 | Hero ranks as a gold sink | Deferred: revisit after P7 if gold still piles up | Never |
| D10 | Night building surcharge | Approved: +50% / 12 s; yellow price, red upward arrow and lore tooltip | Daytime terms at night |
| D11 | Damage numbers default | Approved: important only (strong reactions, crits, boss damage) | All / none |
| D12 | AA default | Approved: FSR2, option C from P0 comparison crops (2026-11-13) | TAA / TAA with sharpening |
| D13 | Camera zoom/pan | Approved: fixed full-city view; likely phone target | Earlier proposal: user zoom/pan |
| D14 | Expert run length (§3, ECO-5) | Approved: night 20-22 as the expert balance target; no forced ending | Night 25-30: needs a late multiplicative lever (idol milestones D7 or similar) or a smaller late gap between enemy and income growth |

After approval: update `AGENTS.md` (endless-mode layout rule, shop rule "мало случайных карточек и
платное «Обновить»", merge), `docs/CURRENT_RULES.md`, `decisions.md` (author's choices, reversing
docs/34 §2 merge-as-material, §5 wear, §13 random shop), `open_questions.md`, `memory/CURRENT.md`.

---

## 16. Appendices

### A. Data and code map (current)
- Rules: `data/ritual/endless.tres` (`RitualTrialConfig`), `data/ritual/combat_catalogue.tres`
  (21 copied towers from `data/ritual/buildings/`, unchanged reaction references, four levels and
  two branches), `RitualPlot`, `RitualSpecialisation`, `RitualTower`; historical
  `combat_endless.tres` and test fixtures retain the previous building rules. Nights
  `RitualNightRules` sub-resource, streets
  `street_upper/lower`, heroes, gifts, omens, rite curves; board `data/ritual/board_city.tres`.
- Sim: `src/sim/ritual/ritual_trial.gd` (commands, economy, dawn, gifts, supplies, hero),
  `ritual_field.gd` (routes, level behaviour, wear, splash), `ritual_night_plan.gd` (generator),
  `ritual_pack.gd`, `ritual_state_codec.gd` (snapshot/hash).
- UI: `src/ui/ritual_trial_panel.gd` (layout, input, messages), `ritual_shop_panel.gd`,
  `ritual_match_hud.gd`, `ritual_idol_slot.gd`, `ritual_scout_queue.gd`.
- View: `src/view/ritual_board.gd` (2D overlay: selection, preview, mobs glyphs, rings),
  `ritual_stage_3d.gd`, `ritual_arena_3d.gd` (fire bowls `_build_fires`/`_corner_bowls`),
  `ritual_daylight.gd`, `ritual_battle_layer.gd`, `arena_stage_3d.gd`, `render_quality.gd`,
  `arena_tower_3d.gd` (level marks), `reaction_flash.gd`.
- Tests: `tests/unit/test_ritual_catalogue.gd` (active P2 model), `test_ritual_endless.gd` and
  `test_ritual_streets.gd` (historical fixtures), `test_ritual_trial.gd`,
  `test_ritual_panel_regressions.gd`; tools `ritual_endless_probe.gd`, `ritual_trial_smoke.gd`.

### B. Replay tool core (to become `tools/ritual_replay.gd`)
The record stores every command with its tick; cells are serialised as `"(x, y)"`. Hero index is
not stored — add `hero_index` to `RitualTrialRecord.build_report` (the 2026-11-12 run was Solovey =
1, inferred from "Соловей пал").
```gdscript
var trial := RitualTrial.new(settings, 0, int(summary["seed"]), hero_index)
while trial.phase == RitualTrial.Phase.RUNNING:
	while next < commands.size() and int(commands[next]["tick"]) == trial.tick_count:
		var entry: Dictionary = commands[next]
		var xy: PackedStringArray = String(entry["cell"]).trim_prefix("(").trim_suffix(")").split(",")
		trial.execute(RitualCommand.new(int(entry["action"]), int(entry["item"]),
			Vector2i(int(xy[0]), int(xy[1])), int(entry["rotation"]), int(entry["tower_id"]),
			int(entry["progress"])))
		next += 1
	trial.tick()
```
Notes: scripts outside `src/` need `@warning_ignore_start(...)` for JSON Variant casts (project
warnings are errors); a replay that ends in defeat with the panel attached writes a new
`attempt_*.json` — tools must disable `_save_result` or clean up.

### C. Night curve tool
`total_hp`, `total_gold` of `RitualNightPlan` per night for several seeds (table §2.3) — keep as
`tools/ritual_curve.gd` and use it in ECO-8.

### E. Bench and what-if tools (prototypes exist as session scripts; port into `tools/`)
- `tools/ritual_bench.gd`: builds a bare `RitualField` (no trial → no breach/defeat), places
  buildings by id/level/anchor next to the main road (P2 plots (12,8) and (14,8); historical
  anchors (12,9) and (14,9)), keeps `durability = -1` (no wear), spawns a scenario stream with
  `field.spawn_mob(enemy, hp_percent)` and drives `prepare_tick / fire_trial_towers / finish_tick`
  for 1500 ticks; damage is summed from `hit_observed` (`hp_damage + ward_damage`). Outputs: solo
  table per level/branch/scenario, support table next to two attackers of the same tier,
  pair-synergy table (§2.7 F2, F5, F6). Cost is cumulative purchases/upgrades in P2 and merge
  copies for historical rules. BLD-10 is tested against the same timed combat, including statuses.
- `tools/ritual_whatif.gd`: replays a record to the dusk before night N, takes `snapshot()`, and for
  each variant `RitualTrial.from_snapshot()` → modify (remove a building group, add a gift, buy rites,
  disable reactions, auto-cast hero skill) - play the night without commands or new boss gifts - HP lost, damage,
  reactions, enemies left. Note: change the shared rules (e.g. `combat.reactions`) only **after**
  `from_snapshot`, which checks `rules_hash`. Gift-selection pauses are skipped without granting
  a gift so every variant reaches dawn. The state hash uses the rules fingerprint, not the source
  resource path: loading and duplicating identical rules must give the same state hash.
- `tools/ritual_curve.gd`: §2.3 table.

### D. Evidence files
`docs/reports/2026-11-12_gorodishche_audit/`: 01 evening (fire bowls, empty city), 02 buy mode (no
card highlight, no cancel hint), 03 selection (weak outline, no same-type highlight), 04 night 14
(clutter, wind arrows, scout icons), 05 night 15 (collapse, HP 9), 06 defeat screen, 07 1:1 crop
(softness), 08 night 13 buy mode (dead rite card, reroll 27, scattered free cells), 09 night 1
("осталось пачек: 0" with enemies alive, shop shrunk to one card, stale buy hint), 10 first evening /
brightest day / night side by side (luminance 42 / 69 / 47), 11 1:1 close-ups (terem without
gatehouse, gate, sunken roads hiding enemies, label clutter, dark element-less buildings),
12 1920×800, 13 1440×959 (4:3).
Note: damage numbers in 03–05 are from the live-speed tail of each capture, not from fast-forward.
