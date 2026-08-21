-- Community Variant Script API V1 thermometer preview.
-- Community Variant Script API V1 温度计预览。
--
-- This file follows the same registry/handler style as the other SDK examples:
-- `rules[].id = "thermometer"` activates this handler, and the per-puzzle
-- thermometer paths live in `rules[].data.paths`.
-- 本文件沿用其它 SDK 示例的 registry/handler 风格：`rules[].id = "thermometer"`
-- 激活本 handler，每题温度计路径放在 `rules[].data.paths`。
--
-- The Host invokes this Script V1 handler with read-only board snapshots. The
-- App owns move transactions, candidate display, conflict UI, completion flow
-- and persistence.
-- Host 通过只读棋盘快照调用这个 Script V1 handler。落子事务、候选显示、冲突 UI、
-- 完成流程和持久化仍由 App 负责。
local plugin = community_variant.script()
local thermometer = {}
local board = community_variant.board

local function normalize_paths(data)
  -- Thermometer geometry is puzzle-owned data. The rule semantics are fixed:
  -- values must strictly increase from bulb to tip along every path.
  -- 温度计几何是每题数据。规则语义固定：每条路径都必须从圆头到末端严格递增。
  return data.paths
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

local function violation(path_index, first, second)
  return {
    code = "thermometer_order",
    cells = { first, second },
    data = {
      path = path_index
    }
  }
end

local function path_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end

  return board.value(ctx, cell)
end

local function find_path_violations(path, path_index, ctx, override_cell, override_digit)
  local violations = {}

  -- Thermometer order is global along the path, not only adjacent.
  -- If earlier and later filled cells have empty cells between them, they still
  -- must satisfy earlier < later.
  -- 温度计顺序约束作用于整条路径，不只检查相邻格。即使两个已填数字中间有空格，
  -- 也必须满足前方数字 < 后方数字。
  for left_index = 1, #path - 1 do
    for right_index = left_index + 1, #path do
      local first = path[left_index]
      local second = path[right_index]
      local first_digit = path_digit(ctx, first, override_cell, override_digit)
      local second_digit = path_digit(ctx, second, override_cell, override_digit)

      if not board.is_empty(first_digit) and not board.is_empty(second_digit) then
        if first_digit >= second_digit then
          violations[#violations + 1] = violation(path_index, first, second)
        end
      end
    end
  end

  return violations
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for path_index, path in ipairs(model.paths) do
    local path_violations = find_path_violations(
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

local function candidate_allowed_on_occurrence(path, offset, ctx, cell, digit)
  -- A digit is allowed at one thermometer position only if it is greater than
  -- every filled earlier cell and smaller than every filled later cell.
  -- 某个候选数字只有在大于路径前方已填数字、且小于路径后方已填数字时才允许。
  for index = 1, offset - 1 do
    local previous_digit = board.value(ctx, path[index])

    if not board.is_empty(previous_digit) and digit <= previous_digit then
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

local function candidate_allowed(model, ctx, cell, digit)
  local occurrences = model.by_cell[cell]

  if occurrences == nil then
    return true
  end

  for _, occurrence in ipairs(occurrences) do
    local path = model.paths[occurrence.path_index]

    if not candidate_allowed_on_occurrence(path, occurrence.offset, ctx, cell, digit) then
      return false
    end
  end

  return true
end

-- Required: create one private rule instance from one puzzle rule config.
-- 必须：从一份题目规则 config 创建一个私有规则实例。
function thermometer.create(config, scope)
  -- Path geometry is puzzle-owned config. The returned callbacks close over
  -- this one rule instance, so Host never passes or inspects `model`.
  -- 路径几何属于题目 config。返回的 callbacks 通过闭包持有本规则实例，
  -- Host 不再传入或查看 `model`。
  local paths = normalize_paths(config)
  local model = {
    paths = paths,
    by_cell = index_paths(paths)
  }
  return {
    -- Required: validate a proposed move for this rule only.
    -- 必须：只针对本规则校验一次拟落子。
    validate_move = function(ctx, move)
      -- This callback reports thermometer violations only. It does not decide
      -- the full input transaction and never mutates Host board state.
      -- 本 callback 只报告温度计违规，不决定完整输入事务，也绝不修改 Host 棋盘状态。
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
      -- Host maps these typed violations to conflict UI.
      -- Host 负责把 typed violations 映射到冲突 UI。
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
      -- The handler may remove candidates that break thermometer order, but it
      -- cannot replace the Host-owned full candidate set.
      -- handler 可以移除违反温度计顺序的候选，但不能替换 Host-owned 完整候选集合。
      local remove = {}
      local reasons = {}

      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "thermometer_order"
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
      -- Completion remains Host-owned. This callback reports only whether
      -- thermometer rules themselves are valid.
      -- 完成流程仍归 Host。本 callback 只报告温度计规则自身是否有效。
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
      -- Overlay is declarative. Lua returns primitives; the App-owned board
      -- painter performs actual rendering and theme adaptation.
      -- Overlay 是声明式输出。Lua 只返回 primitives；真正渲染和主题适配由
      -- App-owned 棋盘 painter 完成。
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

plugin:register_rule("thermometer", thermometer)

return plugin:build()
