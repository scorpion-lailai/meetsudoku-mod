# Friendly Sudoku

A cell is friendly
when its digit equals its one-based row, column, or box number; puzzle data
provides only the required total.

The package derives every coordinate attribute in `main.lua`, validates partial
upper/lower count bounds and the completed exact count, and emits one generic
`board_level_numeric_clue`. Its existing board validation also reports the
currently filled friendly cells through the generic `board_rule_observation`
surface; the game displays the marked cells using the fixed outline.

Use this example when one board-wide target is defined by properties of the
cells themselves rather than by a path, region, or pair of cells.
