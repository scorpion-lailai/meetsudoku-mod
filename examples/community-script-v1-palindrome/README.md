# Community Script V1 Palindrome

This example shows a fully scripted Palindrome Sudoku rule.

- `rules.palindrome` activates the registered handler.
- `rules.<handler>.lines` contains per-puzzle palindrome line geometry.
- Lua owns only palindrome validation, candidate elimination suggestions, and
  declarative line overlay.
- The Host owns the board, input transaction, notes, candidates, conflicts,
  completion, persistence, hints, and rendering.

回文线规则：

- 每条线从两端向中间对称。
- 对称位置上的两个格子必须填入相同数字。
- 中心格没有额外约束。

Script V1 callbacks:

- `validate_move(ctx, move)` reports mismatched mirrored cells for a proposed
  move.
- `validate_board(ctx)` reports current-board palindrome mismatches.
- `get_candidate_eliminations(ctx, cell)` removes candidates that cannot match
  already-filled mirrored cells.
- `validate_final_state(ctx)` reports only whether palindrome rules are valid.
- `build_overlay(ctx)` returns declarative polyline primitives for the Host
  painter.

## Puzzle data

Each `rules.palindrome.lines` entry is an ordered path. `main.lua` normalizes
that path once, pairs positions from its two ends, and uses the same pairs for
validation, candidate removal, and the visible line.
