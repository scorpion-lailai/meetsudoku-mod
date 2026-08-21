-- Community Variant Script API V1 Modular Lines Sudoku technical reference.
-- Community Variant Script API V1 模数线数独技术参考包。
--
-- Every overlapping window of three cells on each ordered path must contain
-- three different non-negative remainders modulo three. Puzzle JSON owns only
-- path geometry. Lua owns the fixed mod=3 meaning and derives the generic
-- Constraint Program; the Host owns gameplay, candidates, notes and completion.
-- 每条有序路径上的每个连续三格窗口，除以 3 的余数都必须两两不同。题目 JSON
-- 只保存路径几何；Lua 拥有固定的 mod=3 语义并派生通用 Constraint Program，
-- Host 负责游戏流程、候选、笔记和完成判定。
local plugin = community_variant.script()
local modular_lines = {}
local cell_api = community_variant.cell
local schema = community_variant.schema
local constraint = community_variant.constraint
local overlay_geometry = community_variant.overlay_geometry

local MODULUS = 3
local MIN_LINE_LENGTH = 3
local MAX_LINE_LENGTH = 9
local MAX_LINES = 4
local LINE_OPACITY = 0.86
local LINE_WIDTH = 0.13
local ENDPOINT_RADIUS = 0.20

local function are_orthogonal_neighbors(first, second)
  local row_delta = math.abs(cell_api.row(first) - cell_api.row(second))
  local column_delta = math.abs(
    cell_api.column(first) - cell_api.column(second)
  )
  return row_delta + column_delta == 1
end

local function normalize(config)
  schema.expect_exact_keys(config, { lines = true }, "modular_lines data")
  schema.expect_array(config.lines, 1, MAX_LINES, "modular_lines data.lines")

  local lines = {}
  local claimed = {}
  for line_index, raw_line in ipairs(config.lines) do
    local label = "modular_lines line " .. line_index
    schema.expect_array(raw_line, MIN_LINE_LENGTH, MAX_LINE_LENGTH, label)
    local line = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if claimed[cell] then
        error("modular_lines paths must not share cells")
      end
      if offset > 1 and not are_orthogonal_neighbors(line[offset - 1], cell) then
        error(label .. " must pass through orthogonal neighboring cells")
      end
      line[offset] = cell
      claimed[cell] = true
    end
    lines[#lines + 1] = line
  end
  return { lines = lines }
end

local function remainder(cell)
  return constraint.remainder(constraint.value(cell), MODULUS)
end

local function build_constraints(model)
  local predicates = {}
  local seen_pairs = {}
  local function add_pair(first, second)
    local lower = math.min(first, second)
    local upper = math.max(first, second)
    local key = tostring(lower) .. ":" .. tostring(upper)
    if seen_pairs[key] then return end
    seen_pairs[key] = true
    predicates[#predicates + 1] = constraint.not_equal(
      remainder(lower),
      remainder(upper)
    )
  end
  for _, line in ipairs(model.lines) do
    for offset = 1, #line - 2 do
      add_pair(line[offset], line[offset + 1])
      add_pair(line[offset], line[offset + 2])
      add_pair(line[offset + 1], line[offset + 2])
    end
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, line in ipairs(model.lines) do
    primitives[#primitives + 1] = {
      type = "polyline",
      points = overlay_geometry.cell_centers(line),
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = LINE_WIDTH,
        opacity = LINE_OPACITY,
        cap = "round",
        join = "round"
      }
    }
    for _, endpoint in ipairs({ line[1], line[#line] }) do
      primitives[#primitives + 1] = {
        type = "circle",
        center = overlay_geometry.cell_center(endpoint),
        radius = ENDPOINT_RADIUS,
        paint = {
          stroke = { theme = "constraint_line" },
          fill = "#FFFFFF",
          stroke_width = 0.045,
          opacity = LINE_OPACITY
        }
      }
    end
  end
  return { primitives = primitives }
end

-- define runs once at exact-session startup. The Host then materializes the
-- generic predicates and exclusively owns all gameplay-time rule execution.
-- define 只在 exact-session 启动时执行一次；随后 Host 物化通用谓词并独占游戏中的
-- 规则执行。
function modular_lines.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("modular_lines", modular_lines)

return plugin:build()
