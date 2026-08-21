# Arrow Thermometer Sudoku

This package demonstrates composition of two independent Script V1 handlers in
one puzzle:

- `thermometer` enforces strict increase from bulb to tip;
- `arrow` enforces `head = sum(path)`;
- each handler owns its own `rules.<handler>` geometry;
- the Host merges their typed violations and candidate removals;
- both handlers contribute declarative overlay primitives.

There is no combined rule type and no central `if/elseif` dispatcher. The
package registers two normal handlers and the puzzle activates both entries.

The App remains the only Gameplay Core: it owns board state, classic Sudoku
validation, input transactions, candidates, conflicts, notes, undo, save/load,
completion and rendering.

The repository reference bank contains five package-local difficulties with ten
puzzles each.

中文说明：这个示例在一个题目中组合独立的温度计和箭头 handler。温度计负责
路径递增，箭头负责圆头等于路径和；Host 合并两者的 typed 结果，Lua 不接管
棋盘或游戏生命周期。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
