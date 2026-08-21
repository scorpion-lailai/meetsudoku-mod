# Composite Sudoku

This Community Script V1 package is the technical reference sample and the
completed 50-puzzle Mod bank for Composite Sudoku.

Rule summary:

- Cells marked with `C` may contain only composite digits.
- The composite digits are `4`, `6`, `8` and `9`.
- `1` is neither prime nor composite and is not allowed on a marked cell.
- Unmarked cells have no additional Composite rule restriction.

Host ownership:

- The Host owns board state, input transactions, candidates, notes, completion,
  save/recovery, navigation and rendering.
- Lua owns only the Composite rule semantics, candidate-elimination projection
  and static composite-mark overlay declarations.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
