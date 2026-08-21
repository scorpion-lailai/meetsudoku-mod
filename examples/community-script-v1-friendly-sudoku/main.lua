-- Friendly Sudoku, Community Variant Script API V1 technical package.
-- A cell is friendly when its digit matches its one-based row, column, or box
-- number. Puzzle data owns only the required board-wide total.
local plugin = community_variant.script()
local friendly_sudoku = {}
local board = community_variant.board
local schema = community_variant.schema

local MAX_CELLS = 81
local COUNT_EXCEEDED = "friendly_count_exceeded"
local COUNT_UNREACHABLE = "friendly_count_unreachable"
local COUNT_MISMATCH = "friendly_count_mismatch"
local INCOMPLETE = "friendly_incomplete"

local function expect_target(value)
  local target = schema.expect_integer(value, "friendly_sudoku.target")
  if target < 0 or target > MAX_CELLS then
    error("friendly_sudoku.target must be in 0..81")
  end
  return target
end

local function normalize(config)
  schema.expect_exact_keys(config, { target = true }, "friendly_sudoku data")
  return { target = expect_target(config.target) }
end

local function is_friendly(cell, digit)
  local row = math.floor(cell / 9) + 1
  local column = (cell % 9) + 1
  local box = math.floor((row - 1) / 3) * 3
      + math.floor((column - 1) / 3) + 1
  return digit == row or digit == column or digit == box
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function count_state(ctx, override_cell, override_digit)
  local known, empty = 0, 0
  local friendly_cells, empty_cells = {}, {}
  for cell = 0, 80 do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    if board.is_empty(digit) then
      empty = empty + 1
      empty_cells[#empty_cells + 1] = cell
    elseif is_friendly(cell, digit) then
      known = known + 1
      friendly_cells[#friendly_cells + 1] = cell
    end
  end
  return {
    known = known,
    empty = empty,
    friendly_cells = friendly_cells,
    empty_cells = empty_cells
  }
end

local function partial_violations(model, state)
  if state.known > model.target then
    return {{ code = COUNT_EXCEEDED, cells = state.friendly_cells }}
  end
  if state.known + state.empty < model.target then
    return {{ code = COUNT_UNREACHABLE, cells = state.friendly_cells }}
  end
  return {}
end

local function final_violations(model, state)
  if state.empty > 0 then
    local violations = partial_violations(model, state)
    if #violations > 0 then return violations end
    return {{ code = INCOMPLETE, cells = state.empty_cells }}
  end
  if state.known ~= model.target then
    return {{ code = COUNT_MISMATCH, cells = state.friendly_cells }}
  end
  return {}
end

function friendly_sudoku.create(config, scope)
  local model = normalize(config)
  return {
    validate_move = function(ctx, move)
      local violations = partial_violations(
        model,
        count_state(ctx, move.cell, move.digit)
      )
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,
    validate_board = function(ctx)
      local state = count_state(ctx, nil, nil)
      return {
        violations = partial_violations(model, state),
        -- The Host renders this generic, current-board observation with its
        -- fixed style. The package owns only the positive Friendly predicate.
        observation = { active_cells = state.friendly_cells },
        diagnostics = {}
      }
    end,
    validate_final_state = function(ctx)
      local violations = final_violations(model, count_state(ctx, nil, nil))
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,
    build_overlay = function(ctx)
      return {
        primitives = {
          {
            type = "builtin",
            kind = "board_level_numeric_clue",
            data = { value = model.target }
          }
        },
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("friendly_sudoku", friendly_sudoku)
return plugin:build()
