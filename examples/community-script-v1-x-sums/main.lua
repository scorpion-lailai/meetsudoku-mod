-- Community Variant Script API V1 X-Sums Sudoku reference package.
-- Community Variant Script API V1 X 和值数独参考包。
--
-- Each outside clue gives the sum of the first X cells seen from that side,
-- where X is the digit in the first cell. Puzzle JSON owns only side, index
-- and sum. This file owns the fixed X-Sums semantics and keeps move, board,
-- candidate and final-state checks on one feasibility core. The Host owns
-- board mutation, classic Sudoku rules, candidates, notes, completion,
-- persistence and rendering.
-- 每个盘外提示表示从该侧开始前 X 格之和，X 是最靠近提示的第一格数字。题目
-- JSON 只保存 side、index 和 sum；固定规则语义、部分可满足性与候选删除投影由
-- 本文件定义。棋盘变更、经典数独规则、候选、笔记、完成、存档和渲染归 Host。
local plugin = community_variant.script()
local x_sums = {}
local board = community_variant.board

local MAX_CLUES = 36
local VIOLATION_CODE = "x_sums_no_completion"
local INCOMPLETE_CODE = "x_sums_incomplete"

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

local function line_for(side, index)
  local cells = {}
  if side == "left" then
    for column = 0, 8 do cells[#cells + 1] = index * 9 + column end
  elseif side == "right" then
    for column = 8, 0, -1 do cells[#cells + 1] = index * 9 + column end
  elseif side == "top" then
    for row = 0, 8 do cells[#cells + 1] = row * 9 + index end
  elseif side == "bottom" then
    for row = 8, 0, -1 do cells[#cells + 1] = row * 9 + index end
  end
  return cells
end

local function overlay_axis(side)
  if side == "left" or side == "right" then return "row" end
  return "column"
end

local function normalize_clues(config)
  expect_exact_keys(config, { clues = true }, "x_sums data")
  expect_array(config.clues, 1, MAX_CLUES, "x_sums data.clues")

  local clues = {}
  local clues_by_cell = {}
  local used = {}
  for clue_index, raw in ipairs(config.clues) do
    local label = "x_sums clue " .. clue_index
    expect_exact_keys(raw, {
      side = true,
      index = true,
      sum = true
    }, label)
    if raw.side ~= "left" and raw.side ~= "right" and raw.side ~= "top" and raw.side ~= "bottom" then
      error(label .. ".side must be left, right, top or bottom")
    end
    local index = expect_integer(raw.index, 0, 8, label .. ".index")
    local sum = expect_integer(raw.sum, 1, 45, label .. ".sum")
    local key = raw.side .. ":" .. index
    if used[key] then error("x_sums clues must not repeat a side/index pair") end
    used[key] = true

    local clue = {
      side = raw.side,
      axis = overlay_axis(raw.side),
      index = index,
      sum = sum,
      cells = line_for(raw.side, index)
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

local function sum_possible(empty_count, remaining)
  -- Conservative but safe for candidate projection: Host owns classic Sudoku
  -- legality, so this rule only checks whether the X-Sums arithmetic can still
  -- be satisfied using Sudoku digits. Over-approximating keeps candidate
  -- eliminations safe; final-state still requires exact assigned sums.
  if remaining < 0 then return false end
  if empty_count == 0 then return remaining == 0 end
  return remaining >= empty_count and remaining <= empty_count * 9
end

local function prefix_possible(clue, ctx, first_digit, override_cell, override_digit)
  local fixed_sum = 0
  local empty_count = 0
  for position = 1, first_digit do
    local cell = clue.cells[position]
    local digit
    if position == 1 then
      digit = first_digit
    else
      digit = value_for(ctx, cell, override_cell, override_digit)
    end
    if board.is_empty(digit) then
      empty_count = empty_count + 1
    else
      fixed_sum = fixed_sum + digit
    end
  end
  if fixed_sum > clue.sum then return false end
  return sum_possible(empty_count, clue.sum - fixed_sum)
end

local function clue_possible(clue, ctx, override_cell, override_digit)
  local first_cell = clue.cells[1]
  local first_value = value_for(ctx, first_cell, override_cell, override_digit)
  if not board.is_empty(first_value) then
    if type(first_value) ~= "number" or first_value % 1 ~= 0 or first_value < 1 or first_value > 9 then
      return false
    end
    return prefix_possible(clue, ctx, first_value, override_cell, override_digit)
  end

  for first_digit = 1, 9 do
    if prefix_possible(clue, ctx, first_digit, override_cell, override_digit) then
      return true
    end
  end
  return false
end

local function clue_satisfied(clue, ctx)
  local first_digit = board.value(ctx, clue.cells[1])
  if board.is_empty(first_digit) or type(first_digit) ~= "number" or first_digit % 1 ~= 0 or first_digit < 1 or first_digit > 9 then
    return false
  end
  local total = 0
  for position = 1, first_digit do
    local digit = board.value(ctx, clue.cells[position])
    if board.is_empty(digit) or type(digit) ~= "number" or digit % 1 ~= 0 or digit < 1 or digit > 9 then
      return false
    end
    total = total + digit
  end
  return total == clue.sum
end

local function violation(clue, code)
  return { code = code, cells = clue.cells }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    if not clue_possible(clue, ctx, override_cell, override_digit) then
      violations[#violations + 1] = violation(clue, VIOLATION_CODE)
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local clues = model.clues_by_cell[cell]
  if clues == nil then return true end
  for _, clue in ipairs(clues) do
    if not clue_possible(clue, ctx, cell, digit) then return false end
  end
  return true
end

local function final_violations(model, ctx)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    if not clue_satisfied(clue, ctx) then
      violations[#violations + 1] = violation(clue, INCOMPLETE_CODE)
    end
  end
  return violations
end

function x_sums.create(config, scope)
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
        if model.clues_by_cell[cell] ~= nil then cells[#cells + 1] = cell end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = VIOLATION_CODE
        end
      end
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
            side = clue.side,
            index = clue.index,
            label = tostring(clue.sum)
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("x_sums", x_sums)

return plugin:build()
