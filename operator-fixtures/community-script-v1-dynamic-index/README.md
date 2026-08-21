# Dynamic Index Constraint Operator Fixture

This repository-owned package is a generic Community Script API V1 authoring
proof for `community_variant.constraint.element_at`. It is not a named Sudoku
variant, a 159 package, or a distributable puzzle-bank release.

`rules.dynamic_index` contains one ordered nine-cell sequence, one index cell
and one target digit. `main.lua` validates that puzzle-varying data and emits
exactly:

```lua
constraint.equal(
  constraint.element_at(cells, constraint.value(index_cell)),
  constraint.constant(target)
)
```

The index digit is one-based: digit `1` selects the first sequence cell and
digit `9` selects the ninth. The Host compiles the predicate once at startup
into the Native Rule Graph and owns partial validation, candidates, conflicts,
note cleanup, completion and persistence. No Gameplay Lua callback, Runtime
plan ID, mutable state, custom UI or variant-specific Host branch is used.

中文说明：这是 `element_at` 的通用启动期物化证明，不是 159 数独 Mod，也不是正式
题库。题目只提供有序九格、索引格和目标数字；Lua 完整校验这些参数并生成 typed
predicate，Host 在启动期物化后独占 Gameplay 执行。
