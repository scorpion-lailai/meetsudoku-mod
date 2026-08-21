-- Community Variant Script API V1 Anti-XV reference implementation.
local plugin = community_variant.script()
local anti_xv = {}
local board = community_variant.board

local function expand_pairs()
  local pairs = {}
  local by_cell = {}
  for row = 0, 8 do
    for column = 0, 8 do
      local first = row * 9 + column
      for _, offset in ipairs({ { 0, 1 }, { 1, 0 } }) do
        local next_row = row + offset[1]
        local next_column = column + offset[2]
        if next_row <= 8 and next_column <= 8 then
          local second = next_row * 9 + next_column
          pairs[#pairs + 1] = { first, second }
          by_cell[first] = by_cell[first] or {}
          by_cell[second] = by_cell[second] or {}
          by_cell[first][#by_cell[first] + 1] = second
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

local function violates_anti_xv(first_digit, second_digit)
  local sum = first_digit + second_digit
  return sum == 5 or sum == 10
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, pair in ipairs(model.pairs) do
    local first_digit = pair_digit(ctx, pair[1], override_cell, override_digit)
    local second_digit = pair_digit(ctx, pair[2], override_cell, override_digit)
    if not board.is_empty(first_digit)
        and not board.is_empty(second_digit)
        and violates_anti_xv(first_digit, second_digit) then
      violations[#violations + 1] = {
        code = "anti_xv_adjacent_sum",
        cells = { pair[1], pair[2] }
      }
    end
  end
  return violations
end

local function mark_candidate_removal(remove_set, digit)
  if digit >= 1 and digit <= 9 then
    remove_set[digit] = true
  end
end

function anti_xv.create(config, scope)
  if type(config) ~= "table" or next(config) ~= nil then
    error("anti_xv requires empty rule data")
  end
  local pairs, by_cell = expand_pairs()
  local model = { pairs = pairs, by_cell = by_cell }

  return {
    validate_move = function(ctx, move)
      local violations = {}
      if not board.is_empty(move.digit) then
        violations = find_violations(model, ctx, move.cell, move.digit)
      end
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
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
      local remove_set = {}
      for _, neighbor in ipairs(model.by_cell[cell] or {}) do
        local digit = board.value(ctx, neighbor)
        if not board.is_empty(digit) then
          mark_candidate_removal(remove_set, 5 - digit)
          mark_candidate_removal(remove_set, 10 - digit)
        end
      end
      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        if remove_set[digit] then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "anti_xv_adjacent_sum"
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

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

plugin:register_rule("anti_xv", anti_xv)
return plugin:build()
