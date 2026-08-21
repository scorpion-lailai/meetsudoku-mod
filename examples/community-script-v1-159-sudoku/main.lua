-- 159 Sudoku, Community Variant Script API V1 materialized reference.
-- 159 数独：Community Variant Script API V1 启动期物化参考实现。
--
-- The package owns the complete fixed rule. In each row, the values in
-- columns 1, 5, and 9 select the positions that must contain 1, 5, and 9.
-- Puzzle JSON only activates this handler with an empty object. It cannot
-- redefine rows, index columns, targets, predicates, or execution details.
-- 包级 Lua 拥有完整固定规则：每一行第 1、5、9 列的数字分别索引该行中
-- 必须填入 1、5、9 的位置。题目 JSON 只用空对象激活规则，不能覆盖行序列、
-- 索引列、目标数字、约束或执行细节。
local plugin = community_variant.script()
local constraint = community_variant.constraint
local cell_api = community_variant.cell
local schema = community_variant.schema
local one_five_nine = {}

local INDEX_TARGETS = {
  { column = 1, target = 1 },
  { column = 5, target = 5 },
  { column = 9, target = 9 }
}

local function normalize(config)
  schema.expect_exact_keys(config, {}, "one_five_nine")

  local rows = {}
  for row = 0, 8 do
    local cells = {}
    for column = 0, 8 do
      cells[#cells + 1] = cell_api.index(row, column)
    end
    rows[#rows + 1] = cells
  end
  return { rows = rows }
end

local function build_constraints(model)
  local predicates = {}
  for _, row_cells in ipairs(model.rows) do
    for _, mapping in ipairs(INDEX_TARGETS) do
      local selected_value = constraint.element_at(
        row_cells,
        constraint.value(row_cells[mapping.column])
      )
      predicates[#predicates + 1] = constraint.equal(
        selected_value,
        constraint.constant(mapping.target)
      )
    end
  end
  return predicates
end

-- define runs once at exact-session startup. The Host validates and compiles
-- these 27 typed predicates into the Native Rule Graph. Gameplay does not call
-- Lua; the Host owns candidates, conflicts, note cleanup, completion, save and UI.
-- define 只在精确会话启动时运行一次。Host 校验并把 27 条 typed predicate
-- 编译为 Native Rule Graph；Gameplay 不回调 Lua，候选、冲突、笔记清理、
-- 完成判定、存档和 UI 仍由 Host 负责。
function one_five_nine.define(config, scope)
  local model = normalize(config)
  return { constraints = build_constraints(model) }
end

plugin:register_rule("one_five_nine", one_five_nine)
return plugin:build()
