-- Community Variant Script API V1 Windoku preview.
-- Community Variant Script API V1 Windoku 预览。
--
-- This file is a complete Script V1 reference implementation. The author owns
-- the four fixed windows, while the
-- Host owns board state, move transactions, candidate display, conflict UI and
-- saves.
-- 本文件是完整的 Script V1 参考实现。作者拥有四个固定窗口；棋盘状态、落子事务、
-- 候选显示、冲突 UI 和存档仍归 Host。
local plugin = community_variant.script()
local window = {}
local board = community_variant.board

local function normalize_window(cells)
  -- Fixed geometry is package-owned. Puzzle data only activates this handler
  -- with an empty object; it cannot redefine the published 3x3 windows.
  -- 固定几何是包级语义。题目数据只用空对象激活 handler，不能重新定义已发布的
  -- 3x3 窗口。
  if type(cells) ~= "table" or #cells ~= 9 then
    error("window must contain exactly 9 cells")
  end

  local seen = {}
  local min_row = 9
  local max_row = -1
  local min_col = 9
  local max_col = -1

  for _, cell in ipairs(cells) do
    if type(cell) ~= "number" or cell % 1 ~= 0 or cell < 0 or cell > 80 then
      error("window cells must be unique integers in 0..80")
    end
    if seen[cell] then
      error("window cells must be unique integers in 0..80")
    end
    seen[cell] = true

    local row = math.floor(cell / 9)
    local col = cell % 9
    min_row = math.min(min_row, row)
    max_row = math.max(max_row, row)
    min_col = math.min(min_col, col)
    max_col = math.max(max_col, col)
  end

  local width = max_col - min_col + 1
  local height = max_row - min_row + 1
  if width ~= 3 or height ~= 3 then
    error("window cells must form a complete 3x3 region")
  end
  for row = min_row, max_row do
    for col = min_col, max_col do
      if not seen[row * 9 + col] then
        error("window cells must form a complete 3x3 region")
      end
    end
  end

  return {
    cells = cells,
    origin = { x = min_col, y = min_row },
    width = width,
    height = height
  }
end

local function standard_windows()
  return {
    { cells = { 10, 11, 12, 19, 20, 21, 28, 29, 30 } },
    { cells = { 14, 15, 16, 23, 24, 25, 32, 33, 34 } },
    { cells = { 46, 47, 48, 55, 56, 57, 64, 65, 66 } },
    { cells = { 50, 51, 52, 59, 60, 61, 68, 69, 70 } }
  }
end

local function cell_set(cells)
  local set = {}
  for _, cell in ipairs(cells) do
    set[cell] = true
  end
  return set
end

local function contains_cell(model, cell)
  return model.cell_set[cell] == true
end

local function violation(window_index, first, second)
  return {
    code = "window_repeat",
    cells = { first, second },
    data = {
      window = window_index
    }
  }
end

local function find_repeated_digits(model, ctx, override_cell, override_digit)
  local violations = {}

  for window_index, window in ipairs(model.windows) do
    local seen = {}
    for _, cell in ipairs(window.cells) do
      local digit = board.value(ctx, cell)
      if cell == override_cell then
        digit = override_digit
      end

      if not board.is_empty(digit) then
        local previous = seen[digit]
        if previous ~= nil then
          violations[#violations + 1] = violation(window_index, previous, cell)
        else
          seen[digit] = cell
        end
      end
    end
  end

  return violations
end

local function used_digits_on_window(window, ctx, except_cell)
  local used = {}
  for _, cell in ipairs(window.cells) do
    if cell ~= except_cell then
      local digit = board.value(ctx, cell)
      if not board.is_empty(digit) then
        used[digit] = true
      end
    end
  end
  return used
end

-- Required: create one private rule instance from one puzzle rule config.
-- 必须：从一份题目规则 config 创建一个私有规则实例。
function window.create(config, scope)
  -- This handler has package-invariant geometry. The puzzle config only
  -- activates the handler; it cannot redefine the four published windows.
  -- 本 handler 的窗口几何由包固定。题目 config 只负责激活 handler，不能重新定义
  -- 已发布的四个窗口。
  local windows = {}

  for _, raw in ipairs(standard_windows()) do
    windows[#windows + 1] = normalize_window(raw.cells)
  end

  local model = {
    windows = windows,
    cell_set = cell_set({
      10, 11, 12, 19, 20, 21, 28, 29, 30,
      14, 15, 16, 23, 24, 25, 32, 33, 34,
      46, 47, 48, 55, 56, 57, 64, 65, 66,
      50, 51, 52, 59, 60, 61, 68, 69, 70
    })
  }
  return {
    -- Required: validate a proposed move for this rule only.
    -- 必须：只针对本规则校验一次拟落子。
    validate_move = function(ctx, move)
      -- The handler reports only window violations. The Host owns the full
      -- input transaction and decides how a rejected result is presented.
      -- handler 只报告窗口规则违规。完整输入事务以及拒绝结果如何展示，由 Host 负责。
      local cell = move.cell
      local digit = move.digit

      if not contains_cell(model, cell) or board.is_empty(digit) then
        return {
          accepted = true,
          violations = {},
          diagnostics = {}
        }
      end

      local violations = find_repeated_digits(model, ctx, cell, digit)

      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Required: report current-board violations for this rule.
    -- 必须：报告当前盘面中属于本规则的违规。
    validate_board = function(ctx)
      return {
        violations = find_repeated_digits(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    -- Optional: suggest candidate removals; never replace the full candidate set.
    -- 可选：建议移除候选；不能替换完整候选集合。
    candidate_scope = function()
      local cells = {}
      for cell = 0, 80 do
        if model.cell_set[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}

      if contains_cell(model, cell) then
        for _, window in ipairs(model.windows) do
          if contains_cell({ cell_set = cell_set(window.cells) }, cell) then
            local used = used_digits_on_window(window, ctx, cell)
            for digit = 1, 9 do
              if used[digit] == true then
                remove[#remove + 1] = digit
                reasons[tostring(digit)] = "window_repeat"
              end
            end
          end
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    -- Required: report whether this rule is valid for final-state checks.
    -- 必须：报告本规则在最终状态检查中是否有效。
    validate_final_state = function(ctx)
      local violations = find_repeated_digits(model, ctx, nil, nil)

      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Optional: return declarative overlay primitives for this rule.
    -- 可选：返回本规则的声明式 overlay primitives。
    build_overlay = function(ctx)
      local primitives = {}

      for _, current_window in ipairs(model.windows) do
        primitives[#primitives + 1] = {
          type = "rect",
          origin = current_window.origin,
          width = current_window.width,
          height = current_window.height,
          paint = {
            stroke = { theme = "constraint_line" },
            stroke_width = 0.035,
            opacity = 0.8
          }
        }
      end

      return {
        primitives = primitives
      }
    end
  }
end

plugin:register_rule("window", window)

return plugin:build()
