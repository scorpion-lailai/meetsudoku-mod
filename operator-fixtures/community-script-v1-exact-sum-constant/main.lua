-- Generic exact-sum constant operator fixture for Script API V1.
-- This is authoring and materialization evidence only, not a playable Mod.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local exact_sum = {}

local function normalize(config)
  schema.expect_exact_keys(
    config,
    {
      cells = true,
      target = true
    },
    "exact_sum"
  )
  schema.expect_array(config.cells, 2, 4, "exact_sum.cells")
  local cells = {}
  local seen = {}
  for index, raw_cell in ipairs(config.cells) do
    local cell = cell_api.expect(raw_cell, "exact_sum.cells[" .. index .. "]")
    if seen[cell] then
      error("exact_sum.cells must not contain duplicates")
    end
    seen[cell] = true
    cells[index] = cell
  end
  table.sort(cells)
  local target = schema.expect_integer(config.target, "exact_sum.target")
  if target < #cells or target > 9 * #cells then
    error("exact_sum.target must be " .. #cells .. ".." .. (9 * #cells))
  end
  return {
    cells = cells,
    target = target
  }
end

function exact_sum.define(config, scope)
  local model = normalize(config)
  return {
    constraints = {
      constraint.exact_sum_equals_constant(model.cells, model.target)
    }
  }
end

plugin:register_rule("exact_sum", exact_sum)
return plugin:build()
