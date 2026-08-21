# Community Variant Script API V1 作者指南

[English](community-script-v1-author-guide.md)

本指南面向希望制作可玩的 MeetSudoku 变形数独的作者。作者提供规则语义、可选的棋盘标记、题目数据和面向玩家的翻译；游戏负责通用棋盘、输入、撤销、笔记、冲突显示、存档、进度和完成流程。

`variant.json.ruleGuide` 是玩家看到的文字。它只能解释题目规则、可见标记，以及玩家需要比较或推断的内容。不要把 Host、App、Lua、候选数、存档、完成流程、UI 或实现细节写入 `rule_guide.item_*`；这些内容属于本作者指南。

## 五分钟开始

1. 按玩家可见的规则形状选择最接近你想法的公开示例。使用 `examples/` 中的完整包，不要使用运算符 fixture 或非公开技术包。
2. 复制示例的包结构，修改稳定的 `manifest.id`、`manifest.name`、版本号、玩家标题、描述、规则指南和题目数据。
3. 在 `main.lua` 中保留 `community_variant.script()`。每个已注册规则只能选择一个 handler：启动期物化使用 `define(config, scope)`，有界运行时校验和观察使用 `create(config, scope)`。
4. 将不随题目变化的规则含义和全部推导写入 `main.lua`，只把随题目变化的几何或参数放入 `rules.<handler>`。
5. 每道题都提供 81 个字符的 `puzzle`、81 个字符的 `solution`，以及 handler 需要的配置。加入两个必需语言文件，然后使用 App 的本地插件预览，再进行发布。

新包不得使用 `community_variant.new()`、`community_variant.constraint_program()`、`normalize/compile_rules` 或 manifest v2 字段。API 1-4 仅作为旧包的只读兼容输入。当前作者契约是 Script V1、manifest schema 3 和 exact API 5。

## 包结构

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

最小 manifest 如下：

```json
{
  "manifestVersion": 3,
  "id": "author.my_script_variant",
  "name": "My Script Variant",
  "version": "0.1.0"
}
```

游戏会根据这份契约推导固定 API、运行时、入口、权限、标准资源路径、语言处理和可选图标元数据。作者不需要手写旧版运行时或权限字段。

## 选择示例

使用 SDK 首页查看完整的能力导航。以下四个公开包适合作为起点：

| 作者目标 | 起始包 | 展示内容 |
|---|---|---|
| 开局时固定的规则 | `community-script-v1-159-sudoku/` | `define`、schema 校验，以及从题目数据推导 typed constraints。 |
| 游戏过程中检查的规则 | `community-script-v1-fortress/` | `create`、校验、候选数范围和有界 overlay。 |
| 路径与数字关系 | `community-script-v1-region-sum-lines/` | 路径归一化、规则推导和路径标记。 |
| 非标准棋盘拓扑 | `community-script-v1-jigsaw/` | 随题目变化的区域和替代拓扑数据。 |

`operator-fixtures/` 只用于展示通用语法，不是可玩的变形数独，也不能作为公开 Mod 的起始模板。

## 多语言与命名

将每种语言写成 `i18n/<locale>.json` 的扁平 JSON 字符串表。公开包必须提供 `i18n/en_us.json` 和 `i18n/zh_cn.json`。可选语言文件名使用小写语言代码和可选地区代码，例如 `ja.json`、`pt_br.json` 和 `zh_tw.json`。不要使用连字符、大小写混合、脚本名称或私有别名。

运行时按精确 locale、已声明的纯语言 locale、`en_us` 的顺序查找。已声明的语言必须包含与 `en_us` 完全相同的 key 集；回退只代表运行时容错，不能证明该语言已经完成翻译。

名称保持稳定：

- `manifest.id` 是永久技术标识，永远不翻译。
- `manifest.name` 是稳定的包管理名称，不随语言改变。
- `variant.title` 是玩家看到的标题，可以按语言翻译。
- `variant.description`、`rule.<handler>` 和 `rule_guide.*` 是对应语言的玩家文案。
- 各语言的 localization key 必须保持一致，不要创建 `variant.title_zh` 或 `variant.title_ja` 这样的 key。

规则指南只解释玩家规则。App 的翻译 key 不属于 Mod 包。

## 注册规则

每种规则注册一个 handler，不要编写全局 `if/elseif` 分发器。题目 `rules` 对象中的 key 会激活对应 handler。每个 handler 只能选择一种执行形状：

- `define(config, scope)` 返回 typed constraint 谓词和可选的启动标记；该 handler 在游戏过程中不会再次调用。
- `create(config, scope)` 返回私有 Rule Instance，用于有界校验、候选数观察和 session feature。

可玩的参考包必须包含实质性的作者逻辑。它应该从归一化的题目数据推导关系、几何、约束、状态转换或标记。把题目 JSON 中已经完整的运算符参数直接转交给一个游戏辅助函数，属于 `operator_fixture`，不是可玩的参考包。

