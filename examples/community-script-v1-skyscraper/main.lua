-- Community Variant Script API V1 Skyscraper Sudoku reference package.
-- Community Variant Script API V1 摩天楼数独参考包。
--
-- This file owns the package-invariant rule: digits are building heights and a
-- clue equals the number of new maximum heights seen from its boundary side.
-- Puzzle JSON supplies only clue geometry and counts. The Host supplies a
-- read-only board snapshot, verifies callback results, and remains responsible
-- for input, notes, completion flow, persistence, and native rendering.
-- 本文件定义每题不变的规则：数字代表楼高，盘外提示等于从对应方向看到的“新最高楼”
-- 数量。题目 JSON 只提供提示位置和数字；Host 提供只读棋盘快照、校验回调结果，并继续
-- 负责输入、笔记、完成流程、存档和原生渲染。
local plugin = community_variant.script()
local skyscraper = {}
local board = community_variant.board

local MAX_CLUES = 36
local VIOLATION_CODE = "skyscraper_no_completion"
local INCOMPLETE_CODE = "skyscraper_incomplete"
local ALL_DIGITS_MASK = 511

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

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
  if type(value) ~= "number" or value % 1 ~= 0 or
      value < minimum or value > maximum then
    error(label .. " must be an integer in " .. minimum .. ".." .. maximum)
  end
  return value
end

