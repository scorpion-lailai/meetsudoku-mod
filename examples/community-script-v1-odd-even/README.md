# Odd/Even Sudoku

This package is a **Community Variant Script API V1** reference implementation
for Odd/Even Sudoku. The rule is written in Lua and is evaluated as a
validation extension over the Host's classic Sudoku core.

The package demonstrates:

- `rules.odd_even` activates one registered handler;
- `rules.<handler>.marks` contains puzzle-owned parity mark geometry;
- `validate_move` and `validate_board` reject digits that do not match a marked
  cell's parity;
- `get_candidate_eliminations` removes even digits from odd-marked cells and
  odd digits from even-marked cells;
- `validate_final_state` reports whether the Odd/Even rule is valid;
- `build_overlay` emits Host built-in `parity_mark` primitives, with circles for
  odd cells and squares for even cells.

The author owns the Odd/Even rule semantics and per-puzzle mark data. The App
still owns board state, move transactions, the classic Sudoku rules, candidate
display, conflicts, notes, undo, save/load, completion, progress, navigation
and rendering.

中文说明：这是一个 Community Variant Script API V1 的奇偶数独示例。带奇数标记的
格子只能填 `1/3/5/7/9`，带偶数标记的格子只能填 `2/4/6/8`。Lua 只提供规则验证、
候选删除建议和声明式奇偶标记 overlay，棋盘、经典数独基础规则、冲突显示和游戏
生命周期仍由 App 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
