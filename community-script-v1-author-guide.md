# Community Variant Script API V1 Author Guide

本文是 Mod 作者编写变形数独 Lua 规则的入口。作者定义规则、可选棋盘标记和题目数据；
游戏负责通用的输入、撤销、笔记、冲突提示、存档、进度和完成流程。

`variant.json.ruleGuide` 是玩家看到的规则提示，只描述玩法本身、题面标记和约束
语义。不要把 Host/App/Lua、候选、存档、完成流程、UI 或 Overlay 实现边界写进
`rule_guide.item_*`；这些说明只放在本文档。

## Quick Start

1. 复制 `examples/community-script-v1-fortress/`。它适合从“落子时检查规则”的玩法开始，
   并使用当前的 `board`、`cell` 和 `schema` helpers。
2. 修改 `manifest.json` 的 `id`、`name` 和 `version`，并同步 `variant.json`、
   `i18n/` 与 `puzzle_bank.json` 的玩法内容。
3. 在 `main.lua` 中保留 `community_variant.script()`，为每个规则选择唯一的
   `define(config, scope)` 或 `create(config, scope)` handler。
4. 为每道题填写 `puzzle`、`solution` 和该玩法所需的 `rules.<handler>` 数据。
5. 打开 [SDK 首页](README.md)，按规则形状选择更接近的公开示例进行对照。

新包不要使用 `community_variant.new()`、`community_variant.constraint_program()`、
`normalize/compile_rules` 或 manifest v2 字段。App 只为 API 1-4 已发布包保留它们的
兼容 runtime；默认类型提示不会把它们作为新作者入口。Script V1 的唯一默认入口是
`community_variant.script()` 和精简 manifest schema 3。

## Package Layout

Script V1 插件仍使用 `community_variant` 包结构：

```text
my-script-variant/
  manifest.json
  main.lua
  variant.json
  puzzle_bank.json
  i18n/
    en_us.json
    zh_cn.json
```

`manifest.json` 使用精简 manifest schema 3。Host 自动补齐 exact API 5、Lua
runtime、入口、固定权限/能力、标准资源路径、locale 和可选图标：

```json
{
  "manifestVersion": 3,
  "id": "author.my_script_variant",
  "name": "My Script Variant",
  "version": "0.1.0"
}
```

## Localization and package names

将每种语言写成 `i18n/<locale>.json` 的扁平 JSON 字符串表。公开包必须同时提供
`en_us` 和 `zh_cn`；其他语言
使用小写的两位或三位语言代码，并可加两位地区后缀，例如 `ja`、`pt_br`、`zh_cn`、
`zh_tw`。不要使用连字符、大小写混合、脚本名或自定义别名。

读取顺序是：精确 locale、已声明的语言级 locale、`en_us`。例如可同时提供
`pt_br.json` 和 `pt.json`；巴西葡语优先使用 `pt_br`，没有对应 key 时可继续使用
`pt`，最后回退到 `en_us`。简体中文使用 `zh_cn`，繁体中文使用 `zh_tw`。

名称分工必须稳定：

- `manifest.id`：永久技术标识，不翻译；
- `manifest.name`：稳定的包管理名称，不随 locale 变化；
- `variant.title`：玩家看到的玩法名称，每种语言可以翻译；
- `variant.description`、`rule.<handler>` 与 `rule_guide.*`：玩家规则文案，应使用该
  locale 的自然语言；
- localization key：跨语言保持相同 key，不为同一个概念创建 `*_zh`、`*_ja` 等
  locale 专用 key。

公开包必须提供 `i18n/en_us.json` 和 `i18n/zh_cn.json`。可选语言一旦声明，必须包含
与 `en_us.json` 相同的完整 key 集，并逐项翻译；不能以缺 key 的语言文件作为“已支持”
状态。Host 仍按精确 locale、语言级 locale、`en_us` 顺序解析，fallback 只用于运行时
容错，不代表翻译完成。保持 JSON value 为纯文本；规则指南只解释玩家规则，不要写入
实现、存档、候选或完成流程。App 的 i18n key 不属于 Mod 包，不能复制到 Mod JSON。

## Rule Registration

不要写一个全局 `if/elseif` 分发器。每种规则注册一个 handler，题目
`rules` 对象中的 key 激活对应 handler。handler 必须且只能选择：

