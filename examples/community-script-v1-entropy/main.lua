-- Community Variant Script API V1 Entropy Sudoku reference package.
-- Lua owns the global 2x2 band rule; the Host owns gameplay state and UI.
local plugin = community_variant.script()
local entropy = {}

local board = community_variant.board
local schema = community_variant.schema

local WINDOW_CODE = "entropy_window_infeasible"
local INCOMPLETE_CODE = "entropy_incomplete"

local function build_model(config)
  schema.expect_exact_keys(config, {}, "entropy data")

  local windows = {}
  local windows_by_cell = {}
  for row = 0, 7 do
    for column = 0, 7 do
      local top_left = row * 9 + column
      local window = {
        cells = {top_left, top_left + 1, top_left + 9, top_left + 10},
      }
      windows[#windows + 1] = window
      for _, cell in ipairs(window.cells) do
        windows_by_cell[cell] = windows_by_cell[cell] or {}
        windows_by_cell[cell][#windows_by_cell[cell] + 1] = window
      end
    end
  end

  local candidate_scope = {}
  for cell = 0, 80 do candidate_scope[#candidate_scope + 1] = cell end
  return {
    windows = windows,
    windows_by_cell = windows_by_cell,
    candidate_scope = candidate_scope,
  }
end

local function value_for(ctx, cell, override_cell, override_digit)
  if cell == override_cell then return override_digit end
  return board.value(ctx, cell)
end

local function digit_band(value)
  return math.floor((value - 1) / 3) + 1
end

local function bands_feasible(distinct_bands, empty_cells)
  return 3 - distinct_bands <= empty_cells
end

local function window_feasible(window, ctx, override_cell, override_digit)
  local seen_bands = {}
  local distinct_bands = 0
  local empty_cells = 0
  for _, cell in ipairs(window.cells) do
    local value = value_for(ctx, cell, override_cell, override_digit)
    if board.is_empty(value) then
      empty_cells = empty_cells + 1
    else
      local band = digit_band(value)
      if not seen_bands[band] then
        seen_bands[band] = true
        distinct_bands = distinct_bands + 1
      end
    end
  end
  return bands_feasible(distinct_bands, empty_cells)
end

local function failing_windows(model, ctx, cell, digit)
  local windows = cell == nil and model.windows or (model.windows_by_cell[cell] or {})
  local failures = {}
  for _, window in ipairs(windows) do
    if not window_feasible(window, ctx, cell, digit) then
      failures[#failures + 1] = window
    end
  end
  return failures
end

local function violations_for(windows)
  local violations = {}
  for _, window in ipairs(windows) do
    violations[#violations + 1] = {
      code = WINDOW_CODE,
      cells = window.cells,
    }
  end
  return violations
end

local function blocked_candidate_bands(model, ctx, cell)
  local blocked = {}
  for _, window in ipairs(model.windows_by_cell[cell] or {}) do
    local seen_bands = {}
    local distinct_bands = 0
    local empty_other_cells = 0
    for _, window_cell in ipairs(window.cells) do
      if window_cell ~= cell then
        local value = board.value(ctx, window_cell)
        if board.is_empty(value) then
          empty_other_cells = empty_other_cells + 1
        else
          local band = digit_band(value)
          if not seen_bands[band] then
            seen_bands[band] = true
            distinct_bands = distinct_bands + 1
          end
        end
      end
    end
    if empty_other_cells < 2 then
      for band = 1, 3 do
        local trial_bands = distinct_bands + (seen_bands[band] and 0 or 1)
        if not bands_feasible(trial_bands, empty_other_cells) then
          blocked[band] = true
        end
      end
    end
  end
  return blocked
end

function entropy.create(config, scope)
  local model = build_model(config)
  return {
    validate_move = function(ctx, move)
      local failures = failing_windows(model, ctx, move.cell, move.digit)
      return {
        accepted = #failures == 0,
        violations = violations_for(failures),
        diagnostics = {},
      }
    end,
    validate_board = function(ctx)
      return {
        violations = violations_for(failing_windows(model, ctx, nil, nil)),
        diagnostics = {},
      }
    end,
    candidate_scope = function()
      return model.candidate_scope
    end,
    get_candidate_eliminations = function(ctx, cell, base_candidates)
      local remove = {}
      local reasons = {}
      local candidates = base_candidates or {1, 2, 3, 4, 5, 6, 7, 8, 9}
      local blocked_bands = blocked_candidate_bands(model, ctx, cell)
      for _, digit in ipairs(candidates) do
        if blocked_bands[digit_band(digit)] then
          remove[#remove + 1] = digit
          reasons[tostring(digit)] = WINDOW_CODE
        end
      end
      return {remove = remove, reasons = reasons, diagnostics = {}}
    end,
    validate_final_state = function(ctx)
      local incomplete = {}
      for cell = 0, 80 do
        if board.is_empty(board.value(ctx, cell)) then
          incomplete[#incomplete + 1] = cell
        end
      end
      if #incomplete > 0 then
        return {
          valid = false,
          violations = {{code = INCOMPLETE_CODE, cells = incomplete}},
          diagnostics = {},
        }
      end
      local failures = failing_windows(model, ctx, nil, nil)
      return {
        valid = #failures == 0,
        violations = violations_for(failures),
        diagnostics = {},
      }
    end,
  }
end

plugin:register_rule("entropy", entropy)
return plugin:build()
