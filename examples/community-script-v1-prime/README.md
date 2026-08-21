# Prime Sudoku

This is a minimal Community Script V1 reference package for Prime Sudoku.

Rule summary:

- Cells marked with `P` may contain only prime digits.
- The prime digits are `2`, `3`, `5` and `7`.
- Unmarked cells have no additional Prime rule restriction.

Dataset evidence:

Host ownership:

- The Host owns board state, input transactions, candidates, notes, completion,
  save/recovery, navigation and rendering.
- Lua owns only the Prime rule semantics, candidate-elimination projection and
  static prime-mark overlay declarations.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
