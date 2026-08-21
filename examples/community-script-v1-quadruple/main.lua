-- Community Variant Script API V1 Quadruple Sudoku semantic fixture.
-- Community Variant Script API V1 四数提示数独语义测试包。
--
-- The package fixes the required-multiset rule in this file. Puzzle data may
-- supply only internal intersection coordinates and displayed
-- digits. The Host owns board mutation, candidate display, completion, saves,
-- progress and rendering; this handler returns bounded typed proposals only.
local plugin = community_variant.script()
local quadruple = {}
local board = community_variant.board

local MAX_CLUES = 32
local VIOLATION_CODE = "quadruple_membership"

local function expect_exact_keys(value, allowed, label)
  if type(value) ~= "table" then
    error(label .. " must be an object")
  end
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

local function expect_integer(value, minimum, maximum, label)
  if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
    error(label .. " must be an integer in " .. minimum .. ".." .. maximum)
  end
  return value
end

local function surrounding_cells(row, column)
  local top_left = (row - 1) * 9 + (column - 1)
  return {
    top_left,
    top_left + 1,
    top_left + 9,
    top_left + 10
  }
end

local function normalize_clues(config)
  expect_exact_keys(config, { clues = true }, "quadruple data")
  expect_array(config.clues, 1, MAX_CLUES, "quadruple data.clues")

  local clues = {}
  local by_cell = {}
  local used_intersections = {}

  for index, raw in ipairs(config.clues) do
    local label = "quadruple clue " .. index
    expect_exact_keys(raw, {
      intersection = true,
      digits = true
    }, label)
    expect_exact_keys(raw.intersection, {
      row = true,
      column = true
    }, label .. ".intersection")
    expect_array(raw.digits, 1, 4, label .. ".digits")

    local row = expect_integer(raw.intersection.row, 1, 8, label .. ".intersection.row")
    local column = expect_integer(
      raw.intersection.column,
      1,
      8,
      label .. ".intersection.column"
    )
    local intersection_key = tostring(row) .. ":" .. tostring(column)
    if used_intersections[intersection_key] then
      error("quadruple clues must not repeat an intersection")
    end
    used_intersections[intersection_key] = true

    local digits = {}
    local required = {}
    for digit_index, raw_digit in ipairs(raw.digits) do
      local digit = expect_integer(raw_digit, 1, 9, label .. ".digits[" .. digit_index .. "]")
      digits[#digits + 1] = digit
      required[digit] = (required[digit] or 0) + 1
    end

    local clue = {
      row = row,
      column = column,
      cells = surrounding_cells(row, column),
      digits = digits,
      required = required
    }
    clues[#clues + 1] = clue
    local clue_index = #clues
    for _, cell in ipairs(clue.cells) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = clue_index
    end
  end

  return { clues = clues, by_cell = by_cell }
end

local function clue_value(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

-- One empty cell can satisfy only one missing occurrence. Summing all missing
-- multiplicities prevents two different clue digits from competing for the
-- same final slot.
local function clue_is_feasible(clue, ctx, override_cell, override_digit)
  local assigned = {}
  local empty_count = 0
  for _, cell in ipairs(clue.cells) do
    local value = clue_value(ctx, cell, override_cell, override_digit)
    if board.is_empty(value) then
      empty_count = empty_count + 1
    elseif clue.required[value] ~= nil then
      assigned[value] = (assigned[value] or 0) + 1
    end
  end

  local missing_count = 0
  for digit, required_count in pairs(clue.required) do
    local missing = required_count - (assigned[digit] or 0)
    if missing > 0 then
      missing_count = missing_count + missing
    end
  end
  return missing_count <= empty_count
end

local function violation(clue)
  return {
    code = VIOLATION_CODE,
    cells = { clue.cells[1], clue.cells[2], clue.cells[3], clue.cells[4] }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    if not clue_is_feasible(clue, ctx, override_cell, override_digit) then
      violations[#violations + 1] = violation(clue)
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local clue_indexes = model.by_cell[cell]
  if clue_indexes == nil then
    return true
  end
  for _, clue_index in ipairs(clue_indexes) do
    if not clue_is_feasible(model.clues[clue_index], ctx, cell, digit) then
      return false
    end
  end
  return true
end

local function clue_text(digits)
  if #digits == 1 then
    return tostring(digits[1])
  end
  if #digits == 2 then
    return tostring(digits[1]) .. " " .. tostring(digits[2])
  end
  local first_line = tostring(digits[1]) .. " " .. tostring(digits[2])
  if #digits == 3 then
    return first_line .. "\n" .. tostring(digits[3])
  end
  return first_line .. "\n" .. tostring(digits[3]) .. " " .. tostring(digits[4])
end

local function clue_overlay(clue)
  local center = { x = clue.column, y = clue.row }
  return {
    {
      type = "circle",
      center = center,
      radius = 0.34,
      paint = {
        stroke = { theme = "constraint_line" },
        fill = "#FFFFFF",
        stroke_width = 0.035,
        opacity = 1
      }
    },
    {
      type = "text",
      position = center,
      value = clue_text(clue.digits),
      paint = {
        fill = { theme = "constraint_line" },
        text_size = 0.20,
        text_align = "center",
        opacity = 1
      }
    }
  }
end

function quadruple.create(config, scope)
  local model = normalize_clues(config)
  return {
    validate_move = function(ctx, move)
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
      local cells = {}
      for cell = 0, 80 do
        if model.by_cell[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = VIOLATION_CODE
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, clue in ipairs(model.clues) do
        local pair = clue_overlay(clue)
        primitives[#primitives + 1] = pair[1]
        primitives[#primitives + 1] = pair[2]
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("quadruple", quadruple)

return plugin:build()