- `define(config, scope)`：启动期返回 1..64 个 typed Constraint Program
  predicates 和可选棋盘标记；它们在开局固定后不再调用该 handler 的 Lua。
- `create(config, scope)`：创建私有 Rule Instance，通过 bounded Host runtime
  提供 validation、candidate observation 或 session feature。

`define` 仍然需要真实作者逻辑。可玩 reference 应从更小的 puzzle geometry/parameter
派生关系、约束或 Overlay；只把 puzzle 中已经完整成形的 operator 参数转交给一个
同名 helper，属于非可玩的 `operator_fixture`，不能算作 Mod/reference 完成证据。
一个可玩的包必须在 `main.lua` 中写出完整的规则推导或检查逻辑；不要只把题目中已经
准备好的完整参数转交给一个 helper。

可物化规则示例：

```lua
local plugin = community_variant.script()
local c = community_variant.constraint
local cell = community_variant.cell
local schema = community_variant.schema
local increasing_path = {}

function increasing_path.define(config, scope)
  schema.expect_exact_keys(config, { path = true }, "increasing_path")
  schema.expect_array(config.path, 2, 9, "increasing_path.path")
  local path = {}
  local seen = {}
  for index, raw_cell in ipairs(config.path) do
    local current = cell.expect(raw_cell, "increasing_path.path[" .. index .. "]")
    if seen[current] then error("increasing_path.path contains duplicates") end
    seen[current] = true
    path[index] = current
  end
  local constraints = {}
  for index = 1, #path - 1 do
    constraints[#constraints + 1] = c.less_than(
      c.value(path[index]),
      c.value(path[index + 1])
    )
  end
  return {
    constraints = constraints
  }
end

plugin:register_rule("increasing_path", increasing_path)
return plugin:build()
```

`define` 不能返回 board observations、候选、violations、mutable state 或 gameplay
callbacks，也不能与 `create` 出现在同一 handler。

动态索引使用 `constraint.element_at(cells, constraint.value(index_cell))`。首版只接受
9 个有序且不重复的 `0..80` 格子；索引格中的数字按 `1..9` 选择序列中的第 1..9
个位置。sequence 顺序属于规则语义，不能排序：

```lua
local c = community_variant.constraint
local selected = c.element_at(
  { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
  c.value(10)
)

return {
  constraints = {
    c.equal(selected, c.constant(9))
  }
}
```

当前 Community Host 只接受直接的
`equal(element_at(cells, value(index_cell)), constant(target))`，其中 target 为
`1..9`。不要把 `element_at` 放入 `sum`、`not_equal`、逻辑组合或另一个
`element_at`，也不要在 Lua/JSON 中填写 `element_value_equals_constant_v1` 等 Host
Runtime plan ID；不支持的组合会在 Gameplay 前结构化拒绝。完整参考见
`operator-fixtures/community-script-v1-dynamic-index/`。它是非可玩的 operator fixture，
不能作为完整玩法的 Author Logic 证据。

位置和值关系使用 `constraint.value_selected_pair_sum_equals_constant`。它接收一条
有序且不重复的九格序列、两个不同的 selector 格和固定目标值。两个 selector 格中的
数字按 `1..9` 选择序列位置，被选中的两个数字之和必须等于目标值；这个 predicate
只能直接放在 `define()` 返回的根 `constraints` 数组中：

```lua
local c = community_variant.constraint

return {
  constraints = {
    c.value_selected_pair_sum_equals_constant(
      { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
      10,
      11,
      17
    )
  }
}
```

不要在 Lua/JSON 中填写
`value_selected_pair_sum_equals_constant_v1`、Evidence、候选或 runtime plan ID。
Host 会在启动期校验、编译并物化该规则；作者仍负责从 puzzle-varying 数据推导
完整声明。完整通用验证参考见
`operator-fixtures/community-script-v1-value-selected-pair-sum/`，该 fixture
不是可玩的具名 Mod，也不占用玩法容量。

固定和值关系使用 `constraint.exact_sum_equals_constant`。它接收 `2..4` 个不同格和
一个固定目标；这些格中的数字之和必须等于目标。格顺序没有语义，SDK 会归一化排序。
该 predicate 只能直接放在 `define()` 返回的根 `constraints` 数组中：

