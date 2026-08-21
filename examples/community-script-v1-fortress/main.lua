-- Community Variant Script API V1 Fortress Sudoku reference package.
-- 堡垒数独参考包：Lua 从每题阴影格集合推导全部正交边界格对，并完整实现
-- 阴影端严格大于非阴影端的规则。Host 仍拥有棋盘事务、候选/笔记、存档和 UI。
local plugin = community_variant.script()
local fortress = {}

local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema
local overlay_geometry = community_variant.overlay_geometry

local MIN_DIGIT = 1
local MAX_DIGIT = 9
local MAX_SHADED_CELLS = 80
local CELLS_PER_OVERLAY_PATH = 12
local CELL_INSET = 0.04
local CELL_HALF_SIZE = 0.5 - CELL_INSET
local FILL_OPACITY = 0.32
local ORDER_CODE = "fortress_order"
local INCOMPLETE_CODE = "fortress_incomplete"

local function normalize(config)
  schema.expect_exact_keys(config, { shaded_cells = true }, "fortress data")
  schema.expect_array(
    config.shaded_cells,
    1,
    MAX_SHADED_CELLS,
    "fortress.shaded_cells"
  )

  local shaded_cells = {}
  local shaded_by_cell = {}
  for index, raw_cell in ipairs(config.shaded_cells) do
    local cell = cell_api.expect(raw_cell, "fortress.shaded_cells[" .. index .. "]")
    if shaded_by_cell[cell] then
      error("fortress.shaded_cells must not repeat a cell")
    end
    shaded_cells[#shaded_cells + 1] = cell
    shaded_by_cell[cell] = true
  end
  table.sort(shaded_cells)

  local pairs = {}
  local pairs_by_cell = {}
  local scope_by_cell = {}

  local function add_boundary(first, second)
    local first_shaded = shaded_by_cell[first] == true
    local second_shaded = shaded_by_cell[second] == true
    if first_shaded == second_shaded then return end

    local pair = {
      index = #pairs + 1,
      high = first_shaded and first or second,
      low = first_shaded and second or first
    }
    pairs[#pairs + 1] = pair
    pairs_by_cell[first] = pairs_by_cell[first] or {}
    pairs_by_cell[second] = pairs_by_cell[second] or {}
    pairs_by_cell[first][#pairs_by_cell[first] + 1] = pair
    pairs_by_cell[second][#pairs_by_cell[second] + 1] = pair
    scope_by_cell[first] = true
    scope_by_cell[second] = true
  end

  for cell = 0, 80 do
    local row = cell_api.row(cell)
    local column = cell_api.column(cell)
    if column < 8 then
      add_boundary(cell, cell_api.index(row, column + 1))
    end
    if row < 8 then
      add_boundary(cell, cell_api.index(row + 1, column))
    end
  end

  if #pairs == 0 then
    error("fortress shading must create at least one orthogonal boundary")
  end

  local candidate_scope = {}
  for cell = 0, 80 do
    if scope_by_cell[cell] then candidate_scope[#candidate_scope + 1] = cell end
  end

  return {
    shaded_cells = shaded_cells,
    shaded_by_cell = shaded_by_cell,
    pairs = pairs,
    pairs_by_cell = pairs_by_cell,
    candidate_scope = candidate_scope,
    scope_by_cell = scope_by_cell
  }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function pair_possible(high_value, low_value)
  local high_empty = board.is_empty(high_value)
  local low_empty = board.is_empty(low_value)
  if not high_empty and not low_empty then return high_value > low_value end
  if not high_empty then return high_value > MIN_DIGIT end
  if not low_empty then return low_value < MAX_DIGIT end
  return true
end

local function failing_cells(model, ctx, override_cell, override_digit)
  local related = override_cell == nil and model.pairs
      or model.pairs_by_cell[override_cell] or {}
  local cells = {}
  local seen = {}
  for _, pair in ipairs(related) do
    local high_value = value_for(ctx, pair.high, override_cell, override_digit)
    local low_value = value_for(ctx, pair.low, override_cell, override_digit)
    if not pair_possible(high_value, low_value) then
      if not seen[pair.high] then
        cells[#cells + 1] = pair.high
        seen[pair.high] = true
      end
      if not seen[pair.low] then
        cells[#cells + 1] = pair.low
        seen[pair.low] = true
      end
    end
  end
  table.sort(cells)
  return cells
end

local function violations_for(cells, code)
  if #cells == 0 then return {} end
  return {
    {
      code = code,
      cells = cells
    }
  }
end

local function candidate_allowed(model, ctx, cell, digit)
  return #failing_cells(model, ctx, cell, digit) == 0
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

local function build_shading_overlay(model)
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

function fortress.create(config, scope)
  local model = normalize(config)
  return {
    validate_move = function(ctx, move)
      if not model.scope_by_cell[move.cell] then
        return { accepted = true, violations = {}, diagnostics = {} }
      end
      local cells = failing_cells(model, ctx, move.cell, move.digit)
      return {
        accepted = #cells == 0,
        violations = violations_for(cells, ORDER_CODE),
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      local cells = failing_cells(model, ctx, nil, nil)
      return {
        violations = violations_for(cells, ORDER_CODE),
        diagnostics = {}
      }
    end,

    candidate_scope = function()
      return model.candidate_scope
    end,

    get_candidate_eliminations = function(ctx, cell)
      if not model.scope_by_cell[cell] then
        return { remove = {}, reasons = {}, diagnostics = {} }
      end
      local remove = {}
      local reasons = {}
      for digit = MIN_DIGIT, MAX_DIGIT do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = ORDER_CODE
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
          violations = violations_for(incomplete, INCOMPLETE_CODE),
          diagnostics = {}
        }
      end
      local cells = failing_cells(model, ctx, nil, nil)
      return {
        valid = #cells == 0,
        violations = violations_for(cells, ORDER_CODE),
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      return {
        primitives = build_shading_overlay(model),
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("fortress", fortress)
return plugin:build()
