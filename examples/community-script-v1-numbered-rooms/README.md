# Numbered Rooms Sudoku

Each puzzle clue is `{side, index, digit}`. Lua validates the bounded clue list,
derives the ordered nine-cell line from the edge, and emits one
`equal(element_at(line, value(first_cell)), constant(digit))` constraint per
clue, including independent left/right clues.

The same normalized clues produce generic `boundary_label` Overlay IR, so each
clue digit appears on its actual board edge without changing the 9x9 layout.
The Host materializes the startup predicates into the Native Rule Graph and
owns validation, candidates, conflicts, note cleanup, completion, persistence
and presentation. The package contains no runtime Lua callback or
variant-specific Host branch.

Each puzzle provides only its edge clues. The line construction, constraint and
matching label are derived from the same normalized clue in `main.lua`.
