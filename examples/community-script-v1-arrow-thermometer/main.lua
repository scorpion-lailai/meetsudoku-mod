-- Community Variant Script API V1 Arrow + Thermometer reference package.
-- Community Variant Script API V1 箭头 + 温度计参考包。
--
-- Two independent handlers are registered below. The Host invokes both and
-- merges their typed validation results. Neither handler owns board mutation,
-- classic Sudoku validation, candidates, notes, persistence or UI.
-- 下面注册两个独立 handler。Host 调用两者并合并 typed 校验结果。两个 handler
-- 都不能修改棋盘，也不拥有经典数独、候选、笔记、存档或 UI。
local plugin = community_variant.script()
local thermometer = {}
local arrow = {}
local board = community_variant.board
local cell_api = community_variant.cell

-- Thermometer handler -------------------------------------------------------

local function normalize_paths(data)
  if type(data) ~= "table" or type(data.paths) ~= "table"
      or #data.paths < 1 or #data.paths > 16 then
    error("thermometer data must contain 1..16 paths")
  end

  local paths = {}
  for path_index, raw_path in ipairs(data.paths) do
    if type(raw_path) ~= "table" or #raw_path < 2 or #raw_path > 9 then
      error("thermometer path must contain 2..9 cells")
    end

    local path = {}
    local seen = {}
    for offset, raw_cell in ipairs(raw_path) do
      local cell = cell_api.expect(
        raw_cell,
        "thermometer.paths[" .. path_index .. "][" .. offset .. "]"
      )
      if seen[cell] then
        error("thermometer path cells must be unique")
      end
      seen[cell] = true
      path[#path + 1] = cell
    end
    paths[#paths + 1] = path
  end
  return paths
end

local function index_paths(paths)
  local by_cell = {}
  for path_index, path in ipairs(paths) do
    for offset, cell in ipairs(path) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = {
        path_index = path_index,
        offset = offset
      }
    end
  end
  return by_cell
end

local function thermometer_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function thermometer_violation(path_index, first, second)
  return {
    code = "thermometer_order",
    cells = { first, second },
    data = { path = path_index }
  }
end

local function thermometer_path_violations(
  path,
  path_index,
  ctx,
  override_cell,
  override_digit
)
  local violations = {}

  -- Compare every filled earlier/later pair, not only adjacent cells.
  -- 比较路径上所有已填的前后格，而不只检查相邻格。
  for left = 1, #path - 1 do
    for right = left + 1, #path do
      local first = path[left]
      local second = path[right]
      local first_digit = thermometer_digit(
        ctx,
        first,
        override_cell,
        override_digit
      )
      local second_digit = thermometer_digit(
        ctx,
        second,
        override_cell,
        override_digit
      )

      if not board.is_empty(first_digit) and not board.is_empty(second_digit)
          and first_digit >= second_digit then
        violations[#violations + 1] = thermometer_violation(
          path_index,
          first,
          second
        )
      end
    end
  end
  return violations
end

local function thermometer_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for path_index, path in ipairs(model.paths) do
    local path_violations = thermometer_path_violations(
      path,
      path_index,
      ctx,
      override_cell,
      override_digit
    )
    for _, item in ipairs(path_violations) do
      violations[#violations + 1] = item
    end
  end
  return violations
end

local function thermometer_candidate_allowed(path, offset, ctx, cell, digit)
  for index = 1, offset - 1 do
    local previous = board.value(ctx, path[index])
    if not board.is_empty(previous) and digit <= previous then
      return false
    end
  end
  for index = offset + 1, #path do
    local next_digit = board.value(ctx, path[index])
    if not board.is_empty(next_digit) and digit >= next_digit then
      return false
    end
  end
  return true
end

function thermometer.create(config, scope)
  local paths = normalize_paths(config)
  local model = {
    paths = paths,
    by_cell = index_paths(paths)
  }

  return {
    validate_move = function(ctx, move)
      local violations = thermometer_violations(
        model,
        ctx,
        move.cell,
        move.digit
      )
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = thermometer_violations(model, ctx, nil, nil),
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
      local occurrences = model.by_cell[cell]

      if occurrences ~= nil then
        for digit = 1, 9 do
          local allowed = true
          for _, occurrence in ipairs(occurrences) do
            local path = model.paths[occurrence.path_index]
            if not thermometer_candidate_allowed(
                path,
                occurrence.offset,
                ctx,
                cell,
                digit
            ) then
              allowed = false
            end
          end
          if not allowed then
            remove[#remove + 1] = digit
            reasons[tostring(digit)] = "thermometer_order"
          end
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    validate_final_state = function(ctx)
      local violations = thermometer_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, path in ipairs(model.paths) do
        primitives[#primitives + 1] = {
          type = "builtin",
          kind = "thermometer",
          data = { cells = path }
        }
      end
      return {
        primitives = primitives
      }
    end
  }
end

-- Arrow handler -------------------------------------------------------------

local function normalize_arrows(data)
  if type(data) ~= "table" or type(data.arrows) ~= "table"
      or #data.arrows < 1 or #data.arrows > 16 then
    error("arrow data must contain 1..16 arrows")
  end

  local arrows = {}
  for index, raw in ipairs(data.arrows) do
    if type(raw) ~= "table" or type(raw.head) ~= "number"
        or type(raw.path) ~= "table" or #raw.path < 1 or #raw.path > 8 then
      error("arrow " .. index .. " must contain head and a 1..8 cell path")
    end

    local head = cell_api.expect(raw.head, "arrow.head")
    local path = {}
    local seen = { [head] = true }
    for path_index, raw_cell in ipairs(raw.path) do
      local cell = cell_api.expect(raw_cell, "arrow.path[" .. path_index .. "]")
      if seen[cell] then
        error("arrow cells must be unique")
      end
      seen[cell] = true
      path[#path + 1] = cell
    end
    arrows[#arrows + 1] = { head = head, path = path }
  end
  return arrows
end

local function index_arrows(arrows)
  local by_cell = {}
  for arrow_index, item in ipairs(arrows) do
    by_cell[item.head] = by_cell[item.head] or {}
    by_cell[item.head][#by_cell[item.head] + 1] = {
      arrow_index = arrow_index
    }
    for _, cell in ipairs(item.path) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = {
        arrow_index = arrow_index
      }
    end
  end
  return by_cell
end

local function arrow_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function arrow_violation(item)
  local cells = { item.head }
  for _, cell in ipairs(item.path) do
    cells[#cells + 1] = cell
  end
  return {
    code = "arrow_sum",
    cells = cells
  }
end

local function arrow_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, item in ipairs(model.arrows) do
    local head_digit = arrow_digit(ctx, item.head, override_cell, override_digit)
    local path_sum = 0
    local complete = not board.is_empty(head_digit)

    for _, cell in ipairs(item.path) do
      local digit = arrow_digit(ctx, cell, override_cell, override_digit)
      if board.is_empty(digit) then
        complete = false
      else
        path_sum = path_sum + digit
      end
    end

    if complete and head_digit ~= path_sum then
      violations[#violations + 1] = arrow_violation(item)
    end
  end
  return violations
end

local function arrow_candidate_allowed(item, ctx, cell, digit)
  local head_digit = board.value(ctx, item.head)
  if cell == item.head then
    head_digit = digit
  end

  local path_sum = 0
  local unknown_path = 0
  for _, path_cell in ipairs(item.path) do
    local path_digit = board.value(ctx, path_cell)
    if path_cell == cell then
      path_digit = digit
    end
    if board.is_empty(path_digit) then
      unknown_path = unknown_path + 1
    else
      path_sum = path_sum + path_digit
    end
  end

  local minimum = path_sum + unknown_path
  local maximum = path_sum + unknown_path * 9
  if cell == item.head then
    return digit >= minimum and digit <= maximum
  end
  if board.is_empty(head_digit) then
    return minimum <= 9 and maximum >= 1
  end
  return head_digit >= minimum and head_digit <= maximum
end

function arrow.create(config, scope)
  local arrows = normalize_arrows(config)
  local model = {
    arrows = arrows,
    by_cell = index_arrows(arrows)
  }

  return {
    validate_move = function(ctx, move)
      local violations = arrow_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = arrow_violations(model, ctx, nil, nil),
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
      local occurrences = model.by_cell[cell]

      if occurrences ~= nil then
        for digit = 1, 9 do
          local allowed = true
          for _, occurrence in ipairs(occurrences) do
            local item = model.arrows[occurrence.arrow_index]
            if not arrow_candidate_allowed(item, ctx, cell, digit) then
              allowed = false
            end
          end
          if not allowed then
            remove[#remove + 1] = digit
            reasons[tostring(digit)] = "arrow_sum"
          end
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    validate_final_state = function(ctx)
      local violations = arrow_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, item in ipairs(model.arrows) do
        local cells = { item.head }
        for _, cell in ipairs(item.path) do
          cells[#cells + 1] = cell
        end
        primitives[#primitives + 1] = {
          type = "builtin",
          kind = "arrow",
          data = { cells = cells }
        }
      end
      return {
        primitives = primitives
      }
    end
  }
end

plugin:register_rule("thermometer", thermometer)
plugin:register_rule("arrow", arrow)

return plugin:build()
