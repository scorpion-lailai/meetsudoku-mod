# XV Sudoku

This package is a **Community Variant Script API V1 contract preview** for XV
Sudoku. The author-facing contract starts from the XV semantic object; the
current Script V1 handler is the runtime materialization target. The rule is
written as author-owned Script V1 logic instead of a startup Rule IR
declaration.

The example reviews pair-sum semantics:

- `rules.xv` activates one registered handler;
- `rules.<handler>.marks` contains puzzle-owned X/V edge marks;
- X means the two adjacent digits sum to 10;
- V means the two adjacent digits sum to 5;
- `validate_move` provides immediate post-move feedback when both cells are
  filled;
- `validate_board` scans all marked pairs;
- `get_candidate_eliminations` removes digits that cannot satisfy an
  already-filled neighbor;
- `validate_final_state` reports whether XV is valid for final-state checks;
- `build_overlay` emits startup declarative X/V mark primitives.

The author owns only XV rule logic and presentation declarations. The App still
owns board state, move transactions, candidates display, conflict UI, notes,
undo, save/load, progress, navigation, sandbox and Workshop policy.

中文说明：XV 规则只约束已标记的相邻边。X 表示两格数字之和必须为 10，V 表示
两格数字之和必须为 5。未标记的边不增加限制。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
