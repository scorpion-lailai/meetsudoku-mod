# Sandwich Sudoku

This package is the Script V1 Sandwich Sudoku reference Mod.

- `rules.sandwich` activates the Lua handler;
- `rules.sandwich.clues` contains only puzzle-owned axis, index and sum;
- each clue equals the sum of the digits strictly between 1 and 9 in its row or column;
- omitted rows and columns add no negative constraint;
- validation, candidate elimination and final-state checks share one exact partial-feasibility test;
- `build_overlay` emits one Host-owned `boundary_label` primitive per clue;
- row labels normalize to the left edge and column labels to the top edge;
- duplicate logical rows or columns are rejected.

The single `puzzle_bank.json` contains 50 puzzles grouped into five local
difficulties, ten per difficulty.
The Host owns classic Sudoku rules, board mutation, input, notes, completion,
progress, persistence and rendering.

## 中文说明

这个包是 Script V1 三明治数独参考 Mod。

- `rules.sandwich` 激活 Lua handler；
- `rules.sandwich.clues` 只保存每题自己的轴、序号与和值；
- 每个提示等于对应行列中严格位于数字 1 与 9 之间的数字之和；
- 没有提示的行列不增加负约束；
- 规则校验、候选删除和完成判定复用同一个精确部分可满足性判断；
- `build_overlay` 为每个提示输出一个 Host-owned `boundary_label` primitive；
- 行提示固定投影到左边界，列提示固定投影到上边界；
- 重复声明同一行列会被拒绝。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
