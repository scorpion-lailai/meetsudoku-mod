# Position Sums Sudoku

For each directed row or column, the first two digits are `A` and `B`.
The first outside clue is the sum `A + B`. The second outside clue is the sum
of the digits at positions `A` and `B` in that same direction.

The rule is declared in `main.lua`. Puzzle data supplies only the directed
clue geometry and its two values. The example also shows how one rule can
produce two aligned outside-clue labels for the same row or column.
