-- Community Variant Script API V1 Magic Square Sudoku materialized reference.
-- Community Variant Script API V1 魔方阵数独启动期物化参考实现。
--
-- The package owns the complete fixed rule: one classic-box-aligned 3x3
-- region has three row sums, three column sums and two diagonal sums equal to
-- 15. Puzzle JSON owns only the varying box index. Lua derives all cells,
-- constraints and Overlay geometry from that index; Gameplay never calls Lua.
-- 包级 Lua 拥有完整且固定的规则：一个与经典宫对齐的 3x3 区域，其三行、
-- 三列和两条主对角线之和都等于 15。题目 JSON 只保存变化的宫索引；Lua
-- 负责派生全部格子、约束和 Overlay，Gameplay 不回调 Lua。
local plugin = community_variant.script()
local magic_square = {}
local cell_api = community_variant.cell
local schema = community_variant.schema
local constraint = community_variant.constraint

local TARGET_SUM = 15
local FILL_OPACITY = 0.20
local OUTLINE_OPACITY = 0.92
local OUTLINE_WIDTH = 0.055

local function normalize(config)
  schema.expect_exact_keys(config, { box = true }, "magic_square")
  local box = schema.expect_integer(config.box, "magic_square.box")
  if box < 0 or box > 8 then
    error("magic_square.box must be an integer in 0..8")
  end

  local box_row = math.floor(box / 3) * 3
  local box_column = (box % 3) * 3
  local cells = {}
  for local_row = 0, 2 do
    for local_column = 0, 2 do
      cells[#cells + 1] = cell_api.index(
        box_row + local_row,
        box_column + local_column
      )
    end
  end

  local lines = {
    { cells[1], cells[2], cells[3] },
    { cells[4], cells[5], cells[6] },
    { cells[7], cells[8], cells[9] },
    { cells[1], cells[4], cells[7] },
    { cells[2], cells[5], cells[8] },
    { cells[3], cells[6], cells[9] },
    { cells[1], cells[5], cells[9] },
    { cells[3], cells[5], cells[7] }
  }

  return {
    box = box,
    row = box_row,
    column = box_column,
    cells = cells,
    lines = lines
  }
end

local function line_sum(line)
  local values = {}
  for index, cell in ipairs(line) do
    values[index] = constraint.value(cell)
  end
  return constraint.sum(values)
end

local function build_constraints(model)
  local predicates = {}
  for index, line in ipairs(model.lines) do
    predicates[index] = constraint.equal(
      line_sum(line),
      constraint.constant(TARGET_SUM)
    )
  end
  return predicates
end

local function rectangle_commands(model)
  local left = model.column
  local top = model.row
  local right = left + 3
  local bottom = top + 3
  return {
    { op = "move_to", x = left, y = top },
    { op = "line_to", x = right, y = top },
    { op = "line_to", x = right, y = bottom },
    { op = "line_to", x = left, y = bottom },
    { op = "close" }
  }
end

local function build_overlay(model)
  local commands = rectangle_commands(model)
  return {
    primitives = {
      {
        type = "path",
        commands = commands,
        paint = {
          fill = { theme = "constraint_fill" },
          opacity = FILL_OPACITY
        }
      },
      {
        type = "path",
        commands = commands,
        paint = {
          stroke = { theme = "constraint_line" },
          stroke_width = OUTLINE_WIDTH,
          opacity = OUTLINE_OPACITY,
          cap = "round",
          join = "round"
        }
      }
    }
  }
end

-- define is startup-only. The Host compiles these eight typed predicates once
-- and then owns candidates, conflicts, note cleanup and completion.
-- define 只在启动期执行。Host 一次性编译八条 typed predicates，随后统一负责
-- 候选、冲突、笔记清理和完成判定。
function magic_square.define(config, scope)
  local model = normalize(config)
  return {
    constraints = build_constraints(model),
    overlay = build_overlay(model)
  }
end

plugin:register_rule("magic_square", magic_square)

return plugin:build()
