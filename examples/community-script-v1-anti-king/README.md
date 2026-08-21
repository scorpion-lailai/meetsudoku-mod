# Anti-King Sudoku

This package is a **Community Variant Script API V1 contract preview** for
Anti-King Sudoku. The author-facing contract starts from the Anti-King semantic
object; the current Script V1 handler is the runtime materialization target.
The king-move not-equal rule is written as author-owned Script V1 logic.

The example reviews a fixed offset-pair semantic rule:

- `rules.anti_king` activates one registered handler;
- `rules.<handler>` stays empty because the king offsets are package-invariant;
- Lua expands the four canonical offsets into the full king-move pair graph;
- `create(config, scope)` creates one private pair graph instance;
- `validate_move` rejects equal digits across any king move;
- `validate_board` scans all king pairs;
- `get_candidate_eliminations` removes digits already present in king-neighbor
  cells;
- `validate_final_state` reports whether the Anti-King rule is valid;
- the package uses static empty overlay because Anti-King has no board marks.

The author owns only Anti-King rule logic. The App still owns board state, move
transactions, candidates display, conflict UI, notes, undo, save/load, progress,
navigation, sandbox and Workshop policy.

The handler exposes:

- `create(config, scope)` validates empty config and builds the fixed pair graph.
- `validate_move(ctx, move)` checks equal digits across king-neighbor cells.
- `validate_board(ctx)` reports all current Anti-King violations.
- `get_candidate_eliminations(ctx, cell)` suggests removals from Host-owned
  candidates.
- `validate_final_state(ctx)` reports rule validity; the Host still decides
  whole-puzzle completion.

This package intentionally does not implement `build_overlay`: its manifest
uses the static empty-overlay mode because Anti-King has no visual marks.

中文说明：Anti-King 是固定 offset 规则。任何两个王步相邻格不能填入相同数字。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
