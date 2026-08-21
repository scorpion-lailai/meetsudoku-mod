# Beacon Sudoku

Beacon Sudoku starts with selected cells covered. Every placement reveals part
of the board; a correct placement reveals more than an ordinary one.

`rules.beacon.covered_cells` contains only the puzzle-specific initial mask.
`main.lua` validates that geometry against the puzzle givens, then derives the
fixed Beacon rule: every committed placement reveals an orthogonal radius-one
cross, and a correct placement additionally reveals the four diagonal cells of
the king-radius-one square. A correct placement therefore reveals the full 3x3
square while an ordinary placement reveals only the cross. The game applies
those declared changes and keeps the resulting board state.
