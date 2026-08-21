# Kropki Sudoku

This package demonstrates a complete Script V1 Kropki Sudoku mod.

- `rules.kropki` activates the Lua handler;
- `rules.<handler>.marks` contains puzzle-owned marked orthogonal edges;
- white/consecutive dots require the two digits to differ by 1;
- black/ratio2 dots require one digit to be exactly twice the other;
- `get_candidate_eliminations` returns removals only and never replaces Host candidates;
- `build_overlay` emits declarative circle primitives for white/black Kropki dots.

Host still owns board state, input transactions, undo, notes, save/load,
progress, completion, conflict UI and rendering.

## 中文说明

这个包是完整的 Script V1 黑白点数独示例。

- `rules.kropki` 只负责选择 Lua handler；
- `rules.<handler>.marks` 保存每题自己的正交相邻标记边；
- 白点 / consecutive 表示两格数字差 1；
- 黑点 / ratio2 表示一格数字是另一格的 2 倍；
- `get_candidate_eliminations` 只返回要删除的候选，不接管 Host 候选系统；
- `build_overlay` 只返回声明式圆点 primitive，真正渲染仍由 Host 完成。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
