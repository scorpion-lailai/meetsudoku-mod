# MeetSudoku Plugin SDK

[English](README.md)

Community Variant Script API V1 让作者通过 `main.lua`、题目数据和可选棋盘标记创建
变形数独。公开的包结构与 Lua/JSON 契约见[中文作者指南](community-script-v1-author-guide.zh-CN.md)，
也可以阅读[英文作者指南](community-script-v1-author-guide.md)。

## MeetSudoku 与 Steam 创意工坊

本 SDK 用于编写可玩的 MeetSudoku 变形数独 Mod。你可以在[MeetSudoku Steam 创意工坊](https://steamcommunity.com/app/4932400/workshop/)浏览和订阅已发布的 Mod。

## 最小实现模型

一个可玩的变形数独只需要三部分：完整的规则实现、规则对应的可视化覆盖层，以及题库。
不需要修改 MeetSudoku 应用本身。

- `main.lua` 是唯一的规则入口，负责规则解析、落子校验、候选数校验、完成状态校验和
  覆盖层生成。
- `puzzle_bank.json` 提供 81 格题目、答案，以及每道题变化的几何或数值参数。
- `variant.json` 声明关卡和每日数独入口；`manifest.json` 标识包；`i18n/` 提供玩家可见
  的多语言文案。

固定的规则含义和所有规则推导都必须放在 `main.lua` 中；JSON 只是数据，不是第二套规则语言。
建议从 `examples/` 中最接近的公开包开始，并将该变形数独的完整逻辑保留在自己的 `main.lua`。

## 包图标

如果希望 Mod 在 MeetSudoku 中显示自己的图标，可以在包根目录放置可选的
`icon.png`。它必须是有效的正方形 PNG，尺寸不超过 `1024 x 1024`，文件不超过
`4 MiB`。当前 Script V1 会自动发现这个固定的根目录文件名；精简的
`manifest.json` 不要增加 `icon` 字段。

包图标与 Steam 创意工坊的 `previewfile` 不同：包图标随 Mod 一起提供，并由 App
复用于插件列表、闯关和每日数独入口；Workshop 预览图是上传到 Steam 页面上的图片。
图标缺失或无法解码时，MeetSudoku 会回退到 App Logo。

## 五分钟开始

1. 从下面的公开示例中选择最接近玩家看到的规则形状。
2. 复制完整包结构，修改稳定身份和玩家可见的多语言文案。
3. 将固定的完整规则逻辑保留在 `main.lua` 中。
4. 只在 `puzzle_bank.json` 中填写每道题变化的几何或数值。
5. 提供 `en_us` 和 `zh_cn`，在应用的插件预览中验证后，再发布到 Steam 创意工坊。

### 最小包结构

```text
my-variant/
  manifest.json
  main.lua
  variant.json
  puzzle_bank.json
  icon.png              # 可选，MeetSudoku 内显示的正方形 PNG 图标
  i18n/
    en_us.json
    zh_cn.json
```

### 关键代码形态

下面是一个真实公开包的精简代码形态。正式实现还必须完成配置规范化与校验、所有必需的
运行时接口，并统一返回诊断信息。

```lua
local plugin = community_variant.script()
local board = community_variant.board
local overlay_geometry = community_variant.overlay_geometry

local rule = {}

function rule.create(config, scope)
  local marks = normalize_marks(config) -- 完整的变形数独规则校验

  return {
    validate_move = function(ctx, move)
      local violations = find_violations(marks, ctx, move.cell, move.digit)
      return { accepted = #violations == 0, violations = violations, diagnostics = {} }
    end,

    validate_final_state = function(ctx)
      local violations = find_violations(marks, ctx, nil, nil)
      return { valid = #violations == 0, violations = violations, diagnostics = {} }
    end,

    build_overlay = function(ctx)
      return {
        primitives = build_mark_primitives(marks, overlay_geometry),
        diagnostics = {}
      }
    end
  }
end

plugin:register_rule("my_rule", rule)
return plugin:build()
```

对应的题库只提供每道题变化的数值或几何数据：

```json
{
  "rules": {
    "my_rule": {
      "marks": [{ "cells": [0, 1] }, { "cells": [9, 18] }]
    }
  }
}
```

### 分享前检查

- 使用 manifest schema 3 和公开的 Community Script API V1。
- 所有规则、候选数、完成状态和覆盖层逻辑都在 `main.lua` 中。
- 提供完整的 `en_us` 和 `zh_cn`，其他语言遵循下面的命名规范。
- 每道题都包含 81 位的 `puzzle` 和 `solution`。
- 发布 Steam 创意工坊前，先使用应用提供的包校验和插件预览。
- 如果规则形状相近，优先从已有公开示例开始扩展。

<!-- GENERATED:capability-navigation:start -->
## 选择起始示例

选择最接近你希望玩家看到的规则形状的示例。

| 你想实现什么 | 从这里开始 | 原因 |
|---|---|---|
| 开局固定的规则 | [`159 数独`](examples/community-script-v1-159-sudoku/) | 从少量题目数据派生一个全局固定规则。 |
| 解题过程中检查的规则 | [`堡垒数独`](examples/community-script-v1-fortress/) | 在玩家落子时校验局部关系。 |
| 自定义区域或棋盘布局 | [`锯齿宫数独`](examples/community-script-v1-jigsaw/) | 描述区域或非标准棋盘布局。 |
| 提示、标签或视觉引导 | [`数字房间`](examples/community-script-v1-numbered-rooms/) | 把题目自有的提示数据转成规则与标记。 |
| 解题过程中变化的格子 | [`战争迷雾数独`](examples/community-script-v1-fog-of-war/) | 描述由规则驱动且范围受限的格子变化。 |

## 按规则形状浏览

每个公开可玩参考只出现一次，并按最适合作为作者起点的规则形状归类。

### 棋盘布局与关联区域

[`星形数独`](examples/community-script-v1-asterisk/) ·
[`克隆数独`](examples/community-script-v1-clone/) ·
[`计数圆圈数独`](examples/community-script-v1-counting-circles/) ·
[`对角线数独`](examples/community-script-v1-diagonal/) ·
[`不相交组数独`](examples/community-script-v1-disjoint-groups/) ·
[`锯齿宫数独`](examples/community-script-v1-jigsaw/) ·
[`魔方阵数独`](examples/community-script-v1-magic-square/) ·
[`无宫数独`](examples/community-script-v1-no-boxes/) ·
[`同值区域`](examples/community-script-v1-same-values/) ·
[`窗口数独`](examples/community-script-v1-windoku/)

### 格、邻域与成对关系

[`反国王数独`](examples/community-script-v1-anti-king/) ·
[`反骑士数独`](examples/community-script-v1-anti-knight/) ·
[`反曼哈顿距离数独`](examples/community-script-v1-anti-taxicab/) ·
[`反 XV 数独`](examples/community-script-v1-anti-xv/) ·
[`巴腾堡数独`](examples/community-script-v1-battenburg/) ·
[`合数数独`](examples/community-script-v1-composite/) ·
[`熵数独`](examples/community-script-v1-entropy/) ·
[`堡垒数独`](examples/community-script-v1-fortress/) ·
[`友好数独`](examples/community-script-v1-friendly-sudoku/) ·
[`极值数独`](examples/community-script-v1-minmax/) ·
[`非连续数独`](examples/community-script-v1-non-consecutive/) ·
[`奇偶数独`](examples/community-script-v1-odd-even/) ·
[`质数数独`](examples/community-script-v1-prime/) ·
[`重复邻居数独`](examples/community-script-v1-repeated-neighbours/)

### 提示、标签与数字条件

[`159 数独`](examples/community-script-v1-159-sudoku/) ·
[`连续数独`](examples/community-script-v1-consecutive/) ·
[`数比数独`](examples/community-script-v1-greater-than/) ·
[`交点和值数独`](examples/community-script-v1-intersection-sum/) ·
[`黑白点数独`](examples/community-script-v1-kropki/) ·
[`小杀手数独`](examples/community-script-v1-little-killer/) ·
[`数字房间`](examples/community-script-v1-numbered-rooms/) ·
[`位置和值数独`](examples/community-script-v1-position-sums/) ·
[`四数提示数独`](examples/community-script-v1-quadruple/) ·
[`三明治数独`](examples/community-script-v1-sandwich/) ·
[`摩天楼数独`](examples/community-script-v1-skyscraper/) ·
[`X 和值数独`](examples/community-script-v1-x-sums/) ·
[`XV 数独`](examples/community-script-v1-xv/)

### 路径与有序序列

[`箭头数独`](examples/community-script-v1-arrow/) ·
[`箭头温度计数独`](examples/community-script-v1-arrow-thermometer/) ·
[`线间数独`](examples/community-script-v1-between-lines/) ·
[`荷兰耳语数独`](examples/community-script-v1-dutch-whispers/) ·
[`德国耳语数独`](examples/community-script-v1-german-whispers/) ·
[`封锁线数独`](examples/community-script-v1-lockout-lines/) ·
[`模数线数独`](examples/community-script-v1-modular-lines/) ·
[`回文数独`](examples/community-script-v1-palindrome/) ·
[`区域和值线`](examples/community-script-v1-region-sum-lines/) ·
[`连数线数独`](examples/community-script-v1-renban/) ·
[`温度计数独`](examples/community-script-v1-thermometer/) ·
[`拉链线数独`](examples/community-script-v1-zipper-lines/)

### 解题过程中变化的棋盘状态

[`信标数独`](examples/community-script-v1-beacon-sudoku/) ·
[`战争迷雾数独`](examples/community-script-v1-fog-of-war/)

<!-- GENERATED:capability-navigation:end -->

## 公开示例

`examples/` 包含公开可玩的参考包。每个包都展示一条可以由作者扩展的完整规则：固定玩法
语义写在 `main.lua`，每道题只提供会变化的几何或数值。

## 多语言与命名

每个公开包都必须提供 `i18n/en_us.json` 和 `i18n/zh_cn.json`。其他语言可选，文件名使用小写 locale：两位或三位
语言代码，可选两位地区后缀，例如 `ja.json`、`pt_br.json`、`zh_cn.json` 或
`zh_tw.json`。游戏按“精确 locale → 已声明的语言级 locale → `en_us`”顺序查找文案。

请区分稳定名称与玩家可见名称：

- `manifest.id` 是永久技术标识。
- `manifest.name` 是稳定、不可本地化的包管理名称。
- `variant.title` 是各语言中展示给玩家的玩法名称，可以翻译。
- `variant.description` 和全部 `rule_guide.*` 值都是该语言中的玩家文案。

每个已声明的 locale 都必须与 `en_us` 保持完整且相同的 key 集，包括全部
`rule_guide.*`。使用既有 `variant.*`、`rule.<handler>`、`rule_guide.*` key 集合，
不要为不同语言另起 key 名。运行时回退只是容错机制，不代表该语言已经翻译完整。

## 公开 SDK 内容

`operator-fixtures/` 是不可玩的通用运算符语法小例子。它们不是创建可玩变形数独的
起点；请从公开示例和作者指南开始。

## SDK 结构

```text
plugin-sdk/
  README.md
  README.zh-CN.md
  community-script-v1-author-guide.md
  community-script-v1-author-guide.zh-CN.md
  manifest.schema.json
  types-community.lua
  examples/
  operator-fixtures/
```

这个目录是 Mod 作者使用的公开 SDK 来源，包含公开包契约、示例和作者文档；它不包含
MeetSudoku 应用本身的实现。
