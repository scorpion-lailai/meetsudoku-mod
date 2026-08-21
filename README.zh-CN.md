# MeetSudoku Plugin SDK

[English](README.md)

Community Variant Script API V1 让作者通过 `main.lua`、题目数据和可选棋盘标记创建
变形数独。公开的包结构与 Lua/JSON 契约见[作者指南](community-script-v1-author-guide.md)。

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
`rule_guide.*`。使用既有 `variant.*`、`rule.<handler>`、`rule_guide.*` key family，
不要为不同语言另起 key 名。运行时 fallback 只是容错机制，不代表该语言已经翻译完整。

## 公开 SDK 内容

`operator-fixtures/` 是不可玩的通用运算符语法小例子。`technical-packages/` 是尚未公开
的进行中内容，因此不会同步到这个公开镜像。`operator-fixtures/` 也不是创建可玩变形
数独的起点；请从公开示例和作者指南开始。

## SDK 结构

```text
plugin-sdk/
  README.md
  README.zh-CN.md
  community-script-v1-author-guide.md
  manifest.schema.json
  types-community.lua
  examples/
  operator-fixtures/
```

这个仓库是公开 SDK 镜像。数独应用仓库仍是运行时实现、资格记录、发布元数据和非公开
技术包的事实来源。
