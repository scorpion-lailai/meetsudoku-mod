-- Community Variant Script API V1 Dutch Whispers reference package.
-- Community Variant Script API V1 荷兰耳语数独参考包。
--
-- Path geometry is puzzle-owned. This package fixes the semantic threshold:
-- orthogonally adjacent cells on a path must differ by at least four. The Host
-- owns board state, candidates, completion, persistence and rendering.
local plugin = community_variant.script()
local dutch_whispers = {}
local board = community_variant.board
local cell_api = community_variant.cell
local adjacency = community_variant.adjacency
local path_api = community_variant.path
local overlay_geometry = community_variant.overlay_geometry

local function normalize_paths(config)
  if type(config) ~= "table" or type(config.paths) ~= "table" then
    error("dutch_whispers requires data.paths")
  end
  local paths = {}
  local pairs_by_cell = {}
  local used_edges = {}
  local used_cells = {}
  for path_index, raw_path in ipairs(config.paths) do
    if type(raw_path) ~= "table" or #raw_path < 2 then
      error("dutch_whispers path " .. path_index .. " requires at least two cells")
    end
    local path = {}
    local path_cells = {}
    for cell_index, raw_cell in ipairs(raw_path) do
      local cell = cell_api.expect(raw_cell, "dutch_whispers path cell")
      if path_cells[cell] then
        error("dutch_whispers path must not repeat a cell")
      end
      if used_cells[cell] then
        error("dutch_whispers paths must not share a cell")
      end
      path_cells[cell] = true
      used_cells[cell] = true
      path[cell_index] = cell
      if cell_index > 1 then
        local previous = path[cell_index - 1]
        if not adjacency.orthogonal(previous, cell) then
          error("dutch_whispers path cells must be orthogonal neighbors")
        end
        local edge = path_api.edge_key(previous, cell)
        if used_edges[edge] then
          error("dutch_whispers paths must not repeat an edge")
        end
        used_edges[edge] = true
        local pair = { first = previous, second = cell }
        for _, endpoint in ipairs({ previous, cell }) do
          pairs_by_cell[endpoint] = pairs_by_cell[endpoint] or {}
          pairs_by_cell[endpoint][#pairs_by_cell[endpoint] + 1] = pair
        end
      end
    end
    paths[#paths + 1] = path
  end
  if #paths == 0 then
    error("dutch_whispers requires at least one path")
  end
  return { paths = paths, pairs_by_cell = pairs_by_cell }
end

local function pair_digit(ctx, cell, override_cell, override_digit)
  if cell == override_cell then
    return override_digit
  end
  return board.value(ctx, cell)
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, path in ipairs(model.paths) do
    for index = 1, #path - 1 do
      local first_cell = path[index]
      local second_cell = path[index + 1]
      local first = pair_digit(ctx, first_cell, override_cell, override_digit)
      local second = pair_digit(ctx, second_cell, override_cell, override_digit)
      if not board.is_empty(first) and not board.is_empty(second)
          and math.abs(first - second) < 4 then
        violations[#violations + 1] = {
          code = "dutch_whispers_minimum_difference",
          cells = { first_cell, second_cell }
        }
      end
    end
  end
  return violations
end

local function candidate_allowed(model, ctx, cell, digit)
  local pairs = model.pairs_by_cell[cell]
  if pairs == nil then
    return true
  end
  for _, pair in ipairs(pairs) do
    local other = pair.first == cell and pair.second or pair.first
    local other_digit = board.value(ctx, other)
    if not board.is_empty(other_digit) and math.abs(digit - other_digit) < 4 then
      return false
    end
  end
  return true
end

function dutch_whispers.create(config, scope)
  local model = normalize_paths(config)
  return {
    validate_move = function(ctx, move)
      local violations = find_violations(model, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = find_violations(model, ctx, nil, nil), diagnostics = {} }
    end,

    candidate_scope = function()
      local cells = {}
      for cell = 0, 80 do
        if model.pairs_by_cell[cell] ~= nil then
          cells[#cells + 1] = cell
        end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell)
      local remove = {}
      local reasons = {}
      for digit = 1, 9 do
        if not candidate_allowed(model, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = "dutch_whispers_minimum_difference"
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(model, ctx, nil, nil)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, path in ipairs(model.paths) do
        local points = overlay_geometry.cell_centers(path)
        primitives[#primitives + 1] = {
          type = "polyline",
          points = points,
          paint = {
            stroke = "#F28C28",
            stroke_width = 0.18,
            opacity = 0.9
          }
        }
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("dutch_whispers", dutch_whispers)

return plugin:build()
