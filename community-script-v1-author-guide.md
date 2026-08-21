# Community Variant Script API V1 Author Guide

[Chinese](community-script-v1-author-guide.zh-CN.md)

This guide is the public entry point for authors who want to make a playable
MeetSudoku variant. An author supplies the rule semantics, optional board
marks, puzzle data, and player-facing translations. The game supplies the
shared board, input, undo, notes, conflict presentation, save, progress, and
completion flow.

`variant.json.ruleGuide` is the text shown to players. It must explain only
the puzzle rule, visible marks, and what a player should compare or infer. Do
not put Host, App, Lua, candidate, save, completion, UI, or implementation
details into `rule_guide.item_*`; those belong in this author guide.

## Five-minute start

1. Choose the public example whose player-visible rule shape is closest to
   your idea. Use a complete package from `examples/`, never an operator
   fixture or a non-public technical package.
2. Copy its package shape and change the stable `manifest.id`, `manifest.name`,
   version, player title, description, rule guide, and puzzle data.
3. Keep `community_variant.script()` in `main.lua`. Each registered rule uses
   exactly one handler: `define(config, scope)` for startup materialization or
   `create(config, scope)` for bounded runtime validation and observations.
4. Put package-invariant rule meaning and all derivation in `main.lua`. Put
   only puzzle-varying geometry or parameters in `rules.<handler>`.
5. Give every puzzle an 81-character `puzzle`, an 81-character `solution`,
   and the configuration expected by its handler. Add both required locales,
   then use the app's local plugin preview before publishing.

New packages must not use `community_variant.new()`,
`community_variant.constraint_program()`, `normalize/compile_rules`, or
manifest v2 fields. API 1-4 are read-only compatibility inputs for older
packages. The current authoring contract is Script V1 with manifest schema 3
and exact API 5.

## Package layout

```text
my-script-variant/
  manifest.json
  main.lua
  variant.json
  puzzle_bank.json
  i18n/
    en_us.json
    zh_cn.json
```

The minimal manifest is:

```json
{
  "manifestVersion": 3,
  "id": "author.my_script_variant",
  "name": "My Script Variant",
  "version": "0.1.0"
}
```

The game derives the fixed API, runtime, entry, permissions, standard resource
paths, locale handling, and optional icon metadata from this contract. Authors
do not hand-fill legacy runtime or permission fields.

## Choose an example

Use the SDK home page for the complete capability navigation. These four
references are useful first templates:

| Authoring goal | Starting package | What it demonstrates |
|---|---|---|
| A rule fixed at startup | `community-script-v1-159-sudoku/` | `define`, schema checks, and typed constraints derived from puzzle data. |
| A rule checked during play | `community-script-v1-fortress/` | `create`, validation, candidate scope, and a bounded overlay. |
| Paths and numeric relationships | `community-script-v1-region-sum-lines/` | Path normalization, rule derivation, and path marks. |
| A nonstandard board topology | `community-script-v1-jigsaw/` | Puzzle-varying regions and replacement topology data. |

`operator-fixtures/` only demonstrate generic syntax and are not playable
variants. They are never a starting point for a public Mod.

## Localization and names

Write each locale as a flat JSON string table in `i18n/<locale>.json`. Public
packages must provide `i18n/en_us.json` and `i18n/zh_cn.json`. Optional locale filenames
use lowercase language and optional region codes, such as `ja.json`,
`pt_br.json`, and `zh_tw.json`. Do not use hyphens, mixed case, script names,
or private aliases.

Runtime lookup is exact locale, then declared language-only locale, then
`en_us`. A declared locale must contain the complete key set of `en_us`; a
fallback is only runtime resilience, not proof that the locale is translated.

Keep names stable:

- `manifest.id` is the permanent technical identifier and is never translated.
- `manifest.name` is the stable package-management name and does not change by
  locale.
- `variant.title` is the player-visible title and may be translated.
- `variant.description`, `rule.<handler>`, and `rule_guide.*` are player copy
  in that locale.
- Localization keys stay identical across locales. Do not create keys such as
  `variant.title_zh` or `variant.title_ja`.

Rule guides explain the player rule only. App translation keys do not belong in
the Mod package.

## Rule registration

Register one handler per rule instead of writing a global `if/elseif`
dispatcher. The key in the puzzle `rules` object activates the matching
handler. A handler chooses exactly one of these profiles:

- `define(config, scope)` returns typed constraint predicates and optional
  startup marks. The handler is not called again during gameplay.
- `create(config, scope)` returns a private Rule Instance used for bounded
  validation, candidate observations, and session features.

A playable reference must contain substantive author logic. It should derive
relations, geometry, constraints, state transitions, or marks from normalized
puzzle data. Forwarding already-complete operator arguments from JSON to one
gameplay helper is an `operator_fixture`, not a playable reference.

