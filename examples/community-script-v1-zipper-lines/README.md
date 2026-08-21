# Zipper Lines Sudoku

This directory contains the complete Script V1 Zipper Lines reference package.

- `rules.zipper_lines.lines` contains only puzzle-owned odd path geometry;
- Lua derives each center cell and its symmetric pairs from the path;
- every symmetric pair must sum to the center digit;
- empty-center validation intersects the feasible target digits from every pair;
- intersecting lines are valid and apply all related constraints;
- move, board, candidate and final validation share one feasibility core;
- full-board candidate batches reuse normalized board reads and reduce each
  line to one exact-target/lower-bound scan;
- the overlay uses a custom polyline and center diamond, without a Host
  `zipper_line` primitive.

The current `puzzle_bank.json` contains five package-local difficulty levels
with 10 puzzles each.

## 中文说明

本目录包含完整的 Script V1 拉链线参考包。

- `rules.zipper_lines.lines` 只保存每题变化的奇数长度路径；
- Lua 从路径推导中心格和全部对称 pair；
- 每个对称 pair 的数字之和必须等于中心格数字；
- 中心为空时，校验会计算所有 pair 共同允许的中心目标；
- 不同线可以相交，共享格同时满足全部相关约束；
- 落子、盘面、候选和终盘校验复用同一个可行性核心；
- 整盘候选 batch 会复用归一化棋盘读值，并把每条线收敛为一次目标值/下界扫描；
- Overlay 使用通用折线和中心菱形，不新增 Host `zipper_line` primitive。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
