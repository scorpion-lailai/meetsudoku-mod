-- Community Variant Script API V1 preview.
-- Community Variant Script API V1 预览。
--
-- This file intentionally follows the SDK's existing Registry Builder style:
-- a rule is registered by id, then puzzle `rules[].id` activates that handler.
-- Authors add new rules by adding new handlers, not by editing a central
-- if/elseif dispatcher.
-- 本文件刻意沿用现有 SDK 的 Registry Builder 风格：规则按 id 注册，题目中的
-- `rules[].id` 只负责激活对应 handler。作者新增规则时新增 handler，不修改中央
-- if/elseif 分发器。
--
-- This package uses the Script V1 callback contract. The Host invokes the
-- callbacks with read-only board snapshots and owns gameplay transactions,
-- candidate display, conflict UI, completion flow and persistence.
-- 本包使用 Script V1 callback contract。Host 通过只读棋盘快照调用 callbacks，
-- 并负责落子事务、候选显示、冲突 UI、完成流程和持久化。
local plugin = community_variant.script()
local diagonal = {}
local board = community_variant.board

-- Package-invariant semantics: this variant uses both standard Sudoku
-- diagonals. Puzzle data only activates this handler; it cannot redefine which
-- cells belong to the published rule.
-- 包级固定语义：这个变体使用两条标准数独对角线。题目数据只激活 handler，
-- 不能重新定义已发布规则包含哪些格子。
local function standard_diagonals()
  local main_cells = {}
  local anti_cells = {}

  for row = 0, 8 do
    main_cells[#main_cells + 1] = row * 9 + row
    anti_cells[#anti_cells + 1] = row * 9 + (8 - row)
  end

  return {
    {
      id = "main",
      cells = main_cells,
      violation_code = "diagonal_repeat"
    },
    {
      id = "anti",
      cells = anti_cells,
      violation_code = "diagonal_repeat"
    }
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

local function violation(code, first, second)
  return {
    code = code,
    cells = { first, second }
  }
end

local function find_repeated_digits(model, ctx, override_cell, override_digit)
  local violations = {}

  for diagonal_index, current_diagonal in ipairs(model.diagonals) do
    local seen = {}

    for _, cell in ipairs(current_diagonal.cells) do
      local digit = board.value(ctx, cell)

      if cell == override_cell then
        digit = override_digit
      end

      if not board.is_empty(digit) then
        local previous = seen[digit]

        if previous ~= nil then
          local item = violation(current_diagonal.violation_code, previous, cell)
          item.data = {
            diagonal = current_diagonal.id,
            index = diagonal_index
          }
          violations[#violations + 1] = item
        else
          seen[digit] = cell
        end
      end
    end
  end

  return violations
end

local function used_digits_on_diagonals(model, ctx, except_cell)
  local used = {}

  for _, current_diagonal in ipairs(model.diagonals) do
    if current_diagonal.cell_set[except_cell] == true then
      for _, cell in ipairs(current_diagonal.cells) do
        if cell ~= except_cell then
          local digit = board.value(ctx, cell)

          if not board.is_empty(digit) then
            used[digit] = true
          end
        end
      end
    end
  end

  return used
end

-- Required: create one private rule instance from one puzzle rule config.
-- 必须：从一份题目规则 config 创建一个私有规则实例。
function diagonal.create(config, scope)
  -- This rule has package-invariant semantics. The puzzle config only
  -- activates the handler; it cannot redefine the two diagonal geometries.
  -- 本规则的语义由包固定。题目 config 只负责激活 handler，不能重新定义
  -- 两条对角线几何。
  if type(config) ~= "table" or next(config) ~= nil then
    error("diagonal requires empty rule data")
  end

  local diagonals = standard_diagonals()
  local all_cells = {}

  for _, current_diagonal in ipairs(diagonals) do
    current_diagonal.cell_set = cell_set(current_diagonal.cells)
    for _, cell in ipairs(current_diagonal.cells) do
      all_cells[#all_cells + 1] = cell
    end
  end

  local model = {
    diagonals = diagonals,
    cell_set = cell_set(all_cells)
  }

  return {
    -- Required: validate a proposed move for this rule only.
    -- 必须：只针对本规则校验一次拟落子。
    validate_move = function(ctx, move)
      -- The handler reports only its own violations. The Host owns the full
      -- input transaction and decides how a rejected result is presented.
      -- handler 只报告本规则的违规。完整输入事务以及拒绝结果如何展示，
      -- 由 Host 负责。
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
      -- Host maps violations to conflict UI; Lua does not paint conflicts.
      -- Host 负责把 violations 映射到冲突 UI；Lua 不直接绘制冲突。
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
      -- The handler suggests removals only. The Host still computes the base
      -- candidate set and owns candidate display.
      -- handler 只能建议移除候选。基础候选集合和候选显示仍由 Host 计算和持有。
      local remove = {}
      local reasons = {}

      if contains_cell(model, cell) then
        local used = used_digits_on_diagonals(model, ctx, cell)

        for digit = 1, 9 do
          if used[digit] == true then
            remove[#remove + 1] = digit
            reasons[tostring(digit)] = "diagonal_repeat"
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
      -- Completion remains Host-owned. This callback reports only whether
      -- the diagonal rule itself is valid.
      -- 完成流程仍归 Host。本 callback 只报告对角线规则自身是否有效。
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
      -- Overlay is declarative. Lua does not receive Canvas, Flutter widgets
      -- or theme internals; the Host validates and renders these primitives.
      -- Overlay 是声明式输出。Lua 不接收 Canvas、Flutter widget 或主题内部对象；
      -- Host 校验 primitive 后负责实际绘制。
      return {
        primitives = {
          {
            type = "line",
            from = { x = 0, y = 0 },
            to = { x = 9, y = 9 },
            paint = {
              stroke = { theme = "constraint_line" },
              stroke_width = 0.024,
              opacity = 0.22,
              cap = "butt",
              join = "miter"
            }
          },
          {
            type = "line",
            from = { x = 9, y = 0 },
            to = { x = 0, y = 9 },
            paint = {
              stroke = { theme = "constraint_line" },
              stroke_width = 0.024,
              opacity = 0.22,
              cap = "butt",
              join = "miter"
            }
          }
        }
      }
    end
  }
end

plugin:register_rule("diagonal", diagonal)
plugin:register_rule("single_diagonal", diagonal)

return plugin:build()