### A materialized rule

```lua
local plugin = community_variant.script()
local c = community_variant.constraint
local cell = community_variant.cell
local schema = community_variant.schema
local increasing_path = {}

function increasing_path.define(config, scope)
  schema.expect_exact_keys(config, { path = true }, "increasing_path")
  schema.expect_array(config.path, 2, 9, "increasing_path.path")

  local path = {}
  local seen = {}
  for index, raw_cell in ipairs(config.path) do
    local current = cell.expect(raw_cell, "increasing_path.path[" .. index .. "]")
    if seen[current] then error("increasing_path.path contains duplicates") end
    seen[current] = true
    path[index] = current
  end

  local constraints = {}
  for index = 1, #path - 1 do
    constraints[#constraints + 1] = c.less_than(
      c.value(path[index]),
      c.value(path[index + 1])
    )
  end
  return { constraints = constraints }
end

plugin:register_rule("increasing_path", increasing_path)
return plugin:build()
```

`define` cannot return board observations, candidates, violations, mutable
state, or gameplay callbacks. It also cannot appear together with `create` in
the same handler.

### A runtime rule

```lua
local plugin = community_variant.script()
local my_rule = {}

function my_rule.create(config, scope)
  local state = { config = config }

  return {
    validate_move = function(ctx, move)
      return { accepted = true, violations = {}, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = {}, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      return { valid = true, violations = {}, diagnostics = {} }
    end,
  }
end

plugin:register_rule("my_rule", my_rule)
return plugin:build()
```

The corresponding puzzle contains only changing data:

```json
{
  "difficulty": 1,
  "puzzle": "000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "solution": "123456789456789123789123456214365897365897214897214365531642978642978531978531642",
  "rules": { "my_rule": {} }
}
```

`solution` is always required, contains only digits `1..9`, and must preserve
all non-zero givens in `puzzle`. Do not add `puzzleId` or an `{id,data}` wrapper;
the game derives a stable puzzle identity from the canonical puzzle and rules.

## Rule Instance lifecycle

This section applies only to `create`. The game calls `create` once for every
rule entry during exact-session startup. The private instance is reused by
startup feature and mark construction and by gameplay calls to
`validate_move`, `validate_board`, `get_candidate_eliminations`, and
`validate_final_state`.

Use `create` to validate and normalize immutable puzzle data, precompute paths,
edges, or cages, and build read-only lookup tables. Do not cache a callback's
`ctx.board`; each callback receives the current immutable board snapshot.
Restart and recovery create a fresh instance. After shutdown, the old instance
must not be used.

The old top-level names `normalize`, `candidate_eliminations`,
`validate_completion`, and `compile_overlay` are rejected by Script V1.

## Required and optional functions

| Function | Required | Purpose |
|---|---:|---|
| `define(config, scope)` | Materialized rules | Return typed predicates and optional startup marks. |
| `create(config, scope)` | Runtime rules | Create one private Rule Instance for one puzzle rule. |
| `instance.validate_move(ctx, move)` | Yes | Report whether the rule accepts the submitted move. |
| `instance.validate_board(ctx)` | Yes | Report current violations. |
| `instance.validate_final_state(ctx)` | Yes | Report whether the rule is valid at final-state checking. |

Optional functions:

| Function | Purpose |
|---|---|
| `instance.get_candidate_eliminations(ctx, cell, base_candidates)` | Return only digits to remove from the Host candidate set. |
| `instance.build_overlay(ctx)` | Return declaration-only board marks. The app owns drawing, theme, and layout. |

`move` has a 0-based cell and a digit from `1..9`; clearing may use `0`.

## Bounded cell-state rules

`cell_state_rule` exposes a bounded progressive-visibility rule. Lua derives
the complete immutable declaration in `main.lua`; puzzle JSON may contain only
initial hidden-cell geometry or another puzzle-varying bounded parameter. The
game owns event delivery, input blocking, visibility state, undo, restart,
persistence, recovery, and board projection.

The Fog of War example uses one `correct` placement to reveal a king-radius-one
area. A different package may derive one to four ordered transitions, but the
public vocabulary remains:

- event: `move.committed`;
- placement: `correct` or `any`;
- effect: `set_cell_state` to `visible` with `union` accumulation;
- selector: `move.cell`, expanded by `king` or `orthogonal`, radius `0..2`;
- restart: `initial`.

Do not add arbitrary events, state names, re-hide effects, custom selectors,
Lua mutable state, painter callbacks, candidate ownership, or package-ID
branches. A new named Mod still needs its own identity and product admission.

## Data model and SDK helpers

Cells use a 0-based row-major index:

```text
r1c1 = 0   r1c9 = 8
r2c1 = 9   r9c9 = 80
```

Use the SDK helpers for scalar reads and validation:

