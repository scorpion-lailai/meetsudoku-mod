# 159 Sudoku

Every row uses the same fixed rule: if cells 1, 5, and 9 contain column numbers
`a`, `b`, and `c`, then cells `a`, `b`, and `c` in that row must contain 1, 5,
and 9 respectively.
`main.lua` derives all nine ordered rows and emits 27 typed
`equal(element_at(...), constant(...))` predicates. Puzzle data only activates
`rules.one_five_nine` with an empty object and cannot redefine the fixed rule.

The Host compiles the predicates once at startup and owns gameplay validation,
candidates, conflicts, note cleanup, completion, persistence, and rendering.
The package has no Overlay, mutable feature state, gameplay Lua callback, or
variant-specific Host branch.

Every public row contains
only `difficulty`, `puzzle`, required `solution`, and activation-only `rules`.

中文说明：这是 159 数独的 Script V1 启动期物化参考包。逐行查看第 1、5、9 格：
若格内分别是列号 `a`、`b`、`c`，则该行第 `a`、`b`、`c` 格必须分别填 1、5、9。
