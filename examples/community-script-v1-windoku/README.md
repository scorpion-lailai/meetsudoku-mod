# Windoku

This package is a **Community Variant Script API V1 contract preview** for
Windoku. The author-facing contract starts from the Windoku semantic object;
the current Script V1 handler is the runtime materialization target. The fixed
four-window rule is written as author-owned Script V1 logic.

The example reviews a fixed-geometry all-different semantic rule:

- `rules.window` activates one registered handler;
- `rules.<handler>` stays empty because the four windows are package-invariant;
- `create(config, scope)` creates one private fixed-window instance;
- `validate_move` provides immediate post-move feedback;
- `validate_board` scans every window for duplicates;
- `get_candidate_eliminations` removes digits already used in the same window;
- `validate_final_state` reports whether the window rule is valid;
- `build_overlay` emits declarative 3x3 window rectangles.

The author owns only Windoku rule logic and presentation declarations. The App
still owns board state, move transactions, candidates display, conflict UI,
notes, undo, save/load, progress, navigation, sandbox and Workshop policy.

The handler exposes:

- `create(config, scope)` builds the four package-invariant windows.
- `validate_move(ctx, move)` checks duplicates in the affected window.
- `validate_board(ctx)` reports duplicate digits in all four windows.
- `get_candidate_eliminations(ctx, cell)` suggests removals from Host-owned
  candidates.
- `validate_final_state(ctx)` reports window-rule validity; the Host still
  decides whole-puzzle completion.
- `build_overlay(ctx)` returns declarative rectangles for Host rendering.

中文说明：Windoku 的四个窗口是包级固定语义，不由题目数据改变。每个窗口都必须
满足全不同，和行、列、宫一样参与校验。

## What main.lua derives

`main.lua` contains this variant’s complete fixed rule. It validates the puzzle-owned `rules` data and derives or checks the rule during play; puzzle data does not redefine the variant.
