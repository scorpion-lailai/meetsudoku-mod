-- Community Variant Script API V1 Renban Lines Sudoku reference package.
-- Community Variant Script API V1 连数线数独参考包。
--
-- This file owns the fixed rule: every line contains distinct digits that fit
-- one consecutive interval, while their order along the line is unrestricted.
-- Puzzle JSON owns only line geometry. The Host owns classic Sudoku rules,
-- board mutation, candidates, notes, completion, persistence and rendering;
-- this handler returns bounded validation, candidate and Overlay proposals.
-- 本文件固定规则语义：每条线上的数字互不重复，且能组成一个连续数字区间，在线上
-- 的顺序不限。题目 JSON 只保存线条几何。经典规则、棋盘变更、候选、笔记、完成、
-- 存档和渲染归 Host；handler 只返回有界的校验、候选和 Overlay 建议。
local plugin = community_variant.script()
local renban = {}
local overlay_geometry = community_variant.overlay_geometry
local board = community_variant.board
local cell_api = community_variant.cell

local MAX_LINES = 32
local MIN_LINE_LENGTH = 2
local MAX_LINE_LENGTH = 9
local DUPLICATE_CODE = "renban_duplicate"
local INTERVAL_CODE = "renban_no_consecutive_interval"
local INCOMPLETE_CODE = "renban_incomplete"

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

local function are_line_neighbors(first, second)
  local first_row = math.floor(first / 9)
  local first_column = first % 9
  local second_row = math.floor(second / 9)
  local second_column = second % 9
  local row_delta = math.abs(first_row - second_row)
  local column_delta = math.abs(first_column - second_column)
  return row_delta <= 1 and column_delta <= 1 and row_delta + column_delta > 0
end

local function orientation(first, second, third)
  local value = (second.x - first.x) * (third.y - first.y) -
      (second.y - first.y) * (third.x - first.x)
  if value > 0 then return 1 end
  if value < 0 then return -1 end
  return 0
end

local function on_segment(first, second, point)
  return point.x >= math.min(first.x, second.x) and
      point.x <= math.max(first.x, second.x) and
      point.y >= math.min(first.y, second.y) and
      point.y <= math.max(first.y, second.y)
end

local function segments_intersect(first_start, first_end, second_start, second_end)
  local first_second_start = orientation(first_start, first_end, second_start)
  local first_second_end = orientation(first_start, first_end, second_end)
  local second_first_start = orientation(second_start, second_end, first_start)
  local second_first_end = orientation(second_start, second_end, first_end)
  if first_second_start * first_second_end < 0 and
      second_first_start * second_first_end < 0 then
    return true
  end
  return (first_second_start == 0 and on_segment(first_start, first_end, second_start)) or
      (first_second_end == 0 and on_segment(first_start, first_end, second_end)) or
      (second_first_start == 0 and on_segment(second_start, second_end, first_start)) or
      (second_first_end == 0 and on_segment(second_start, second_end, first_end))
end

local function grid_point_for_cell(cell)
  return { x = cell % 9, y = math.floor(cell / 9) }
end

local function lines_intersect(first, second)
  local second_cells = {}
  for _, cell in ipairs(second) do
    second_cells[cell] = true
  end
  for _, cell in ipairs(first) do
    if second_cells[cell] then return true end
  end
  for first_offset = 1, #first - 1 do
    local first_start = grid_point_for_cell(first[first_offset])
    local first_end = grid_point_for_cell(first[first_offset + 1])
    for second_offset = 1, #second - 1 do
      local second_start = grid_point_for_cell(second[second_offset])
      local second_end = grid_point_for_cell(second[second_offset + 1])
      if segments_intersect(first_start, first_end, second_start, second_end) then
        return true
      end
    end
  end
  return false
end

