-- Community Variant Script API V1 Region Sum Lines technical reference.
-- Community Variant Script API V1 区域和值线技术参考包。
--
-- Puzzle JSON owns only path geometry. Lua validates each orthogonal path,
-- splits it whenever the classic 3x3 box changes, and emits generic equality
-- predicates over segment sums. The Host owns gameplay-time execution.
local plugin = community_variant.script()
local region_sum_lines = {}
local cell_api = community_variant.cell
local schema = community_variant.schema
local constraint = community_variant.constraint
local overlay_geometry = community_variant.overlay_geometry

local MAX_PATHS = 2
local MAX_PATH_LENGTH = 4
local MAX_SEGMENTS = 2
local MAX_ROOTS = 64
local LINE_WIDTH = 0.13
local LINE_OPACITY = 0.86

local function are_orthogonal_neighbors(first, second)
  local row_delta = math.abs(cell_api.row(first) - cell_api.row(second))
  local column_delta = math.abs(cell_api.column(first) - cell_api.column(second))
  return row_delta + column_delta == 1
end

local function box_of(cell)
  return math.floor(cell_api.row(cell) / 3) * 3
      + math.floor(cell_api.column(cell) / 3)
end

local function split_segments(path)
  local segments = {}
  local segment = {}
  local current_box = nil
  for _, cell in ipairs(path) do
    local box = box_of(cell)
    if current_box ~= nil and box ~= current_box then
      segments[#segments + 1] = segment
      segment = {}
    end
    segment[#segment + 1] = cell
    current_box = box
  end
  segments[#segments + 1] = segment
  if #segments ~= MAX_SEGMENTS then
    error("region_sum_lines path must contain exactly 2 box segments")
  end
  for _, item in ipairs(segments) do
    if #item ~= 2 then
      error("region_sum_lines V1 segments must contain exactly 2 cells")
    end
  end
  return segments
end

local function normalize(config)
  schema.expect_exact_keys(config, { paths = true }, "region_sum_lines data")
  schema.expect_array(config.paths, 1, MAX_PATHS, "region_sum_lines data.paths")
  local paths = {}
  for path_index, raw_path in ipairs(config.paths) do
    local label = "region_sum_lines path " .. path_index
    schema.expect_array(raw_path, MAX_PATH_LENGTH, MAX_PATH_LENGTH, label)
    local path = {}
    local seen = {}
    for offset, raw_cell in ipairs(raw_path) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if seen[cell] then error(label .. " must not repeat a cell") end
      if offset > 1 and not are_orthogonal_neighbors(path[offset - 1], cell) then
        error(label .. " must pass through orthogonal neighboring cells")
      end
      path[offset] = cell
      seen[cell] = true
    end
    paths[#paths + 1] = { cells = path, segments = split_segments(path) }
  end
  return { paths = paths }
end

local function segment_sum(segment)
  local values = {}
  for index, cell in ipairs(segment) do
    values[index] = constraint.value(cell)
  end
  return constraint.sum(values)
end

local function build_constraints(model)
  local predicates = {}
  for _, path in ipairs(model.paths) do
    local first_sum = segment_sum(path.segments[1])
    for segment_index = 2, #path.segments do
      predicates[#predicates + 1] = constraint.equal(
        first_sum,
        segment_sum(path.segments[segment_index])
      )
    end
  end
  if #predicates > MAX_ROOTS then
    error("region_sum_lines expansion exceeds 64 root constraints")
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, path in ipairs(model.paths) do
    primitives[#primitives + 1] = {
      type = "polyline",
      points = overlay_geometry.cell_centers(path.cells),
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = LINE_WIDTH,
        opacity = LINE_OPACITY,
        cap = "round",
        join = "round"
      }
    }
  end
  return { primitives = primitives }
end

function region_sum_lines.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("region_sum_lines", region_sum_lines)
return plugin:build()
