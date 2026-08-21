-- Community Variant Script API V1 Sandwich Sudoku reference package.
-- Community Variant Script API V1 三明治数独参考包。
--
-- Every boundary clue equals the sum of the digits strictly between 1 and 9 in
-- its row or column. Puzzle JSON owns only clue axis, index and sum. The
-- fixed boundary digits, exact partial-feasibility semantics and result codes
-- live here. The Host owns classic rules, board mutation, candidates, notes,
-- completion, persistence and rendering.
-- 每个边界提示等于对应行列中严格位于数字 1 与 9 之间的数字之和。题目 JSON 只
-- 保存提示的轴、序号与和值；固定边界数字、精确部分可满足性和结果代码由
-- 本文件定义。经典规则、棋盘变更、候选、笔记、完成、存档和渲染归 Host。
local plugin = community_variant.script()
local sandwich = {}
local board = community_variant.board

local MAX_CLUES = 18
local ALL_MIDDLE_DIGITS_MASK = 127
local VIOLATION_CODE = "sandwich_no_completion"
local INCOMPLETE_CODE = "sandwich_incomplete"

local function expect_exact_keys(value, allowed, label)
  if type(value) ~= "table" then error(label .. " must be an object") end
  for key, _ in pairs(value) do
    if not allowed[key] then
      error(label .. " contains unsupported field " .. tostring(key))
    end
  end
end

local function expect_array(value, minimum, maximum, label)
  if type(value) ~= "table" or #value < minimum or #value > maximum then
    error(label .. " must contain " .. minimum .. ".." .. maximum .. " items")
  end
  for key, _ in pairs(value) do
    if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #value then
      error(label .. " must be a dense array")
    end
  end
end

local function expect_integer(value, minimum, maximum, label)
  if type(value) ~= "number" or value % 1 ~= 0 or value < minimum or value > maximum then
    error(label .. " must be an integer in " .. minimum .. ".." .. maximum)
  end
  return value
end

-- For each subset of digits 2..8, store the reachable sums for every exact
-- cardinality as bits in one Lua integer. The recurrence adds one digit to a
-- previously computed mask, so startup work is bounded by 128 * 8 operations.
local SUBSET_SUM_BITS = { [0] = { [0] = 1 } }
for mask = 1, ALL_MIDDLE_DIGITS_MASK do
  local bit_index = 0
  while (mask & (1 << bit_index)) == 0 do bit_index = bit_index + 1 end
  local digit = bit_index + 2
  local previous = mask & (~(1 << bit_index))
  local previous_bits = SUBSET_SUM_BITS[previous]
  local current_bits = {}
  for count = 0, 7 do
    local without_digit = previous_bits[count] or 0
    local with_digit = 0
    if count > 0 then
      with_digit = (previous_bits[count - 1] or 0) << digit
    end
    current_bits[count] = without_digit | with_digit
  end
  SUBSET_SUM_BITS[mask] = current_bits
end

local function subset_exists(available_mask, count, sum)
  if count < 0 or count > 7 or sum < 0 or sum > 35 then return false end
  local sums = SUBSET_SUM_BITS[available_mask][count] or 0
  return (sums & (1 << sum)) ~= 0
end

