-- Generic value-selected pair-sum operator fixture for Script API V1.
-- This is an authoring proof, not a named Sudoku variant or a playable bank.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local pair_sum = {}

local function normalize(config)
  schema.expect_exact_keys(
    config,
    {
      cells = true,
      first_index_cell = true,
      second_index_cell = true,
      target = true
    },
    "value_selected_pair_sum"
  )
  schema.expect_array(config.cells, 9, 9, "value_selected_pair_sum.cells")
  local cells = {}
  local seen = {}
  for index, raw_cell in ipairs(config.cells) do
    local cell = cell_api.expect(
      raw_cell,
      "value_selected_pair_sum.cells[" .. index .. "]"
    )
    if seen[cell] then
      error("value_selected_pair_sum.cells must not contain duplicates")
    end
    seen[cell] = true
    cells[index] = cell
  end
  local first = cell_api.expect(
    config.first_index_cell,
    "value_selected_pair_sum.first_index_cell"
  )
  local second = cell_api.expect(
    config.second_index_cell,
    "value_selected_pair_sum.second_index_cell"
  )
  if first == second then
    error("value_selected_pair_sum selector cells must differ")
  end
  local target = schema.expect_integer(
    config.target,
    "value_selected_pair_sum.target"
  )
  if target < 2 or target > 18 then
    error("value_selected_pair_sum.target must be 2..18")
  end
  return {
    cells = cells,
    first = first,
    second = second,
    target = target
  }
end

function pair_sum.define(config, scope)
  local model = normalize(config)
  return {
    constraints = {
      constraint.value_selected_pair_sum_equals_constant(
        model.cells,
        model.first,
        model.second,
        model.target
      )
    }
  }
end

plugin:register_rule("value_selected_pair_sum", pair_sum)
return plugin:build()
