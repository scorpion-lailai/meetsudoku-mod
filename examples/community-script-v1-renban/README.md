# Renban Lines Sudoku

This package is the Script V1 Renban Lines Sudoku reference Mod.

- `rules.renban` activates the Lua handler;
- `rules.renban.lines` contains only puzzle-owned line geometry;
- Renban lines must not share cells or cross one another;
- digits on each line are distinct and form a consecutive set in any order;
- validation and candidate elimination share the same partial-feasibility test;
- `build_overlay` emits one declarative purple polyline per Renban line.
- The reference package chooses `0.6` for its Renban polyline; this is styling,
  not a Host cap for path rules.

The package contains 50 reference puzzles in `puzzle_bank.json`, grouped into five
package-local difficulty levels with ten puzzles each.
The Host owns classic Sudoku rules, board mutation, input, notes, completion,
progress, persistence and rendering.

## 中文说明

这个包是 Script V1 连数线数独参考 Mod。

- `rules.renban` 激活 Lua handler；
- `rules.renban.lines` 只保存每题自己的线条几何；
- 连数线之间不能共享格子，也不能互相穿越；
- 每条线上的数字互不重复，并能以任意顺序组成一组连续数字；
- 规则校验和候选删除复用同一个部分盘面可满足性判断；
- `build_overlay` 为每条连数线输出一条声明式紫色折线。
- Reference package 为连数线选择 `0.6` 透明度；这是样式选择，不是路径规则的 Host 上限。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
