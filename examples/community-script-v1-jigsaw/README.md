# Jigsaw Sudoku

This package demonstrates irregular-region logic written by a Script V1
author:

- `rules.jigsaw_regions` activates the handler;
- `rules.<handler>.regions` contains nine puzzle-owned regions; each region
  only needs a `cells` list, and the Host derives stable region IDs when
  omitted;
- `base_topology` stores the same nine regions as a generic replacement
  topology semantic object for Host materialization;
- `validate_move` and `validate_board` enforce all-different inside each
  irregular region;
- `get_candidate_eliminations` removes digits already used in the region;
- `validate_final_state` reports region validity;
- `build_overlay` emits declarative region-boundary line primitives.

Important boundary: Script V1 owns the author-readable Jigsaw semantics and
validates puzzle-owned region data. The Host promotes the generic
`base_topology` object into native replacement topology before gameplay starts,
so classic 3x3 boxes are replaced by the nine irregular regions for placement,
conflicts, candidates and completion. Host capability selection does not depend
on the `jigsaw_regions` handler ID.

The App still owns board state, row/column/region rules, move transactions,
candidates, conflicts, notes, undo, save/load, completion and rendering.

中文说明：这个示例把不规则区域的全异逻辑写在 Lua 中，并返回区域边界 Overlay。
每个区域只需要提供 `cells`，省略 `id` 时 Host 会生成稳定区域 ID。Host 会把通用
`base_topology` 数据提升为 native 替代拓扑，因此经典 3x3 宫会被九个锯齿宫替代。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
