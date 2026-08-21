# Fog of War Sudoku

This is the Script V1 schema 6 reference package for Fog of War.
`main.lua` registers a real `fog` handler and returns an author-facing
`cell_state_rule` semantic object; the Host materializes it into the internal
`cell_state` runtime feature. Each puzzle provides its initial
`rules.fog.covered_cells` mask.

Fog's Lua model may call the action a reveal, but the exported semantic object
uses generic state-transition terms: `move.committed` event, correct-placement
condition, `move.cell` selector, king-neighborhood expansion and a
`set_cell_state` effect that marks selected cells `visible`.

Level progression and Daily Sudoku are enabled. Daily selection uses a fixed
seed so every player receives the same puzzle on the same date.

The Host validates and executes the generic declaration and owns mutable board,
visibility, input, notes, completion, persistence and rendering state.