```lua
local c = community_variant.constraint

return {
  constraints = {
    c.exact_sum_equals_constant({ 3, 1, 2, 0 }, 18)
  }
}
```

目标值必须在格数到 `9 * 格数` 的范围内；不支持嵌入 `and/or/not/count`、动态目标、
重复格、全异或负线索。一个 program 最多可声明八条此类根约束。不要填写
`exact_sum_equals_constant_interval_v1`、Evidence、候选或 runtime plan ID。完整
技术验证参考见
`operator-fixtures/community-script-v1-exact-sum-constant/`。它是非可玩的 operator
fixture，不是具名 Mod，也不代表任何现有 Mod 已获准采用该规则。

频次与多重集关系使用两个独立的 intent-level helper：

```lua
local c = community_variant.constraint

return {
  constraints = {
    c.self_referential_frequency(group_cells),
    c.multiset_equal(first_cells, second_cells)
  }
}
```

`self_referential_frequency` 接收 `1..9` 个唯一格子；每个出现的数字 `d` 必须恰好
出现 `d` 次，并包含承载该数字的格子。`multiset_equal` 接收两个长度相同、各含
`1..9` 个唯一格子且互不重叠的格组；两组数字位置可以不同，但每个数字的出现次数
必须相同。SDK 负责格子和可交换格组的 canonicalization。

两个 predicate 在 V1 中都只能直接出现在 `constraints` 根数组中，不得嵌入
`and/or/not/count` 或 expression。作者不得填写 `_group` wire operator、exact plan
ID、histogram、Evidence、候选或 runtime state。通用真实 Lua 参考见
`operator-fixtures/community-script-v1-self-referential-frequency/` 与
`operator-fixtures/community-script-v1-multiset-equality/`；单题仅用于技术验证，
不是具名玩法或正式题库。

需要 Script Runtime 时使用：

```lua
local plugin = community_variant.script()
local my_rule = {}

function my_rule.create(config, scope)
  local state = {
    config = config
  }

  return {
    validate_move = function(ctx, move)
      return {
        accepted = true,
        violations = {},
        diagnostics = {}
      }
    end,

    validate_board = function(ctx)
      return {
        violations = {},
        diagnostics = {}
      }
    end,

    validate_final_state = function(ctx)
      return {
        valid = true,
        violations = {},
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("my_rule", my_rule)

return plugin:build()
```

对应 puzzle：

```json
{
  "difficulty": 1,
  "puzzle": "000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "solution": "123456789456789123789123456214365897365897214897214365531642978642978531978531642",
  "rules": {
    "my_rule": {}
  }
}
```

`rules.<handler>` 的值就是传给该 handler 的 `define(config, scope)` 或
`create(config, scope)` 的 puzzle config。
Lua 可以把 config 转成私有闭包 state，Host 不会再把 `model` 传回 callback。
`solution` 是必填的 81 位完整答案，只能包含 `1..9`，并必须与 `puzzle` 的非零
提示一致。不要填写 `puzzleId`、空 `overlay` 或 `{id,data}` wrapper；
Host 会从 `puzzle + rules` 的 canonical hash 派生稳定题目 ID。

如果题目需要替换经典 3x3 宫，例如不规则区域拓扑，可以在同一道题上增加通用
`base_topology`：

```json
{
  "base_topology": {
    "type": "explicit_regions",
    "regions": [
      {"cells": [0, 1, 2, 10, 11, 12, 13, 19, 22]}
    ]
  }
}
```

`base_topology` 是 Host-native replacement topology 语义对象，不由 handler 名称或
package/content ID 触发。真实对象必须包含完整九个区域；上面的片段只展示字段形状。
Lua 仍然需要在自己的 handler 中实现作者可读的规则校验。

若玩法只保留行列唯一性并移除标准 3x3 宫，使用：

```lua
base_topology = { type = "row_column_only" }
```

这是完整的基础拓扑语义，不是空规则。`define` 可以返回该拓扑并让
`constraint_program.constraints` 为空；标准拓扑仍必须至少有一个约束。

### Rule Instance Lifecycle

