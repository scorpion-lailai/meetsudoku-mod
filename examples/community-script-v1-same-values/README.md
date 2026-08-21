# Same Values Sudoku

`rules.same_values.labels` contains one or two labels, each joining exactly two
equal-sized, orthogonally connected and globally disjoint regions. `main.lua`
validates and canonicalizes that geometry, derives one generic
`multiset_equal` constraint per label, and projects matching region fill,
outline and labels from the same normalized model. Gameplay runs only the
materialized Native Constraint Program.

Each puzzle supplies only the labelled regions; `main.lua` derives the
multiset-equality relationship and matching presentation.
