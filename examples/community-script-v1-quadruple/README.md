# Quadruple Sudoku

This package is the Script V1 Quadruple Sudoku reference Mod.

- `rules.quadruple` activates the Lua handler.
- `rules.<handler>.clues` stores puzzle-owned intersection geometry and digits.
- The rule treats clue digits as a required multiset, including repeats.
- Candidate elimination checks the total missing multiplicity against the
  remaining empty cells.
- Each clue emits one circle and one multiline text Overlay primitive.

The Host retains ownership of the board, input, candidates, completion,
persistence, progress and UI.

## 中文说明

- `rules.quadruple` 激活 Lua handler。
- `rules.<handler>.clues` 保存每题自己的交点位置和提示数字。
- 规则把提示数字作为必含多重集，重复数字按出现次数计算。
- 候选过滤比较全部缺失次数与剩余空格数。
- 每条提示只生成一个圆和一个多行文字 Overlay primitive。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
