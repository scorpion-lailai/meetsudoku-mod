-- Community Variant Script API V1 Composite Sudoku reference implementation.
--
-- The rule handler owns only the Composite marked-cell semantics. The fixed
-- composite digit set is {4, 6, 8, 9}. Puzzle JSON owns only marked cells. The
-- Host owns board mutation, classic Sudoku legality, candidates, notes,
-- completion, persistence and rendering.
local plugin = community_variant.script()
local composite = {}
local board = community_variant.board
local cell_api = community_variant.cell

local COMPOSITE_DIGITS = {
  [4] = true,
  [6] = true,
  [8] = true,
  [9] = true
}

local NON_COMPOSITE_DIGITS = { 1, 2, 3, 5, 7 }
local VIOLATION_CODE = "composite_digit_required"
local INCOMPLETE_CODE = "composite_incomplete"

local function expect_exact_keys(value, allowed, label)
  if type(value) ~= "table" then error(label .. " must be an object") end
  for key, _ in pairs(value) do
    if not allowed[key] then
      error(label .. " contains unsupported field " .. tostring(key))
    end
  end
end

local function expect_array(value, minimum, maximum, label)
  if type(value) ~= "table" or #value < minimum or #value > maximum then
    error(label .. " must contain " .. minimum .. ".." .. maximum .. " items")
  end
  for key, _ in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value then
      error(label .. " must be a dense array")
    end
  end
end

local function normalize_cells(config)
  expect_exact_keys(config, { cells = true }, "composite data")
  expect_array(config.cells, 1, 40, "composite data.cells")

  local cells = {}
  local by_cell = {}
  for index, raw_cell in ipairs(config.cells) do
    local cell = cell_api.expect(raw_cell, "composite cell " .. index)
    if by_cell[cell] then error("composite cells must not repeat a cell") end
    cells[#cells + 1] = cell
    by_cell[cell] = true
  end
  return { cells = cells, by_cell = by_cell }
end

local function is_composite_digit(value)
  return COMPOSITE_DIGITS[value] == true
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function make_violation(cell, code)
  return { code = code, cells = { cell } }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, cell in ipairs(model.cells) do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    if not board.is_empty(digit) and not is_composite_digit(digit) then
      violations[#violations + 1] = make_violation(cell, VIOLATION_CODE)
    end
  end
  return violations
end

local function final_violations(model, ctx)
  local violations = {}
  for _, cell in ipairs(model.cells) do
    local digit = board.value(ctx, cell)
    if board.is_empty(digit) then
      violations[#violations + 1] = make_violation(cell, INCOMPLETE_CODE)
    elseif not is_composite_digit(digit) then
      violations[#violations + 1] = make_violation(cell, VIOLATION_CODE)
    end
  end
  return violations
end

local function cell_center(cell)
  local row = math.floor(cell / 9)
  local column = cell % 9
  return { x = column + 0.5, y = row + 0.5 }
end

local function mark_overlay(cell)
  local center = cell_center(cell)
  return {
    {
      type = "circle",
      center = center,
      radius = 0.24,
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = 0.035,
        opacity = 1
      }
    },
    {
      type = "text",
      position = center,
      value = "C",
      paint = {
        fill = { theme = "constraint_line" },
        text_size = 0.28,
        text_align = "center",
        opacity = 1
      }
    }
  }
end

function composite.create(config, scope)
  local model = normalize_cells(config)
  return {
    validate_move = function(ctx, move)
      if not model.by_cell[move.cell] or board.is_empty(move.digit) then
        return { accepted = true, violations = {}, diagnostics = {} }
      end
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    candidate_scope = function()
      return model.cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      if not model.by_cell[cell] then
        return { remove = {}, reasons = {}, diagnostics = {} }
      end
      local reasons = {}
      for _, digit in ipairs(NON_COMPOSITE_DIGITS) do
        reasons[tostring(digit)] = VIOLATION_CODE
      end
      return {
        remove = NON_COMPOSITE_DIGITS,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    validate_final_state = function(ctx)
      local violations = final_violations(model, ctx)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, cell in ipairs(model.cells) do
        for _, primitive in ipairs(mark_overlay(cell)) do
          primitives[#primitives + 1] = primitive
        end
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("composite", composite)

return plugin:build()
