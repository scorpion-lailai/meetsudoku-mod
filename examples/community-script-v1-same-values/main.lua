-- Same Values materialized reference for Script API V1.
-- Puzzle data owns labelled region geometry. Lua owns the complete variant
-- meaning: it validates and groups the regions, derives one multiset equality
-- per label, and projects the same normalized model into the board Overlay.
local plugin = community_variant.script()
local same_values = {}
local adjacency = community_variant.adjacency
local cell_api = community_variant.cell
local constraint = community_variant.constraint
local schema = community_variant.schema

local MIN_LABELS = 1
local MAX_LABELS = 2
local MIN_REGION_SIZE = 2
local MAX_REGION_SIZE = 9
local FILL_OPACITY = 0.18
local OUTLINE_OPACITY = 0.9
local OUTLINE_WIDTH = 0.045
local LABEL_SIZE = 0.22

local function region_key(cells)
  local parts = {}
  for index, cell in ipairs(cells) do
    parts[index] = tostring(cell)
  end
  return table.concat(parts, ":")
end

local function normalize_region(raw_region, path, globally_used)
  schema.expect_array(raw_region, MIN_REGION_SIZE, MAX_REGION_SIZE, path)
  local cells = {}
  local local_used = {}
  for index, raw_cell in ipairs(raw_region) do
    local cell = cell_api.expect(raw_cell, path .. "[" .. index .. "]")
    if local_used[cell] then error(path .. " must not repeat a cell") end
    if globally_used[cell] then
      error("same_values regions must be globally disjoint")
    end
    local_used[cell] = true
    globally_used[cell] = true
    cells[#cells + 1] = cell
  end

  local reached = { [cells[1]] = true }
  local queue = { cells[1] }
  local cursor = 1
  while cursor <= #queue do
    local current = queue[cursor]
    cursor = cursor + 1
    for _, candidate in ipairs(cells) do
      if not reached[candidate]
          and adjacency.orthogonal(current, candidate) then
        reached[candidate] = true
        queue[#queue + 1] = candidate
      end
    end
  end
  if #queue ~= #cells then
    error(path .. " must be orthogonally connected")
  end

  table.sort(cells)
  local by_cell = {}
  for _, cell in ipairs(cells) do by_cell[cell] = true end
  return { cells = cells, by_cell = by_cell, key = region_key(cells) }
end

local function normalize(config)
  schema.expect_exact_keys(config, { labels = true }, "same_values")
  schema.expect_array(config.labels, MIN_LABELS, MAX_LABELS, "same_values.labels")

  local labels = {}
  local labels_seen = {}
  local globally_used = {}
  for index, raw in ipairs(config.labels) do
    local path = "same_values.labels[" .. index .. "]"
    schema.expect_exact_keys(raw, { label = true, regions = true }, path)
    if type(raw.label) ~= "string" or not string.match(raw.label, "^[A-Z]$") then
      error(path .. ".label must be one uppercase ASCII letter")
    end
    if labels_seen[raw.label] then
      error("same_values labels must be unique")
    end
    labels_seen[raw.label] = true

    schema.expect_array(raw.regions, 2, 2, path .. ".regions")
    local first = normalize_region(
      raw.regions[1], path .. ".regions[1]", globally_used
    )
    local second = normalize_region(
      raw.regions[2], path .. ".regions[2]", globally_used
    )
    if #first.cells ~= #second.cells then
      error(path .. " regions must contain the same number of cells")
    end
    if second.key < first.key then first, second = second, first end
    labels[#labels + 1] = {
      label = raw.label,
      regions = { first, second }
    }
  end
  table.sort(labels, function(first, second)
    return first.label < second.label
  end)
  return { labels = labels }
end

local function append_segment(commands, x1, y1, x2, y2)
  commands[#commands + 1] = { op = "move_to", x = x1, y = y1 }
  commands[#commands + 1] = { op = "line_to", x = x2, y = y2 }
end

local function append_closed_cell(commands, cell)
  local row = cell_api.row(cell)
  local column = cell_api.column(cell)
  commands[#commands + 1] = { op = "move_to", x = column, y = row }
  commands[#commands + 1] = { op = "line_to", x = column + 1, y = row }
  commands[#commands + 1] = { op = "line_to", x = column + 1, y = row + 1 }
  commands[#commands + 1] = { op = "line_to", x = column, y = row + 1 }
  commands[#commands + 1] = { op = "close" }
end

local function has_cell(region, row, column)
  if row < 0 or row > 8 or column < 0 or column > 8 then return false end
  return region.by_cell[row * 9 + column] == true
end

local function region_overlay(region, label)
  local fill_commands = {}
  local outline_commands = {}
  for _, cell in ipairs(region.cells) do
    append_closed_cell(fill_commands, cell)
    local row = cell_api.row(cell)
    local column = cell_api.column(cell)
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

  local anchor = region.cells[1]
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
    },
    {
      type = "text",
      position = {
        x = cell_api.column(anchor) + 0.16,
        y = cell_api.row(anchor) + 0.27
      },
      value = label,
      paint = {
        fill = { theme = "constraint_line" },
        text_size = LABEL_SIZE,
        text_align = "left",
        opacity = 1
      }
    }
  }
end

local function build_constraints(model)
  local predicates = {}
  for index, entry in ipairs(model.labels) do
    predicates[index] = constraint.multiset_equal(
      entry.regions[1].cells,
      entry.regions[2].cells
    )
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, entry in ipairs(model.labels) do
    for _, region in ipairs(entry.regions) do
      for _, primitive in ipairs(region_overlay(region, entry.label)) do
        primitives[#primitives + 1] = primitive
      end
    end
  end
  return { primitives = primitives }
end

function same_values.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("same_values", same_values)
return plugin:build()
