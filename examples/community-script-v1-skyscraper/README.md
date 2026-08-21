# Skyscraper Sudoku

This package is the Script V1 Skyscraper Sudoku reference Mod.

The Host owns classic Sudoku rules, board mutation, input, notes, completion,
progress, persistence and rendering.

## 中文说明

这个包是 Script V1 摩天楼数独参考 Mod。

- `rules.skyscraper` 激活 Lua handler；
- `rules.skyscraper.clues` 只保存每题自己的侧面、序号与可见楼数；
- 每个提示统计从对应侧面看到的连续新高楼数量；
- 左右提示对应行，上下提示对应列；
- 规则校验和完成判定复用同一个精确数字掩码可满足性判断；
- 本包有意不注册 Script 候选投影；
- `build_overlay` 为每个提示输出 Host-owned `boundary_label` primitive；
- 包内包含 50 道生成题，分为五个本地难度组；每组分别来自通过 smoke 资格评定的
  原生 21-25 级；
- 36 条提示的预算 spike 保留在测试 fixture 中，不代表题库难度或正式发布容量。

经典数独规则、棋盘变更、输入、笔记、完成流程、进度、存档和渲染仍由 Host 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
