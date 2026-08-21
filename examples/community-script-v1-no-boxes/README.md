# No Boxes Sudoku

It keeps the standard nine
rows and nine columns and removes the standard 3x3 box houses.

The package uses the startup-only materialized route. Lua validates the fixed
81-cell topology and returns a generic `base_topology` declaration; the Host
materializes it before gameplay. There are no runtime Lua callbacks, package-ID
branches, or custom rendering primitives.

Each solution is row/column-valid but
intentionally repeats digits in standard 3x3 boxes, proving that the replacement
topology is active.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
