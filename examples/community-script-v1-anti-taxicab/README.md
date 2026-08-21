# Anti-Taxicab Sudoku

In addition to the normal Sudoku rule, a digit `X` cannot appear again in a
cell whose Manhattan distance from it is exactly `X`.

For example, two `4`s cannot be four orthogonal steps apart. Diagonal steps do
not count toward that distance.

## Package structure

- `main.lua` derives the complete fixed Anti-Taxicab rule for the 9×9 board.
- `puzzle_bank.json` provides five difficulties with ten puzzles each.
- Each puzzle activates the fixed rule with an empty `anti_taxicab` object; it
  does not repeat the rule relation in puzzle data.

Use this example when a fixed board-wide rule is derived once in `define()`,
while individual puzzles only provide their grid and solution.
