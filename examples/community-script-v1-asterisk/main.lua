-- Asterisk Sudoku technical package, Community Variant Script API V1.
--
-- The fixed Asterisk geometry is package-owned: one center cell, two diagonal
-- axes and one horizontal axis select exactly nine cells. Puzzle JSON only
-- activates the rule. Lua derives both the Native all-different root and the
-- matching Overlay from that one model; no gameplay callback runs after
-- startup materialization.
local plugin = community_variant.script()
local asterisk = {}
local cell = community_variant.cell
local constraint = community_variant.constraint
local overlay_geometry = community_variant.overlay_geometry
local schema = community_variant.schema

local CENTER_ROW = 4
local CENTER_COLUMN = 4
local AXES = {
  { { -3, 0 }, { -2, -2 }, { -2, 2 }, { 0, -3 }, { 0, 0 }, { 0, 3 }, { 2, -2 }, { 2, 2 }, { 3, 0 } },
}
local OVERLAY_LINES = {
  { { -3, 0 }, { -2, -2 }, { 0, -3 }, { 2, -2 }, { 3, 0 } },
  { { -3, 0 }, { -2, 2 }, { 0, 3 }, { 2, 2 }, { 3, 0 } },
  { { 0, -3 }, { 0, 0 }, { 0, 3 } },
}

local function model_cell(offset)
  return cell.index(CENTER_ROW + offset[1], CENTER_COLUMN + offset[2])
end

local function build_model()
  local cells, seen = {}, {}
  for _, offset in ipairs(AXES[1]) do
    local index = model_cell(offset)
    if seen[index] then error("asterisk geometry must not repeat a cell") end
    seen[index] = true
    cells[#cells + 1] = index
  end
  table.sort(cells)
  if #cells ~= 9 then error("asterisk geometry must contain exactly nine cells") end

  local lines = {}
  for line_index, offsets in ipairs(OVERLAY_LINES) do
    local line = {}
    for point_index, offset in ipairs(offsets) do
      line[point_index] = model_cell(offset)
    end
    lines[line_index] = line
  end
  return { cells = cells, lines = lines }
end

local function build_overlay(model)
  local primitives = {}
  for index, line in ipairs(model.lines) do
    primitives[index] = {
      type = "polyline",
      points = overlay_geometry.cell_centers(line),
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = 0.045,
        opacity = 0.90,
        cap = "round",
        join = "round"
      }
    }
  end
  return { primitives = primitives }
end

function asterisk.define(config, scope)
  schema.expect_exact_keys(config, {}, "asterisk")
  local model = build_model()
  return {
    constraints = { constraint.all_different(model.cells) },
    overlay = build_overlay(model)
  }
end

plugin:register_rule("asterisk", asterisk)
return plugin:build()
