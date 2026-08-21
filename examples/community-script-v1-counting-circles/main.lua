-- Counting Circles materialized reference package for Script API V1.
-- Puzzle data owns only disjoint marked cell groups. Lua validates and
-- canonicalizes those groups, then derives both generic frequency roots and
-- the per-cell circle Overlay from the same normalized model.
local plugin = community_variant.script()
local counting_circles = {}
local cell_api = community_variant.cell
local constraint = community_variant.constraint
local overlay_geometry = community_variant.overlay_geometry
local schema = community_variant.schema

local MIN_GROUPS = 1
local MAX_GROUPS = 2
local MIN_GROUP_SIZE = 3
local MAX_GROUP_SIZE = 8

local function group_key(cells)
  local parts = {}
  for index, cell in ipairs(cells) do parts[index] = tostring(cell) end
  return table.concat(parts, ":")
end

local function normalize_group(raw_group, path, globally_used)
  schema.expect_array(raw_group, MIN_GROUP_SIZE, MAX_GROUP_SIZE, path)
  local cells = {}
  local local_used = {}
  for index, raw_cell in ipairs(raw_group) do
    local cell = cell_api.expect(raw_cell, path .. "[" .. index .. "]")
    if local_used[cell] then error(path .. " must not repeat a cell") end
    if globally_used[cell] then
      error("counting_circles groups must be globally disjoint")
    end
    local_used[cell] = true
    globally_used[cell] = true
    cells[#cells + 1] = cell
  end
  table.sort(cells)
  return { cells = cells, key = group_key(cells) }
end

local function normalize(config)
  schema.expect_exact_keys(config, { groups = true }, "counting_circles")
  schema.expect_array(config.groups, MIN_GROUPS, MAX_GROUPS,
      "counting_circles.groups")

  local groups = {}
  local globally_used = {}
  for index, raw_group in ipairs(config.groups) do
    groups[#groups + 1] = normalize_group(
        raw_group, "counting_circles.groups[" .. index .. "]", globally_used)
  end
  table.sort(groups, function(first, second) return first.key < second.key end)
  return { groups = groups }
end

local function build_constraints(model)
  local predicates = {}
  for index, group in ipairs(model.groups) do
    predicates[index] = constraint.self_referential_frequency(group.cells)
  end
  return predicates
end

local function build_overlay(model)
  local primitives = {}
  for _, group in ipairs(model.groups) do
    for _, cell in ipairs(group.cells) do
      primitives[#primitives + 1] = {
        type = "circle",
        center = overlay_geometry.cell_center(cell),
        radius = 0.28,
        paint = {
          stroke = { theme = "constraint_line" },
          stroke_width = 0.045,
          opacity = 0.9
        }
      }
    end
  end
  return { primitives = primitives }
end

function counting_circles.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("counting_circles", counting_circles)
return plugin:build()
