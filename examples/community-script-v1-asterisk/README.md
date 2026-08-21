# Asterisk Sudoku

The nine cells on the drawn asterisk must
contain the digits 1 through 9 without repetition.

`main.lua` derives the fixed nine-cell group and its three visible axes from
the board center. It then emits one generic `all_different` constraint and
three path Overlay primitives. The Host materializes the constraint once at
startup and owns gameplay, candidates, conflicts, completion, persistence and
rendering.
