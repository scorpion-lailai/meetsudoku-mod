-- Community Variant Script API V1 irregular-region reference implementation.
-- Community Variant Script API V1 不规则区域参考实现。
--
-- Script V1 contributes author-readable region validation and declarative
-- boundaries. The Host promotes this puzzle's generic base_topology data into
-- native replacement topology, so gameplay uses rows, columns and irregular
-- regions instead of classic 3x3 boxes. Board mutation, candidates, conflicts,
-- persistence, completion and rendering remain Host-owned.
-- Script V1 提供作者可读的区域校验和声明式边界。Host 会把本题的
-- base_topology 数据提升为 native 替代拓扑，因此游戏规则使用“行、列、锯齿宫”，
-- 而不是经典 3x3 宫。棋盘修改、候选、冲突、持久化、完成流程和渲染仍由 Host 负责。
local plugin = community_variant.script()
local jigsaw = {}
local board = community_variant.board
local cell_api = community_variant.cell

local function normalize_regions(data)
  if type(data) ~= "table" or type(data.regions) ~= "table"
      or #data.regions ~= 9 then
    error("jigsaw_regions requires exactly 9 regions")
  end

  local regions = {}
  local coverage = {}
  for region_index, raw in ipairs(data.regions) do
    if type(raw) ~= "table" or type(raw.cells) ~= "table" or #raw.cells ~= 9 then
      error("each jigsaw region requires exactly 9 cells")
    end

    local cells = {}
    local seen = {}
    for cell_index, raw_cell in ipairs(raw.cells) do
      local cell = cell_api.expect(
        raw_cell,
        "regions[" .. region_index .. "].cells[" .. cell_index .. "]"
      )
      if seen[cell] or coverage[cell] ~= nil then
        error("jigsaw regions must partition the board without overlap")
      end
      seen[cell] = true
      coverage[cell] = region_index
      cells[#cells + 1] = cell
    end

    regions[#regions + 1] = {
      id = "region_" .. tostring(region_index),
      cells = cells
    }
  end

  for cell = 0, 80 do
    if coverage[cell] == nil then
      error("jigsaw regions must cover every board cell")
    end
  end

  return regions, coverage
end

local function region_violation(region, first, second)
  return {
    code = "jigsaw_region_repeat",
    cells = { first, second },
    data = {
      region = region.id
    }
  }
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}

  for _, region in ipairs(model.regions) do
    local seen = {}
    for _, cell in ipairs(region.cells) do
      local digit = board.value(ctx, cell)
      if cell == override_cell then
        digit = override_digit
      end

      if not board.is_empty(digit) then
        local previous = seen[digit]
        if previous ~= nil then
          violations[#violations + 1] = region_violation(
            region,
            previous,
            cell
          )
        else
          seen[digit] = cell
        end
      end
    end
  end

  return violations
end

local function region_cells_for(model, cell)
  local region_index = model.by_cell[cell]
  local regions = {}
  if region_index ~= nil then
    regions[#regions + 1] = model.regions[region_index]
  end
  return regions
end

local function used_digits(region, ctx, except_cell)
  local used = {}
  for _, cell in ipairs(region.cells) do
    if cell ~= except_cell then
      local digit = board.value(ctx, cell)
      if not board.is_empty(digit) then
        used[digit] = true
      end
    end
  end
  return used
end

-- Required: create one private region model from puzzle-owned geometry.
-- 必须：根据题目拥有的区域几何创建私有 region model。
function jigsaw.create(config, scope)
  local regions, by_cell = normalize_regions(config)
  local model = {
    regions = regions,
    by_cell = by_cell
  }

  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return {
        accepted = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = find_violations(model, ctx, nil, nil),
        diagnostics = {}
      }
    end,

    candidate_scope = function()
      local cells = {}
      for cell = 0, 80 do
        if model.by_cell[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove_set = {}
      local reasons = {}
      for _, region in ipairs(region_cells_for(model, cell)) do
        local used = used_digits(region, ctx, cell)
        for digit = 1, 9 do
          if used[digit] then
            remove_set[digit] = true
            reasons[tostring(digit)] = "jigsaw_region_repeat"
          end
        end
      end

      local remove = {}
      for digit = 1, 9 do
        if remove_set[digit] then
          remove[#remove + 1] = digit
        end
      end

      return {
        remove = remove,
        reasons = reasons,
        diagnostics = {}
      }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return {
        valid = #violations == 0,
        violations = violations,
        diagnostics = {}
      }
    end,

    build_overlay = function(ctx)
      -- The Host renders the promoted replacement topology. Returning no Lua
      -- primitives here avoids drawing the same jigsaw boundaries twice.
      -- Host 会渲染已提升的替代拓扑。这里不返回 Lua primitive，避免锯齿宫边界重复绘制。
      return {
        primitives = {}
      }
    end
  }
end

plugin:register_rule("jigsaw_regions", jigsaw)

return plugin:build()
