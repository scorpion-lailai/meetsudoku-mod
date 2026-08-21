# Modular Lines Sudoku

Every consecutive group of three cells on a marked line has the same remainder
when divided by three.

- `rules.modular_lines.lines` contains only puzzle-owned ordered orthogonal path geometry;
- the package owns the fixed `mod = 3` semantics in `main.lua`;
- every overlapping length-three window emits three generic `remainder@1` comparisons;
- the game applies the derived predicates together with classic Sudoku rules;
- the overlay draws each path and endpoint markers.

中文说明：题目 JSON 只保存有序正交路径，
固定的 `mod = 3` 规则在 `main.lua` 中实现；每个连续三格窗口由 Lua 派生三条通用
`remainder@1` 约束，游戏负责应用约束和通用流程。
