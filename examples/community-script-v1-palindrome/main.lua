-- Community Variant Script API V1 Palindrome reference implementation.
-- Community Variant Script API V1 回文数独参考实现。
--
-- The author owns only palindrome line semantics, candidate elimination
-- suggestions, and optional overlay declarations. The Host owns the board,
-- move transaction, classic Sudoku validation, candidates, notes, conflicts,
-- persistence, completion, hints and rendering.
-- 作者只拥有回文线规则语义、候选删除建议和可选 overlay 声明。棋盘、落子事务、
-- 经典数独校验、候选、笔记、冲突、持久化、完成、提示和渲染仍由 Host 负责。
local plugin = community_variant.script()
local palindrome = {}
local board = community_variant.board
local cell_api = community_variant.cell
local adjacency = community_variant.adjacency
local path_api = community_variant.path
local overlay_geometry = community_variant.overlay_geometry

local function add_mirror(by_cell, cell, mirror)
  by_cell[cell] = by_cell[cell] or {}
  by_cell[cell][#by_cell[cell] + 1] = mirror
end

local function normalize_lines(config)
  -- Line geometry is puzzle-owned data. Rule semantics are package-owned:
  -- every cell listed by a line is part of the path, and mirrored positions on
  -- that ordered path must contain the same digit.
  -- 线条几何属于题目数据。规则语义属于包级代码：line 数组里的每个格子都是路径
  -- 经过的格子，路径上的对称位置必须相同。
  if type(config) ~= "table" or type(config.lines) ~= "table" then
    error("palindrome requires data.lines")
  end

  local lines = {}
  local pairs = {}
  local by_cell = {}
  local used_pairs = {}
  local used_line_cells = {}

  for line_index, raw_line in ipairs(config.lines) do
    if type(raw_line) ~= "table" or #raw_line < 3 then
      error("palindrome line " .. line_index .. " must contain at least three cells")
    end

    local line = {}
    local used_cells = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, "palindrome line cell")
      if used_cells[cell] ~= nil then
        error("palindrome line " .. line_index .. " must not repeat a cell")
      end
      if used_line_cells[cell] ~= nil then
        error("palindrome lines must not share a cell")
      end
      used_cells[cell] = true
      used_line_cells[cell] = true
      line[offset] = cell
    end

    for offset = 1, #line - 1 do
      if not adjacency.eight_way(line[offset], line[offset + 1]) then
        error("palindrome line " .. line_index .. " must pass through adjacent cell centers")
      end
    end

    lines[#lines + 1] = line
    for left = 1, math.floor(#line / 2) do
      local right = #line - left + 1
      local first = line[left]
      local second = line[right]
      local key = path_api.edge_key(first, second)

      if used_pairs[key] == nil then
        used_pairs[key] = true
        pairs[#pairs + 1] = {
          cells = { first, second },
          line = line_index
        }
        add_mirror(by_cell, first, second)
        add_mirror(by_cell, second, first)
      end
    end
  end

  return {
    lines = lines,
    pairs = pairs,
    by_cell = by_cell
  }
end

local function pair_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function violation(pair)
  return {
    code = "palindrome_mismatch",
    cells = { pair.cells[1], pair.cells[2] },
    data = {
      line = pair.line
    }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, pair in ipairs(model.pairs) do
    local first_digit = pair_digit(ctx, pair.cells[1], override_cell, override_digit)
    local second_digit = pair_digit(ctx, pair.cells[2], override_cell, override_digit)

    -- Partial board semantics: a palindrome pair is not false until both
    -- mirrored cells are filled. Empty cells remain undetermined.
    -- 部分盘面语义：回文 pair 只有在两端都已填数时才判断真假；有空格时保持未定。
    if not board.is_empty(first_digit) and not board.is_empty(second_digit) then
      if first_digit ~= second_digit then
        violations[#violations + 1] = violation(pair)
      end
    end
  end

  return violations
end

local function sorted_unique(values)
  table.sort(values)
  local result = {}
  local previous = nil
  for _, value in ipairs(values) do
    if value ~= previous then
      result[#result + 1] = value
      previous = value
    end
  end
  return result
end

local function allowed_digit_from_mirrors(model, ctx, cell)
  local mirrors = model.by_cell[cell]
  if mirrors == nil then
    return nil, false
  end

  local required = nil
  for _, mirror in ipairs(mirrors) do
    local digit = board.value(ctx, mirror)
    if not board.is_empty(digit) then
      if required == nil then
        required = digit
      elseif required ~= digit then
        return nil, true
      end
    end
  end

  return required, false
end

-- Required: create a private rule instance for one puzzle rule declaration.
-- 必须：为一条题目规则声明创建私有 rule instance。
function palindrome.create(config, scope)
  local model = normalize_lines(config)

  return {
    -- Validate only this rule; the Host owns the full move transaction.
    -- 这里只校验本规则；完整落子事务仍由 Host 决定。
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Report current-board palindrome violations for the Host conflict layer.
    -- 把当前盘面的回文违规交给 Host 冲突层。
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
      local remove = {}
      local reasons = {}
      local required, contradiction = allowed_digit_from_mirrors(model, ctx, cell)

      if contradiction then
        for digit = 1, 9 do
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "palindrome_mismatch"
        end
      elseif required ~= nil then
        for digit = 1, 9 do
          if digit ~= required then
            remove[#remove + 1] = digit
            reasons[tostring(digit)] = "palindrome_mirror"
          end
        end
      end

      return {
        remove = sorted_unique(remove),
        reasons = reasons,
        diagnostics = {}
      }
    end,

    -- Completion remains Host-owned; this reports only Palindrome validity.
    -- 完成流程仍归 Host；这里仅报告回文规则是否有效。
    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Optional: return declarative overlay primitives for palindrome lines.
    -- 可选：返回回文线的声明式 overlay primitives。
    build_overlay = function(ctx)
      local primitives = {}

      for _, line in ipairs(model.lines) do
        local points = overlay_geometry.cell_centers(line)

        primitives[#primitives + 1] = {
          type = "polyline",
          points = points,
          paint = {
            -- Palindrome line color is presentation-only. It carries no rule
            -- meaning beyond "cells on this line are mirrored".
            -- 回文线颜色只用于展示，不承载除“这些格子在线上对称”之外的规则语义。
            stroke = "#8A4FD3",
            stroke_width = 0.08,
            opacity = 0.85,
            cap = "round",
            join = "round"
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

plugin:register_rule("palindrome", palindrome)

return plugin:build()
