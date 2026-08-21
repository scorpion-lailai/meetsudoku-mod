-- Community Variant Script API V1 Battenburg Sudoku reference package.
-- Lua owns checkerboard semantics and bounded observations; the Host owns state.
local plugin = community_variant.script()
local battenburg = {}

local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema

local MIN_DIGIT = 1
local MAX_DIGIT = 9
local ORDER_CODE = "battenburg_pattern_required"
local UNMARKED_CODE = "battenburg_unmarked_pattern_forbidden"
local INCOMPLETE_CODE = "battenburg_incomplete"
local MARKER_PATH_SIZE = 12
local DARK_PATH_SIZE = 6
local MARKER_HALF_SIZE = 0.16
local DARK_HALF_SIZE = 0.14

local function marker_key(row, column)
  return tostring(row) .. ":" .. tostring(column)
end

local function window_cells(row, column)
  local top_left = cell_api.index(row - 1, column - 1)
  return {top_left, top_left + 1, top_left + 9, top_left + 10}
end

local function normalize(config)
  schema.expect_exact_keys(config, {intersections = true}, "battenburg data")
  schema.expect_array(config.intersections, 1, 32, "battenburg.intersections")

  local intersections = {}
  local marked_by_key = {}
  local seen = {}
  for index, raw in ipairs(config.intersections) do
    schema.expect_exact_keys(raw, {row = true, column = true},
        "battenburg.intersections[" .. index .. "]")
    local row = schema.expect_integer(raw.row,
        "battenburg.intersections[" .. index .. "].row")
    local column = schema.expect_integer(raw.column,
        "battenburg.intersections[" .. index .. "].column")
    if row < 1 or row > 8 or column < 1 or column > 8 then
      error("battenburg intersection row and column must be in 1..8")
    end
    local key = marker_key(row, column)
    if seen[key] then error("battenburg.intersections must not repeat an intersection") end
    seen[key] = true
    intersections[#intersections + 1] = {row = row, column = column, key = key}
    marked_by_key[key] = true
  end
  table.sort(intersections, function(a, b) return a.key < b.key end)

  local windows = {}
  local windows_by_cell = {}
  for row = 1, 8 do
    for column = 1, 8 do
      local key = marker_key(row, column)
      local window = {cells = window_cells(row, column), marked = marked_by_key[key] == true,
        row = row, column = column, key = key}
      windows[#windows + 1] = window
      for _, cell in ipairs(window.cells) do
        windows_by_cell[cell] = windows_by_cell[cell] or {}
        windows_by_cell[cell][#windows_by_cell[cell] + 1] = window
      end
    end
  end
  local candidate_scope = {}
  for cell = 0, 80 do candidate_scope[#candidate_scope + 1] = cell end
  return {intersections = intersections, marked_by_key = marked_by_key, windows = windows,
    windows_by_cell = windows_by_cell, candidate_scope = candidate_scope}
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function parity(value)
  if value == 0 then return nil end
  return value % 2
end

local ORIENTATIONS = {{1, 0, 0, 1}, {0, 1, 1, 0}}
local function matches_orientation(values, orientation)
  for index, value in ipairs(values) do
    local actual = parity(value)
    if actual ~= nil and actual ~= orientation[index] then return false end
  end
  return true
end

local function checker_possible(values)
  return matches_orientation(values, ORIENTATIONS[1]) or matches_orientation(values, ORIENTATIONS[2])
end

local function window_fails(window, ctx, override_cell, override_digit)
  local values = {}
  local complete = true
  for index, cell in ipairs(window.cells) do
    values[index] = value_for(ctx, cell, override_cell, override_digit)
    if values[index] == 0 then complete = false end
  end
  local possible = checker_possible(values)
  if window.marked then return not possible, ORDER_CODE end
  return complete and possible, UNMARKED_CODE
end

local function failing_windows(model, ctx, cell, digit)
  local windows = cell == nil and model.windows or (model.windows_by_cell[cell] or {})
  local result = {}
  for _, window in ipairs(windows) do
    local failed, code = window_fails(window, ctx, cell, digit)
    if failed then result[#result + 1] = {window = window, code = code} end
  end
  return result
end

local function candidate_failure_code(model, ctx, cell, digit)
  for _, window in ipairs(model.windows_by_cell[cell] or {}) do
    local filled_other = 0
    for _, window_cell in ipairs(window.cells) do
      if window_cell ~= cell and board.value(ctx, window_cell) ~= 0 then
        filled_other = filled_other + 1
      end
    end
    if (window.marked and filled_other > 0)
        or (not window.marked and filled_other == 3) then
      local failed, code = window_fails(window, ctx, cell, digit)
      if failed then return code end
    end
  end
  return nil
end

local function violations_for(failures)
  local grouped = {}
  local order = {}
  for _, failure in ipairs(failures) do
    if grouped[failure.code] == nil then grouped[failure.code] = {code = failure.code, cells = {}, seen = {}}; order[#order + 1] = failure.code end
    local group = grouped[failure.code]
    for _, cell in ipairs(failure.window.cells) do
      if not group.seen[cell] then group.cells[#group.cells + 1] = cell; group.seen[cell] = true end
    end
  end
  local violations = {}
  for _, code in ipairs(order) do
    table.sort(grouped[code].cells)
    grouped[code].seen = nil
    violations[#violations + 1] = grouped[code]
  end
  return violations
end

local function append_rect(commands, left, top, right, bottom)
  commands[#commands + 1] = {op = "move_to", x = left, y = top}
  commands[#commands + 1] = {op = "line_to", x = right, y = top}
  commands[#commands + 1] = {op = "line_to", x = right, y = bottom}
  commands[#commands + 1] = {op = "line_to", x = left, y = bottom}
  commands[#commands + 1] = {op = "close"}
end

local function marker_center(intersection)
  return {x = intersection.column, y = intersection.row}
end

local function build_overlay(model)
  local primitives = {}
  local background, dark
  for index, intersection in ipairs(model.intersections) do
    if (index - 1) % MARKER_PATH_SIZE == 0 then
      background = {}
      primitives[#primitives + 1] = {type = "path", commands = background, paint = {
        fill = "#FFFFFF", stroke = {theme = "constraint_line"}, stroke_width = 0.025, opacity = 1.0}}
    end
    if (index - 1) % DARK_PATH_SIZE == 0 then
      dark = {}
      primitives[#primitives + 1] = {type = "path", commands = dark, paint = {
        fill = {theme = "constraint_line"}, opacity = 1.0}}
    end
    local center = marker_center(intersection)
    append_rect(background, center.x - MARKER_HALF_SIZE, center.y - MARKER_HALF_SIZE,
      center.x + MARKER_HALF_SIZE, center.y + MARKER_HALF_SIZE)
    append_rect(dark, center.x - DARK_HALF_SIZE, center.y - DARK_HALF_SIZE, center.x,
      center.y)
    append_rect(dark, center.x, center.y, center.x + DARK_HALF_SIZE,
      center.y + DARK_HALF_SIZE)
  end
  return primitives
end

function battenburg.create(config, scope)
  local model = normalize(config)
  return {
    validate_move = function(ctx, move)
      local failures = failing_windows(model, ctx, move.cell, move.digit)
      return {accepted = #failures == 0, violations = violations_for(failures), diagnostics = {}}
    end,
    validate_board = function(ctx)
      local failures = failing_windows(model, ctx, nil, nil)
      return {violations = violations_for(failures), diagnostics = {}}
    end,
    candidate_scope = function() return model.candidate_scope end,
    get_candidate_eliminations = function(ctx, cell, base_candidates)
      local remove, reasons = {}, {}
      local candidates = base_candidates or {1, 2, 3, 4, 5, 6, 7, 8, 9}
      for _, digit in ipairs(candidates) do
        local code = candidate_failure_code(model, ctx, cell, digit)
        if code ~= nil then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = code
        end
      end
      return {remove = remove, reasons = reasons, diagnostics = {}}
    end,
    validate_final_state = function(ctx)
      local incomplete = {}
      for cell = 0, 80 do if board.is_empty(board.value(ctx, cell)) then incomplete[#incomplete + 1] = cell end end
      if #incomplete > 0 then
        return {valid = false, violations = {{code = INCOMPLETE_CODE, cells = incomplete}}, diagnostics = {}}
      end
      local failures = failing_windows(model, ctx, nil, nil)
      return {valid = #failures == 0, violations = violations_for(failures), diagnostics = {}}
    end,
    build_overlay = function(ctx) return {primitives = build_overlay(model), diagnostics = {}} end
  }
end

plugin:register_rule("battenburg", battenburg)
return plugin:build()
