# Entropy Sudoku

This Community Script V1 reference package implements the global
Entropy rule: every adjacent 2x2 window contains at least one digit from each
band, 1-3, 4-6, and 7-9.

`main.lua` owns the fixed windows, digit bands, exact partial feasibility and
candidate-elimination observations. The Host owns board mutation, candidates,
notes, persistence, progress and UI. The rule has no Overlay or mutable state.

The package contains five local difficulty tracks with 10 puzzles each.
