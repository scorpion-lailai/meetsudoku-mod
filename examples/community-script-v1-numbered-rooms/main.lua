-- Numbered Rooms, Community Variant Script API V1 materialized reference.
-- 数字房间：Community Variant Script API V1 启动期物化参考包。
--
-- A directed outside clue reads its full row or column from that edge. The
-- first cell contains N, so the clue digit must appear at position N. Puzzle
-- JSON owns only clue direction, line index and digit. This Lua validates the
-- clue data, derives the ordered line, and materializes generic constraints.
-- 一个有方向的盘外提示从该边缘读取完整行或列。第一格的数字为 N，因此提示
-- 数字必须出现在第 N 格。题目 JSON 只保存提示方向、线索索引和数字；本 Lua
-- 校验题面数据、派生有序线，并物化通用约束。
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local numbered_rooms = {}

local MAX_CLUES = 18

local function expect_range(value, minimum, maximum, label)
  local result = schema.expect_integer(value, label)
  if result < minimum or result > maximum then
    error(label .. " must be in " .. minimum .. ".." .. maximum)
  end
  return result
end

local function directed_line(side, index)
  local cells = {}
  if side == "left" then
    for column = 0, 8 do
      cells[#cells + 1] = cell_api.index(index, column)
    end
  elseif side == "right" then
    for column = 8, 0, -1 do
      cells[#cells + 1] = cell_api.index(index, column)
    end
  elseif side == "top" then
    for row = 0, 8 do
      cells[#cells + 1] = cell_api.index(row, index)
    end
  elseif side == "bottom" then
    for row = 8, 0, -1 do
      cells[#cells + 1] = cell_api.index(row, index)
    end
  else
    error("numbered_rooms clue side must be left, right, top or bottom")
  end
  return cells
end

local function overlay_axis(side)
  if side == "left" or side == "right" then
    return "row"
  end
  return "column"
end

local function normalize(config)
  schema.expect_exact_keys(config, { clues = true }, "numbered_rooms")
  schema.expect_array(config.clues, 1, MAX_CLUES, "numbered_rooms.clues")

  local clues = {}
  local seen = {}
  for position, raw in ipairs(config.clues) do
    local label = "numbered_rooms.clues[" .. position .. "]"
    schema.expect_exact_keys(raw, {
      side = true,
      index = true,
      digit = true
    }, label)
    if raw.side ~= "left" and raw.side ~= "right"
        and raw.side ~= "top" and raw.side ~= "bottom" then
      error(label .. ".side must be left, right, top or bottom")
    end
    local index = expect_range(raw.index, 0, 8, label .. ".index")
    local digit = expect_range(raw.digit, 1, 9, label .. ".digit")
    local key = raw.side .. ":" .. index
    if seen[key] then
      error("numbered_rooms clues must not repeat a side/index pair")
    end
    seen[key] = true
    clues[#clues + 1] = {
      side = raw.side,
      axis = overlay_axis(raw.side),
      index = index,
      digit = digit,
      cells = directed_line(raw.side, index)
    }
  end
  return { clues = clues }
end

local function build_constraints(model)
  local predicates = {}
  for _, clue in ipairs(model.clues) do
    local selected_value = constraint.element_at(
      clue.cells,
      constraint.value(clue.cells[1])
    )
    predicates[#predicates + 1] = constraint.equal(
      selected_value,
      constraint.constant(clue.digit)
    )
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, clue in ipairs(model.clues) do
    primitives[#primitives + 1] = {
      type = "builtin",
      kind = "boundary_label",
      data = {
        axis = clue.axis,
        side = clue.side,
        index = clue.index,
        label = tostring(clue.digit)
      }
    }
  end
  return { primitives = primitives }
end

-- define runs once at exact-session startup. The Host validates and compiles
-- the typed predicates into the Native Rule Graph. Gameplay does not call Lua;
-- the Host owns candidates, conflicts, note cleanup, completion, save and UI.
function numbered_rooms.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("numbered_rooms", numbered_rooms)
return plugin:build()
