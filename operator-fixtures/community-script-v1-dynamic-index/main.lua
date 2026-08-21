-- Generic Dynamic Index Constraint operator fixture for Script API V1.
-- This is an authoring proof, not a named Sudoku variant or a 159 package.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local dynamic_index = {}

local function normalize(config)
  schema.expect_exact_keys(
    config,
    { cells = true, index_cell = true, target = true },
    "dynamic_index"
  )
  schema.expect_array(config.cells, 9, 9, "dynamic_index.cells")

  local cells = {}
  local seen = {}
  for index, raw_cell in ipairs(config.cells) do
    local cell = cell_api.expect(
      raw_cell,
      "dynamic_index.cells[" .. index .. "]"
    )
    if seen[cell] then
      error("dynamic_index.cells must not contain duplicates")
    end
    seen[cell] = true
    cells[index] = cell
  end

  local index_cell = cell_api.expect(
    config.index_cell,
    "dynamic_index.index_cell"
  )
  local target = schema.expect_integer(config.target, "dynamic_index.target")
  if target < 1 or target > 9 then
    error("dynamic_index.target must be in 1..9")
  end

  return {
    cells = cells,
    index_cell = index_cell,
    target = target
  }
end

function dynamic_index.define(config, scope)
  local model = normalize(config)
  local selected_value = constraint.element_at(
    model.cells,
    constraint.value(model.index_cell)
  )
  return {
    constraints = {
      constraint.equal(selected_value, constraint.constant(model.target))
    }
  }
end

plugin:register_rule("dynamic_index", dynamic_index)
return plugin:build()