```lua
local board = community_variant.board
local cell = community_variant.cell
local digit = board.value(ctx, current_cell)
local empty = board.is_empty(digit)
local checked_cell = cell.expect(raw_cell, "path cell")
```

The public namespaces are `board`, `cell`, `schema`, `adjacency`, `path`, and
`overlay_geometry`. They validate bounded geometry, calculate row/column and
edge identities, and convert cells to existing board coordinates. They do not
provide named gameplay helpers such as `thermometer(path)` or `killer(cage)`;
the complete rule remains readable in `main.lua`.

`ctx.board.cells[row][col]` remains a read-only public table for deliberate
bounded traversal or snapshot identity checks. Do not copy a private adapter
for scalar reads, empty checks, or cell range validation.

## Constraint examples

Dynamic sequence selection uses `constraint.element_at(cells,
constraint.value(index_cell))`. The sequence must contain nine ordered,
distinct cells in `0..80`; the selector digit chooses positions `1..9`.
Sequence order is semantic and must not be sorted.

```lua
local c = community_variant.constraint
local selected = c.element_at(
  { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
  c.value(10)
)

return { constraints = { c.equal(selected, c.constant(9)) } }
```

The current contract accepts only direct
`equal(element_at(cells, value(index_cell)), constant(target))`. Do not nest
`element_at` inside `sum`, `not_equal`, logical operators, or another
`element_at`, and do not write internal runtime plan IDs in Lua or JSON.

Position-selected pair sums use
`constraint.value_selected_pair_sum_equals_constant`. It accepts one ordered
nine-cell sequence, two distinct selector cells, and a fixed target. The two
selected values must add to that target, and the predicate belongs directly in
the root `constraints` array.

Fixed sums use `constraint.exact_sum_equals_constant` with `2..4` distinct
cells and a target. Cell order has no meaning and is canonicalized by the SDK.
The target must be between the number of cells and nine times that number.

Frequency and multiset relations use the intent-level helpers
`self_referential_frequency(group_cells)` and
`multiset_equal(first_cells, second_cells)`. Both belong directly in the root
`constraints` array. Do not write wire operator IDs, evidence, histograms,
candidate state, or runtime plan IDs.

## Overlay return shapes

`build_overlay` returns declaration-only primitives. For example:

```lua
return {
  primitives = {
    {
      type = "line",
      from = { x = 0, y = 0 },
      to = { x = 9, y = 9 },
      paint = { stroke = { theme = "constraint_line" }, stroke_width = 0.04 },
    },
  },
  diagnostics = {},
}
```

Use the built-in `boundary_label` for row/column edge numbers and
`outside_ray_clue` for clues entering the board from an edge. These built-ins
describe marks only; the Lua handler must independently implement the matching
validation and final-state rule.

Overlay opacity is generally `0..1`. Cell and region fills are limited to
`0.6`; lines, paths, outlines, and text are not subject to that fill limit.

## Return shapes

```lua
-- validate_move
return {
  accepted = false,
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}

-- validate_board
return {
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}

-- get_candidate_eliminations
return {
  remove = { 5, 8 },
  reasons = { ["5"] = "my_rule_broken", ["8"] = "my_rule_broken" },
  diagnostics = {},
}

-- validate_final_state
return {
  valid = false,
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}
```

## Authority boundary

Lua may read an immutable board snapshot, validate the rule, report violating
cells, suggest candidate removals, return declaration-only marks, and return
author diagnostics.

Lua may not modify the board, block or roll back a Host transaction, replace
the complete candidate set, edit notes, write saves, control UI or completion
navigation, access files/network/time/randomness/native libraries, or write
official achievements, statistics, or progress.

## Package checks and publishing

Before sharing a package, check that every puzzle has an 81-digit solution,
preserves its givens, and supplies only the rule data that `main.lua` expects.
Malformed configuration should raise a clear initialization error instead of
silently changing the rule. Use the app's local plugin preview to test the
package, then publish the same validated package to Steam Workshop.

## Common mistakes

| Mistake | Correct approach |
|---|---|
| Starting with `community_variant.new()` or `constraint_program()` | Start with `community_variant.script()` and Script V1. |
| Hand-writing API, runtime, or permission fields in the manifest | Use manifest schema 3 with only the stable package fields. |
| Mixing `define` and `create` in one handler | Select one execution profile. |
| Copying a private board adapter | Use `board.value`, `board.is_empty`, and `cell.expect`. |
| Putting fixed rule meaning in puzzle JSON | Derive fixed semantics in `main.lua`; keep JSON puzzle-varying. |
| Returning a complete candidate set | Return only digits to remove. |
| Making every fill opacity `0.6` | Apply the `0.6` limit only to cell/region fills. |
| Treating an operator fixture as a playable Mod | Use a complete public example with substantive Lua logic. |

For a complete public inventory and the closest player-visible starting point,
return to the [SDK home](README.md).
