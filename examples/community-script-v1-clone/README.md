# Clone Sudoku

`rules.clone.regions` contains exactly two translated, orthogonally connected
cell regions. `main.lua` validates and canonicalizes those regions, derives the
corresponding cell pairs, emits typed `equal(value(a), value(b))` predicates,
and derives the matching region Overlay from the same normalized model. The
Host compiles those predicates once and runs the resulting Native Constraint
Program during gameplay; Clone does not register gameplay Lua callbacks.

Each puzzle supplies only the two regions; it does not contain the derived
cell-pair equality rules.
