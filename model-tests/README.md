# Model tests (8 Oct 2026)

Haiku 5.5, Sonnet 5.5 and Opus 5.5 got the same Unbound tasks. Nothing here is part of the game: these files are only stored on this branch, and the game itself is unchanged.

## bakery/
A village bakery built with a Blender script. Only the screenshots survive; the code was lost.

## pyromancer/
- The **Phoenix Wings** ability (`phoenix-*.png`) and the **Ashen Pyromancer** character (`character-*.png`).
- `haiku.patch`, `sonnet.patch` and `opus.patch` hold each model's full code. They are not applied to the game.
- To try one later, from the repo root: `git apply model-tests/pyromancer/opus.patch`. Then use `--phoenix` to cast the ability and `--lineup` to see the character.

| Task | Haiku | Sonnet | Opus |
|---|---|---|---|
| Bakery | 17 min, 188k tokens | 7 min, 106k | 12 min, 125k |
| Pyromancer | 17 min, 179k | 20 min, 146k | 18 min, 159k |
