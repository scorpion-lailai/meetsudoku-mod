# Counting Circles Sudoku

`rules.counting_circles.groups` contains only one or two disjoint groups of
three to eight cell indexes. For every digit `d` present in a group, that digit
must occur exactly `d` times in the group, including the cell carrying it.
`main.lua` validates and canonicalizes the groups, derives one generic
`self_referential_frequency` root per group, and derives one outline circle per
marked cell from the same model. The Host materializes the roots at startup and
owns gameplay validation, candidates, notes, completion, persistence and UI.

Each puzzle supplies only the marked groups; the frequency rule itself stays
fixed in `main.lua`.