local function path_key(line, reversed)
  local parts = {}
  for offset = 1, #line do
    local index = reversed and (#line - offset + 1) or offset
    parts[#parts + 1] = tostring(line[index])
  end
  return table.concat(parts, ":")
end

local function normalize_lines(config)
  -- Fixed semantics cannot be overridden by puzzle fields. The only accepted
  -- value is the per-puzzle line geometry.
  -- 固定规则不能由题目字段覆盖；这里只接受每题变化的线条几何。
  expect_exact_keys(config, { lines = true }, "renban data")
  expect_array(config.lines, 1, MAX_LINES, "renban data.lines")

  local lines = {}
  local lines_by_cell = {}
  local used_paths = {}

  for line_index, raw_line in ipairs(config.lines) do
    local label = "renban line " .. line_index
    expect_array(raw_line, MIN_LINE_LENGTH, MAX_LINE_LENGTH, label)

    local line = {}
    local used_cells = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if used_cells[cell] then
        error(label .. " must not repeat a cell")
      end
      used_cells[cell] = true
      line[offset] = cell

      if offset > 1 and not are_line_neighbors(line[offset - 1], cell) then
        error(label .. " must pass through adjacent cell centers")
      end
    end

    local forward_key = path_key(line, false)
    local reverse_key = path_key(line, true)
    if used_paths[forward_key] or used_paths[reverse_key] then
      error("renban lines must not repeat a path")
    end
    for _, existing in ipairs(lines) do
      if lines_intersect(line, existing) then
        error("renban lines must not intersect or share cells")
      end
    end
    used_paths[forward_key] = true
    used_paths[reverse_key] = true

    lines[#lines + 1] = line
    for _, cell in ipairs(line) do
      lines_by_cell[cell] = lines_by_cell[cell] or {}
      lines_by_cell[cell][#lines_by_cell[cell] + 1] = line
    end
  end

  return { lines = lines, lines_by_cell = lines_by_cell }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function inspect_line(line, ctx, override_cell, override_digit)
  -- For a line of length n, every assigned digit must fit at least one start
  -- interval [s, s+n-1], where 1 <= s <= 10-n. This existence test is shared
  -- by move validation, board validation, candidates and completion.
  -- 长度为 n 的线要求所有已填数字至少能落入一个 [s, s+n-1] 区间，且
  -- 1 <= s <= 10-n。落子、盘面、候选和完成判定共用这个存在性判断。
  local seen = {}
  local assigned_cells = {}
  local minimum = nil
  local maximum = nil
  local empty_count = 0

  for _, cell in ipairs(line) do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    if board.is_empty(digit) then
      empty_count = empty_count + 1
    else
      assigned_cells[#assigned_cells + 1] = cell
      if seen[digit] then
        return {
          valid = false,
          code = DUPLICATE_CODE,
          cells = assigned_cells,
          empty_count = empty_count
        }
      end
      seen[digit] = true
      minimum = minimum == nil and digit or math.min(minimum, digit)
      maximum = maximum == nil and digit or math.max(maximum, digit)
    end
  end

  if minimum == nil then
    return { valid = true, empty_count = empty_count }
  end

  local line_length = #line
  local lower_start = math.max(1, maximum - line_length + 1)
  local upper_start = math.min(10 - line_length, minimum)
  if lower_start > upper_start then
    return {
      valid = false,
      code = INTERVAL_CODE,
      cells = assigned_cells,
      empty_count = empty_count
    }
  end

  return { valid = true, empty_count = empty_count }
end

local function violation_for(line, inspection)
  return {
    code = inspection.code,
    cells = inspection.cells or line
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, line in ipairs(model.lines) do
    local inspection = inspect_line(line, ctx, override_cell, override_digit)
    if not inspection.valid then
      violations[#violations + 1] = violation_for(line, inspection)
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local related_lines = model.lines_by_cell[cell]
  if related_lines == nil then
    return true, nil
  end
  for _, line in ipairs(related_lines) do
    local inspection = inspect_line(line, ctx, cell, digit)
    if not inspection.valid then
      return false, inspection.code
    end
  end
  return true, nil
end

local function final_violations(model, ctx)
  local violations = {}
  for _, line in ipairs(model.lines) do
    local inspection = inspect_line(line, ctx, nil, nil)
    if not inspection.valid then
      violations[#violations + 1] = violation_for(line, inspection)
    elseif inspection.empty_count > 0 then
      violations[#violations + 1] = {
        code = INCOMPLETE_CODE,
        cells = line
      }
    end
  end
  return violations
end

function renban.create(config, scope)
  local model = normalize_lines(config)
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
        if model.lines_by_cell[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        local allowed, code = candidate_allowed(model, ctx, cell, digit)
        if not allowed then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = code
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
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
      for _, line in ipairs(model.lines) do
        local points = overlay_geometry.cell_centers(line)
        primitives[#primitives + 1] = {
          type = "polyline",
          points = points,
          paint = {
            -- Purple is the conventional Renban presentation. It is visual
            -- metadata only; validation always reads the line cell indexes.
            -- 紫色是连数线的常见表现，只属于视觉 metadata；规则始终读取格子索引。
            stroke = "#9A67C7",
            stroke_width = 0.18,
            -- The reference style chooses 0.6; it is not a Host cap for path rules.
            -- Reference style 选择 0.6；它不是路径规则的 Host 透明度上限。
            opacity = 0.6,
            cap = "round",
            join = "round"
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("renban", renban)

return plugin:build()
