-- Disjoint Groups Sudoku, Community Variant Script API V1.
-- 不相交组数独：固定保留经典数独，并增加九个相同相对位置组。
local plugin = community_variant.script()
local constraint = community_variant.constraint
local disjoint_groups = {}

local function cell_index(box_row, box_col, local_row, local_col)
  return (box_row + local_row) * 9 + (box_col + local_col)
end

local function build_nine_all_different_groups()
  local predicates = {}
  local group_index = 0

  -- Each local position is repeated once in each of the nine 3x3 boxes.
  for local_row = 0, 2 do
    for local_col = 0, 2 do
      local cells = {}
      for box_row = 0, 6, 3 do
        for box_col = 0, 6, 3 do
          cells[#cells + 1] = cell_index(box_row, box_col, local_row, local_col)
        end
      end
      group_index = group_index + 1
      predicates[group_index] = constraint.all_different(cells)
    end
  end

  return predicates
end

-- The geometry is package-invariant. Puzzle data may only activate this
-- handler and cannot redefine or partially enable its nine groups.
function disjoint_groups.define(config, scope)
  if config == nil then
    config = {}
  end
  if next(config) ~= nil then
    error("disjoint_groups does not accept puzzle geometry")
  end
  return { constraints = build_nine_all_different_groups() }
end

plugin:register_rule("disjoint_groups", disjoint_groups)
return plugin:build()
