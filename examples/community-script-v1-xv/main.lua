-- Community Variant Script API V1 XV preview.
-- Community Variant Script API V1 XV 预览。
--
-- This file is a complete Script V1 reference implementation. The author owns
-- the X/V semantics, while the Host owns
-- board state, move transactions, candidates display, conflict UI and saves.
-- 本文件是完整的 Script V1 参考实现。作者拥有 X/V 语义；棋盘状态、落子事务、
-- 候选显示、冲突 UI 和存档仍归 Host。
local plugin = community_variant.script()
local xv = {}
local overlay_geometry = community_variant.overlay_geometry
local board = community_variant.board

-- X/V numeric semantics are package-invariant. Puzzle data supplies only the
-- marked edges, not the meaning of X or V.
-- X/V 数值语义是包级固定规则。题目数据只提供标记边，不能重新定义 X 或 V 的含义。
local sum_by_mark = {
  x = 10,
  v = 5
}

local function log_info(ctx, message)
  local line = "[community-script-v1-xv] " .. message
  if ctx ~= nil and ctx.log ~= nil and ctx.log.info ~= nil then
    ctx.log:info(line)
  end
  print(line)
end

local function point(x, y)
  return { x = x, y = y }
end

local function custom_line(points)
  return {
    type = "polyline",
    points = points,
    paint = {
      stroke = { theme = "constraint_line" },
      stroke_width = 0.08,
      opacity = 1.0,
      cap = "round",
      join = "round"
    }
  }
end

local function x_overlay(first_x, first_y, second_x, second_y)
  -- 0.18 is glyph half-size in board-cell units. It affects only visuals.
  -- 0.18 是棋盘单位里的字形半宽，只影响显示，不影响规则。
  local center_x = (first_x + second_x) / 2
  local center_y = (first_y + second_y) / 2
  return {
    custom_line({
      point(center_x - 0.18, center_y - 0.18),
      point(center_x + 0.18, center_y + 0.18)
    }),
    custom_line({
      point(center_x + 0.18, center_y - 0.18),
      point(center_x - 0.18, center_y + 0.18)
    })
  }
end

local function v_overlay(first_x, first_y, second_x, second_y)
  local center_x = (first_x + second_x) / 2
  local center_y = (first_y + second_y) / 2

  if first_y == second_y then
    return {
      custom_line({
        point(center_x - 0.20, center_y - 0.18),
        point(center_x, center_y + 0.18),
        point(center_x + 0.20, center_y - 0.18)
      })
    }
  end

  return {
    custom_line({
      point(center_x - 0.18, center_y - 0.20),
      point(center_x + 0.18, center_y),
      point(center_x - 0.18, center_y + 0.20)
    })
  }
end

local overlay_by_mark = {
  x = x_overlay,
  v = v_overlay
}

local function normalize_marks(data)
  local marks = {}

  for index, mark in ipairs(data.marks) do
    local target = sum_by_mark[mark.type]
    if target == nil then
      error("unsupported XV mark: " .. tostring(mark.type))
    end

    marks[#marks + 1] = {
      type = mark.type,
      cells = mark.cells,
      target = target,
      violation_code = "xv_" .. mark.type .. "_sum"
    }
  end

  return marks
end

local function index_marks(marks)
  local by_cell = {}

  for mark_index, mark in ipairs(marks) do
    for offset, cell in ipairs(mark.cells) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = {
        mark_index = mark_index,
        offset = offset
      }
    end
  end

  return by_cell
end

local function other_cell(mark, cell)
  if mark.cells[1] == cell then
    return mark.cells[2]
  end
  return mark.cells[1]
end

local function violation(mark)
  return {
    code = mark.violation_code,
    cells = { mark.cells[1], mark.cells[2] },
    data = {
      mark = mark.type,
      target = mark.target
    }
  }
end

local function mark_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end

  return board.value(ctx, cell)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, mark in ipairs(model.marks) do
    local first_digit = mark_digit(ctx, mark.cells[1], override_cell, override_digit)
    local second_digit = mark_digit(ctx, mark.cells[2], override_cell, override_digit)

    -- Partial board semantics: an X/V mark is not false until both cells are
    -- filled. Empty cells remain undetermined.
    -- 部分盘面语义：X/V 只有在两格都已填时才判断真假；有空格时保持未定。
    if not board.is_empty(first_digit) and not board.is_empty(second_digit) then
      if first_digit + second_digit ~= mark.target then
        violations[#violations + 1] = violation(mark)
      end
    end
  end

  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local occurrences = model.by_cell[cell]

  if occurrences == nil then
    return true
  end

  for _, occurrence in ipairs(occurrences) do
    local mark = model.marks[occurrence.mark_index]
    local neighbor = other_cell(mark, cell)
    local neighbor_digit = board.value(ctx, neighbor)

    if not board.is_empty(neighbor_digit) and digit + neighbor_digit ~= mark.target then
      return false
    end
  end

  return true
end

-- Required: create one private rule instance from one puzzle rule config.
-- 必须：从一份题目规则 config 创建一个私有规则实例。
function xv.create(config, scope)
  -- Host passes puzzle-owned config once when invoking this rule. The returned
  -- callbacks close over `model`, so Host does not pass or inspect author state.
  -- Host 调用本规则时传入一次题目 config。返回的 callbacks 通过闭包持有 `model`，
  -- Host 不再传入或查看作者自己的状态。
  local marks = normalize_marks(config)
  local model = {
    marks = marks,
    by_cell = index_marks(marks)
  }

  return {
    -- Required: validate a proposed move for this rule only.
    -- 必须：只针对本规则校验一次拟落子。
    validate_move = function(ctx, move)
      log_info(ctx, "validate_move cell=" .. tostring(move.cell) .. " digit=" .. tostring(move.digit))
      local violations = find_violations(model, ctx, move.cell, move.digit)

      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Required: report current-board violations for this rule.
    -- 必须：报告当前盘面中属于本规则的违规。
    validate_board = function(ctx)
      log_info(ctx, "validate_board")
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    -- Optional: suggest candidate removals; never replace the full candidate set.
    -- 可选：建议移除候选；不能替换完整候选集合。
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
      log_info(ctx, "get_candidate_eliminations cell=" .. tostring(cell))
      local remove = {}
      local reasons = {}

      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "xv_sum"
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
      log_info(ctx, "validate_final_state")
      local violations = find_violations(model, ctx, nil, nil)

      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Optional: return declarative overlay primitives for this rule.
    -- 可选：返回本规则的声明式 overlay primitives。
    build_overlay = function(ctx)
      log_info(ctx, "build_overlay")
      local primitives = {}

      for _, mark in ipairs(model.marks) do
        local first = overlay_geometry.cell_center(mark.cells[1])
        local second = overlay_geometry.cell_center(mark.cells[2])
        local first_x, first_y = first.x, first.y
        local second_x, second_y = second.x, second.y
        local generated = overlay_by_mark[mark.type](
          first_x,
          first_y,
          second_x,
          second_y
        )

        for _, primitive in ipairs(generated) do
          primitives[#primitives + 1] = primitive
        end
      end

      return {
        primitives = primitives
      }
    end
  }
end

plugin:register_rule("xv", xv)

return plugin:build()
