# MinMax Sudoku

`rules.minmax` contains only puzzle-varying `minimum_cells` and
`maximum_cells`. `main.lua` validates and canonicalizes those marks, derives
all in-bounds orthogonal comparisons, rejects contradictory pairs, emits typed
`less_than(value(low), value(high))` predicates, and builds the inward/outward
triangle Overlay from the same normalized model. The Host compiles the
predicates once and owns gameplay validation, candidates, conflicts, note
cleanup, completion, persistence, and rendering.

中文说明：这是极值数独的 Script V1 启动期物化技术参考包。题目 JSON 只保存最小值和
最大值标记格；Lua 负责完整的正交邻格派生、冲突检查、严格比较约束和三角标记。
