-- Intersection Sum Sudoku, product-owned materialized public reference.
-- Puzzle data owns only clue coordinates and target sums. Lua validates that
-- data, derives each four-cell window, and materializes generic constraints.
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local intersection_sum = {}

-- exact_sum_equals_constant@1 uses a bounded independent-digit interval
-- analysis plan. This public profile accepts four through eight visible clues.
local MIN_CLUES = 4
local MAX_CLUES = 8
local MIN_SUM = 6
local MAX_SUM = 30

local function key_for(row, column)
  return string.format("%02d:%02d", row, column)
end

local function expect_range(value, minimum, maximum, label)
  local result = schema.expect_integer(value, label)
  if result < minimum or result > maximum then
    error(label .. " must be in " .. minimum .. ".." .. maximum)
  end
  return result
end

local function window_cells(row, column)
  local top_left = cell_api.index(row - 1, column - 1)
  return {top_left, top_left + 1, top_left + 9, top_left + 10}
end

local function normalize(config)
  schema.expect_exact_keys(config, {clues = true}, "intersection_sum data")
  schema.expect_array(config.clues, MIN_CLUES, MAX_CLUES, "intersection_sum.clues")

  local clues, seen = {}, {}
  for position, raw in ipairs(config.clues) do
    local label = "intersection_sum.clues[" .. position .. "]"
    schema.expect_exact_keys(raw, {row = true, column = true, sum = true}, label)
    local row = expect_range(raw.row, 1, 8, label .. ".row")
    local column = expect_range(raw.column, 1, 8, label .. ".column")
    local target = expect_range(raw.sum, MIN_SUM, MAX_SUM, label .. ".sum")
    local key = key_for(row, column)
    if seen[key] then error("intersection_sum.clues must not repeat an intersection") end
    seen[key] = true
    clues[#clues + 1] = {
      row = row,
      column = column,
      target = target,
      key = key,
      cells = window_cells(row, column)
    }
  end
  table.sort(clues, function(first, second) return first.key < second.key end)
  return {clues = clues}
end

local function build_constraints(model)
  local predicates = {}
  for _, clue in ipairs(model.clues) do
    predicates[#predicates + 1] =
      constraint.exact_sum_equals_constant(clue.cells, clue.target)
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, clue in ipairs(model.clues) do
    local center = {x = clue.column, y = clue.row}
    primitives[#primitives + 1] = {
      type = "circle",
      center = center,
      radius = 0.30,
      paint = {
        stroke = {theme = "constraint_line"},
        fill = "#FFFFFF",
        stroke_width = 0.035,
        opacity = 1
      }
    }
    primitives[#primitives + 1] = {
      type = "text",
      position = center,
      value = tostring(clue.target),
      paint = {
        fill = {theme = "constraint_line"},
        text_size = 0.24,
        text_align = "center",
        opacity = 1
      }
    }
  end
  return {primitives = primitives}
end

-- define runs once at exact-session startup. The Host validates and compiles
-- the typed predicates into the Native Rule Graph; gameplay never calls Lua.
function intersection_sum.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("intersection_sum", intersection_sum)
return plugin:build()
