-- Community Variant Script API V1 Consecutive reference package.
-- Community Variant Script API V1 连续数独参考包。
--
-- Mark locations are puzzle-owned. The package fixes one meaning for every
-- mark: its two orthogonally adjacent digits must differ by exactly one. The
-- Host still owns the board, input, candidates, completion, saves and UI.
local plugin = community_variant.script()
local consecutive = {}
local overlay_geometry = community_variant.overlay_geometry
local board = community_variant.board
local cell_api = community_variant.cell

local function are_orthogonally_adjacent(first, second)
  local row_delta = math.abs(math.floor(first / 9) - math.floor(second / 9))
  local column_delta = math.abs((first % 9) - (second % 9))
  return row_delta + column_delta == 1
end

local function edge_key(first, second)
  if first < second then
    return tostring(first) .. ":" .. tostring(second)
  end
  return tostring(second) .. ":" .. tostring(first)
end

local function normalize_marks(config)
  if type(config) ~= "table" or type(config.marks) ~= "table" then
    error("consecutive requires data.marks")
  end

  local marks = {}
  local by_cell = {}
  local used_edges = {}
  for index, raw in ipairs(config.marks) do
    if type(raw) ~= "table" or type(raw.cells) ~= "table" or #raw.cells ~= 2 then
      error("consecutive mark " .. index .. " must contain exactly two cells")
    end
    local first = cell_api.expect(raw.cells[1], "consecutive mark first cell")
    local second = cell_api.expect(raw.cells[2], "consecutive mark second cell")
    if first == second or not are_orthogonally_adjacent(first, second) then
      error("consecutive mark cells must be different orthogonal neighbors")
    end
    local key = edge_key(first, second)
    if used_edges[key] then
      error("consecutive marks must not repeat an edge")
    end
    used_edges[key] = true
    marks[#marks + 1] = { cells = { first, second } }
    local mark_index = #marks
    for _, cell in ipairs({ first, second }) do
      by_cell[cell] = by_cell[cell] or {}
      by_cell[cell][#by_cell[cell] + 1] = mark_index
    end
  end
  if #marks == 0 then
    error("consecutive requires at least one marked edge")
  end
  return { marks = marks, by_cell = by_cell }
end

local function mark_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function violation(mark)
  return { code = "consecutive_difference", cells = { mark.cells[1], mark.cells[2] } }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, mark in ipairs(model.marks) do
    local first = mark_digit(ctx, mark.cells[1], override_cell, override_digit)
    local second = mark_digit(ctx, mark.cells[2], override_cell, override_digit)
    if not board.is_empty(first) and not board.is_empty(second) and math.abs(first - second) ~= 1 then
      violations[#violations + 1] = violation(mark)
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
    local neighbor_digit = board.value(ctx, other_cell(mark, cell))
    if not board.is_empty(neighbor_digit) and math.abs(digit - neighbor_digit) ~= 1 then
      return false
    end
  end
  return true
end

function consecutive.create(config, scope)
  local model = normalize_marks(config)
  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = find_violations(model, ctx, nil, nil), diagnostics = {} }
    end,

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
          reasons[tostring(digit)] = "consecutive_difference"
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, mark in ipairs(model.marks) do
        primitives[#primitives + 1] = {
          type = "circle",
          center = overlay_geometry.edge_center(mark.cells[1], mark.cells[2]),
          radius = 0.18,
          paint = {
            stroke = "#222222",
            stroke_width = 0.035,
            opacity = 1
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("consecutive", consecutive)

return plugin:build()
