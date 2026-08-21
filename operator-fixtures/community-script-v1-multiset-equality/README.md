# Multiset Equality Constraint Operator Fixture

This repository-owned package is a generic authoring proof for
`constraint.multiset_equal(first_cells, second_cells)`. It is not Same Values,
another named Sudoku variant, or a distributable puzzle-bank release.

The puzzle supplies only two varying cell groups. `main.lua` validates their
data shape and constructs one root predicate. The SDK enforces two equal-sized,
disjoint groups of 1..9 unique cells, canonicalizes cells and commutative group
order, and preserves duplicate digit frequencies rather than positional
equality. The Host materializes the predicate at startup.

The single puzzle is a technical Creator Validation fixture, not difficulty or
content qualification evidence. Authors must not write Host analysis plan IDs,
histograms, matching evidence or runtime state, and must not nest this predicate
inside logic or count expressions.

中文说明：这是多重集相等语义对象的通用 Lua 编写证明，不是具名玩法或正式题库。
题目只提供两组变化的格子；SDK 负责完整校验和 canonicalization，Host 在启动期
物化并独占 Gameplay 执行。
