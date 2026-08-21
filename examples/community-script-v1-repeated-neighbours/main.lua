-- Repeated Neighbours Sudoku technical package.
-- Lua derives the complete gray/white partition and every orthogonal
-- neighbourhood from puzzle-owned gray cells. Host owns board state, notes,
-- candidates UI, transactions, persistence and product flow.
local plugin = community_variant.script()
local repeated_neighbours = {}

local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema
local overlay_geometry = community_variant.overlay_geometry

local MIN_DIGIT = 1
local MAX_DIGIT = 9
local CELL_INSET = 0.04
local CELL_HALF_SIZE = 0.5 - CELL_INSET
local CELLS_PER_OVERLAY_PATH = 12
local FILL_OPACITY = 0.32
local GRAY_CODE = "repeated_neighbours_gray"
local WHITE_CODE = "repeated_neighbours_white"
local INCOMPLETE_CODE = "repeated_neighbours_incomplete"

local function orthogonal_neighbours(cell)
  local row = cell_api.row(cell)
  local column = cell_api.column(cell)
  local neighbours = {}
  if row > 0 then neighbours[#neighbours + 1] = cell_api.index(row - 1, column) end
  if column > 0 then neighbours[#neighbours + 1] = cell_api.index(row, column - 1) end
  if column < 8 then neighbours[#neighbours + 1] = cell_api.index(row, column + 1) end
  if row < 8 then neighbours[#neighbours + 1] = cell_api.index(row + 1, column) end
  table.sort(neighbours)
  return neighbours
end

local function normalize(config)
  schema.expect_exact_keys(
    config,
    { shaded_cells = true },
    "repeated_neighbours data"
  )
  schema.expect_array(
    config.shaded_cells,
    0,
    81,
    "repeated_neighbours.shaded_cells"
  )

  local shaded_cells = {}
  local shaded_by_cell = {}
  for index, raw_cell in ipairs(config.shaded_cells) do
    local cell = cell_api.expect(
      raw_cell,
      "repeated_neighbours.shaded_cells[" .. index .. "]"
    )
    if shaded_by_cell[cell] then
      error("repeated_neighbours.shaded_cells must not repeat a cell")
    end
    shaded_by_cell[cell] = true
    shaded_cells[#shaded_cells + 1] = cell
  end
  table.sort(shaded_cells)

  local centers = {}
  local centers_by_affected_cell = {}
  local candidate_scope = {}
  for cell = 0, 80 do
    local neighbours = orthogonal_neighbours(cell)
    local cells = { cell }
    for _, neighbour in ipairs(neighbours) do
      cells[#cells + 1] = neighbour
      centers_by_affected_cell[neighbour] = centers_by_affected_cell[neighbour] or {}
    end
    table.sort(cells)
    local center = {
      cell = cell,
      cells = cells,
      neighbours = neighbours,
      shaded = shaded_by_cell[cell] == true
    }
    centers[#centers + 1] = center
    candidate_scope[#candidate_scope + 1] = cell
    for _, neighbour in ipairs(neighbours) do
      centers_by_affected_cell[neighbour][#centers_by_affected_cell[neighbour] + 1] = center
    end
  end

  return {
    shaded_cells = shaded_cells,
    centers = centers,
    centers_by_affected_cell = centers_by_affected_cell,
    candidate_scope = candidate_scope
  }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function center_violation(center, ctx, override_cell, override_digit)
  local seen = {}
  local has_empty = false
  local has_duplicate = false
  for _, neighbour in ipairs(center.neighbours) do
    local value = value_for(ctx, neighbour, override_cell, override_digit)
    if board.is_empty(value) then
      has_empty = true
    elseif seen[value] then
      has_duplicate = true
    else
      seen[value] = true
    end
  end

  if center.shaded then
    if has_duplicate or has_empty then return nil end
    return { code = GRAY_CODE, cells = center.cells }
  end
  if has_duplicate then
    return { code = WHITE_CODE, cells = center.cells }
  end
  return nil
end

local function find_violations(model, ctx, override_cell, override_digit)
  local centers = override_cell == nil
      and model.centers
      or model.centers_by_affected_cell[override_cell] or {}
  local violations = {}
  for _, center in ipairs(centers) do
    local violation = center_violation(center, ctx, override_cell, override_digit)
    if violation ~= nil then violations[#violations + 1] = violation end
  end
  return violations
end

local function candidate_restrictions(model, ctx, cell)
  local blocked = {}
  local required = nil
  for _, center in ipairs(model.centers_by_affected_cell[cell] or {}) do
    local seen = {}
    local has_empty = false
    local has_duplicate = false
    for _, neighbour in ipairs(center.neighbours) do
      if neighbour ~= cell then
        local value = board.value(ctx, neighbour)
        if board.is_empty(value) then
          has_empty = true
        elseif seen[value] then
          has_duplicate = true
        else
          seen[value] = true
        end
      end
    end

    if center.shaded then
      if not has_duplicate and not has_empty then
        if required == nil then
          required = seen
        else
          for digit = MIN_DIGIT, MAX_DIGIT do
            if required[digit] and not seen[digit] then required[digit] = nil end
          end
        end
      end
    elseif has_duplicate then
      return { block_all = true }
    else
      for digit = MIN_DIGIT, MAX_DIGIT do
        if seen[digit] then blocked[digit] = true end
      end
    end
  end
  return {
    block_all = false,
    blocked = blocked,
    required = required
  }
end

local function append_cell_rect(commands, cell)
  local center = overlay_geometry.cell_center(cell)
  local left = center.x - CELL_HALF_SIZE
  local right = center.x + CELL_HALF_SIZE
  local top = center.y - CELL_HALF_SIZE
  local bottom = center.y + CELL_HALF_SIZE
  commands[#commands + 1] = { op = "move_to", x = left, y = top }
  commands[#commands + 1] = { op = "line_to", x = right, y = top }
  commands[#commands + 1] = { op = "line_to", x = right, y = bottom }
  commands[#commands + 1] = { op = "line_to", x = left, y = bottom }
  commands[#commands + 1] = { op = "close" }
end

local function build_overlay(model)
  local primitives = {}
  local commands = nil
  for index, cell in ipairs(model.shaded_cells) do
    if (index - 1) % CELLS_PER_OVERLAY_PATH == 0 then
      commands = {}
      primitives[#primitives + 1] = {
        type = "path",
        commands = commands,
        paint = {
          fill = { theme = "constraint_fill" },
          opacity = FILL_OPACITY
        }
      }
    end
    append_cell_rect(commands, cell)
  end
  return primitives
end

function repeated_neighbours.create(config, scope)
  local model = normalize(config)
  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    candidate_scope = function()
      return model.candidate_scope
    end,

    get_candidate_eliminations = function(ctx, cell, base_candidates)
      local remove = {}
      local reasons = {}
      local candidates = base_candidates or { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
      local restrictions = candidate_restrictions(model, ctx, cell)
      for _, digit in ipairs(candidates) do
        if restrictions.block_all
            or restrictions.blocked[digit]
            or (restrictions.required ~= nil and not restrictions.required[digit]) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "repeated_neighbours"
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local incomplete = {}
      for _, cell in ipairs(model.candidate_scope) do
        if board.is_empty(board.value(ctx, cell)) then
          incomplete[#incomplete + 1] = cell
        end
      end
      if #incomplete > 0 then
        return {
          valid = false,
          violations = {
            { code = INCOMPLETE_CODE, cells = incomplete }
          },
          diagnostics = {}
        }
      end
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      return {
        primitives = build_overlay(model),
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("repeated_neighbours", repeated_neighbours)
return plugin:build()
