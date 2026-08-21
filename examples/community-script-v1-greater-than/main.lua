-- Community Variant Script API V1 Greater Than reference package.
-- Community Variant Script API V1 数比数独参考包。
--
-- The package owns only directed edge relations and their static marks. The
-- Host still owns board state, input transactions, candidates, completion,
-- persistence and the Native Gameplay Core.
local plugin = community_variant.script()
local greater_than = {}
local overlay_geometry = community_variant.overlay_geometry
local board = community_variant.board

local function point(x, y)
  return { x = x, y = y }
end

local function mark_overlay(first_x, first_y, second_x, second_y, direction)
  local center_x = (first_x + second_x) / 2
  local center_y = (first_y + second_y) / 2
  local dx = second_x - first_x
  local dy = second_y - first_y
  local length = math.sqrt(dx * dx + dy * dy)
  local nx = -dy / length
  local ny = dx / length
  local ux = dx / length
  local uy = dy / length
  local half = 0.18
  local arm = 0.20
  local tip_x = center_x + (direction == "less_than" and -ux or ux) * half
  local tip_y = center_y + (direction == "less_than" and -uy or uy) * half
  local base_x = center_x - (direction == "less_than" and -ux or ux) * half
  local base_y = center_y - (direction == "less_than" and -uy or uy) * half

  return {
    {
      type = "polyline",
      points = {
        point(tip_x, tip_y),
        point(base_x + nx * arm, base_y + ny * arm)
      },
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = 0.08,
        opacity = 1.0,
        cap = "round",
        join = "round"
      }
    },
    {
      type = "polyline",
      points = {
        point(tip_x, tip_y),
        point(base_x - nx * arm, base_y - ny * arm)
      },
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = 0.08,
        opacity = 1.0,
        cap = "round",
        join = "round"
      }
    }
  }
end

local function normalize_marks(data)
  if type(data) ~= "table" or type(data.marks) ~= "table" then
    error("greater_than requires data.marks")
  end

  local marks = {}
  local seen = {}
  for index, mark in ipairs(data.marks) do
    if type(mark) ~= "table" or (mark.type ~= "less_than" and mark.type ~= "greater_than") then
      error("greater_than mark " .. tostring(index) .. " has an unsupported type")
    end
    if type(mark.cells) ~= "table" or #mark.cells ~= 2 then
      error("greater_than mark " .. tostring(index) .. " requires two cells")
    end
    local first = tonumber(mark.cells[1])
    local second = tonumber(mark.cells[2])
    if first == nil or second == nil or first == second
        or first < 0 or first > 80 or second < 0 or second > 80 then
      error("greater_than mark " .. tostring(index) .. " has invalid cells")
    end
    local row_delta = math.abs(math.floor(first / 9) - math.floor(second / 9))
    local col_delta = math.abs((first % 9) - (second % 9))
    if row_delta + col_delta ~= 1 then
      error("greater_than mark " .. tostring(index) .. " must join orthogonal cells")
    end
    local key = tostring(first) .. ":" .. tostring(second)
    if seen[key] then
      error("greater_than contains duplicate directed edge")
    end
    seen[key] = true
    marks[#marks + 1] = { type = mark.type, cells = { first, second } }
  end
  return marks
end

local function relation_holds(mark, first_digit, second_digit)
  if mark.type == "less_than" then
    return first_digit < second_digit
  end
  return first_digit > second_digit
end

local function violation(mark)
  return {
    code = "greater_than_" .. mark.type,
    cells = { mark.cells[1], mark.cells[2] },
    data = { relation = mark.type }
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
    if not board.is_empty(first_digit) and not board.is_empty(second_digit)
        and not relation_holds(mark, first_digit, second_digit) then
      violations[#violations + 1] = violation(mark)
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  for _, mark in ipairs(model.marks) do
    local first = mark.cells[1]
    local second = mark.cells[2]
    if first == cell or second == cell then
      local other = first == cell and second or first
      local other_digit = board.value(ctx, other)
      if not board.is_empty(other_digit) then
        local first_digit = first == cell and digit or other_digit
        local second_digit = second == cell and digit or other_digit
        if not relation_holds(mark, first_digit, second_digit) then
          return false
        end
      end
    end
  end
  return true
end

function greater_than.create(config, scope)
  local marks = normalize_marks(config)
  local model = { marks = marks }

  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = find_violations(model, ctx, nil, nil), diagnostics = {} }
    end,

    candidate_scope = function()
      local included = {}
      for _, mark in ipairs(model.marks) do
        for _, cell in ipairs(mark.cells) do
          included[cell] = true
        end
      end
      local cells = {}
      for cell = 0, 80 do
        if included[cell] then
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
          reasons[tostring(digit)] = "greater_than_order"
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
        local first = overlay_geometry.cell_center(mark.cells[1])
        local second = overlay_geometry.cell_center(mark.cells[2])
        local first_x, first_y = first.x, first.y
        local second_x, second_y = second.x, second.y
        local generated = mark_overlay(first_x, first_y, second_x, second_y, mark.type)
        for _, primitive in ipairs(generated) do
          primitives[#primitives + 1] = primitive
        end
      end
      return { primitives = primitives }
    end
  }
end

plugin:register_rule("greater_than", greater_than)

return plugin:build()
