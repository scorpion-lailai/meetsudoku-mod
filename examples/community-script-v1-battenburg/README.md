# Battenburg Sudoku

This Community Script V1 reference package demonstrates a complete Battenburg
rule implementation. A marked internal intersection requires its surrounding
2x2 cells to be an odd/even checkerboard. An unmarked intersection forbids the
same completed pattern.

`main.lua` owns the rule semantics, partial-feasibility checks, candidate
elimination observations and static intersection Overlay. The Host owns board
mutation, candidates, notes, persistence, progress and UI.
