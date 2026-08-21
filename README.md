# MeetSudoku Plugin SDK

[Chinese](README.zh-CN.md)

Community Variant Script API V1 lets authors create Sudoku variants with
`main.lua`, puzzle data, and optional board marks. Start with the
[author guide](community-script-v1-author-guide.md) or its
[Chinese mirror](community-script-v1-author-guide.zh-CN.md) for the public
package and Lua/JSON contract.

## MeetSudoku and Steam Workshop

This SDK is used to build playable Sudoku Mods for MeetSudoku. Browse and
subscribe to published Mods on the [MeetSudoku Steam Workshop](https://steamcommunity.com/app/4932400/workshop/).

## Minimal implementation model

A playable variant needs only three pieces: a complete rule implementation, its
visual Overlay, and a puzzle bank. The package does not require changes to the
MeetSudoku application.

- `main.lua` is the single rule entry point. It owns rule parsing, move and
  candidate validation, final-state validation, and Overlay generation.
- `puzzle_bank.json` supplies the 81-cell puzzle, its solution, and only the
  per-puzzle geometry or values that vary from one puzzle to another.
- `variant.json` declares the level and daily entry points. `manifest.json`
  identifies the package, while `i18n/` contains player-facing translations.

The fixed rule meaning and all rule derivation stay in `main.lua`; JSON is data,
not a second rule language. Start from the closest package in `examples/` and
keep the complete logic in that package's `main.lua`.

## Package icon

Add an optional `icon.png` at the package root to give the Mod its own image in
MeetSudoku. It must be a valid square PNG no larger than `1024 x 1024` and
`4 MiB`. Script V1 discovers this exact root filename automatically; do not
add an `icon` field to the minimal `manifest.json`.

This package icon is separate from the Steam Workshop `previewfile`: the icon
is bundled with the Mod and reused by the app, while the Workshop preview is
the image uploaded to the Steam page. If the package icon is absent or cannot
be decoded, MeetSudoku falls back to its app logo.

## Five-minute path

1. Choose the closest player-visible rule shape from the examples below.
2. Copy the complete package shape and change its stable identity and player
   translations.
3. Keep the complete fixed rule logic in `main.lua`.
4. Put only puzzle-varying geometry or values in `puzzle_bank.json`.
5. Provide `en_us` and `zh_cn`, preview the package in the app, then publish it
   to the Steam Workshop.

### Minimal package shape

```text
my-variant/
  manifest.json
  main.lua
  variant.json
  puzzle_bank.json
  icon.png              # optional square PNG used inside MeetSudoku
  i18n/
    en_us.json
    zh_cn.json
```

### Key code shape

The following is a shortened excerpt of a real package. Production code must
also normalize and validate its configuration, implement every required
runtime surface, and return diagnostics consistently.

```lua
local plugin = community_variant.script()
local board = community_variant.board
local overlay_geometry = community_variant.overlay_geometry

local rule = {}

function rule.create(config, scope)
  local marks = normalize_marks(config) -- complete rule-specific validation

  return {
    validate_move = function(ctx, move)
      local violations = find_violations(marks, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(marks, ctx, nil, nil)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      return {
        primitives = build_mark_primitives(marks, overlay_geometry),
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("my_rule", rule)
return plugin:build()
```

The corresponding puzzle data contains only changing values or geometry:

```json
{
  "rules": {
    "my_rule": {
      "marks": [{ "cells": [0, 1] }, { "cells": [9, 18] }]
    }
  }
}
```

### Before sharing

- Use manifest schema 3 and the public Community Script API V1.
- Keep all rule, candidate, completion, and Overlay logic in `main.lua`.
- Provide complete `en_us` and `zh_cn` locales; additional locales must use the
  naming rules below.
- Include an 81-character `puzzle` and `solution` for every puzzle.
- Use the app's package validation and local plugin preview before publishing
  it to the Steam Workshop.
- Use a published example as the starting point when it matches the rule shape.

<!-- GENERATED:capability-navigation:start -->
## Choose a starting example

Choose the example that most closely matches the rule you want players to see.

| Your goal | Start here | Why |
|---|---|---|
| A fixed rule from the start | [`159 Sudoku`](examples/community-script-v1-159-sudoku/) | Derive one package-wide rule from small puzzle data. |
| A rule checked while solving | [`Fortress Sudoku`](examples/community-script-v1-fortress/) | Validate a local relationship as players place digits. |
| Custom regions or board layout | [`Jigsaw Sudoku`](examples/community-script-v1-jigsaw/) | Describe regions or a nonstandard base layout. |
| Clues, labels, or visual guides | [`Numbered Rooms`](examples/community-script-v1-numbered-rooms/) | Turn puzzle-owned clue data into rules and marks. |
| Cells that change as play continues | [`Fog of War Sudoku`](examples/community-script-v1-fog-of-war/) | Describe a bounded, rule-driven change to visible cells. |

## Browse by capability

Every public playable reference appears once, grouped by the rule shape that is most useful when choosing an authoring starting point.

### Grid layout and linked regions

[`Asterisk Sudoku`](examples/community-script-v1-asterisk/) ·
[`Clone Sudoku`](examples/community-script-v1-clone/) ·
[`Counting Circles Sudoku`](examples/community-script-v1-counting-circles/) ·
[`Diagonal Sudoku`](examples/community-script-v1-diagonal/) ·
[`Disjoint Groups Sudoku`](examples/community-script-v1-disjoint-groups/) ·
[`Jigsaw Sudoku`](examples/community-script-v1-jigsaw/) ·
[`Magic Square Sudoku`](examples/community-script-v1-magic-square/) ·
[`No Boxes Sudoku`](examples/community-script-v1-no-boxes/) ·
[`Same Values Sudoku`](examples/community-script-v1-same-values/) ·
[`Windoku`](examples/community-script-v1-windoku/)

### Cell, neighbour, and pair patterns

[`Anti-King Sudoku`](examples/community-script-v1-anti-king/) ·
[`Anti-Knight Sudoku`](examples/community-script-v1-anti-knight/) ·
[`Anti-Taxicab`](examples/community-script-v1-anti-taxicab/) ·
[`Anti-XV Sudoku`](examples/community-script-v1-anti-xv/) ·
[`Battenburg Sudoku`](examples/community-script-v1-battenburg/) ·
[`Composite Sudoku`](examples/community-script-v1-composite/) ·
[`Entropy Sudoku`](examples/community-script-v1-entropy/) ·
[`Fortress Sudoku`](examples/community-script-v1-fortress/) ·
[`Friendly Sudoku`](examples/community-script-v1-friendly-sudoku/) ·
[`MinMax Sudoku`](examples/community-script-v1-minmax/) ·
[`Non-Consecutive Sudoku`](examples/community-script-v1-non-consecutive/) ·
[`Odd/Even Sudoku`](examples/community-script-v1-odd-even/) ·
[`Prime Sudoku`](examples/community-script-v1-prime/) ·
[`Repeated Neighbours Sudoku`](examples/community-script-v1-repeated-neighbours/)

### Clues, labels, and numeric conditions

[`159 Sudoku`](examples/community-script-v1-159-sudoku/) ·
[`Consecutive Sudoku`](examples/community-script-v1-consecutive/) ·
[`Greater Than Sudoku`](examples/community-script-v1-greater-than/) ·
[`Intersection Sum Sudoku`](examples/community-script-v1-intersection-sum/) ·
[`Kropki Sudoku`](examples/community-script-v1-kropki/) ·
[`Little Killer Sudoku`](examples/community-script-v1-little-killer/) ·
[`Numbered Rooms`](examples/community-script-v1-numbered-rooms/) ·
[`Position Sums Sudoku`](examples/community-script-v1-position-sums/) ·
[`Quadruple Sudoku`](examples/community-script-v1-quadruple/) ·
[`Sandwich Sudoku`](examples/community-script-v1-sandwich/) ·
[`Skyscraper Sudoku`](examples/community-script-v1-skyscraper/) ·
[`X-Sums Sudoku`](examples/community-script-v1-x-sums/) ·
[`XV Sudoku`](examples/community-script-v1-xv/)

### Paths and ordered sequences

[`Arrow Sudoku`](examples/community-script-v1-arrow/) ·
[`Arrow Thermometer Sudoku`](examples/community-script-v1-arrow-thermometer/) ·
[`Between Lines Sudoku`](examples/community-script-v1-between-lines/) ·
[`Dutch Whispers Sudoku`](examples/community-script-v1-dutch-whispers/) ·
[`German Whispers Sudoku`](examples/community-script-v1-german-whispers/) ·
[`Lockout Lines Sudoku`](examples/community-script-v1-lockout-lines/) ·
[`Modular Lines Sudoku`](examples/community-script-v1-modular-lines/) ·
[`Palindrome`](examples/community-script-v1-palindrome/) ·
[`Region Sum Lines Sudoku`](examples/community-script-v1-region-sum-lines/) ·
[`Renban Lines Sudoku`](examples/community-script-v1-renban/) ·
[`Thermometer Sudoku`](examples/community-script-v1-thermometer/) ·
[`Zipper Lines Sudoku`](examples/community-script-v1-zipper-lines/)

### Board changes during play

[`Beacon Sudoku`](examples/community-script-v1-beacon-sudoku/) ·
[`Fog of War Sudoku`](examples/community-script-v1-fog-of-war/)

<!-- GENERATED:capability-navigation:end -->

## Public examples

`examples/` contains public playable reference packages. Each one demonstrates
a complete rule that authors can adapt: the package-wide rule belongs in
`main.lua`, while each puzzle supplies only its changing geometry or values.

## Languages and naming

Every public package must include both `i18n/en_us.json` and
`i18n/zh_cn.json`. Additional languages are optional and use lowercase locale
filenames: a two- or three-letter language code, with
an optional two-letter region suffix, such as `ja.json`, `pt_br.json`,
`zh_cn.json`, or `zh_tw.json`. The game resolves an exact locale first, then a
declared language-only locale, then `en_us`.

Use one stable name and localized player-facing names:

- `manifest.id` is the permanent technical identifier.
- `manifest.name` is the stable, non-localized package-management name.
- `variant.title` is the player-facing name in each locale and may be
  translated.
- `variant.description` and every `rule_guide.*` value are player-facing copy
  in that locale.

Every declared locale must contain the complete `en_us` key set, including all
`rule_guide.*` keys. Use the existing key families—`variant.*`,
`rule.<handler>`, and `rule_guide.*`—rather than locale-specific key names.
Runtime fallback is a resilience mechanism and does not make a locale complete.

## Public SDK material

`operator-fixtures/` contains small, non-playable syntax examples for generic
operators. They are not starting points for a playable variant; use the public
examples and author guide instead.

## SDK layout

```text
plugin-sdk/
  README.md
  README.zh-CN.md
  community-script-v1-author-guide.md
  community-script-v1-author-guide.zh-CN.md
  manifest.schema.json
  types-community.lua
  examples/
  operator-fixtures/
```

This directory is the public SDK source used by Mod authors. The SDK contains
the public package contract, examples, and author documentation; it does not
contain the MeetSudoku application's implementation.
