-- Generic Multiset Equality Constraint operator fixture for Script API V1.
-- This is an authoring proof, not a named Sudoku variant or release bank.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local schema = community_variant.schema
local multiset = {}

local function normalize(config)
  schema.expect_exact_keys(
    config,
    { first_cells = true, second_cells = true },
    "multiset"
  )
  schema.expect_array(config.first_cells, 1, 9, "multiset.first_cells")
  schema.expect_array(config.second_cells, 1, 9, "multiset.second_cells")
  return {
    first_cells = config.first_cells,
    second_cells = config.second_cells
  }
end

local function build_constraints(model)
  return {
    constraint.multiset_equal(model.first_cells, model.second_cells)
  }
end

function multiset.define(config, scope)
  local model = normalize(config)
  return { constraints = build_constraints(model) }
end

plugin:register_rule("multiset", multiset)
return plugin:build()
