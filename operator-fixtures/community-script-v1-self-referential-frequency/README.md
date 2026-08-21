# Self-Referential Frequency Constraint Operator Fixture

This repository-owned package is a generic authoring proof for
`constraint.self_referential_frequency(cells)`. It is not Counting Circles,
another named Sudoku variant, or a distributable puzzle-bank release.

`rules.frequency.cells` contains only puzzle-varying geometry. `main.lua`
checks the data shape and constructs one root predicate. The SDK validates the
1..9 unique cells and owns canonical cell ordering. The Host materializes the
predicate at startup and owns all Gameplay execution and state.

The single puzzle is a technical Creator Validation fixture, not difficulty or
content qualification evidence. Authors must not write Host analysis plan IDs,
histograms, evidence objects or runtime state, and must not nest this predicate
inside logic or count expressions.

中文说明：这是自指频次语义对象的通用 Lua 编写证明，不是具名玩法或正式题库。
题目只提供变化的格组；SDK 负责格子校验与 canonicalization，Host 在启动期物化并
独占 Gameplay 执行。
