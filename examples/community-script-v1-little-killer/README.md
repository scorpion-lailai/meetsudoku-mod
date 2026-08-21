# Little Killer Sudoku

This API 5 reference package demonstrates a fixed diagonal-sum Script V1 rule
and the generic `outside_ray_clue` Overlay primitive.

The package owns ray normalization, partial-sum validation, candidate scope,
completion observations and Overlay declarations in `main.lua`. The Host owns
classic Sudoku legality, board mutation, candidate/note state, persistence and
painting.

All clues use the fixed `edge_fixed_v1` direction table:

- top entries point `down_left`;
- right entries point `up_left`;
- bottom entries point `up_right`;
- left entries point `down_right`.

This keeps each edge parallel and keeps the two directions at every board
corner different, avoiding converging arrows and labels.
