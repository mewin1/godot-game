# Шрифты интерфейса

Выбор автора 15 ноября 2026 (critique.md п. 17): пара Kurale + Fira Sans. Оба шрифта — SIL Open
Font License 1.1 (текст лицензии — `OFL.txt` в папке каждого), с кириллицей; лежат в репозитории,
чтобы игра работала без сети.

| Файл | Где | Источник |
|---|---|---|
| `kurale/Kurale-Regular.ttf` | заголовки: «Ночь 3», баннеры, имя героя, карточки усилений | github.com/google/fonts, `ofl/kurale` |
| `fira_sans/FiraSans-Regular.ttf` | подписи, подсказки, кнопки | github.com/google/fonts, `ofl/firasans` |
| `fira_sans/FiraSans-SemiBold.ttf` | числа (золото, HP, цены, таймер) | github.com/google/fonts, `ofl/firasans` |

Подключение — `DuskTheme.create()` (src/ui/dusk_theme.gd).
