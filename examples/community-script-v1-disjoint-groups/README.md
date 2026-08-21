# Disjoint Groups Sudoku

The package keeps the classic row, column, and 3x3 box rules. It adds nine
fixed `all_different` groups: for each relative position inside a 3x3 box, the
nine cells at that position across all nine boxes form one group. Puzzle data
only activates `rules.disjoint_groups` with an empty object; the fixed geometry
and typed predicates live in `main.lua`.

The Host compiles the predicates once at startup and owns gameplay validation,
candidates, note cleanup, completion, persistence, and rendering. This package
does not register gameplay callbacks, mutable state, or overlays.

当前包是 API 5 的启动期物化参考实现。每个 3x3 宫中相同相对位置的九个格子组成一组，
共九组；每组数字不能重复。题目 JSON 只负责激活固定规则，不保存派生坐标或 IR。