local function cells_for(side, index)
  -- Normalize every boundary clue into nine 0-based cells ordered from the
  -- clue toward the board: left/right select a row, top/bottom a column.
  -- 将四侧提示统一成“从提示向棋盘内”排列的九个 0-based 格号：左右对应行，上下对应列。
  local cells = {}
  for offset = 0, 8 do
    if side == "left" or side == "right" then
      local column = side == "left" and offset or 8 - offset
      cells[#cells + 1] = index * 9 + column
    else
      local row = side == "top" and offset or 8 - offset
      cells[#cells + 1] = row * 9 + index
    end
  end
  return cells
end

local function axis_for(side)
  if side == "left" or side == "right" then return "row" end
  return "column"
end

local function normalize_clues(config)
  -- Public puzzle data is deliberately narrow:
  -- { clues = { { side = left|right|top|bottom, index = 0..8,
  --               count = 1..9 }, ... } }
  -- The same side/index pair is unique. Opposite sides of one line are valid
  -- because they describe two independently oriented observations.
  -- 公开题目数据只允许上述提示字段；同一 side/index 不可重复，但同一行列可同时从两端提示。
  expect_exact_keys(config, { clues = true }, "skyscraper data")
  expect_array(config.clues, 1, MAX_CLUES, "skyscraper data.clues")

  local clues = {}
  local clues_by_cell = {}
  local used_sides = {}
  for clue_index, raw in ipairs(config.clues) do
    local label = "skyscraper clue " .. clue_index
    expect_exact_keys(raw, { side = true, index = true, count = true }, label)
    if raw.side ~= "left" and raw.side ~= "right" and
        raw.side ~= "top" and raw.side ~= "bottom" then
      error(label .. ".side must be left, right, top or bottom")
    end
    local index = expect_integer(raw.index, 0, 8, label .. ".index")
    local count = expect_integer(raw.count, 1, 9, label .. ".count")
    local side_key = raw.side .. ":" .. index
    if used_sides[side_key] then
      error("skyscraper clues must not repeat a side and index")
    end
    used_sides[side_key] = true

    local clue = {
      side = raw.side,
      axis = axis_for(raw.side),
      index = index,
      count = count,
      cells = cells_for(raw.side, index)
    }
    clues[#clues + 1] = clue
    for _, cell in ipairs(clue.cells) do
      clues_by_cell[cell] = clues_by_cell[cell] or {}
      clues_by_cell[cell][#clues_by_cell[cell] + 1] = clue
    end
  end
  return { clues = clues, clues_by_cell = clues_by_cell, known_feasibility = {} }
end

-- DP state is `used digit mask -> reachable visibility-count bitset`.
-- DP 状态为“已使用数字掩码 -> 可达可见楼数量位集”。
--
-- A 9-bit mask records which heights have appeared. Its highest set bit is the
-- current maximum, so no extra maximum dimension is needed. Precomputing that
-- value avoids scanning digits in every transition while preserving exactness.
-- 9 位掩码记录已出现的楼高，最高置位就是当前最高楼，因此状态不需要额外的最大值维度；
-- 预计算可避免每次转移重复扫描数字，同时保持精确判定。
local MAX_DIGIT_BY_MASK = {}
for mask = 0, ALL_DIGITS_MASK do
  local maximum = 0
  for digit = 9, 1, -1 do
    if (mask & (1 << (digit - 1))) ~= 0 then
      maximum = digit
      break
    end
  end
  MAX_DIGIT_BY_MASK[mask] = maximum
end

local MAX_CACHE_ENTRIES = 256
local FEASIBILITY_CACHE = {}
local feasibility_cache_size = 0

local function line_feasible(cells, ctx, target, override_cell, override_digit)
  -- `override_cell/override_digit` evaluates a proposed move
  -- without mutating the Host board. Fixed cells admit only their value; empty
  -- cells admit every unused digit. Whenever a newly appended digit exceeds
  -- the mask's previous maximum, all reachable visibility counts increase by 1.
  -- `override_cell/override_digit` 用于在不修改 Host 棋盘的情况下试填一步；
  -- 已填格只接受原值，空格可取任一未使用数字。新数字高于此前最高楼时，可达计数整体加一。
  --
  -- A completely empty line has an exact closed-form base case: for every
  -- target 1..9, some permutation of 1..9 realizes that visibility count.
  -- Skipping repeated empty-line DP is important when all 36 clues are active.
  -- 全空行具有精确基例：1..9 的每个目标值都存在对应排列；直接返回可避免 36 条提示时
  -- 对相同空行反复执行 DP。
  local fixed_count = 0
  local values = {}
  local pattern = {}
  for _, cell in ipairs(cells) do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    values[#values + 1] = digit
    pattern[#pattern + 1] = board.is_empty(digit) and "." or tostring(digit)
    if not board.is_empty(digit) then
      fixed_count = fixed_count + 1
      if type(digit) ~= "number" or digit % 1 ~= 0 or
          digit < 1 or digit > 9 then
        return false, fixed_count
      end
    end
  end
  if fixed_count == 0 then return target >= 1 and target <= 9, 0 end

  -- Feasibility is target-specific. Keeping only visibility counts that can
  -- still reach this clue's target prevents a partially filled line from
  -- materializing every possible visibility outcome in a board callback.
  -- 可满足性与提示目标相关。只保留仍可能达到目标的可见数量，避免部分填盘时
  -- 在 board callback 内物化全部可见数量状态。
  local cache_key = tostring(target) .. ":" .. table.concat(pattern)
  local reachable_bits = FEASIBILITY_CACHE[cache_key]
  if reachable_bits == nil then
    local states = { [0] = 1 }
    local active_masks = { 0 }
    for _, digit in ipairs(values) do
      local next_states = {}
      local next_masks = {}
      local first_digit = board.is_empty(digit) and 1 or digit
      local last_digit = board.is_empty(digit) and 9 or digit
      local remaining_positions = 9 - _
      local minimum_visible = target - remaining_positions
      if minimum_visible < 0 then minimum_visible = 0 end
      local allowed_bits = 0
      for visible = minimum_visible, target do
        allowed_bits = allowed_bits | (1 << visible)
      end
      for _, mask in ipairs(active_masks) do
        local visibility_bits = states[mask]
        for candidate = first_digit, last_digit do
          local candidate_bit = 1 << (candidate - 1)
          if (mask & candidate_bit) == 0 then
            local next_mask = mask | candidate_bit
            local next_bits = visibility_bits
            if candidate > MAX_DIGIT_BY_MASK[mask] then
              next_bits = next_bits << 1
            end
            next_bits = next_bits & allowed_bits
            if next_bits ~= 0 then
              if next_states[next_mask] == nil then
                next_masks[#next_masks + 1] = next_mask
                next_states[next_mask] = next_bits
              else
                next_states[next_mask] = next_states[next_mask] | next_bits
              end
            end
          end
        end
      end
      states = next_states
      active_masks = next_masks
      if #active_masks == 0 then
        FEASIBILITY_CACHE[cache_key] = 0
        return false, fixed_count
      end
    end
    reachable_bits = states[ALL_DIGITS_MASK] or 0
    -- The cache is intentionally bounded. Script V1 runtimes are long-lived,
    -- so repeated board checks must not retain every board pattern ever observed.
    -- 缓存固定上限，避免长生命周期 Script V1 在盘面检查中永久保留所有历史盘面模式。
    if feasibility_cache_size >= MAX_CACHE_ENTRIES then
      FEASIBILITY_CACHE = {}
      feasibility_cache_size = 0
    end
    FEASIBILITY_CACHE[cache_key] = reachable_bits
    feasibility_cache_size = feasibility_cache_size + 1
  end

  local target_bit = 1 << target
  return reachable_bits & target_bit ~= 0, fixed_count
end

local function feasibility_key(cells, ctx, target)
  local pattern = {}
  for _, cell in ipairs(cells) do
    local digit = board.value(ctx, cell)
    pattern[#pattern + 1] = board.is_empty(digit) and "." or tostring(digit)
  end
  return tostring(target) .. ":" .. table.concat(pattern)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  local clues = override_cell == nil
      and model.clues
      or (model.clues_by_cell[override_cell] or {})
  for _, clue in ipairs(clues) do
    local feasible, fixed_count = line_feasible(
        clue.cells, ctx, clue.count, override_cell, override_digit)
    if override_cell ~= nil then
      model.known_feasibility[feasibility_key(clue.cells, ctx, clue.count)] = feasible
    end
    if not feasible then
      violations[#violations + 1] = {
        code = VIOLATION_CODE,
        cells = clue.cells
      }
    end
  end
  return violations
end

local function known_board_violations(model, ctx)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    local known = model.known_feasibility[feasibility_key(clue.cells, ctx, clue.count)]
    if known == false then
      violations[#violations + 1] = { code = VIOLATION_CODE, cells = clue.cells }
    end
  end
  return violations
end

local function final_violations(model, ctx)
  local violations = {}
  for _, clue in ipairs(model.clues) do
    local feasible, fixed_count = line_feasible(clue.cells, ctx, clue.count)
    if not feasible then
      violations[#violations + 1] = { code = VIOLATION_CODE, cells = clue.cells }
    elseif fixed_count < 9 then
      violations[#violations + 1] = {
        code = INCOMPLETE_CODE,
        cells = clue.cells
      }
    end
  end
  return violations
end

function skyscraper.create(config, scope)
  -- Normalize and validate author data once when the Host creates the rule.
  -- Every gameplay handler below reuses the same exact feasibility predicate,
  -- preventing move, board and final-state semantics from drifting.
  -- Host 创建规则时只归一化一次作者数据；下列所有 handler 共用同一个精确可满足性判定，
  -- 避免落子、盘面与终局语义发生偏差。
  local model = normalize_clues(config)
  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_board = function(ctx)
      -- Full-board projection must stay within the callback sandbox on sparse
      -- public puzzles. Exact feasibility is evaluated before every player
      -- move and retained by line signature; startup/recovery only projects
      -- already-known invalid lines. Final-state validation remains exact.
      return { violations = known_board_violations(model, ctx), diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = final_violations(model, ctx)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      -- Lua emits declarative Overlay IR only. `boundary_label` carries the
      -- normalized side/index/count; the Host validates it and paints the
      -- native four-sided label without changing board coordinates or layout.
      -- Lua 只输出声明式 Overlay IR；`boundary_label` 携带归一化后的方向、索引和提示数，
      -- Host 校验后使用原生四侧标签绘制，不改变棋盘坐标或布局。
      local primitives = {}
      for _, clue in ipairs(model.clues) do
        primitives[#primitives + 1] = {
          type = "builtin",
          kind = "boundary_label",
          data = {
            axis = clue.axis,
            side = clue.side,
            index = clue.index,
            label = tostring(clue.count)
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("skyscraper", skyscraper)

return plugin:build()
