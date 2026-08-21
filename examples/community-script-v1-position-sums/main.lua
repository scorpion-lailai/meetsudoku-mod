-- Position Sums technical Demo for Script API V1.
-- The package derives each directed line, its two selector cells, both
-- arithmetic relations and the generic two-lane boundary presentation.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema

local position_sums = {}

local function normalize_side(axis, side, path)
  if axis == "row" and (side == "left" or side == "right") then
    return side
  end
  if axis == "column" and (side == "top" or side == "bottom") then
    return side
  end
  error(path .. " has an invalid side for its axis")
end

local function build_sequence(axis, side, index)
  local cells = {}
  if axis == "row" then
    for offset = 0, 8 do
      local column = side == "left" and offset or 8 - offset
      cells[#cells + 1] = index * 9 + column
    end
  else
    for offset = 0, 8 do
      local row = side == "top" and offset or 8 - offset
      cells[#cells + 1] = row * 9 + index
    end
  end
  return cells
end

local function normalize(config)
  schema.expect_exact_keys(config, { clues = true }, "position_sums")
  schema.expect_array(config.clues, 1, 32, "position_sums.clues")
  local clues = {}
  local locations = {}
  for ordinal, raw in ipairs(config.clues) do
    local path = "position_sums.clues[" .. ordinal .. "]"
    schema.expect_exact_keys(
      raw,
      { axis = true, side = true, index = true, first_sum = true, selected_sum = true },
      path
    )
    if raw.axis ~= "row" and raw.axis ~= "column" then
      error(path .. ".axis must be row or column")
    end
    local side = normalize_side(raw.axis, raw.side, path .. ".side")
    local index = schema.expect_integer(raw.index, path .. ".index")
    if index < 0 or index > 8 then error(path .. ".index must be 0..8") end
    local first_sum = schema.expect_integer(raw.first_sum, path .. ".first_sum")
    local selected_sum = schema.expect_integer(raw.selected_sum, path .. ".selected_sum")
    if first_sum < 2 or first_sum > 18 then
      error(path .. ".first_sum must be 2..18")
    end
    if selected_sum < 2 or selected_sum > 18 then
      error(path .. ".selected_sum must be 2..18")
    end
    local location = raw.axis .. ":" .. side .. ":" .. tostring(index)
    if locations[location] then error(path .. " duplicates a boundary location") end
    locations[location] = true
    local cells = build_sequence(raw.axis, side, index)
    clues[#clues + 1] = {
      axis = raw.axis,
      side = side,
      index = index,
      cells = cells,
      first_sum = first_sum,
      selected_sum = selected_sum
    }
  end
  table.sort(clues, function(first, second)
    local left = first.axis .. ":" .. first.side .. ":" .. tostring(first.index)
    local right = second.axis .. ":" .. second.side .. ":" .. tostring(second.index)
    return left < right
  end)
  return clues
end

local function build_constraints(clues)
  local predicates = {}
  for _, clue in ipairs(clues) do
    predicates[#predicates + 1] = constraint.equal(
      constraint.sum({
        constraint.value(clue.cells[1]),
        constraint.value(clue.cells[2])
      }),
      constraint.constant(clue.first_sum)
    )
    predicates[#predicates + 1] =
      constraint.value_selected_pair_sum_equals_constant(
        clue.cells,
        clue.cells[1],
        clue.cells[2],
        clue.selected_sum
      )
  end
  return predicates
end

local function build_overlay(clues)
  local primitives = {}
  for _, clue in ipairs(clues) do
    primitives[#primitives + 1] = {
      type = "builtin",
      kind = "boundary_number_lanes",
      data = {
        axis = clue.axis,
        side = clue.side,
        index = clue.index,
        lanes = {
          { slot = 1, value = clue.first_sum },
          { slot = 2, value = clue.selected_sum }
        }
      }
    }
  end
  return { primitives = primitives }
end

function position_sums.define(config, scope)
  local clues = normalize(config)
  return {
    constraints = build_constraints(clues),
    overlay = build_overlay(clues)
  }
end

plugin:register_rule("position_sums", position_sums)
return plugin:build()
