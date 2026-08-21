-- Community Variant Script API V1 Between Lines Sudoku reference package.
-- Community Variant Script API V1 线间数独参考包。
--
-- The first and last cells of every path are endpoints. Every interior digit
-- must lie strictly between the endpoint digits. Puzzle JSON owns only path
-- geometry. The Host owns classic rules, board mutation, candidates, notes,
-- completion, persistence and rendering.
-- 每条路径的首尾格是端点，所有内部数字必须严格介于两端数字之间。题目 JSON 只
-- 保存路径几何；经典规则、棋盘变更、候选、笔记、完成、存档和渲染归 Host。
local plugin = community_variant.script()
local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema
local overlay_geometry = community_variant.overlay_geometry
local between_lines = {}

local MAX_LINES = 21
local MIN_LINE_LENGTH = 3
local MAX_LINE_LENGTH = 9
local INTERVAL_CODE = "between_lines_no_open_interval"
local INCOMPLETE_CODE = "between_lines_incomplete"

local function are_line_neighbors(first, second)
  local row_delta = math.abs(cell_api.row(first) - cell_api.row(second))
  local column_delta = math.abs(
    cell_api.column(first) - cell_api.column(second)
  )
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
  return { x = cell_api.column(cell), y = cell_api.row(cell) }
end

