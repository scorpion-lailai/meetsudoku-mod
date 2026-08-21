# Consecutive Sudoku

This package demonstrates a complete Script V1 Consecutive Sudoku mod. Only
explicitly marked orthogonal edges are constrained.

- `rules.consecutive` activates the Lua handler;
- `rules.<handler>.marks` contains puzzle-owned marked orthogonal edges;
- marked edges require the two digits to differ by exactly 1;
- `get_candidate_eliminations` returns removals only and never replaces Host candidates;
- `build_overlay` emits a declarative hollow circle for every marked edge.

Host still owns board state, input transactions, undo, notes, save/load,
progress, completion, conflict UI and rendering.

## 中文说明

这个包是完整的 Script V1 连续数独示例。只有题面明确标记的正交边受到约束。

- `rules.consecutive` 只负责选择 Lua handler；
- `rules.<handler>.marks` 保存每题自己的正交相邻标记边；
- 标记边表示两格数字之差必须为 1；
- `get_candidate_eliminations` 只返回要删除的候选，不接管 Host 候选系统；
- `build_overlay` 为每条标记边返回声明式空心圆，真正渲染仍由 Host 完成。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
