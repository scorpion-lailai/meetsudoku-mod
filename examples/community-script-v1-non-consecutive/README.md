# Non-Consecutive Sudoku

This package is a **Community Variant Script API V1** reference implementation
for Non-Consecutive Sudoku. The rule is written in Lua and is evaluated as a
validation extension over the Host's classic Sudoku core.

The package demonstrates:

- `rules.non_consecutive` activates one registered handler;
- `rules.<handler>` is empty because orthogonal adjacency is package-invariant;
- `validate_move` and `validate_board` reject orthogonally adjacent digits
  whose absolute difference is `1`;
- `get_candidate_eliminations` removes `n - 1` and `n + 1` beside a filled
  orthogonal neighbor;
- `validate_final_state` reports whether the Non-Consecutive rule is valid;
- no overlay is emitted because Non-Consecutive has no visual marks.

The author owns the Non-Consecutive rule semantics. The App still owns board
state, move transactions, the classic Sudoku rules, candidate display,
conflicts, notes, undo, save/load, completion, progress, navigation and
rendering.

中文说明：这是一个 Community Variant Script API V1 的非连续数独示例。上下左右
相邻的两个格子不能填入连续数字，例如一个格子填 `5`，相邻格不能填 `4` 或
`6`。Lua 只提供规则验证和候选删除建议，棋盘、经典数独基础规则、冲突显示和
游戏生命周期仍由 App 负责。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
