-- Community Variant Script API V1 Arrow reference implementation.
-- Community Variant Script API V1 箭头数独参考实现。
--
-- The author owns the Arrow relation and puzzle geometry. The Host owns board
-- state, classic Sudoku validation, move transactions, candidate display,
-- conflicts, notes, persistence, completion and rendering.
-- 作者拥有箭头关系和题目几何。棋盘、经典数独校验、落子事务、候选、冲突、笔记、
-- 持久化、完成流程和渲染仍由 Host 负责。
local plugin = community_variant.script()
local arrow = {}
local board = community_variant.board
local cell_api = community_variant.cell

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

    arrows[#arrows + 1] = {
      head = head,
      path = path
    }
  end

  return arrows
end

local function index_arrows(arrows)
  local by_cell = {}

  for arrow_index, item in ipairs(arrows) do
    by_cell[item.head] = by_cell[item.head] or {}
    by_cell[item.head][#by_cell[item.head] + 1] = {
      arrow_index = arrow_index,
      role = "head",
      offset = 0
    }

    for offset, cell in ipairs(item.path) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = {
        arrow_index = arrow_index,
        role = "path",
        offset = offset
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

local function violation(item)
  local cells = { item.head }
  for _, cell in ipairs(item.path) do
    cells[#cells + 1] = cell
  end
  return {
    code = "arrow_sum",
    cells = cells
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
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

    -- A partial arrow is undetermined. It becomes a violation only when all
    -- cells are filled and the target sum is false.
    -- 未完成的箭头保持未定；只有所有格子填满且和不正确时才产生违规。
    if complete and head_digit ~= path_sum then
      violations[#violations + 1] = violation(item)
    end
  end

  return violations
end

local function candidate_allowed(item, ctx, cell, digit)
  local path_sum = 0
  local unknown_path = 0
  local head_digit = board.value(ctx, item.head)

  if cell == item.head then
    head_digit = digit
  end

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

  if cell == item.head then
    -- The candidate head must be reachable by the remaining path cells.
    local minimum = path_sum + unknown_path
    local maximum = path_sum + unknown_path * 9
    return digit >= minimum and digit <= maximum
  end

  if board.is_empty(head_digit) then
    -- With an empty head, any reachable path sum from 1..9 is still possible.
    local minimum = path_sum + unknown_path
    local maximum = path_sum + unknown_path * 9
    return minimum <= 9 and maximum >= 1
  end

  -- A filled head fixes the required path sum.
  local minimum = path_sum + unknown_path
  local maximum = path_sum + unknown_path * 9
  return head_digit >= minimum and head_digit <= maximum
end

-- Required: create one private rule instance from puzzle-owned arrow geometry.
-- 必须：根据题目拥有的箭头几何创建私有 rule instance。
function arrow.create(config, scope)
  local arrows = normalize_arrows(config)
  local model = {
    arrows = arrows,
    by_cell = index_arrows(arrows)
  }

  return {
    -- Validate only the Arrow rule; Host owns the full move decision.
    -- 这里只校验箭头规则；完整落子决定由 Host 负责。
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Report all currently complete-but-invalid arrows.
    -- 报告当前所有已填满但和不正确的箭头。
    validate_board = function(ctx)
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    -- Suggest removals from the Host-owned candidate set.
    -- 只向 Host-owned 候选集合提供删除建议。
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
            if not candidate_allowed(item, ctx, cell, digit) then
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

    -- Completion remains Host-owned; this reports Arrow validity only.
    -- 完成流程仍归 Host；这里仅报告箭头规则是否有效。
    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Return a built-in primitive; the Host painter renders the arrow.
    -- 返回 built-in primitive，由 Host painter 负责绘制箭头。
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

plugin:register_rule("arrow", arrow)

return plugin:build()
