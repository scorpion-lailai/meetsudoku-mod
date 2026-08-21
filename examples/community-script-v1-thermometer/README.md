# Thermometer Sudoku

This package is a **Community Variant Script API V1 contract preview**. The
author-facing contract starts from the thermometer semantic object; the current
Script V1 callback shape is the runtime materialization target. The package
keeps the same SDK layout as the current `community_variant` examples. The Host
validates the manifest, discovers the registered script handlers and invokes
their Script V1 callbacks with read-only snapshots.

The example reviews the author-facing semantic shape for a puzzle-data-driven
rule:

- `rules.thermometer` activates one registered handler;
- `rules.<handler>.paths` contains per-puzzle thermometer geometry;
- `validate_move` provides immediate post-move violation feedback;
- `validate_board` scans board-wide conflict cells;
- validation compares every filled earlier/later pair on a thermometer path,
  not only adjacent cells;
- `get_candidate_eliminations` suggests removals only when Host auto-notes are
  active;
- `validate_final_state` reports whether the thermometer rule is valid;
- `build_overlay` emits declarative thermometer overlay.

The author owns only thermometer rule logic and presentation declarations. The
App still owns board state, move transactions, candidates display, conflict UI,
notes, undo, save/load, progress, navigation, sandbox and Workshop policy.

The handler exposes:

- `create(config, scope)` stores this puzzle's paths in a private rule instance.
- `validate_move(ctx, move)` checks strict bulb-to-tip ordering.
- `validate_board(ctx)` reports every filled earlier/later pair that is out of
  order, including non-adjacent pairs.
- `get_candidate_eliminations(ctx, cell)` suggests removals from Host-owned
  candidates.
- `validate_final_state(ctx)` reports rule validity; the Host still decides
  whole-puzzle completion.
- `build_overlay(ctx)` returns declarative thermometer primitives for Host
  rendering.

中文说明：温度计校验会比较路径上所有已填的前后格，不只检查相邻格。
例如一条路径两端分别是 `7 ... 2`，即使中间还有空格，也会被判定为违反
“从圆头到末端严格递增”。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