### 可物化规则

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
  return { constraints = constraints }
end

plugin:register_rule("increasing_path", increasing_path)
return plugin:build()
```

`define` 不能返回棋盘观察结果、候选数、违规项、可变状态或游戏回调，也不能在同一 handler 中与 `create` 同时出现。

### 运行时规则

```lua
local plugin = community_variant.script()
local my_rule = {}

function my_rule.create(config, scope)
  local state = { config = config }

  return {
    validate_move = function(ctx, move)
      return { accepted = true, violations = {}, diagnostics = {} }
    end,

    validate_board = function(ctx)
      return { violations = {}, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      return { valid = true, violations = {}, diagnostics = {} }
    end,
  }
end

plugin:register_rule("my_rule", my_rule)
return plugin:build()
```

对应的题目只包含变化数据：

```json
{
  "difficulty": 1,
  "puzzle": "000000000000000000000000000000000000000000000000000000000000000000000000000000000",
  "solution": "123456789456789123789123456214365897365897214897214365531642978642978531978531642",
  "rules": { "my_rule": {} }
}
```

`solution` 始终必填，只能包含数字 `1..9`，并且必须保留 `puzzle` 中所有非零提示。不要添加 `puzzleId` 或 `{id,data}` 包装；游戏会从规范化的题目和规则派生稳定的题目身份。

## 规则实例生命周期

本节只适用于 `create`。游戏在精确 session 启动期间为每个规则条目调用一次 `create`。返回的私有实例会被启动阶段的 feature 和标记构建，以及游戏过程中的 `validate_move`、`validate_board`、`get_candidate_eliminations` 和 `validate_final_state` 复用。

使用 `create` 校验并归一化不可变的题目数据，预计算路径、边或笼，建立只读查找表。不要缓存回调中的 `ctx.board`；每次回调都会收到当前的不可变棋盘快照。重启和恢复会创建新实例；关闭后不能继续使用旧实例。

Script V1 会拒绝旧的顶层名称 `normalize`、`candidate_eliminations`、`validate_completion` 和 `compile_overlay`。

## 必需与可选函数

| 函数 | 是否必需 | 用途 |
|---|---:|---|
| `define(config, scope)` | 物化规则 | 返回 typed predicates 和可选的启动标记。 |
| `create(config, scope)` | 运行时规则 | 为一道题中的一个规则创建一个私有 Rule Instance。 |
| `instance.validate_move(ctx, move)` | 是 | 报告本规则是否接受提交的落子。 |
| `instance.validate_board(ctx)` | 是 | 报告当前违规项。 |
| `instance.validate_final_state(ctx)` | 是 | 报告最终状态检查时本规则是否有效。 |

可选函数：

| 函数 | 用途 |
|---|---|
| `instance.get_candidate_eliminations(ctx, cell, base_candidates)` | 只返回需要从 Host 候选数集合中移除的数字。 |
| `instance.build_overlay(ctx)` | 返回只声明标记的棋盘覆盖层。App 负责绘制、主题和布局。 |

`move` 包含从 0 开始的 cell 和 `1..9` 的数字；清除输入可以使用 `0`。

## 有界格状态规则

`cell_state_rule` 提供有界的渐进可见性规则。Lua 在 `main.lua` 中派生完整且不可变的声明；题目 JSON 只能包含初始隐藏格几何或其他随题变化的有界参数。游戏负责事件投递、输入阻止、可见性状态、撤销、重启、持久化、恢复和棋盘投影。

战争迷雾示例用一次 `correct` 落子揭示国王距离一格的区域。其他包可以派生一到四个有序转换，但公开词汇保持不变：

- 事件：`move.committed`；
- 落子条件：`correct` 或 `any`；
- 效果：将格状态设为 `visible`，并使用 `union` 累积；
- 选择器：`move.cell`，按 `king` 或 `orthogonal` 扩展，半径为 `0..2`；
- 重启：`initial`。

不要添加任意事件、状态名、重新隐藏效果、自定义选择器、Lua 可变状态、绘制回调、候选数所有权或包 ID 分支。新的具名 Mod 仍然需要独立的身份和产品准入。

## 数据模型与 SDK 工具

格子使用从 0 开始的行优先索引：

```text
r1c1 = 0   r1c9 = 8
r2c1 = 9   r9c9 = 80
```

标量读取和校验请使用 SDK 辅助工具：

```lua
local board = community_variant.board
local cell = community_variant.cell
local digit = board.value(ctx, current_cell)
local empty = board.is_empty(digit)
local checked_cell = cell.expect(raw_cell, "path cell")
```

公开命名空间包括 `board`、`cell`、`schema`、`adjacency`、`path` 和 `overlay_geometry`。它们用于校验有界几何、计算行列和边的身份，以及把格子转换成已有的棋盘坐标；不会提供 `thermometer(path)` 或 `killer(cage)` 这样的具名玩法助手。完整规则仍应清楚地写在 `main.lua` 中。

`ctx.board.cells[row][col]` 仍是只读的公开表，可用于有意的有限遍历或快照身份检查。不要为标量读取、空格判断或格子范围校验复制私有适配器。

## 约束示例

动态序列选择使用 `constraint.element_at(cells, constraint.value(index_cell))`。序列必须包含九个有序、互不相同且位于 `0..80` 的格子；选择器数字选择第 `1..9` 个位置。顺序属于语义，不能排序。

```lua
local c = community_variant.constraint
local selected = c.element_at(
  { 0, 1, 2, 3, 4, 5, 6, 7, 8 },
  c.value(10)
)

return { constraints = { c.equal(selected, c.constant(9)) } }
```

当前契约只接受直接形式 `equal(element_at(cells, value(index_cell)), constant(target))`。不要把 `element_at` 嵌套在 `sum`、`not_equal`、逻辑运算符或另一个 `element_at` 中，也不要在 Lua 或 JSON 中写入内部运行时计划 ID。

位置选值的两数之和使用 `constraint.value_selected_pair_sum_equals_constant`。它接受一条有序的九格序列、两个不同的选择器格和一个固定目标；两个被选中的数字之和必须等于该目标，谓词必须直接位于根 `constraints` 数组中。

固定和值使用 `constraint.exact_sum_equals_constant`，接收 `2..4` 个不同格和一个目标值。格子顺序没有意义，由 SDK 规范化排序。目标值必须位于格子数量到格子数量乘以九之间。

频次和多重集关系使用 `self_referential_frequency(group_cells)` 与 `multiset_equal(first_cells, second_cells)` 这两个意图级辅助函数。两者都必须直接放在根 `constraints` 数组中。不要写 wire operator ID、Evidence、histogram、候选状态或运行时计划 ID。

## 覆盖层返回结构

`build_overlay` 返回只声明标记的图元，例如：

```lua
return {
  primitives = {
    {
      type = "line",
      from = { x = 0, y = 0 },
      to = { x = 9, y = 9 },
      paint = { stroke = { theme = "constraint_line" }, stroke_width = 0.04 },
    },
  },
  diagnostics = {},
}
```

使用内置的 `boundary_label` 显示行列边缘数字，使用 `outside_ray_clue` 显示从棋盘边缘进入的线索。这些内置项只描述标记；Lua handler 仍必须独立实现相应的校验和最终状态规则。

覆盖层的不透明度通常为 `0..1`。格子和区域填充上限为 `0.6`；线、路径、轮廓和文字不受此填充上限限制。

## 返回值结构

```lua
-- validate_move
return {
  accepted = false,
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}

-- validate_board
return {
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}

-- get_candidate_eliminations
return {
  remove = { 5, 8 },
  reasons = { ["5"] = "my_rule_broken", ["8"] = "my_rule_broken" },
  diagnostics = {},
}

-- validate_final_state
return {
  valid = false,
  violations = { { code = "my_rule_broken", cells = { 12, 21 } } },
  diagnostics = {},
}
```

## 职责边界

Lua 可以读取不可变的棋盘快照、校验规则、报告违规格、建议移除候选数、返回只声明标记，以及返回作者诊断。

Lua 不可以修改棋盘、阻止或回滚 Host 事务、替换完整候选数集合、编辑笔记、写存档、控制 UI 或完成导航、访问文件/网络/时间/随机数/native library，也不能写入官方成就、统计或进度。

## 包检查与发布

分享包之前，检查每道题都有 81 位答案、保留题目提示，并且只提供 `main.lua` 需要的规则数据。格式错误的配置应抛出清晰的初始化错误，而不是静默改变规则。先使用 App 的本地插件预览测试包，再把同一份已验证包发布到 Steam 创意工坊。

## 常见错误

| 错误 | 正确做法 |
|---|---|
| 从 `community_variant.new()` 或 `constraint_program()` 开始 | 从 `community_variant.script()` 和 Script V1 开始。 |
| 在 manifest 中手写 API、runtime 或 permission 字段 | 使用只包含稳定包字段的 manifest schema 3。 |
| 在一个 handler 中混用 `define` 和 `create` | 选择一种执行形状。 |
| 复制私有 board adapter | 使用 `board.value`、`board.is_empty` 和 `cell.expect`。 |
| 把固定规则含义放入题目 JSON | 在 `main.lua` 中推导固定语义，让 JSON 只保存随题变化的数据。 |
| 返回完整候选数集合 | 只返回需要移除的数字。 |
| 把所有填充 opacity 都设为 `0.6` | 只对格子或区域填充应用 `0.6` 上限。 |
| 把运算符 fixture 当成可玩的 Mod | 使用包含实质 Lua 逻辑的完整公开示例。 |

如需查看完整公开清单和最接近的玩家规则起点，请返回 [SDK 首页](README.zh-CN.md)。