local function lines_intersect(first, second)
  local second_cells = {}
  for _, cell in ipairs(second) do second_cells[cell] = true end
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
  schema.expect_exact_keys(config, { lines = true }, "between_lines data")
  schema.expect_array(config.lines, 1, MAX_LINES, "between_lines data.lines")

  local lines = {}
  local line_by_cell = {}
  local used_paths = {}
  for line_index, raw_line in ipairs(config.lines) do
    local label = "between_lines line " .. line_index
    schema.expect_array(raw_line, MIN_LINE_LENGTH, MAX_LINE_LENGTH, label)

    local line = {}
    local used_cells = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if used_cells[cell] then error(label .. " must not repeat a cell") end
      used_cells[cell] = true
      line[offset] = cell
      if offset > 1 and not are_line_neighbors(line[offset - 1], cell) then
        error(label .. " must pass through adjacent cell centers")
      end
    end

    local forward_key = path_key(line, false)
    local reverse_key = path_key(line, true)
    if used_paths[forward_key] or used_paths[reverse_key] then
      error("between_lines lines must not repeat a path")
    end
    for _, existing in ipairs(lines) do
      if lines_intersect(line, existing) then
        error("between_lines lines must not intersect or share cells")
      end
    end
    used_paths[forward_key] = true
    used_paths[reverse_key] = true

    lines[#lines + 1] = line
    for _, cell in ipairs(line) do
      line_by_cell[cell] = line
    end
  end
  return { lines = lines, line_by_cell = line_by_cell }
end

local function board_values(model, ctx)
  local cells = ctx.board.cells
  if model.cached_board == cells then return model.cached_values end

  -- One production candidate batch reuses the same immutable board table for
  -- every requested cell. Normalize each rule-owned cell once so the bounded
  -- Lua callback does not repeatedly cross the SDK validation boundary.
  -- 生产候选 batch 会为所有请求格复用同一个不可变棋盘 table。这里只归一化读取每个
  -- 规则格一次，避免有界 Lua callback 为每个格和候选重复跨越 SDK 校验边界。
  local values = {}
  for _, line in ipairs(model.lines) do
    for _, cell in ipairs(line) do
      if values[cell] == nil then values[cell] = board.value(ctx, cell) end
    end
  end
  model.cached_board = cells
  model.cached_values = values
  return values
end

local function value_for(values, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return values[cell]
end

local function inspect_line(line, values, override_cell, override_digit)
  -- Assigned interior digits must still fit inside some strict open interval
  -- whose endpoints are digits 1..9. This same existence test drives every
  -- validation surface.
  -- 已填内部数字必须仍能被 1..9 中的两个端点构成的严格开区间包围。所有校验入口
  -- 共用这个存在性判断。
  local left = value_for(values, line[1], override_cell, override_digit)
  local right = value_for(values, line[#line], override_cell, override_digit)
  local minimum = nil
  local maximum = nil
  local assigned_cells = {}
  local empty_count = 0

  if board.is_empty(left) then
    empty_count = empty_count + 1
  else
    assigned_cells[#assigned_cells + 1] = line[1]
  end
  if board.is_empty(right) then
    empty_count = empty_count + 1
  else
    assigned_cells[#assigned_cells + 1] = line[#line]
  end

  for offset = 2, #line - 1 do
    local cell = line[offset]
    local digit = value_for(values, cell, override_cell, override_digit)
    if board.is_empty(digit) then
      empty_count = empty_count + 1
    else
      assigned_cells[#assigned_cells + 1] = cell
      minimum = minimum == nil and digit or math.min(minimum, digit)
      maximum = maximum == nil and digit or math.max(maximum, digit)
    end
  end

  local left_empty = board.is_empty(left)
  local right_empty = board.is_empty(right)
  local feasible
  if not left_empty and not right_empty then
    local lower = math.min(left, right)
    local upper = math.max(left, right)
    feasible = upper - lower >= 2 and
        (minimum == nil or (minimum > lower and maximum < upper))
  elseif left_empty and right_empty then
    feasible = minimum == nil or (minimum >= 2 and maximum <= 8)
  else
    local endpoint = left_empty and right or left
    if minimum == nil then
      feasible = true
    else
      local can_extend_below = maximum < endpoint and minimum >= 2
      local can_extend_above = minimum > endpoint and maximum <= 8
      feasible = can_extend_below or can_extend_above
    end
  end

  if not feasible then
    return {
      valid = false,
      code = INTERVAL_CODE,
      cells = assigned_cells,
      empty_count = empty_count
    }
  end
  return { valid = true, empty_count = empty_count }
end

local function line_is_feasible(line, values, override_cell, override_digit)
  -- Candidate projection needs only a boolean result. Avoid constructing
  -- violation cells and result tables for every digit in a full-board batch.
  -- 候选投影只需要布尔结果；整盘 batch 的每个数字都不再构造冲突格和结果 table。
  local left = value_for(values, line[1], override_cell, override_digit)
  local right = value_for(values, line[#line], override_cell, override_digit)
  local minimum = nil
  local maximum = nil

  for offset = 2, #line - 1 do
    local digit = value_for(values, line[offset], override_cell, override_digit)
    if not board.is_empty(digit) then
      minimum = minimum == nil and digit or math.min(minimum, digit)
      maximum = maximum == nil and digit or math.max(maximum, digit)
    end
  end

  local left_empty = board.is_empty(left)
  local right_empty = board.is_empty(right)
  if not left_empty and not right_empty then
    local lower = math.min(left, right)
    local upper = math.max(left, right)
    return upper - lower >= 2 and
        (minimum == nil or (minimum > lower and maximum < upper))
  end
  if left_empty and right_empty then
    return minimum == nil or (minimum >= 2 and maximum <= 8)
  end
  if minimum == nil then return true end
  local endpoint = left_empty and right or left
  return (maximum < endpoint and minimum >= 2) or
      (minimum > endpoint and maximum <= 8)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  local values = board_values(model, ctx)
  for _, line in ipairs(model.lines) do
    local inspection = inspect_line(line, values, override_cell, override_digit)
    if not inspection.valid then
      violations[#violations + 1] = {
        code = inspection.code,
        cells = inspection.cells or line
      }
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local line = model.line_by_cell[cell]
  if line == nil then return true end
  local values = board_values(model, ctx)
  return line_is_feasible(line, values, cell, digit)
end

local function final_violations(model, ctx)
  local violations = {}
  local values = board_values(model, ctx)
  for _, line in ipairs(model.lines) do
    local inspection = inspect_line(line, values, nil, nil)
    if not inspection.valid then
      violations[#violations + 1] = {
        code = inspection.code,
        cells = inspection.cells or line
      }
    elseif inspection.empty_count > 0 then
      violations[#violations + 1] = {
        code = INCOMPLETE_CODE,
        cells = line
      }
    end
  end
  return violations
end

function between_lines.create(config, scope)
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
        if model.line_by_cell[cell] ~= nil then
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
          reasons[tostring(digit)] = INTERVAL_CODE
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
            stroke = "#546E7A",
            stroke_width = 0.14,
            opacity = 0.6,
            cap = "round",
            join = "round"
          }
        }
        for _, endpoint in ipairs({ line[1], line[#line] }) do
          primitives[#primitives + 1] = {
            type = "circle",
            center = overlay_geometry.cell_center(endpoint),
            radius = 0.28,
            paint = {
              stroke = "#546E7A",
              fill = "#FFFFFF",
              stroke_width = 0.05,
              opacity = 0.6
            }
          }
        end
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("between_lines", between_lines)

return plugin:build()