本节只适用于 `create` handler。`define` handler 在 startup 编译完成后由 Native Rule
Runtime 独占执行，不存在 gameplay Rule Instance。

Host 在 exact Community session 初始化时，为题目中的每条 puzzle rule 调用一次
`create(config, scope)`。返回的私有 instance 会被同一 session 的 startup
`build_session_features` / `build_overlay` 以及 gameplay `validate_move`、
`validate_board`、`get_candidate_eliminations`、`validate_final_state` 共同复用。

因此 `create` 适合校验并归一化 immutable puzzle config、预计算 path/edge/cage
索引或建立只读 lookup。不要在 instance 中缓存某次 callback 的 `ctx.board`；Host 会为
每次 gameplay 调用传入当前棋盘快照。Runtime restart/recovery 会关闭旧 Lua Rule
Object 并创建一个新 session instance；shutdown/close 后旧 instance 不再使用。

Handler 顶层只允许互斥的 `define` 或 `create`。旧写法 `normalize`、`candidate_eliminations`、
`validate_completion`、`compile_overlay` 会被 Creator Validator / runtime 拒绝。

## Required Functions

| Function | Required | Purpose |
|---|---:|---|
| `define(config, scope)` | materialized handler only | 在 startup 返回 typed predicates 和可选 Overlay；与 `create` 互斥。 |
| `create(config, scope)` | runtime handler only | 在 exact session 初始化时为一个 puzzle rule 创建一次私有 Lua rule instance；与 `define` 互斥。 |
| `instance.validate_move(ctx, move)` | yes | 落子提交后校验本规则是否接受该 move。Lua 只返回反馈，不阻止 Host 输入事务。 |
| `instance.validate_board(ctx)` | yes | 扫描当前棋盘，返回本规则产生的违规 cells。 |
| `instance.validate_final_state(ctx)` | yes | 报告本规则在最终状态检查中是否 valid。Host 仍负责整局 completion。 |

## Optional Functions

| Function | Purpose |
|---|---|
| `instance.get_candidate_eliminations(ctx, cell, base_candidates)` | 返回要从 Host-owned candidates 中移除的数字。`base_candidates` 是本次请求要检查的数字列表；不能返回完整候选集合。 |
| `instance.build_overlay(ctx)` | 启动期返回声明式 overlay primitives。App 负责实际绘制、主题和布局，并缓存结果。 |

## Bounded Cell State Rules

`cell_state_rule` lets a `create` handler declare a fixed progressive-visibility
rule. Lua derives the complete immutable declaration in `main.lua`; puzzle JSON
may contain only initial hidden-cell geometry or another puzzle-varying bounded
parameter. The Host owns event delivery, input blocking, visibility state,
undo, restart, persistence, recovery and board projection.

Fog of War is the smallest reference: one `correct` placement reveals a king
radius-one area. A different Mod may derive one to four ordered transitions,
but every transition remains bounded to this vocabulary:

- event: `move.committed`;
- placement: `correct` or `any`;
- effect: `set_cell_state` to `visible` with `union` accumulation;
- selector: `move.cell`, expanded by `king` or `orthogonal` radius `0..2`;
- restart: `initial`.

Use package-local helpers to keep fixed gameplay semantics readable:

```lua
local function visibility_transition(placement, neighborhood, distance)
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
```

Do not add arbitrary events, state names, re-hide/replace effects, custom
selectors, Lua mutable state, painter callbacks, candidate ownership or Host
branches. A new named Mod still needs its own identity, capacity, content and
Host-audit delivery gates; copying Fog does not grant one.

## Data Model

`cell` 使用 0-based row-major index：

```text
r1c1 = 0
r1c9 = 8
r2c1 = 9
r9c9 = 80
```

常用转换：

```lua
local cell_api = community_variant.cell

local row = cell_api.row(cell)
local column = cell_api.column(cell)
local same_cell = cell_api.index(row, column)
```

`ctx.board.cells` 是 1-based Lua row/col table，空格是 `0`。标量读取请通过 SDK：

```lua
local board = community_variant.board
local digit = board.value(ctx, cell)
local empty = board.is_empty(digit)
```

## Low-Level SDK Utilities

