-- Beacon Sudoku public reference for bounded Cell State V2.
--
-- The package owns the fixed player rule and derives its complete immutable
-- declaration. Puzzle data owns only the initial mask geometry. The Host then
-- executes the generic declaration and exclusively owns input transactions,
-- state snapshots, persistence, recovery and the visibility projection.
local plugin = community_variant.script()
local beacon = {}
local cell_api = community_variant.cell
local schema = community_variant.schema

local CELL_COUNT = 81

local function fail(message)
  error("beacon: " .. message)
end

local function normalize_covered_cells(config)
  if type(config) ~= "table" then fail("config must be an object") end
  schema.expect_exact_keys(config, { covered_cells = true }, "beacon data")
  schema.expect_array(config.covered_cells, 1, CELL_COUNT, "beacon covered_cells")

  local cells, seen = {}, {}
  for index, raw_cell in ipairs(config.covered_cells) do
    local cell = cell_api.expect(raw_cell, "covered_cells[" .. index .. "]")
    if seen[cell] then fail("covered_cells contains duplicate cell " .. tostring(cell)) end
    seen[cell] = true
    cells[#cells + 1] = cell
  end
  table.sort(cells)
  return cells
end

local function validate_hidden_cells_against_puzzle(ctx, covered_cells)
  if type(ctx) ~= "table" or type(ctx.puzzle) ~= "table" or
      type(ctx.puzzle.puzzle) ~= "string" or #ctx.puzzle.puzzle ~= CELL_COUNT then
    fail("ctx.puzzle.puzzle must be an 81-character string")
  end
  for _, cell in ipairs(covered_cells) do
    if string.sub(ctx.puzzle.puzzle, cell + 1, cell + 1) ~= "0" then
      fail("covered cell must be blank at session start: " .. tostring(cell))
    end
  end
end

local function reveal_transition(placement, neighborhood, distance)
  return {
    event = "move.committed",
    condition = { placement = placement },
    effects = {
      {
        operation = "set_cell_state",
        state = "visible",
        selector = {
          origin = "move.cell",
          expand = {
            type = "radius",
            neighborhood = neighborhood,
            distance = distance,
          },
        },
        accumulation = "union",
      },
    },
  }
end

local function build_cell_state_rule(covered_cells)
  -- Both transitions are package-invariant Beacon semantics. Keeping them here
  -- lets other authors derive different bounded V2 rules in their own main.lua
  -- without requiring a Beacon or Fog branch in Host code.
  return {
    kind = "cell_state_rule",
    states = {
      hidden = {
        digits = "conceal",
        candidates = "conceal",
        input = "block",
        overlay = "clip",
      },
    },
    initial = { hidden_cells = covered_cells },
    transitions = {
      -- An any-placement pulse reveals the five-cell orthogonal cross. A
      -- correct placement then adds the four diagonal cells from the 3x3
      -- king neighborhood, so the conditional bonus is observable rather
      -- than being subsumed by the base pulse.
      reveal_transition("any", "orthogonal", 1),
      reveal_transition("correct", "king", 1),
    },
    restart = { policy = "initial" },
  }
end

function beacon.create(config, scope)
  local covered_cells = normalize_covered_cells(config)
  return {
    -- Beacon changes only information visibility. Standard Sudoku legality and
    -- completion remain in the active Host RuleSet.
    validate_move = function(ctx, move)
      return { accepted = true, violations = {} }
    end,
    validate_board = function(ctx)
      return { violations = {} }
    end,
    validate_final_state = function(ctx)
      return { valid = true, violations = {} }
    end,
    build_session_features = function(ctx)
      validate_hidden_cells_against_puzzle(ctx, covered_cells)
      return { features = { build_cell_state_rule(covered_cells) } }
    end,
  }
end

plugin:register_rule("beacon", beacon)
return plugin:build()
