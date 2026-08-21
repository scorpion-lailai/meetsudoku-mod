# Anti-Knight Sudoku

This package is a **Community Variant Script API V1** reference implementation
for Anti-Knight Sudoku. The rule is written in Lua and is evaluated as a
validation extension over the Host's classic Sudoku core.

The package demonstrates:

- `rules.anti_knight` activates one registered handler;
- `rules.<handler>` is empty because the knight offsets are package-invariant;
- `validate_move` and `validate_board` reject equal digits separated by a
  chess-knight move;
- `get_candidate_eliminations` removes digits already used by a knight
  neighbor;
- `validate_final_state` reports whether the Anti-Knight rule is valid;
- no overlay is emitted because Anti-Knight has no visual marks.

The author owns the Anti-Knight rule semantics. The App still owns board state,
move transactions, the classic Sudoku rules, candidate display, conflicts,
notes, undo, save/load, completion, progress, navigation and rendering.

中文说明：这是一个 Community Variant Script API V1 的反骑士数独示例。任意
骑士步相隔的两个格子不能填入相同数字。Lua 只提供规则验证和候选删除建议，
棋盘、经典数独基础规则、冲突显示和游戏生命周期仍由 App 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
