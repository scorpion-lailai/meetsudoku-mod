# Intersection Sum Sudoku

Each number at an internal intersection is the exact sum of the four cells
touching it. Unmarked intersections impose no extra rule.

`rules.intersection_sum.clues` contains the marked intersections and their
targets. `main.lua` validates each clue, derives its four touching cells, and
checks the exact sum while the puzzle is being solved.
