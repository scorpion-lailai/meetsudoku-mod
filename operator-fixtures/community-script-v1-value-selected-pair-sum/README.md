# Value-Selected Pair Sum Operator Fixture

This non-playable fixture proves the public Script V1/API 5 authoring surface
for `constraint.value_selected_pair_sum_equals_constant`. It is not a named
variant, does not occupy a portfolio category, and cannot be promoted as a
playable reference.

The two selector cells contain digits `1..9`. Those digits select positions in
the ordered nine-cell sequence; the two selected digits must sum to `target`.
`main.lua` validates and derives the complete typed predicate at startup.
The Host owns partial evaluation, candidates, conflicts, completion and UI.

中文说明：这是通用 operator 的非可玩验证 fixture，不是具名变形数独，也不占用
玩法容量。两个 selector 格中的数字按 `1..9` 选择有序九格中的位置，被选中的两
个数字之和必须等于目标值。
