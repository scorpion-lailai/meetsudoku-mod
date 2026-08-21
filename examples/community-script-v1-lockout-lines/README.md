# Lockout Lines Sudoku

This is a Community Variant Script API V1 reference implementation. It uses a
scripted validator to enforce the fixed endpoint-exterior rule, derives
candidate scope from declared paths, and renders diamond endpoints with generic
Overlay IR.

Each orthogonal line has two diamond endpoints. Their digits differ by at least
four. Every interior digit must be strictly outside the open interval between
the endpoint digits.

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
