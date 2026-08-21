-- Community Variant Script API V1 Zipper Lines Sudoku reference package.
-- Community Variant Script API V1 拉链线数独参考包。
--
-- Every odd-length path has one derived center cell. Digits in cells equally
-- distant from that center must sum to the center digit. Puzzle JSON owns only
-- line geometry. The Host owns classic rules, board mutation, candidates,
-- notes, completion, persistence and rendering; this handler returns bounded
-- validation, candidate and Overlay proposals.
-- 每条奇数长度路径都有一个可推导的中心格。距中心相同距离的两个格子之和必须等于
-- 中心格数字。题目 JSON 只保存线条几何。经典规则、棋盘变更、候选、笔记、完成、
-- 存档和渲染归 Host；handler 只返回有界的校验、候选和 Overlay 建议。
local plugin = community_variant.script()
local zipper_lines = {}
local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema
local adjacency = community_variant.adjacency
local path_api = community_variant.path
local overlay_geometry = community_variant.overlay_geometry

local MAX_LINES = 32
local MIN_LINE_LENGTH = 3
local MAX_LINE_LENGTH = 9
local NO_TARGET_CODE = "zipper_lines_no_target"
local INCOMPLETE_CODE = "zipper_lines_incomplete"

local function normalize_lines(config)
  -- The author model is intentionally small: lines are puzzle-varying data;
  -- center selection and symmetric-pair sum semantics stay package-owned.
  -- 作者模型刻意保持简洁：线条是每题数据；中心选择和对称 pair 求和语义固定在包内。
  schema.expect_exact_keys(config, { lines = true }, "zipper_lines data")
  schema.expect_array(config.lines, 1, MAX_LINES, "zipper_lines data.lines")

  local lines = {}
  local lines_by_cell = {}
  local used_paths = {}

  for line_index, raw_line in ipairs(config.lines) do
    local label = "zipper_lines line " .. line_index
    schema.expect_array(raw_line, MIN_LINE_LENGTH, MAX_LINE_LENGTH, label)
    if #raw_line % 2 == 0 then error(label .. " must contain an odd number of cells") end

    local cells = {}
    local used_cells = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if used_cells[cell] then error(label .. " must not repeat a cell") end
      used_cells[cell] = true
      cells[offset] = cell
      if offset > 1 and not adjacency.eight_way(cells[offset - 1], cell) then
        error(label .. " must pass through adjacent cell centers")
      end
    end

    local path_key = path_api.canonical_key(cells)
    if used_paths[path_key] then
      error("zipper_lines lines must not repeat a path")
    end
    used_paths[path_key] = true

    local center_offset = math.floor(#cells / 2) + 1
    local pairs = {}
    for distance = 1, center_offset - 1 do
      pairs[#pairs + 1] = {
        left = cells[center_offset - distance],
        right = cells[center_offset + distance]
      }
    end
    local line = {
      cells = cells,
      center = cells[center_offset],
      pairs = pairs,
      index = line_index
    }
    lines[#lines + 1] = line

    -- Intersections are valid. A shared cell simply participates in every
    -- related line, so candidate checks evaluate all of them.
    -- 线条相交是合法的；共享格同时参与所有相关线，候选判断会逐条取交集。
    for _, cell in ipairs(cells) do
      lines_by_cell[cell] = lines_by_cell[cell] or {}
      lines_by_cell[cell][#lines_by_cell[cell] + 1] = line
    end
  end

  return { lines = lines, lines_by_cell = lines_by_cell }
end

local function board_values(model, ctx)
  local cells = ctx.board.cells
  if model.cached_board == cells then return model.cached_values end

  -- A candidate batch reuses one immutable ctx for every requested cell. Cache
  -- the normalized values for cells touched by this rule so the hot feasibility
  -- loop does not repeat SDK boundary validation for every target and digit.
  -- 候选 batch 会为所有请求格复用同一个不可变 ctx。这里只缓存本规则涉及格子的
  -- 归一化读值，避免每个 target 和 digit 都重复执行 SDK 边界校验。
  local values = {}
  for _, line in ipairs(model.lines) do
    for _, cell in ipairs(line.cells) do
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
  -- A filled center or completed pair fixes one exact target. A half-filled
  -- pair only establishes a lower bound because the missing Sudoku digit must
  -- be at least one. This single scan is equivalent to enumerating targets
  -- 2..9 for every pair, but stays bounded for a full-board candidate batch.
  -- 已填中心或完整 pair 会确定唯一 target；只填一端的 pair 只产生下界，因为另一端
  -- 至少为 1。一次扫描与逐个枚举 2..9 完全等价，但能约束整盘候选 batch 的成本。
  local required_target = nil
  local minimum_target = 2
  local center = value_for(values, line.center, override_cell, override_digit)
  if not board.is_empty(center) then required_target = center end

  for _, pair in ipairs(line.pairs) do
    local left = value_for(values, pair.left, override_cell, override_digit)
    local right = value_for(values, pair.right, override_cell, override_digit)
    if not board.is_empty(left) and not board.is_empty(right) then
      local pair_target = left + right
      if required_target ~= nil and required_target ~= pair_target then
        return { valid = false, targets = {}, empty_count = 0 }
      end
      required_target = pair_target
    elseif not board.is_empty(left) then
      minimum_target = math.max(minimum_target, left + 1)
    elseif not board.is_empty(right) then
      minimum_target = math.max(minimum_target, right + 1)
    end
  end

  local feasible_targets = {}
  if required_target ~= nil then
    if required_target >= minimum_target and required_target <= 9 then
      feasible_targets[1] = required_target
    end
  else
    for target = minimum_target, 9 do
      feasible_targets[#feasible_targets + 1] = target
    end
  end

  local empty_count = 0
  for _, cell in ipairs(line.cells) do
    if board.is_empty(value_for(values, cell, override_cell, override_digit)) then
      empty_count = empty_count + 1
    end
  end

  return {
    valid = #feasible_targets > 0,
    targets = feasible_targets,
    empty_count = empty_count
  }
end

local function violation(line, code)
  return {
    code = code,
    cells = line.cells,
    data = { line = line.index }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  local values = board_values(model, ctx)
  for _, line in ipairs(model.lines) do
    if not inspect_line(line, values, override_cell, override_digit).valid then
      violations[#violations + 1] = violation(line, NO_TARGET_CODE)
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local related_lines = model.lines_by_cell[cell]
  if related_lines == nil then return true end
  local values = board_values(model, ctx)
  for _, line in ipairs(related_lines) do
    if not inspect_line(line, values, cell, digit).valid then return false end
  end
  return true
end

local function final_violations(model, ctx)
  local violations = {}
  local values = board_values(model, ctx)
  for _, line in ipairs(model.lines) do
    local inspection = inspect_line(line, values, nil, nil)
    if not inspection.valid then
      violations[#violations + 1] = violation(line, NO_TARGET_CODE)
    elseif inspection.empty_count > 0 then
      violations[#violations + 1] = violation(line, INCOMPLETE_CODE)
    end
  end
  return violations
end

function zipper_lines.create(config, scope)
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
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = NO_TARGET_CODE
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
        local points = overlay_geometry.cell_centers(line.cells)
        primitives[#primitives + 1] = {
          type = "polyline",
          points = points,
          paint = {
            stroke = "#168C8C",
            stroke_width = 0.10,
            opacity = 0.6,
            cap = "round",
            join = "round"
          }
        }

        local center = overlay_geometry.cell_center(line.center)
        local radius = 0.25
        primitives[#primitives + 1] = {
          type = "polygon",
          points = {
            { x = center.x, y = center.y - radius },
            { x = center.x + radius, y = center.y },
            { x = center.x, y = center.y + radius },
            { x = center.x - radius, y = center.y }
          },
          paint = {
            stroke = "#168C8C",
            stroke_width = 0.06,
            opacity = 0.6,
            join = "round"
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("zipper_lines", zipper_lines)

return plugin:build()
