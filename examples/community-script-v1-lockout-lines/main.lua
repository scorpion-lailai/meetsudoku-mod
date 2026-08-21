-- Community Variant Script API V1 Lockout Lines public reference.
-- This package fixes endpoint distance four and exterior-interval semantics.
-- Puzzle JSON supplies only ordered orthogonal path geometry.
local plugin = community_variant.script()
local lockout_lines = {}
local board = community_variant.board
local cell_api = community_variant.cell
local schema = community_variant.schema
local adjacency = community_variant.adjacency
local path_api = community_variant.path
local overlay_geometry = community_variant.overlay_geometry

local MAX_LINES = 12
local MIN_LINE_LENGTH = 3
local MAX_LINE_LENGTH = 9
local MIN_ENDPOINT_DIFFERENCE = 4
local EXTERIOR_CODE = "lockout_lines_endpoint_exterior"
local INCOMPLETE_CODE = "lockout_lines_incomplete"

local function normalize_lines(config)
  schema.expect_exact_keys(config, { lines = true }, "lockout_lines data")
  schema.expect_array(config.lines, 1, MAX_LINES, "lockout_lines data.lines")

  local lines = {}
  local line_by_cell = {}
  local used_cells = {}
  local used_paths = {}
  for line_index, raw_line in ipairs(config.lines) do
    local label = "lockout_lines line " .. line_index
    schema.expect_array(raw_line, MIN_LINE_LENGTH, MAX_LINE_LENGTH, label)
    local line = {}
    local line_cells = {}
    for offset, raw_cell in ipairs(raw_line) do
      local cell = cell_api.expect(raw_cell, label .. " cell")
      if line_cells[cell] then error(label .. " must not repeat a cell") end
      if used_cells[cell] then error("lockout_lines lines must not intersect or share cells") end
      if offset > 1 and not adjacency.orthogonal(line[offset - 1], cell) then
        error(label .. " must pass through orthogonal neighbors")
      end
      line[offset] = cell
      line_cells[cell] = true
    end
    local key = path_api.canonical_key(line)
    if used_paths[key] then error("lockout_lines lines must not repeat a path") end
    used_paths[key] = true
    for _, cell in ipairs(line) do
      used_cells[cell] = true
      line_by_cell[cell] = line
    end
    lines[#lines + 1] = line
  end
  return { lines = lines, line_by_cell = line_by_cell }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function endpoint_values(value)
  if board.is_empty(value) then return { 1, 2, 3, 4, 5, 6, 7, 8, 9 } end
  return { value }
end

local function exterior_to_endpoints(digit, first, last)
  local lower = math.min(first, last)
  local upper = math.max(first, last)
  return digit < lower or digit > upper
end

local function line_is_feasible(line, ctx, override_cell, override_digit)
  local first = value_for(ctx, line[1], override_cell, override_digit)
  local last = value_for(ctx, line[#line], override_cell, override_digit)
  local interiors = {}
  for offset = 2, #line - 1 do
    local digit = value_for(ctx, line[offset], override_cell, override_digit)
    if not board.is_empty(digit) then interiors[#interiors + 1] = digit end
  end

  for _, first_digit in ipairs(endpoint_values(first)) do
    for _, last_digit in ipairs(endpoint_values(last)) do
      if math.abs(first_digit - last_digit) >= MIN_ENDPOINT_DIFFERENCE then
        local feasible = true
        for _, digit in ipairs(interiors) do
          if not exterior_to_endpoints(digit, first_digit, last_digit) then
            feasible = false
            break
          end
        end
        if feasible then return true end
      end
    end
  end
  return false
end

local function assigned_cells(line, ctx, override_cell, override_digit)
  local cells = {}
  for _, cell in ipairs(line) do
    if not board.is_empty(value_for(ctx, cell, override_cell, override_digit)) then
      cells[#cells + 1] = cell
    end
  end
  return cells
end

local function find_violations(model, ctx, override_cell, override_digit)
  local violations = {}
  for _, line in ipairs(model.lines) do
    if not line_is_feasible(line, ctx, override_cell, override_digit) then
      violations[#violations + 1] = {
        code = EXTERIOR_CODE,
        cells = assigned_cells(line, ctx, override_cell, override_digit)
      }
    end
  end
  return violations
end

local function final_violations(model, ctx)
  local violations = find_violations(model, ctx, nil, nil)
  for _, line in ipairs(model.lines) do
    for _, cell in ipairs(line) do
      if board.is_empty(board.value(ctx, cell)) then
        violations[#violations + 1] = { code = INCOMPLETE_CODE, cells = line }
        break
      end
    end
  end
  return violations
end

function lockout_lines.create(config, scope)
  local model = normalize_lines(config)
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
        if model.line_by_cell[cell] ~= nil then cells[#cells + 1] = cell end
      end
      return cells
    end,

    get_candidate_eliminations = function(ctx, cell, base_candidates)
      local remove, reasons = {}, {}
      local candidates = base_candidates or { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
      local line = model.line_by_cell[cell]
      if line == nil then return { remove = remove, reasons = reasons, diagnostics = {} } end
      for _, digit in ipairs(candidates) do
        if not line_is_feasible(line, ctx, cell, digit) then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = EXTERIOR_CODE
        end
      end
      return { remove = remove, reasons = reasons, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = final_violations(model, ctx)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      local primitives = {}
      for _, line in ipairs(model.lines) do
        primitives[#primitives + 1] = {
          type = "polyline", points = overlay_geometry.cell_centers(line),
          paint = { stroke = "#C56A3C", stroke_width = 0.12, opacity = 0.9, cap = "round", join = "round" }
        }
        for _, endpoint in ipairs({ line[1], line[#line] }) do
          local center = overlay_geometry.cell_center(endpoint)
          local radius = 0.22
          primitives[#primitives + 1] = {
            type = "polygon",
            points = {
              { x = center.x, y = center.y - radius },
              { x = center.x + radius, y = center.y },
              { x = center.x, y = center.y + radius },
              { x = center.x - radius, y = center.y }
            },
            paint = { stroke = "#C56A3C", stroke_width = 0.06, opacity = 0.9, join = "round" }
          }
        end
      end
      return { primitives = primitives, diagnostics = {} }
    end
  }
end

plugin:register_rule("lockout_lines", lockout_lines)

return plugin:build()
