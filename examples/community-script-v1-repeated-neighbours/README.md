# Repeated Neighbours Sudoku

Every cell is part of a gray/white partition. A gray cell requires at least one
equal pair among its orthogonally adjacent neighbours. An unshaded cell requires
all of its orthogonally adjacent neighbours to be different. The center cell's
own digit is not compared.

`rules.repeated_neighbours.shaded_cells` contains only the puzzle-varying gray
cells. `main.lua` derives the unshaded complement, every bounded orthogonal
neighbourhood, move and board validation, candidate eliminations, final-state
validation, and the gray-cell fill overlay.
