-- Community Variant Script API V1 Odd/Even reference implementation.
-- Community Variant Script API V1 奇偶数独参考实现。
--
-- The rule handler owns only the parity-mark semantics. The Host owns the
-- board, the move transaction, classic Sudoku validation, candidates, notes,
-- conflicts, persistence, overlay projection and the gameplay lifecycle.
-- handler 只拥有奇偶标记规则语义。棋盘、落子事务、经典数独校验、候选、笔记、
-- 冲突、持久化、overlay 投影和游戏生命周期仍由 Host 负责。
local plugin = community_variant.script()
local odd_even = {}
local board = community_variant.board
local cell_api = community_variant.cell

local function expect_parity(value, label)
  if value ~= "odd" and value ~= "even" then
    error(label .. " must be odd or even")
  end
  return value
end

local function digit_matches_parity(digit, parity)
  if parity == "odd" then
    return digit % 2 == 1
  end
  return digit % 2 == 0
end

local function shape_for_parity(parity)
  -- Built-in parity overlay uses a circle for odd marks and a square for even
  -- marks, matching the Host Odd/Even visual contract.
  -- 内建 parity overlay 中 odd 使用圆形，even 使用方形，与 Host 奇偶视觉契约一致。
  if parity == "odd" then
    return "circle"
  end
  return "square"
end

local function normalize_marks(config)
  -- Mark placement is puzzle-owned data. The rule semantics are fixed:
  -- marked odd cells accept only odd digits; marked even cells accept only even
  -- digits. Unmarked cells have no parity restriction.
  -- 标记位置属于题目数据。规则语义固定：odd 标记只允许奇数，even 标记只允许偶数；
  -- 未标记格没有额外奇偶限制。
  if type(config) ~= "table" or type(config.marks) ~= "table" then
    error("odd_even requires data.marks")
  end

  local marks = {}
  local by_cell = {}

  for index, raw in ipairs(config.marks) do
    if type(raw) ~= "table" then
      error("odd_even mark " .. index .. " must be a table")
    end
    local cell = cell_api.expect(raw.cell, "odd_even mark cell")
    local parity = expect_parity(raw.parity, "odd_even mark parity")
    if by_cell[cell] ~= nil then
      error("odd_even marks must not repeat a cell")
    end

    local mark = {
      cell = cell,
      parity = parity
    }
    marks[#marks + 1] = mark
    by_cell[cell] = mark
  end

  return marks, by_cell
end

local function make_violation(cell, parity)
  return {
    code = "odd_even_parity",
    cells = { cell },
    data = {
      parity = parity
    }
  }
end

local function cell_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, mark in ipairs(model.marks) do
    local digit = cell_digit(ctx, mark.cell, override_cell, override_digit)

    -- Partial board semantics: an empty marked cell is still undetermined.
    -- 部分填盘语义：带标记但尚未填数的格子仍是未确定状态。
    if not board.is_empty(digit) and not digit_matches_parity(digit, mark.parity) then
      violations[#violations + 1] = make_violation(mark.cell, mark.parity)
    end
  end

  return violations
end

local function parity_removals(parity)
  if parity == "odd" then
    return { 2, 4, 6, 8 }
  end
  return { 1, 3, 5, 7, 9 }
end

-- Required: create a private rule instance for one puzzle rule declaration.
-- 必须：为一条题目规则声明创建私有 rule instance。
function odd_even.create(config, scope)
  local marks, by_cell = normalize_marks(config)
  local model = {
    marks = marks,
    by_cell = by_cell
  }

  return {
    -- Validate only this rule; the Host owns the complete move transaction.
    -- 这里只校验本规则；完整落子事务仍由 Host 决定。
    validate_move = function(ctx, move)
      local mark = model.by_cell[move.cell]
      if mark == nil or board.is_empty(move.digit) then
        return {
          accepted = true,
          violations = {},
          diagnostics = {}
        }
      end

      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Report current-board Odd/Even violations for the Host conflict layer.
    -- 把当前盘面的奇偶违规交给 Host 冲突层。
    validate_board = function(ctx)
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    -- Return removals only; never replace the Host-owned candidate set.
    -- 只返回要删除的候选，绝不替换 Host 持有的完整候选集合。
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
      local mark = model.by_cell[cell]
      if mark == nil then
        return {
          remove = {},
          reasons = {},
          diagnostics = {}
        }
      end

      local remove = parity_removals(mark.parity)
      local reasons = {}
      for _, digit in ipairs(remove) do
        reasons[tostring(digit)] = "odd_even_parity"
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    -- Completion remains Host-owned; this reports only Odd/Even validity.
    -- 完成流程仍归 Host；这里仅报告奇偶规则是否有效。
    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Optional: return declarative Host overlay primitives for parity marks.
    -- 可选：返回 parity marks 的声明式 Host overlay primitives。
    build_overlay = function(ctx)
      local primitives = {}

      for _, mark in ipairs(model.marks) do
        primitives[#primitives + 1] = {
          type = "builtin",
          kind = "parity_mark",
          data = {
            cell = mark.cell,
            shape = shape_for_parity(mark.parity)
          }
        }
      end

      return {
        primitives = primitives,
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("odd_even", odd_even)

return plugin:build()
