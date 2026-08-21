# Dutch Whispers Sudoku

This package demonstrates a complete Script V1 Dutch Whispers Sudoku mod.

- `rules.dutch_whispers` activates the Lua handler;
- `rules.<handler>.paths` contains puzzle-owned orthogonal cell paths;
- a cell belongs to exactly one path; paths must not overlap;
- every adjacent pair on a path must differ by at least 4;
- `get_candidate_eliminations` returns removals only;
- `build_overlay` emits a declarative orange polyline for every path.

The Host owns board state, input transactions, candidates, completion,
persistence, conflict UI and rendering.

## 中文说明

这个包是完整的 Script V1 荷兰耳语数独示例。

- `rules.dutch_whispers` 选择 Lua handler；
- `rules.<handler>.paths` 保存每题自己的正交相邻路径；
- 每个格子只能属于一条路径，路径之间不能重叠；
- 路径上每一对相邻数字之差至少为 4；
- `get_candidate_eliminations` 只返回候选删除建议；
- `build_overlay` 为每条路径返回声明式橙色折线。

棋盘、输入事务、候选、完成判定、存档、冲突 UI 和渲染仍由 Host 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
