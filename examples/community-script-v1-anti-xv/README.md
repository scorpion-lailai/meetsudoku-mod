# Anti-XV Sudoku

This Community Variant Script API V1 reference package adds one global negative
constraint to classic Sudoku: every orthogonally adjacent pair must not sum to
5 or 10. The absence of a mark is not puzzle data; the rule always covers all
144 orthogonal pairs.

`rules.<handler>` must remain empty. Lua validates moves, boards and final states,
and removes candidates that would sum to 5 or 10 with a filled orthogonal
neighbor. Anti-XV has no overlay.

中文说明：反 XV 数独在经典数独规则上增加一条全局限制：任意上下左右相邻的两格
之和都不能是 5 或 10。该规则覆盖全部 144 组正交相邻格，不依赖边标记，也不绘制
Overlay。题目中的 `rules.<handler>` 必须为空。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
