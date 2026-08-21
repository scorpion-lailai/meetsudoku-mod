-- Community Variant Script API V1 MinMax Sudoku materialized reference.
-- Community Variant Script API V1 极值数独启动期物化参考实现。
--
-- The package owns the complete fixed MinMax meaning. Puzzle JSON owns only
-- the varying minimum/maximum marks; Lua derives every orthogonal comparison
-- and the matching triangle Overlay from one normalized model. Gameplay does
-- not call Lua after the Host materializes the typed constraints.
-- 包级 Lua 拥有完整且固定的极值语义。题目 JSON 只保存每题变化的最小值/最大值
-- 标记；Lua 从同一份规范模型派生全部正交比较和三角 Overlay。Host 物化 typed
-- constraints 后，Gameplay 不再调用 Lua。
local plugin = community_variant.script()
local minmax = {}
local cell_api = community_variant.cell
local schema = community_variant.schema
local constraint = community_variant.constraint
local overlay_geometry = community_variant.overlay_geometry

local MAX_MARKS = 32
local MAX_COMPARISONS = 64
local INNER_RADIUS = 0.08
local OUTER_RADIUS = 0.30
local HALF_BASE = 0.09
local STROKE_WIDTH = 0.045

local directions = {
  { dx = 0, dy = -1 },
  { dx = -1, dy = 0 },
  { dx = 1, dy = 0 },
  { dx = 0, dy = 1 }
}

local function normalize_marks(raw_cells, kind, marks_by_cell)
  local label = "minmax." .. kind .. "_cells"
  schema.expect_array(raw_cells, 0, MAX_MARKS, label)
  local cells = {}
  local seen = {}
  for index, raw_cell in ipairs(raw_cells) do
    local cell = cell_api.expect(raw_cell, label .. "[" .. index .. "]")
    if seen[cell] then error(label .. " must not repeat a cell") end
    if marks_by_cell[cell] ~= nil then
      error("minmax minimum_cells and maximum_cells must not overlap")
    end
    seen[cell] = true
    marks_by_cell[cell] = kind
    cells[#cells + 1] = cell
  end
  table.sort(cells)
  return cells
end

local function orthogonal_neighbors(cell)
  local row = cell_api.row(cell)
  local column = cell_api.column(cell)
  local neighbors = {}
  if row > 0 then neighbors[#neighbors + 1] = cell_api.index(row - 1, column) end
  if column > 0 then neighbors[#neighbors + 1] = cell_api.index(row, column - 1) end
  if column < 8 then neighbors[#neighbors + 1] = cell_api.index(row, column + 1) end
  if row < 8 then neighbors[#neighbors + 1] = cell_api.index(row + 1, column) end
  return neighbors
end

local function normalize(config)
  schema.expect_exact_keys(
    config,
    { minimum_cells = true, maximum_cells = true },
    "minmax"
  )

  local marks_by_cell = {}
  local minimum_cells = normalize_marks(
    config.minimum_cells,
    "minimum",
    marks_by_cell
  )
  local maximum_cells = normalize_marks(
    config.maximum_cells,
    "maximum",
    marks_by_cell
  )
  if #minimum_cells + #maximum_cells == 0 then
    error("minmax requires at least one marked cell")
  end
  if #minimum_cells + #maximum_cells > MAX_MARKS then
    error("minmax supports at most " .. MAX_MARKS .. " marked cells")
  end

  local pairs = {}
  local pairs_by_key = {}
  local function add_pair(low, high)
    local key = tostring(low) .. ":" .. tostring(high)
    local reverse = tostring(high) .. ":" .. tostring(low)
    if pairs_by_key[reverse] then
      error("minmax marks create opposing comparisons")
    end
    if pairs_by_key[key] then return end
    local pair = { low = low, high = high }
    pairs_by_key[key] = pair
    pairs[#pairs + 1] = pair
  end

  for _, cell in ipairs(minimum_cells) do
    for _, neighbor in ipairs(orthogonal_neighbors(cell)) do
      add_pair(cell, neighbor)
    end
  end
  for _, cell in ipairs(maximum_cells) do
    for _, neighbor in ipairs(orthogonal_neighbors(cell)) do
      add_pair(neighbor, cell)
    end
  end
  table.sort(pairs, function(first, second)
    if first.low ~= second.low then return first.low < second.low end
    return first.high < second.high
  end)
  if #pairs > MAX_COMPARISONS then
    error("minmax produces more than " .. MAX_COMPARISONS .. " comparisons")
  end

  return {
    minimum_cells = minimum_cells,
    maximum_cells = maximum_cells,
    marks_by_cell = marks_by_cell,
    pairs = pairs
  }
end

local function append_triangle(commands, center, direction, kind)
  local tip_radius = kind == "minimum" and INNER_RADIUS or OUTER_RADIUS
  local base_radius = kind == "minimum" and OUTER_RADIUS or INNER_RADIUS
  local perpendicular_x = -direction.dy
  local perpendicular_y = direction.dx
  local tip_x = center.x + direction.dx * tip_radius
  local tip_y = center.y + direction.dy * tip_radius
  local base_x = center.x + direction.dx * base_radius
  local base_y = center.y + direction.dy * base_radius
  commands[#commands + 1] = { op = "move_to", x = tip_x, y = tip_y }
  commands[#commands + 1] = {
    op = "line_to",
    x = base_x + perpendicular_x * HALF_BASE,
    y = base_y + perpendicular_y * HALF_BASE
  }
  commands[#commands + 1] = {
    op = "line_to",
    x = base_x - perpendicular_x * HALF_BASE,
    y = base_y - perpendicular_y * HALF_BASE
  }
  commands[#commands + 1] = { op = "close" }
end

local function mark_overlay(cell, kind)
  local center = overlay_geometry.cell_center(cell)
  local commands = {}
  for _, direction in ipairs(directions) do
    append_triangle(commands, center, direction, kind)
  end
  return {
    type = "path",
    commands = commands,
    paint = {
      stroke = { theme = "constraint_line" },
      stroke_width = STROKE_WIDTH,
      opacity = 1.0,
      cap = "round",
      join = "round"
    }
  }
end

local function build_constraints(model)
  local predicates = {}
  for index, pair in ipairs(model.pairs) do
    predicates[index] = constraint.less_than(
      constraint.value(pair.low),
      constraint.value(pair.high)
    )
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, cell in ipairs(model.minimum_cells) do
    primitives[#primitives + 1] = mark_overlay(cell, "minimum")
  end
  for _, cell in ipairs(model.maximum_cells) do
    primitives[#primitives + 1] = mark_overlay(cell, "maximum")
  end
  return { primitives = primitives }
end

-- define is startup-only. MinMax has no create(), gameplay callback, Script
-- candidate scope, mutable state, or package-specific Host capability.
-- define 只在启动期执行。极值数独不提供 create、Gameplay callback、Script 候选
-- 范围、可变状态，也不要求 Host 增加玩法专用能力。
function minmax.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("minmax", minmax)

return plugin:build()
