-- Community Variant Script API V1 Anti-Knight reference implementation.
-- Community Variant Script API V1 反骑士数独参考实现。
--
-- The rule handler owns only the Anti-Knight semantics. The Host owns the
-- board, the move transaction, classic Sudoku validation, candidates, notes,
-- conflicts, persistence and the gameplay lifecycle.
-- handler 只拥有反骑士语义。棋盘、落子事务、经典数独校验、候选、笔记、冲突、
-- 持久化和游戏生命周期仍由 Host 负责。
local plugin = community_variant.script()
local anti_knight = {}
local board = community_variant.board

local function knight_offsets()
  -- These four directed offsets expand to every undirected knight pair on a
  -- 9x9 board without producing duplicate pairs.
  -- 四个方向展开后覆盖 9x9 棋盘上的所有无向骑士步关系，且不会产生重复 pair。
  return {
    { row_delta = 1, column_delta = -2 },
    { row_delta = 1, column_delta = 2 },
    { row_delta = 2, column_delta = -1 },
    { row_delta = 2, column_delta = 1 }
  }
end

local function expand_pairs(offsets)
  local pairs = {}
  local by_cell = {}

  for row = 0, 8 do
    for column = 0, 8 do
      local first = row * 9 + column

      for _, offset in ipairs(offsets) do
        local next_row = row + offset.row_delta
        local next_column = column + offset.column_delta

        if next_row >= 0 and next_row <= 8
            and next_column >= 0 and next_column <= 8 then
          local second = next_row * 9 + next_column
          pairs[#pairs + 1] = { first, second }

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

local function pair_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function make_violation(first, second)
  return {
    code = "anti_knight_equal",
    cells = { first, second }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, pair in ipairs(model.pairs) do
    local first_digit = pair_digit(ctx, pair[1], override_cell, override_digit)
    local second_digit = pair_digit(ctx, pair[2], override_cell, override_digit)

    if not board.is_empty(first_digit) and first_digit == second_digit then
      violations[#violations + 1] = make_violation(pair[1], pair[2])
    end
  end

  return violations
end

-- Required: create a private rule instance for one puzzle rule declaration.
-- 必须：为一条题目规则声明创建私有 rule instance。
function anti_knight.create(config, scope)
  -- The offsets are package-owned. Empty data prevents individual puzzles from
  -- silently changing the published meaning of Anti-Knight.
  -- offset 属于包级语义。空 data 防止单个题目偷偷改变反骑士定义。
  if type(config) ~= "table" or next(config) ~= nil then
    error("anti_knight requires empty rule data")
  end

  local pairs, by_cell = expand_pairs(knight_offsets())
  local model = {
    pairs = pairs,
    by_cell = by_cell
  }

  return {
    -- Validate only this rule; the Host owns the complete move transaction.
    -- 这里只校验本规则；完整落子事务仍由 Host 决定。
    validate_move = function(ctx, move)
      if model.by_cell[move.cell] == nil or board.is_empty(move.digit) then
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

    -- Report current-board Anti-Knight violations for the Host conflict layer.
    -- 把当前盘面的反骑士违规交给 Host 冲突层。
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
          reasons[tostring(digit)] = "anti_knight_equal"
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    -- Completion remains Host-owned; this reports only Anti-Knight validity.
    -- 完成流程仍归 Host；这里仅报告反骑士规则是否有效。
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

plugin:register_rule("anti_knight", anti_knight)

return plugin:build()
