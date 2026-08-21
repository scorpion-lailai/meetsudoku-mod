# Between Lines Sudoku

This package is the Script V1 Between Lines Sudoku reference Mod.

- `rules.between_lines` activates the Lua handler;
- `rules.between_lines.lines` contains only puzzle-owned line geometry;
- the first and last cells of each path are endpoint circles;
- every interior digit is strictly between the two endpoint digits;
- interior digits need not be ordered, consecutive or distinct beyond classic rules;
- lines must not share cells or cross one another;
- validation and candidate elimination reuse the same partial-feasibility test;
- a full-board candidate batch reuses normalized board values and a boolean-only
  feasibility path under the production instruction budget;
- `build_overlay` emits a polyline followed by two endpoint circles per line;
- the reference package chooses opacity `0.6` for its line and endpoint circles;
  this is styling, not a Host cap for edge/path rules.

The package contains 50 reference puzzles in `puzzle_bank.json`, grouped into
five package-local difficulty levels with ten puzzles each. The Host owns classic Sudoku
rules, board mutation, input, notes, completion, progress, persistence and
rendering.

## 中文说明

这个包是 Script V1 线间数独参考 Mod。

- `rules.between_lines` 激活 Lua handler；
- `rules.between_lines.lines` 只保存每题自己的线条几何；
- 每条路径的首格和末格是端点圆；
- 每个内部格数字都必须严格介于两个端点数字之间；
- 除经典规则外，内部数字不要求排序、连续或互不重复；
- 不同线不能共享格子，也不能互相穿越；
- 规则校验和候选删除复用同一个部分盘面可满足性判断；
- 整盘候选 batch 会复用归一化棋盘读值，并在生产指令预算内使用只返回布尔值的可行性路径；
- `build_overlay` 为每条线依次输出一条折线和两个端点圆；
- Reference package 为线和端点圆选择 `0.6` 透明度；这是样式选择，不是边/路径规则的 Host 上限。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
