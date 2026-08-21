# X-Sums Sudoku

This is a minimal Community Script V1 reference package for X-Sums Sudoku.

Rule summary:

- Each outside clue applies to one oriented row or column.
- The first digit nearest the clue is `X`.
- The first `X` cells from that side must sum to the outside clue.

This package contains a lightweight repository reference bank:

- It does not claim official difficulty or publication-quality dataset evidence.

Host ownership:

- The Host owns board state, input transactions, candidates, notes, completion,
  save/recovery, navigation and rendering.
- Lua owns only the X-Sums rule semantics, candidate-elimination projection and
  static boundary-label overlay declarations.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
