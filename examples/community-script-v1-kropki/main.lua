-- Community Variant Script API V1 Kropki reference implementation.
-- Community Variant Script API V1 黑白点数独参考实现。
--
-- The author owns only the Kropki edge semantics, candidate elimination
-- suggestions, and optional overlay declarations. The Host owns the board,
-- move transaction, classic Sudoku validation, candidates, notes, conflicts,
-- persistence, completion and rendering.
-- 作者只拥有黑白点边规则语义、候选删除建议和可选 overlay 声明。棋盘、落子事务、
-- 经典数独校验、候选、笔记、冲突、持久化、完成和渲染仍由 Host 负责。
local plugin = community_variant.script()
local kropki = {}
local overlay_geometry = community_variant.overlay_geometry
local board = community_variant.board
local cell_api = community_variant.cell

local function expect_mark_type(value, label)
  if value ~= "consecutive" and value ~= "ratio2" then
    error(label .. " must be consecutive or ratio2")
  end
  return value
end

local function are_orthogonally_adjacent(first, second)
  local first_row = math.floor(first / 9)
  local first_column = first % 9
  local second_row = math.floor(second / 9)
  local second_column = second % 9
  return math.abs(first_row - second_row) + math.abs(first_column - second_column) == 1
end

local function edge_key(first, second)
  if first < second then
    return tostring(first) .. ":" .. tostring(second)
  end
  return tostring(second) .. ":" .. tostring(first)
end

local function type_allows(mark_type, first_digit, second_digit)
  if mark_type == "consecutive" then
    return math.abs(first_digit - second_digit) == 1
  end
  return first_digit == second_digit * 2 or second_digit == first_digit * 2
end

local function violation(mark)
  return {
    code = "kropki_" .. mark.type,
    cells = { mark.cells[1], mark.cells[2] },
    data = {
      type = mark.type
    }
  }
end

local function normalize_marks(config)
  -- Mark positions are puzzle-owned. Mark semantics are package-owned:
  -- consecutive = white dot, ratio2 = black dot.
  -- 标记位置属于题目数据。标记语义属于包级代码：consecutive=白点，ratio2=黑点。
  if type(config) ~= "table" or type(config.marks) ~= "table" then
    error("kropki requires data.marks")
  end

  local marks = {}
  local by_cell = {}
  local used_edges = {}

  for index, raw in ipairs(config.marks) do
    if type(raw) ~= "table" or type(raw.cells) ~= "table" then
      error("kropki mark " .. index .. " must contain cells")
    end
    if #raw.cells ~= 2 then
      error("kropki mark " .. index .. " must contain exactly two cells")
    end

    local first = cell_api.expect(raw.cells[1], "kropki mark first cell")
    local second = cell_api.expect(raw.cells[2], "kropki mark second cell")
    if first == second then
      error("kropki mark cells must be different")
    end
    if not are_orthogonally_adjacent(first, second) then
      error("kropki mark cells must be orthogonally adjacent")
    end

    local key = edge_key(first, second)
    if used_edges[key] ~= nil then
      error("kropki marks must not repeat an edge")
    end
    used_edges[key] = true

    local mark = {
      type = expect_mark_type(raw.type, "kropki mark type"),
      cells = { first, second }
    }

    marks[#marks + 1] = mark
    local mark_index = #marks
    for _, cell in ipairs(mark.cells) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = mark_index
    end
  end

  return {
    marks = marks,
    by_cell = by_cell
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

    -- Partial board semantics: a Kropki edge is not false until both endpoint
    -- cells are filled. Empty cells remain undetermined.
    -- 部分盘面语义：黑白点边只有在两端都已填数时才判断真假；有空格时保持未定。
    if not board.is_empty(first_digit) and not board.is_empty(second_digit) then
      if not type_allows(mark.type, first_digit, second_digit) then
        violations[#violations + 1] = violation(mark)
      end
    end
  end

  return violations
end

local function other_cell(mark, cell)
  if mark.cells[1] == cell then
    return mark.cells[2]
  end
  return mark.cells[1]
end

local function candidate_allowed(model, ctx, cell, digit)
  local mark_indexes = model.by_cell[cell]
  if mark_indexes == nil then
    return true
  end

  for _, mark_index in ipairs(mark_indexes) do
    local mark = model.marks[mark_index]
    local neighbor = other_cell(mark, cell)
    local neighbor_digit = board.value(ctx, neighbor)
    if not board.is_empty(neighbor_digit) and not type_allows(mark.type, digit, neighbor_digit) then
      return false
    end
  end

  return true
end

local function overlay_paint(mark_type)
  if mark_type == "consecutive" then
    return {
      -- White Kropki dots are hollow: stroke only, no fill.
      -- 白点是空心圆：只描边，不填充。
      stroke = "#222222",
      stroke_width = 0.035,
      opacity = 1
    }
  end

  return {
    -- Black Kropki dots are solid: same dark stroke and fill.
    -- 黑点是实心圆：描边和填充都使用深色。
    stroke = "#222222",
    fill = "#222222",
    stroke_width = 0.035,
    opacity = 1
  }
end

-- Required: create a private rule instance for one puzzle rule declaration.
-- 必须：为一条题目规则声明创建私有 rule instance。
function kropki.create(config, scope)
  local model = normalize_marks(config)

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

    -- Report current-board Kropki violations for the Host conflict layer.
    -- 把当前盘面的黑白点违规交给 Host 冲突层。
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

      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "kropki_edge"
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    -- Completion remains Host-owned; this reports only Kropki validity.
    -- 完成流程仍归 Host；这里仅报告黑白点规则是否有效。
    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    -- Optional: return declarative overlay primitives for Kropki dots.
    -- 可选：返回黑白点的声明式 overlay primitives。
    build_overlay = function(ctx)
      local primitives = {}

      for _, mark in ipairs(model.marks) do
        primitives[#primitives + 1] = {
          type = "circle",
          center = overlay_geometry.edge_center(mark.cells[1], mark.cells[2]),
          radius = 0.18,
          paint = overlay_paint(mark.type)
        }
      end

      return {
        primitives = primitives,
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("kropki", kropki)

return plugin:build()
