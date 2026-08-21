-- Community Variant Script API V1 Clone Sudoku materialized reference.
-- Community Variant Script API V1 克隆数独启动期物化参考实现。
--
-- The package owns the complete fixed Clone meaning: exactly two disjoint,
-- orthogonally connected regions with the same untranslated shape and
-- orientation. Corresponding offsets must contain equal digits. Puzzle JSON
-- owns only the two varying cell regions. It cannot provide derived pairs,
-- transforms, constraints, Overlay coordinates, or gameplay callbacks.
-- 包级 Lua 拥有完整且固定的克隆语义：恰好两个互不重叠、正交连通、形状与方向
-- 相同且只相差平移的区域；相同相对坐标必须填入相同数字。题目 JSON 只拥有两个
-- 变化的格子区域，不能填写派生格对、变换、约束、Overlay 坐标或 Gameplay callback。
local plugin = community_variant.script()
local clone = {}
local cell_api = community_variant.cell
local schema = community_variant.schema
local adjacency = community_variant.adjacency
local constraint = community_variant.constraint

local MIN_REGION_SIZE = 2
local MAX_REGION_SIZE = 9
local FILL_OPACITY = 0.22
local OUTLINE_OPACITY = 0.9
local OUTLINE_WIDTH = 0.045

local function normalize_region(raw_region, region_index, globally_used)
  local label = "clone.regions[" .. region_index .. "]"
  schema.expect_array(raw_region, MIN_REGION_SIZE, MAX_REGION_SIZE, label)

  local cells = {}
  local used = {}
  local minimum_row = 8
  local minimum_column = 8
  for index, raw_cell in ipairs(raw_region) do
    local current = cell_api.expect(raw_cell, label .. "[" .. index .. "]")
    if used[current] then
      error(label .. " must not repeat a cell")
    end
    if globally_used[current] then
      error("clone regions must not overlap")
    end
    used[current] = true
    globally_used[current] = true
    cells[#cells + 1] = current
    minimum_row = math.min(minimum_row, cell_api.row(current))
    minimum_column = math.min(minimum_column, cell_api.column(current))
  end

  -- Connectivity is semantic, not presentation. Walk only orthogonal neighbors
  -- and require every declared cell to be reached from the first cell.
  -- 连通性属于规则语义而不是画法。这里只沿正交相邻格遍历，并要求首格能到达
  -- 区域内的全部格子。
  local reached = { [cells[1]] = true }
  local queue = { cells[1] }
  local cursor = 1
  while cursor <= #queue do
    local current = queue[cursor]
    cursor = cursor + 1
    for _, candidate in ipairs(cells) do
      if not reached[candidate] and adjacency.orthogonal(current, candidate) then
        reached[candidate] = true
        queue[#queue + 1] = candidate
      end
    end
  end
  if #queue ~= #cells then
    error(label .. " must be orthogonally connected")
  end

  local entries = {}
  for _, current in ipairs(cells) do
    local row_offset = cell_api.row(current) - minimum_row
    local column_offset = cell_api.column(current) - minimum_column
    entries[#entries + 1] = {
      cell = current,
      row_offset = row_offset,
      column_offset = column_offset,
      key = tostring(row_offset) .. ":" .. tostring(column_offset)
    }
  end
  table.sort(entries, function(first, second)
    if first.row_offset ~= second.row_offset then
      return first.row_offset < second.row_offset
    end
    return first.column_offset < second.column_offset
  end)

  local canonical_cells = {}
  local by_cell = {}
  for index, entry in ipairs(entries) do
    canonical_cells[index] = entry.cell
    by_cell[entry.cell] = true
  end
  return {
    entries = entries,
    cells = canonical_cells,
    by_cell = by_cell
  }
end

local function normalize(config)
  schema.expect_exact_keys(config, { regions = true }, "clone")
  schema.expect_array(config.regions, 2, 2, "clone.regions")

  local globally_used = {}
  local first = normalize_region(config.regions[1], 1, globally_used)
  local second = normalize_region(config.regions[2], 2, globally_used)
  if #first.entries ~= #second.entries then
    error("clone regions must contain the same number of cells")
  end

  local pairs = {}
  for index, first_entry in ipairs(first.entries) do
    local second_entry = second.entries[index]
    if first_entry.key ~= second_entry.key then
      error("clone regions must have the same translated shape and orientation")
    end
    -- Equality operand canonicalization belongs to the SDK constructor. Region
    -- order therefore remains author semantics rather than Host IR knowledge.
    -- 相等操作数的规范化由 SDK 构造器负责，脚本不需要了解 Host IR 排序。
    pairs[index] = { first_entry.cell, second_entry.cell }
  end

  return {
    regions = { first, second },
    pairs = pairs
  }
end

local function append_closed_cell(commands, current)
  local row = cell_api.row(current)
  local column = cell_api.column(current)
  commands[#commands + 1] = { op = "move_to", x = column, y = row }
  commands[#commands + 1] = { op = "line_to", x = column + 1, y = row }
  commands[#commands + 1] = { op = "line_to", x = column + 1, y = row + 1 }
  commands[#commands + 1] = { op = "line_to", x = column, y = row + 1 }
  commands[#commands + 1] = { op = "close" }
end

local function append_segment(commands, x1, y1, x2, y2)
  commands[#commands + 1] = { op = "move_to", x = x1, y = y1 }
  commands[#commands + 1] = { op = "line_to", x = x2, y = y2 }
end

local function has_cell(region, row, column)
  if row < 0 or row > 8 or column < 0 or column > 8 then
    return false
  end
  return region.by_cell[row * 9 + column] == true
end

local function region_overlay(region)
  local fill_commands = {}
  local outline_commands = {}
  for _, current in ipairs(region.cells) do
    append_closed_cell(fill_commands, current)
    local row = cell_api.row(current)
    local column = cell_api.column(current)
    if not has_cell(region, row - 1, column) then
      append_segment(outline_commands, column, row, column + 1, row)
    end
    if not has_cell(region, row, column + 1) then
      append_segment(outline_commands, column + 1, row, column + 1, row + 1)
    end
    if not has_cell(region, row + 1, column) then
      append_segment(outline_commands, column + 1, row + 1, column, row + 1)
    end
    if not has_cell(region, row, column - 1) then
      append_segment(outline_commands, column, row + 1, column, row)
    end
  end

  return {
    {
      type = "path",
      commands = fill_commands,
      paint = {
        fill = { theme = "constraint_fill" },
        opacity = FILL_OPACITY
      }
    },
    {
      type = "path",
      commands = outline_commands,
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = OUTLINE_WIDTH,
        opacity = OUTLINE_OPACITY,
        cap = "round",
        join = "round"
      }
    }
  }
end

local function build_constraints(model)
  local predicates = {}
  for index, pair in ipairs(model.pairs) do
    -- Equality is emitted in canonical offset order. The Host compiles this
    -- typed predicate once and owns candidates, conflicts, note cleanup and
    -- completion through the Native Rule Runtime.
    -- 相等约束按规范化后的相对坐标顺序输出。Host 只在启动期编译一次，随后由
    -- Native Rule Runtime 统一负责候选、冲突、笔记清理和完成判定。
    predicates[index] = constraint.equal(
      constraint.value(pair[1]),
      constraint.value(pair[2])
    )
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, region in ipairs(model.regions) do
    for _, primitive in ipairs(region_overlay(region)) do
      primitives[#primitives + 1] = primitive
    end
  end
  return { primitives = primitives }
end

-- define is deliberately startup-only. Clone has no create(), move validator,
-- candidate callback, mutable state, or package-specific Host capability.
-- define 只在启动期执行。克隆数独不提供 create、落子校验 callback、候选 callback、
-- 可变状态，也不要求 Host 按玩法或包 ID 增加特判。
function clone.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("clone", clone)

return plugin:build()
