# Greater Than Sudoku

This package is a **Community Variant Script API V1 contract preview** for Greater Than
Sudoku. The author-facing contract starts from the Greater Than semantic
object; the current Script V1 handler is the runtime materialization target.
The rule is written as author-owned Script V1 logic instead of a startup Rule
IR declaration.

The example reviews directed adjacent-cell order semantics:

- `rules.greater_than` activates one registered handler;
- `rules.<handler>.marks` contains puzzle-owned Greater Than edge marks;
- `less_than` means the first cell is smaller than the second cell;
- `greater_than` means the first cell is larger than the second cell;
- `validate_move` provides immediate post-move feedback when both cells are
  filled;
- `validate_board` scans all marked pairs;
- `get_candidate_eliminations` removes digits that cannot satisfy an
  already-filled neighbor;
- `validate_final_state` reports whether Greater Than is valid for final-state checks;
- `build_overlay` emits startup declarative Greater Than mark primitives.

The author owns only Greater Than rule logic and presentation declarations. The App still
owns board state, move transactions, candidates display, conflict UI, notes,
undo, save/load, progress, navigation, sandbox and Workshop policy.

中文说明：数比数独只约束已标记的相邻边。`less_than` 表示第一格小于第二格，
`greater_than` 表示第一格大于第二格。未标记的边不增加大小约束。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
