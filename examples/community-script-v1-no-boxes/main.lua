-- No Boxes Sudoku, Community Variant Script API V1 reference implementation.
-- The fixed rule replaces the standard 3x3 box topology with rows and columns
-- only. Puzzle data may activate this handler, but cannot redefine the model.
local plugin = community_variant.script()
local no_boxes = {}
local cell_api = community_variant.cell
local schema = community_variant.schema

local function build_topology(config)
  schema.expect_exact_keys(config, {}, "no_boxes data")

  local rows = {}
  local columns = {}
  local row_coverage = {}
  local column_coverage = {}

  for row = 0, 8 do
    local cells = {}
    for column = 0, 8 do
      local cell = cell_api.index(row, column)
      cells[#cells + 1] = cell
      row_coverage[cell] = true
    end
    rows[#rows + 1] = cells
  end

  for column = 0, 8 do
    local cells = {}
    for row = 0, 8 do
      local cell = cell_api.index(row, column)
      cells[#cells + 1] = cell
      column_coverage[cell] = true
    end
    columns[#columns + 1] = cells
  end

  for cell = 0, 80 do
    cell_api.expect(cell, "no_boxes coverage")
    if not row_coverage[cell] or not column_coverage[cell] then
      error("no_boxes topology must cover every cell in rows and columns")
    end
  end

  return {
    type = "row_column_only"
  }
end

function no_boxes.define(config, scope)
  return {
    base_topology = build_topology(config),
    constraints = {}
  }
end

plugin:register_rule("no_boxes", no_boxes)
return plugin:build()
