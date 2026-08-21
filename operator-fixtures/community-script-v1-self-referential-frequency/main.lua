-- Generic Self-Referential Frequency Constraint operator fixture for Script API V1.
-- This is an authoring proof, not a named Sudoku variant or release bank.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local schema = community_variant.schema
local frequency = {}

local function normalize(config)
  schema.expect_exact_keys(config, { cells = true }, "frequency")
  schema.expect_array(config.cells, 1, 9, "frequency.cells")
  return { cells = config.cells }
end

local function build_constraints(model)
  return {
    constraint.self_referential_frequency(model.cells)
  }
end

function frequency.define(config, scope)
  local model = normalize(config)
  return { constraints = build_constraints(model) }
end

plugin:register_rule("frequency", frequency)
return plugin:build()
