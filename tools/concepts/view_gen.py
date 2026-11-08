"""Недостающие ракурсы для моделирования: один вид на кадр.

python3 -I tools/concepts/view_gen.py <группа> <id> <side|back> [--seed N]
Результат: new_concept/views/<id>_<вид>_<seed>.png. Описание то же, что у основного концепта.
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import redesign_gen as rg  # noqa: E402

VIEWS = {
    "side": "strict side profile view from the left, orthographic-like, ",
    "back": "back view from behind, ",
}


def main() -> None:
    args = sys.argv[1:]
    seed = 16
    if "--seed" in args:
        seed = int(args[args.index("--seed") + 1])
        del args[args.index("--seed"):args.index("--seed") + 2]
    group, item_id, view = args
    item = next(i for i in rg.GROUPS[group][0] if i[0] == item_id)
    prompt = rg.prompt_for(group, item).replace("front three-quarter view, ", VIEWS[view])
    if VIEWS[view] not in prompt:
        prompt = VIEWS[view] + prompt
    size = (768, 1024) if group in ("heroes", "units", "idols") else (1024, 1024)
    rg.generate(prompt, size[0], size[1], seed, rg.OUT / "views" / f"{item_id}_{view}_{seed}.png")


if __name__ == "__main__":
    main()
