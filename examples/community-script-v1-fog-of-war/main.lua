-- Fog of War reference package.
--
-- Lua owns the fixed Fog rule below. Puzzle JSON supplies only the cells that
-- start hidden for this puzzle. This script normalizes that puzzle data into a
-- Fog rule model, then derives a generic `cell_state_rule` semantic object.
-- The Host validates and materializes that semantic object into runtime state;
-- it still owns board mutation, input transactions, persistence and UI.
local plugin = community_variant.script()
local cell_api = community_variant.cell
local schema = community_variant.schema
local fog = {}

local BOARD_SIZE = 9
local CELL_COUNT = BOARD_SIZE * BOARD_SIZE
local REVEAL_RADIUS = 1

local function fail(message)
  error("fog: " .. message)
end

local function cells_to_set(cells)
  local set = {}
  for _, cell in ipairs(cells) do
    set[cell] = true
  end
  return set
end

local function complement_cells(hidden_set)
  local visible = {}
  for cell = 0, CELL_COUNT - 1 do
    if not hidden_set[cell] then
      visible[#visible + 1] = cell
    end
  end
  return visible
end

local function normalize_covered_cells(config)
  if type(config) ~= "table" then
    fail("config must be an object")
  end
  schema.expect_exact_keys(config, { covered_cells = true }, "config")
  schema.expect_array(config.covered_cells, 1, CELL_COUNT, "covered_cells")

  local normalized = {}
  local seen = {}
  for index, raw_cell in ipairs(config.covered_cells) do
    local cell = cell_api.expect(raw_cell, "covered_cells[" .. index .. "]")
    if seen[cell] then
      fail("covered_cells contains duplicate cell " .. tostring(cell))
    end
    seen[cell] = true
    normalized[#normalized + 1] = cell
  end
  table.sort(normalized)
  return normalized
end

local function puzzle_digit(ctx, cell)
  if type(ctx) ~= "table" or type(ctx.puzzle) ~= "table" or
      type(ctx.puzzle.puzzle) ~= "string" or #ctx.puzzle.puzzle ~= CELL_COUNT then
    fail("ctx.puzzle.puzzle must be an 81-character string")
  end
  return string.sub(ctx.puzzle.puzzle, cell + 1, cell + 1)
end

local function validate_initial_fog_model(model, ctx)
  -- The puzzle bank owns which cells start hidden. Lua verifies that this
  -- puzzle-varying mask does not hide fixed givens; otherwise the rule would
  -- redefine the starting puzzle instead of only controlling visibility.
  for _, cell in ipairs(model.covered_cells) do
    local digit = puzzle_digit(ctx, cell)
    if digit ~= "0" then
      local row = cell_api.row(cell) + 1
      local column = cell_api.column(cell) + 1
      fail("covered cell r" .. row .. "c" .. column .. " hides a given digit")
    end
  end
end

local function build_fog_model(config, scope)
  if type(scope) ~= "table" then
    fail("scope must be an object")
  end

  local covered_cells = normalize_covered_cells(config)
  local covered_set = cells_to_set(covered_cells)
  local initial_visible_cells = complement_cells(covered_set)

  return {
    covered_cells = covered_cells,
    covered_set = covered_set,
    initial_visible_cells = initial_visible_cells,
    reveal = {
      type = "radius",
      neighborhood = "king",
      distance = REVEAL_RADIUS
    },
    hidden_state = {
      digits = "conceal",
      candidates = "conceal",
      input = "block",
      overlay = "clip"
    },
    trigger = {
      event = "move.committed",
      placement = "correct"
    },
    target = {
      origin = "move.cell"
    },
    accumulation = "union",
    restart_policy = "initial"
  }
end

local function build_visibility_effect(model)
  -- Fog's domain word is "reveal", but the exported semantic object is more
  -- general: on a matching game event, set selected cells to the `visible`
  -- state. The Host compiles this effect into its current cell_state runtime.
  return {
    operation = "set_cell_state",
    state = "visible",
    selector = {
      origin = model.target.origin,
      expand = model.reveal
    },
    accumulation = model.accumulation
  }
end

local function build_visibility_transition(model)
  -- A Cell State declaration always uses the generic event/condition/effect
  -- shape. Fog intentionally selects the narrow one-transition V1-compatible
  -- profile below; other Mods choose their own bounded fixed transitions in
  -- their own main.lua rather than asking Host for a named preset.
  return {
    event = model.trigger.event,
    condition = {
      placement = model.trigger.placement
    },
    effects = {
      build_visibility_effect(model)
    }
  }
end

local function build_cell_state_rule(model)
  return {
    kind = "cell_state_rule",
    states = {
      hidden = model.hidden_state
    },
    initial = {
      hidden_cells = model.covered_cells
    },
    transitions = {
      build_visibility_transition(model),
    },
    restart = {
      policy = model.restart_policy
    }
  }
end

local function no_violations()
  return { violations = {} }
end

function fog.create(config, scope)
  local model = build_fog_model(config, scope)

  return {
    -- Fog changes information exposure and input state. It does not change the
    -- Sudoku solution set, so normal Sudoku legality remains Host-owned.
    validate_move = function(ctx, move)
      return { accepted = true, violations = {} }
    end,

    validate_board = function(ctx)
      return no_violations()
    end,

    validate_final_state = function(ctx)
      return { valid = true, violations = {} }
    end,

    build_session_features = function(ctx)
      validate_initial_fog_model(model, ctx)
      return {
        features = {
          build_cell_state_rule(model)
        }
      }
    end
  }
end

plugin:register_rule("fog", fog)
return plugin:build()
