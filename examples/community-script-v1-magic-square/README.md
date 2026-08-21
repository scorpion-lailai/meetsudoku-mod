# Magic Square Sudoku

`rules.magic_square.box` contains one row-major classic-box index in `0..8`.
`main.lua` validates that index, derives the aligned nine cells, emits the three
row, three column, and two main-diagonal sums equal to 15, and builds the region
Overlay from the same normalized model. The Host compiles the eight typed
predicates once and runs the Native Constraint Program during gameplay; the Mod
does not register gameplay Lua callbacks.