Script V1 提供六组变体无关的底层工具。它们只读取 Host 的不可变快照、校验作者
数据或归一化基础几何标识与坐标点，不判断任何具体玩法，也不会生成 callback、
Rule IR 或 Overlay IR：

| Namespace | Function | Purpose |
|---|---|---|
| `community_variant.board` | `value(ctx, cell)` | 读取 0-based cell 对应的 `0..9` 棋盘数字。 |
| `community_variant.board` | `is_empty(value)` | 判断值是否为 `nil` 或 `0`。 |
| `community_variant.cell` | `expect(value, name?)` | 校验并返回 `0..80` 的整数 cell。 |
| `community_variant.cell` | `row(cell)` / `column(cell)` | 返回 `0..8` 的行列。 |
| `community_variant.cell` | `index(row, column)` | 把 0-based 行列转换为 cell。 |
| `community_variant.schema` | `expect_integer(value, name?)` | 校验并返回整数。 |
| `community_variant.schema` | `expect_array(value, min, max, name?)` | 校验有界 dense array。 |
| `community_variant.schema` | `expect_exact_keys(value, allowed, name?)` | 拒绝 object 中未声明的字段。 |
| `community_variant.adjacency` | `orthogonal(first, second)` | 判断两个格子是否共享一条边。 |
| `community_variant.adjacency` | `eight_way(first, second)` | 判断两个不同格子是否横、竖或对角相邻。 |
| `community_variant.path` | `edge_key(first, second)` | 为两个不同格子生成不区分方向的稳定 edge key。 |
| `community_variant.path` | `canonical_key(cells)` | 为 dense cell path 生成正向/反向等价的稳定 key。 |
| `community_variant.overlay_geometry` | `cell_center(cell)` | 把一个 cell 转换为 Overlay 棋盘坐标中的格心 `{x, y}`。 |
| `community_variant.overlay_geometry` | `cell_centers(cells)` | 按原顺序把 `1..64` 个 dense cells 转换为格心数组；保留重复格。 |
| `community_variant.overlay_geometry` | `edge_center(first, second)` | 返回两个不同且正交相邻格子的公共边中心 `{x, y}`。 |

`ctx.board.cells[row][col]` 仍是稳定、公开、只读的 Lua API，第三方 Mod 可以直接读取。
仓库自带的可玩 reference 承担 SDK 示范责任：新建或修改时，标量读值、空格判断和 cell
校验分别使用 `board.value`、`board.is_empty` 和 `cell.expect`，不要在 package 内复制兼容
一维/字符串键的 board adapter 或基础范围校验。为了遍历完整行列或比较不可变 board
snapshot 身份而直接访问 table 仍然允许。旧 reference 在下次修改时迁移，不因尚未迁移
而失去可玩状态。

`community_variant.constraint.equal(left, right)` 与 `not_equal(left, right)` 会自动排列
交换律操作数。`less_than`、`less_than_or_equal`、`greater_than`、
`greater_than_or_equal` 保留作者表达的数学方向；如果 canonical expression order 需要
交换操作数，SDK 会同时反转 less/greater 操作符。Script V1 `define` 返回的根 predicates
也由 builder 统一排序。作者不得在玩法脚本里复制 Host 的 expression-key 或 root 排序。

`schema.expect_exact_keys` 的 `allowed` 使用 key 到 `true` 的 table：

```lua
local schema = community_variant.schema
local cell_api = community_variant.cell

schema.expect_exact_keys(config, { paths = true }, "config")
schema.expect_array(config.paths, 1, 16, "config.paths")

for index, raw_cell in ipairs(config.paths[1]) do
  local cell = cell_api.expect(raw_cell, "path[" .. index .. "]")
end
```

邻接与 path key helper 会校验所有 cell 都是 `0..80` 的整数。它们不会替 Mod
决定 path 长度、格子是否可重复、线段能否相交，或某种邻接关系对应什么规则：

```lua
local adjacency = community_variant.adjacency
local path = community_variant.path

if not adjacency.eight_way(cells[index - 1], cells[index]) then
  error("line must pass through adjacent cell centers")
end

local identity = path.canonical_key(cells)
```

Overlay geometry helper 只返回现有 Overlay IR 使用的棋盘坐标点，不创建 circle、
polyline 等 primitive，也不决定线宽、颜色或玩法语义：

