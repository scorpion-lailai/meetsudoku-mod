-- Anti-Taxicab is a startup-only materialized rule.
-- The package owns the fixed player rule: a digit X cannot occur again at
-- Manhattan distance X. Puzzle data activates this fixed rule but cannot
-- replace its geometry or relation.
local plugin = community_variant.script()
local anti_taxicab = {}
local cell = community_variant.cell
local schema = community_variant.schema

local function add_entry(entries, origin, target, digit)
  if origin < target then
    entries[#entries + 1] = {
      first = origin,
      second = target,
      forbidden_value = digit,
    }
  end
end

local function derive_entries()
  local entries = {}

  -- For each candidate digit, enumerate every positive decomposition of its
  -- Manhattan distance. The four sign combinations cover every direction.
  -- We retain only origin < target so the Host receives one canonical
  -- unordered pair; its Native graph then restores symmetric adjacency.
  for origin = 0, 80 do
    local row = cell.row(origin)
    local column = cell.column(origin)
    for digit = 1, 9 do
      for row_distance = 1, digit - 1 do
        local column_distance = digit - row_distance
        for _, row_sign in ipairs({ -1, 1 }) do
          for _, column_sign in ipairs({ -1, 1 }) do
            local target_row = row + row_sign * row_distance
            local target_column = column + column_sign * column_distance
            if target_row >= 0 and target_row <= 8
                and target_column >= 0 and target_column <= 8 then
              add_entry(
                entries,
                origin,
                cell.index(target_row, target_column),
                digit
              )
            end
          end
        end
      end
    end
  end

  if #entries ~= 2172 then
    error("anti_taxicab must derive exactly 2172 canonical entries")
  end
  return entries
end

function anti_taxicab.define(config, scope)
  schema.expect_exact_keys(config, {}, "anti_taxicab data")

  return {
    native_constraints = {
      {
        type = "value_dependent_exclusion_graph",
        id = "anti_taxicab_relation",
        entries = derive_entries(),
      },
    },
  }
end

plugin:register_rule("anti_taxicab", anti_taxicab)

return plugin:build()
