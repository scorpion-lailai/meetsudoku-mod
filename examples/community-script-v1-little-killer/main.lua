-- Community Variant Script API V1 Little Killer reference package.
-- 小杀手数独参考包：固定对角线和值由 Lua 完整拥有，盘外提示使用通用
-- `outside_ray_clue` Overlay。Host 仍拥有经典数独、棋盘事务、候选/笔记、
-- 完成流程、存档和绘制。
local plugin = community_variant.script()
local little_killer = {}
local board = community_variant.board

local MAX_CLUES = 16
local MIN_DIGIT = 1
local MAX_DIGIT = 9
local SUM_CODE = "little_killer_sum"
local INCOMPLETE_CODE = "little_killer_incomplete"

local direction_delta = {
  down_right = { row = 1, column = 1 },
  down_left = { row = 1, column = -1 },
  up_right = { row = -1, column = 1 },
  up_left = { row = -1, column = -1 }
}

local inward_directions = {
  top = { down_left = true, down_right = true },
  right = { up_left = true, down_left = true },
  bottom = { up_left = true, up_right = true },
  left = { up_right = true, down_right = true }
}

local direction_family = {
  top = "down_left",
  right = "up_left",
  bottom = "up_right",
  left = "down_right"
}

local function expect_exact_keys(value, allowed, label)
  if type(value) ~= "table" then error(label .. " must be an object") end
  for key, _ in pairs(value) do
    if not allowed[key] then
      error(label .. " contains unsupported field " .. tostring(key))
    end
  end
end

local function expect_integer(value, minimum, maximum, label)
  if type(value) ~= "number" or value % 1 ~= 0
      or value < minimum or value > maximum then
    error(label .. " must be an integer in " .. minimum .. ".." .. maximum)
  end
  return value
end

local function ray_cells(entry, direction)
  expect_exact_keys(entry, { side = true, index = true }, "little_killer.entry")
  if inward_directions[entry.side] == nil then
    error("little_killer.entry.side is unsupported")
  end
  local index = expect_integer(entry.index, 0, 8, "little_killer.entry.index")
  local delta = direction_delta[direction]
  if delta == nil or not inward_directions[entry.side][direction] then
    error("little_killer.direction must point inward")
  end

  local row = entry.side == "top" and 0
      or entry.side == "bottom" and 8 or index
  local column = entry.side == "left" and 0
      or entry.side == "right" and 8 or index
  local cells = {}
  while row >= 0 and row <= 8 and column >= 0 and column <= 8 do
    cells[#cells + 1] = row * 9 + column
    row = row + delta.row
    column = column + delta.column
  end
  return cells
end

local function canonical_ray_key(cells)
  local parts = {}
  for index, cell in ipairs(cells) do
    parts[index] = tostring(cell)
  end
  return table.concat(parts, ",")
end

local function normalize_clues(config)
  expect_exact_keys(config, { clues = true }, "little_killer data")
  if type(config.clues) ~= "table" or #config.clues < 1
      or #config.clues > MAX_CLUES then
    error("little_killer.clues must contain 1..16 items")
  end

  local clues = {}
  local clues_by_cell = {}
  local entry_keys = {}
  local ray_keys = {}
  for clue_index, raw in ipairs(config.clues) do
    local label = "little_killer clue " .. clue_index
    expect_exact_keys(raw, { entry = true, direction = true, value = true }, label)
    if type(raw.entry) ~= "table" then error(label .. ".entry is required") end
    expect_exact_keys(raw.entry, { side = true, index = true }, label .. ".entry")
    if direction_family[raw.entry.side] ~= raw.direction then
      error("little_killer clues must use the edge_fixed_v1 direction family")
    end
    local cells = ray_cells(raw.entry, raw.direction)
    local value = expect_integer(raw.value, 1, 81, label .. ".value")
    if value < #cells or value > #cells * 9 then
      error(label .. ".value is impossible for this ray length")
    end

    local entry_key = raw.entry.side .. ":" .. raw.entry.index
    local ray_key = canonical_ray_key(cells)
    if entry_keys[entry_key] then error("duplicate little_killer entry") end
    if ray_keys[ray_key] then error("duplicate little_killer ray") end
    entry_keys[entry_key] = true
    ray_keys[ray_key] = true

    local clue = {
      index = clue_index,
      entry = { side = raw.entry.side, index = raw.entry.index },
      direction = raw.direction,
      value = value,
      cells = cells
    }
    clues[#clues + 1] = clue
    for _, cell in ipairs(cells) do
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

-- This is deliberately a rule-level bound. It never replaces Host candidates:
-- with `n` empty cells, any integer sum in n..9n is arithmetically possible.
local function sum_possible(empty_count, remaining)
  if remaining < 0 then return false end
  if empty_count == 0 then return remaining == 0 end
  return remaining >= empty_count and remaining <= empty_count * 9
end

local function inspect_clue(clue, ctx, override_cell, override_digit)
  local total = 0
  local empty_count = 0
  for _, cell in ipairs(clue.cells) do
    local digit = value_for(ctx, cell, override_cell, override_digit)
    if board.is_empty(digit) then
      empty_count = empty_count + 1
    elseif type(digit) ~= "number" or digit % 1 ~= 0
        or digit < MIN_DIGIT or digit > MAX_DIGIT then
      return false, empty_count, total
    else
      total = total + digit
    end
  end
  return sum_possible(empty_count, clue.value - total), empty_count, total
end

local function violation(clue)
  return {
    code = SUM_CODE,
    cells = clue.cells,
    data = { clue = clue.index }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  local related = override_cell == nil and model.clues
      or model.clues_by_cell[override_cell] or {}
  for _, clue in ipairs(related) do
    local possible = inspect_clue(clue, ctx, override_cell, override_digit)
    if not possible then violations[#violations + 1] = violation(clue) end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local related = model.clues_by_cell[cell] or {}
  for _, clue in ipairs(related) do
    local possible = inspect_clue(clue, ctx, cell, digit)
    if not possible then return false end
  end
  return true
end

function little_killer.create(config, scope)
  -- `config` is puzzle-varying geometry/value. The fixed meaning above stays
  -- package-owned in this file; Host never receives this private model.
  local model = normalize_clues(config)
  local scope_cells = {}
  for cell, _ in pairs(model.clues_by_cell) do scope_cells[#scope_cells + 1] = cell end
  table.sort(scope_cells)

  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = find_violations(model, ctx, nil, nil), diagnostics = {} }
    end,

    candidate_scope = function()
      return scope_cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}
      for digit = MIN_DIGIT, MAX_DIGIT do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = SUM_CODE
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = {}
      for _, clue in ipairs(model.clues) do
        local possible, empty_count = inspect_clue(clue, ctx, nil, nil)
        if not possible or empty_count > 0 then
          if empty_count > 0 then
            violations[#violations + 1] = {
              code = INCOMPLETE_CODE,
              cells = clue.cells,
              data = { clue = clue.index }
            }
          else
            violations[#violations + 1] = violation(clue)
          end
        end
      end
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for index, clue in ipairs(model.clues) do
        primitives[index] = {
          type = "builtin",
          kind = "outside_ray_clue",
          data = {
            entry = clue.entry,
            direction = clue.direction,
            value = clue.value
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("little_killer", little_killer)
return plugin:build()
