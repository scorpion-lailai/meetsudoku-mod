# Region Sum Lines Sudoku

This reference package contains a 50-puzzle Region Sum Lines bank with five
package-local difficulties and ten puzzles per difficulty. Puzzle JSON stores
only orthogonal paths. `main.lua` validates and splits each path at standard
3x3 box boundaries, then emits generic
`equal(sum(segment A), sum(segment B))` predicates and a path Overlay.

Its public rule
identity follows the Region Sum Line definition in
[Sudoku Coach Construct](https://sudoku.coach/en/construct).
