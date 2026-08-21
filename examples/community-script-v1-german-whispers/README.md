# German Whispers Sudoku

This package demonstrates a complete Script V1 German Whispers Sudoku mod.

- `rules.german_whispers` activates the Lua handler;
- `rules.<handler>.paths` contains puzzle-owned orthogonal cell paths;
- every adjacent pair on a path must differ by at least 5;
- `get_candidate_eliminations` returns removals only;
- `build_overlay` emits a declarative green polyline for every path.

The Host owns board state, input transactions, candidates, completion,
persistence, conflict UI and rendering.

## 中文说明

这个包是完整的 Script V1 德国耳语数独示例。

- `rules.german_whispers` 选择 Lua handler；
- `rules.<handler>.paths` 保存每题自己的正交相邻路径；
- 路径上每一对相邻数字之差至少为 5；
- `get_candidate_eliminations` 只返回候选删除建议；
- `build_overlay` 为每条路径返回声明式绿色折线。

棋盘、输入事务、候选、完成判定、存档、冲突 UI 和渲染仍由 Host 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