```lua
local geometry = community_variant.overlay_geometry

local path_points = geometry.cell_centers(line_cells)
local mark_center = geometry.edge_center(first_cell, second_cell)
```

`cell_center` 与 `edge_center` 返回新的 `{x, y}` table；`cell_centers` 返回新的
dense point array，并保持输入顺序和重复项。所有 cell 必须是 `0..80` 的整数，
`edge_center` 的两个 cell 必须共享一条边。

这些工具属于 SDK substrate，不是玩法 DSL。SDK 不提供 `thermometer(path)`、
`fog(cells)`、`killer(cage)` 等具名玩法助手；具体规则的 partial-board、候选、冲突和
完成语义仍应清晰地写在该 Mod 的 `main.lua` 中。

`move`：

```lua
{
  cell = 32,
  digit = 7
}
```

`digit` 范围是 `1..9`。清除输入可能以 `0` 表示；规则一般只需要忽略 `0`。

## Return Shapes

`validate_move`：

```lua
return {
  accepted = false,
  violations = {
    {
      code = "my_rule_broken",
      cells = { 12, 21 }
    }
  },
  diagnostics = {}
}
```

`validate_board`：

```lua
return {
  violations = {
    {
      code = "my_rule_broken",
      cells = { 12, 21 }
    }
  },
  diagnostics = {}
}
```

`get_candidate_eliminations` 可只处理 `base_candidates` 中给出的数字：

```lua
return {
  remove = { 5, 8 },
  reasons = {
    ["5"] = "my_rule_broken",
    ["8"] = "my_rule_broken"
  },
  diagnostics = {}
}
```

`validate_final_state`：

```lua
return {
  valid = false,
  violations = {
    {
      code = "my_rule_broken",
      cells = { 12, 21 }
    }
  },
  diagnostics = {}
}
```

`build_overlay`：

```lua
return {
  primitives = {
    {
      type = "line",
      from = { x = 0, y = 0 },
      to = { x = 9, y = 9 },
      paint = {
        stroke = { theme = "constraint_line" },
        stroke_width = 0.04
      }
    }
  }
}
```

行列边界数字提示使用 Host-owned `boundary_label` built-in。`side` 可省略；省略时行提示
位于左边界、列提示位于上边界。行只允许 `left/right`，列只允许 `top/bottom`，且不会
改变棋盘尺寸：

```lua
{
  type = "builtin",
  kind = "boundary_label",
  data = {
    axis = "row",  -- row / column
    side = "right", -- optional: left/right for row, top/bottom for column
    index = 4,      -- 0..8
    label = "18"   -- decimal 0..45
  }
}
```

Host 会把提示圆心画在完整 9x9 棋盘的指定边界上，不缩放、平移棋盘。提示只读且不参与
规则判断；Lua handler 仍须独立实现对应的 validation、candidate 和 final-state 语义。

棋盘外斜线数字提示使用 Host-owned `outside_ray_clue` built-in。它只表达“哪个边界入口、
朝哪个绝对斜向、显示哪个整数”，不实现射线上数字的关系：

```lua
{
  type = "builtin",
  kind = "outside_ray_clue",
  data = {
    entry = {
      side = "top", -- top / right / bottom / left
      index = 3      -- 0..8；上下为列，左右为行
    },
    direction = "down_right",
    value = 23       -- integer 1..81
  }
}
```

`direction` 使用不随入口改变的棋盘绝对方向，并且必须从入口指向棋盘内部：

| `entry.side` | 合法 `direction` |
|---|---|
| `top` | `down_left`、`down_right` |
| `right` | `up_left`、`down_left` |
| `bottom` | `up_left`、`up_right` |
| `left` | `up_right`、`down_right` |

第一格就是 `entry` 指向的边界格，之后沿该方向延伸到离开棋盘。一次编译最多包含 16 个
`outside_ray_clue`。同一入口或相同完整射线会拒绝 Overlay；相邻线索可能在视觉上靠近，
但不会因为绘制范围接近而阻断会话启动。不同射线可以经过相同格子。该 built-in 不接受 `style`、任意坐标、箭头长度或绘制参数，
数字、圆形背景、短箭头、主题色和棋盘外间距全部由 Host 决定。
短箭头沿归一化射线中心线绘制在棋盘外，尖端停在实际棋盘边界入口，不进入第一格。

