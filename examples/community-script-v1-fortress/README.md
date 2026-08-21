# Fortress Sudoku

Rule summary:

- Every shaded cell is greater than each orthogonally adjacent unshaded cell.
- Same-shading and diagonally touching cells have no Fortress relationship.
- Puzzle JSON owns only `shaded_cells`; Lua derives every boundary pair.

Implementation notes:

- One shared pair-feasibility function powers move, board, candidate and final
  validation.
- Candidate scope contains only endpoints of derived boundary pairs.
- Shaded cells are packed into bounded custom filled paths with opacity `0.32`.
- The bank contains 50 puzzles in five package-local difficulties, 10 per difficulty.

Host ownership:

- The Host owns board mutation, candidates, notes, input transactions,
  completion flow, persistence, progress and rendering.
- Lua owns only the Fortress rule meaning, bounded validation observations and
  static Overlay declaration.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
