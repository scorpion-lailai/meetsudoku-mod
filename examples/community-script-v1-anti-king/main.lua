-- Community Variant Script API V1 Anti-King preview.
-- Community Variant Script API V1 Anti-King 预览。
--
-- This file is a complete Script V1 reference implementation. The author owns
-- the king-move not-equal semantics,
-- while the Host owns board state, move transactions, candidates display,
-- conflict UI and saves.
-- 本文件是完整的 Script V1 参考实现。作者拥有王步不等语义；棋盘状态、落子事务、
-- 候选显示、冲突 UI 和存档仍归 Host。
local plugin = community_variant.script()
local board = community_variant.board
local cell_api = community_variant.cell
local anti_king = {}

local function king_offsets()
  -- These four canonical directions represent the eight undirected king moves
  -- after expansion over the 9x9 board.
  -- 这四个规范方向在 9x9 棋盘上展开后，代表全部八个无向王步相邻关系。
  return {
    { row_delta = 0, column_delta = 1 },
    { row_delta = 1, column_delta = -1 },
    { row_delta = 1, column_delta = 0 },
    { row_delta = 1, column_delta = 1 }
  }
end

local function expand_pairs(offsets)
  local pairs = {}
  local by_cell = {}

  for row = 0, 8 do
    for col = 0, 8 do
      local first = cell_api.index(row, col)

      for _, offset in ipairs(offsets) do
        local next_row = row + offset.row_delta
        local next_col = col + offset.column_delta

        if next_row >= 0 and next_row <= 8 and next_col >= 0 and next_col <= 8 then
          local second = cell_api.index(next_row, next_col)
          local pair = { first, second }
          pairs[#pairs + 1] = pair

          by_cell[first] = by_cell[first] or {}
          by_cell[first][#by_cell[first] + 1] = second
          by_cell[second] = by_cell[second] or {}
          by_cell[second][#by_cell[second] + 1] = first
        end
      end
    end
  end

  return pairs, by_cell
end

local function violation(first, second)
  return {
    code = "anti_king_equal",
    cells = { first, second }
  }
end

local function pair_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, pair in ipairs(model.pairs) do
    local first = pair[1]
    local second = pair[2]
    local first_digit = pair_digit(ctx, first, override_cell, override_digit)
    local second_digit = pair_digit(ctx, second, override_cell, override_digit)

    if not board.is_empty(first_digit) and first_digit == second_digit then
      violations[#violations + 1] = violation(first, second)
    end
  end

  return violations
end

-- Required: create one private rule instance from one puzzle rule config.
-- 必须：从一份题目规则 config 创建一个私有规则实例。
function anti_king.create(config, scope)
  -- Anti-King has package-invariant semantics. The puzzle config must stay
  -- empty; it only activates this registered handler.
  -- Anti-King 的语义由包固定。题目 config 必须为空，只负责激活已注册 handler。
  if type(config) ~= "table" or next(config) ~= nil then
    error("anti_king uses fixed package semantics and requires empty rule data")
  end

  local pairs, by_cell = expand_pairs(king_offsets())

  local model = {
    pairs = pairs,
    by_cell = by_cell
  }
  return {
    -- Required: validate a proposed move for this rule only.
    -- 必须：只针对本规则校验一次拟落子。
    validate_move = function(ctx, move)
      -- The handler reports only king-neighbor violations. The Host owns the
      -- full input transaction and never exposes mutable board state.
      -- handler 只报告王步邻居违规。完整输入事务归 Host，Lua 不接收可变棋盘状态。
      local cell = move.cell
      local digit = move.digit

      if model.by_cell[cell] == nil or board.is_empty(digit) then
        return {
          accepted = true,
          violations = {},
          diagnostics = {}
        }
      end

      local violations = find_violations(model, ctx, cell, digit)

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
      local remove_set = {}
      local neighbors = model.by_cell[cell]

      if neighbors ~= nil then
        for _, neighbor in ipairs(neighbors) do
          local digit = board.value(ctx, neighbor)
          if not board.is_empty(digit) then
            remove_set[digit] = true
          end
        end
      end

      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        if remove_set[digit] == true then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "anti_king_equal"
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
      local violations = find_violations(model, ctx, nil, nil)

      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end

  }
end

plugin:register_rule("anti_king", anti_king)

return plugin:build()
