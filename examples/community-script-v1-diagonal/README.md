# Diagonal Sudoku

This package is a **Community Variant Script API V1 contract preview**. The
author-facing contract starts from the diagonal semantic object; the current
Script V1 callback shape is the runtime materialization target. `create(config,
scope)` creates a private rule instance, and the Host invokes its validation
and overlay callbacks with read-only snapshots.

The example exists to review the author-facing semantic shape:

- one package;
- one `main.lua`;
- one `plugin:register_rule(...)` handler;
- 50 generated puzzles activating that handler through the `rules` object key;
- five community difficulty levels mapped from existing generated levels 21-25;
- one optional declarative overlay.

The author owns only the two-diagonal rule logic and its presentation. The
App still owns board state, move transactions, candidates display, conflict UI,
notes, undo, save/load, progress, navigation, sandbox and Workshop policy.

The important API shape is that a new rule adds a new registered handler. It
does not add a central `if/elseif` dispatcher over rule names.

The handler exposes:

- `create(config, scope)` creates the fixed two-diagonal model.
- `validate_move(ctx, move)` reports whether a proposed digit repeats on either
  diagonal.
- `validate_board(ctx)` reports current repeated digits.
- `get_candidate_eliminations(ctx, cell)` suggests removals from Host-owned
  candidates.
- `validate_final_state(ctx)` reports whether this rule is valid; the Host
  still decides whole-puzzle completion.
- `build_overlay(ctx)` returns two declarative diagonal lines for Host rendering.
