# Arrow Sudoku

This package is a **Community Variant Script API V1** reference implementation
for Arrow Sudoku. The arrow rule is real Lua logic, not a declarative API 4
program:

- `rules.arrow` activates the registered handler;
- `rules.<handler>.arrows` stores puzzle-owned circle heads and ordered paths;
- every filled arrow is checked with `head = sum(path)`;
- partial arrows remain undetermined until enough information exists;
- `get_candidate_eliminations` removes candidates that cannot satisfy the
  target sum;
- `build_overlay` returns Host `arrow` primitives.

The author owns Arrow semantics and puzzle geometry. The App still owns board
state, classic Sudoku validation, move transactions, candidate display,
conflicts, notes, undo, save/load, completion and UI rendering.

中文说明：这是一个真正由 Lua 编写箭头数独规则的 Script V1 示例。圆头数字
必须等于箭头路径数字之和；题目数据只提供每条箭头的几何和圆头位置，Lua
负责校验和候选删除建议，App 负责游戏生命周期和绘制。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