local function cells_for(axis, index)
  local cells = {}
  for offset = 0, 8 do
    if axis == "row" then
      cells[#cells + 1] = index * 9 + offset
    else
      cells[#cells + 1] = offset * 9 + index
    end
  end
  return cells
end

local function normalize_clues(config)
  expect_exact_keys(config, { clues = true }, "sandwich data")
  expect_array(config.clues, 1, MAX_CLUES, "sandwich data.clues")

  local clues = {}
  local clues_by_cell = {}
  local used_lines = {}
  for clue_index, raw in ipairs(config.clues) do
    local label = "sandwich clue " .. clue_index
    expect_exact_keys(raw, {
      axis = true,
      index = true,
      sum = true
    }, label)
    if raw.axis ~= "row" and raw.axis ~= "column" then
      error(label .. ".axis must be row or column")
    end
    local index = expect_integer(raw.index, 0, 8, label .. ".index")
    local sum = expect_integer(raw.sum, 0, 35, label .. ".sum")
    local line_key = raw.axis .. ":" .. index
    if used_lines[line_key] then
      error("sandwich clues must not repeat a row or column")
    end
    used_lines[line_key] = true

    local clue = {
      axis = raw.axis,
      index = index,
      sum = sum,
      cells = cells_for(raw.axis, index)
    }
    clues[#clues + 1] = clue
    for _, cell in ipairs(clue.cells) do
      clues_by_cell[cell] = clues_by_cell[cell] or {}
      clues_by_cell[cell][#clues_by_cell[cell] + 1] = clue
    end
  end
  return { clues = clues, clues_by_cell = clues_by_cell }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function inspect_clue(clue, ctx, override_cell, override_digit)
  local values = {}
  local seen = {}
  local assigned_cells = {}
  local empty_count = 0
  local one_position = nil
  local nine_position = nil
  local used_middle_mask = 0

  for position, cell in ipairs(clue.cells) do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    values[position] = digit
    if board.is_empty(digit) then
      empty_count = empty_count + 1
    else
      assigned_cells[#assigned_cells + 1] = cell
      if type(digit) ~= "number" or digit % 1 ~= 0 or digit < 1 or digit > 9 or seen[digit] then
        return { valid = false, cells = assigned_cells, empty_count = empty_count }
      end
      seen[digit] = true
      if digit == 1 then
        one_position = position
      elseif digit == 9 then
        nine_position = position
      else
        used_middle_mask = used_middle_mask | (1 << (digit - 2))
      end
    end
  end

  local available_mask = ALL_MIDDLE_DIGITS_MASK & (~used_middle_mask)
  local one_start = one_position or 1
  local one_end = one_position or 9
  local nine_start = nine_position or 1
  local nine_end = nine_position or 9

  for candidate_one = one_start, one_end do
    if board.is_empty(values[candidate_one]) or values[candidate_one] == 1 then
      for candidate_nine = nine_start, nine_end do
        if candidate_nine ~= candidate_one and
            (board.is_empty(values[candidate_nine]) or values[candidate_nine] == 9) then
          local lower = math.min(candidate_one, candidate_nine)
          local upper = math.max(candidate_one, candidate_nine)
          local fixed_sum = 0
          local missing_count = 0
          for position = lower + 1, upper - 1 do
            local digit = values[position]
            if board.is_empty(digit) then
              missing_count = missing_count + 1
            else
              fixed_sum = fixed_sum + digit
            end
          end
          if subset_exists(
              available_mask,
              missing_count,
              clue.sum - fixed_sum
          ) then
            return { valid = true, empty_count = empty_count }
          end
        end
      end
    end
  end

  return { valid = false, cells = assigned_cells, empty_count = empty_count }
end

local function violation(clue, inspection, code)
  return { code = code, cells = inspection.cells or clue.cells }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    local inspection = inspect_clue(clue, ctx, override_cell, override_digit)
    if not inspection.valid then
      violations[#violations + 1] = violation(clue, inspection, VIOLATION_CODE)
    end
  end
  return violations
end

local function prepare_candidate_state(clue, ctx, cell)
  local values = {}
  local seen = {}
  local target_position = nil
  local one_position = nil
  local nine_position = nil
  local used_middle_mask = 0

  for position, clue_cell in ipairs(clue.cells) do
    local digit = board.value(ctx, clue_cell)
    values[position] = digit
    if clue_cell == cell then target_position = position end
    if not board.is_empty(digit) then
      if type(digit) ~= "number" or digit % 1 ~= 0 or
          digit < 1 or digit > 9 or seen[digit] then
        return { valid = false }
      end
      seen[digit] = true
      if digit == 1 then
        one_position = position
      elseif digit == 9 then
        nine_position = position
      else
        used_middle_mask = used_middle_mask | (1 << (digit - 2))
      end
    end
  end

  if target_position == nil or not board.is_empty(values[target_position]) then
    return { valid = false }
  end

  local pairs = {}
  local one_start = one_position or 1
  local one_end = one_position or 9
  local nine_start = nine_position or 1
  local nine_end = nine_position or 9
  for candidate_one = one_start, one_end do
    if board.is_empty(values[candidate_one]) or values[candidate_one] == 1 then
      for candidate_nine = nine_start, nine_end do
        if candidate_nine ~= candidate_one and
            (board.is_empty(values[candidate_nine]) or
                values[candidate_nine] == 9) then
          local lower = math.min(candidate_one, candidate_nine)
          local upper = math.max(candidate_one, candidate_nine)
          local fixed_sum = 0
          local missing_count = 0
          for position = lower + 1, upper - 1 do
            local digit = values[position]
            if board.is_empty(digit) then
              missing_count = missing_count + 1
            else
              fixed_sum = fixed_sum + digit
            end
          end
          pairs[#pairs + 1] = {
            one = candidate_one,
            nine = candidate_nine,
            fixed_sum = fixed_sum,
            missing_count = missing_count,
            target_inside = target_position > lower and target_position < upper
          }
        end
      end
    end
  end

  return {
    valid = true,
    target_position = target_position,
    used_middle_mask = used_middle_mask,
    pairs = pairs
  }
end

local function candidate_state_allows(state, target_sum, digit)
  if not state.valid then return false end
  local target_position = state.target_position
  local middle_bit = nil
  if digit >= 2 and digit <= 8 then
    middle_bit = 1 << (digit - 2)
    if (state.used_middle_mask & middle_bit) ~= 0 then return false end
  end

  for _, pair in ipairs(state.pairs) do
    if digit == 1 then
      if target_position == pair.one then
        local available_mask =
            ALL_MIDDLE_DIGITS_MASK & (~state.used_middle_mask)
        if subset_exists(
            available_mask,
            pair.missing_count,
            target_sum - pair.fixed_sum
        ) then return true end
      end
    elseif digit == 9 then
      if target_position == pair.nine then
        local available_mask =
            ALL_MIDDLE_DIGITS_MASK & (~state.used_middle_mask)
        if subset_exists(
            available_mask,
            pair.missing_count,
            target_sum - pair.fixed_sum
        ) then return true end
      end
    elseif target_position ~= pair.one and target_position ~= pair.nine then
      local available_mask =
          ALL_MIDDLE_DIGITS_MASK & (~state.used_middle_mask) & (~middle_bit)
      local missing_count = pair.missing_count
      local fixed_sum = pair.fixed_sum
      if pair.target_inside then
        missing_count = missing_count - 1
        fixed_sum = fixed_sum + digit
      end
      if subset_exists(
          available_mask,
          missing_count,
          target_sum - fixed_sum
      ) then return true end
    end
  end
  return false
end

local function candidate_eliminations(model, ctx, cell)
  local clues = model.clues_by_cell[cell]
  if clues == nil then return {}, {} end

  local states = {}
  for clue_index, clue in ipairs(clues) do
    states[clue_index] = {
      clue = clue,
      state = prepare_candidate_state(clue, ctx, cell)
    }
  end

  local remove = {}
  local reasons = {}
  for digit = 1, 9 do
    local allowed = true
    for _, entry in ipairs(states) do
      if not candidate_state_allows(entry.state, entry.clue.sum, digit) then
        allowed = false
        break
      end
    end
    if not allowed then
      remove[#remove + 1] = digit
      reasons[tostring(digit)] = VIOLATION_CODE
    end
  end
  return remove, reasons
end

local function final_violations(model, ctx)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    local inspection = inspect_clue(clue, ctx, nil, nil)
    if not inspection.valid then
      violations[#violations + 1] = violation(clue, inspection, VIOLATION_CODE)
    elseif inspection.empty_count > 0 then
      violations[#violations + 1] = violation(clue, inspection, INCOMPLETE_CODE)
    end
  end
  return violations
end

function sandwich.create(config, scope)
  local model = normalize_clues(config)
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
      local cells = {}
      for cell = 0, 80 do
        if model.clues_by_cell[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove, reasons = candidate_eliminations(model, ctx, cell)
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = final_violations(model, ctx)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, clue in ipairs(model.clues) do
        primitives[#primitives + 1] = {
          type = "builtin",
          kind = "boundary_label",
          data = {
            axis = clue.axis,
            index = clue.index,
            label = tostring(clue.sum)
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("sandwich", sandwich)

return plugin:build()