Lua handler 必须从同一份已归一化 clue 数据推导射线格子，并独立实现该玩法的 move、
board、candidate 和 final-state 语义。仅发出 `outside_ray_clue` 不会创建或启用任何数独
规则。

Overlay `opacity` 的通用合法范围是 `0..1`。只有覆盖格子或区域的 fill 规则限制为
不高于 `0.6`；边、棋盘边界、路径、轮廓和文字规则不受该 `0.6` 上限约束。不要为了
某个格子填充规则而给整个 package 的所有 primitive 设置同一上限。

## Authority Boundary

Lua 可以做：

- 读取当前 board snapshot；
- 校验规则；
- 返回 violation cells；
- 返回候选移除建议；
- 返回声明式 overlay；
- 返回作者诊断。

Lua 不可以做：

- 修改棋盘；
- 阻止或回滚 Host move transaction；
- 替换完整候选集合；
- 修改笔记；
- 写存档；
- 控制 UI；
- 控制完成导航；
- 访问文件、网络、时间、随机数或 native library；
- 解锁官方成就或写官方进度。

## Package checks

Before sharing a package, make sure every declared puzzle has an 81-digit
solution, preserves its given digits, and supplies only the rule data that
`main.lua` expects. A malformed rule configuration should raise a clear Lua
error during initialization rather than silently changing the rule.

## Reference Examples

### 推荐模板

先从下面四个当前 SDK 合规的包开始，不要按字母顺序从历史包复制：

| 目标 | 推荐 package | Handler | 关键能力 |
|---|---|---|---|
| 解题过程中检查的规则 | `examples/community-script-v1-fortress/` | `create` | 从 geometry 派生邻域，并给出检查和候选移除。 |
| 开局固定的规则 | `examples/community-script-v1-159-sudoku/` | `define` | 从包级语义派生 typed predicates。 |
| 每题路径派生 | `examples/community-script-v1-region-sum-lines/` | `define` | schema 校验、path normalization 和路径标记。 |
| 区域映射 | `examples/community-script-v1-same-values/` | `define` | 带标签的几何、canonical relation 和区域标记。 |

SDK 首页按五种玩家可见的规则形状列出全部公开可玩示例。先从同一规则形状中选择最接近
的包，再阅读其 `main.lua`、`variant.json`、题库和本说明。

`operator-fixtures/` 中的通用运算符例子只说明语法，不是可玩的 Mod 模板。

所有当前 reference 都使用 `community_variant.board`、`community_variant.cell` 和
`community_variant.schema`。新建或修改 package 时沿用这些 SDK helpers；不要自行复制
多种索引形状的 `board_value`、`is_empty` 或 `expect_cell` adapter。

## Common Mistakes

| 错误 | 正确做法 |
|---|---|
| 使用 `community_variant.new()` 或 `constraint_program()` | 新 Script V1 package 始终从 `community_variant.script()` 开始。 |
| 在 manifest 中手填 API、runtime、entry 或 permissions | 使用只有 `manifestVersion: 3`、`id`、`name`、`version` 的精简 manifest。 |
| 一个 handler 同时写 `define` 与 `create` | 选择一个 execution profile；启动期物化用 `define`，每步观察用 `create`。 |
| 自己兼容 `ctx.board.cells` 的数组、字符串键和索引方式 | 标量读值用 `board.value(ctx, cell)`，空格判断用 `board.is_empty`，输入格校验用 `cell.expect`。 |
| `candidate_scope()` 返回 puzzle JSON 里的任意格子 | 从归一化后的规则 geometry 派生不可变的受影响格上界。 |
| `get_candidate_eliminations` 返回完整候选集 | 只返回需要从 Host 候选中移除的数字。 |
| 所有 Overlay 都把 opacity 限制为 `0.6` | 只有 cell/region fill 不超过 `0.6`；线、轮廓和文字可使用自己的合法 opacity。 |

`community-script-v1-jigsaw/` 展示不规则区域和区域边界标记。每道题的
`base_topology` 数据定义九个区域，用来替代经典 3x3 宫；每个区域只需要 `cells` 列表，
省略 `id` 时会得到稳定的区域标识。
