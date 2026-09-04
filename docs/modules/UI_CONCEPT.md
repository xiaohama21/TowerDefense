# UI 概念图生成与归档（UI_CONCEPT）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 界面排版文字规范（权威）见 [UI_LAYOUT.md](UI_LAYOUT.md)，素材台账见 [ART_ASSETS.md](ART_ASSETS.md)。
> 文档版本：v0.1（2026-09-04）
> v0.1 变更（阶段 8·提交 9 延伸·修复 3，程序 0.8.9.3，概念图源码归档 + 工作流建档，纯文档/素材无逻辑改动）：①概念图**可复现源码**自包含归档 `docs/ui_concept/src/`（11 屏 HTML + 共享 CSS + 快乐体字体 + Kenney 17 图子集，含早期草稿 `archive/`）；②用 Chrome headless 按固定参数重渲 11 屏 PNG 与归档逐字节一致校验：10 屏一致；`ui_squad.png` 原存档图为更早稿——先按现行源码校准、再按 **BUGS B-025** 卡面费用样式改版重渲，11 屏 PNG 与源码保持同源；③本档建档：视觉语言 token、PNG↔源码映射、设计脉络与拍板记录、复现/维护工作流。

---

## 1. 定位与边界

概念图是**设计交付物**：先于代码用 HTML+CSS 快速产出整屏效果，用户拍板后定稿为 PNG 存档，Godot 再按图落地。各文档边界：

| 文档 | 职责 | 与概念图的关系 |
|---|---|---|
| 本档 UI_CONCEPT | 概念图怎么来的、怎么改、怎么重渲、设计脉络 | 概念图工作流入口 |
| UI_LAYOUT | 每屏最终排版文字规范（权威） | 概念图定稿后回写于此 |
| UI.md | 界面职责/功能表 | 概念图对应的功能范围 |
| ART_ASSETS | 运行时素材目录与台账 | 概念图素材 ≠ 运行时素材 |

## 2. 工作流（概念图先行）

1. 需求 → 改/新增 `docs/ui_concept/src/*.html`（或复制同风格屏起稿）。
2. Chrome headless 重渲 1280×720 PNG（命令见第 6 节），展示给用户。
3. 用户拍板 → PNG 覆盖 `docs/ui_concept/ui_*.png`；同步回写 UI_LAYOUT 对应章节与本档，文档版本 +1。
4. 开发按 UI_LAYOUT 落地；运行时素材（九宫格切片等）入库 `assets/` 并登记 ART_ASSETS。

**原则**：PNG 只增改不删历史（历史版本在 git 中可回溯）；HTML 与 PNG 必须同源同步，重渲不一致即视为改版。

## 3. v3 视觉语言（设计 token，2026-09-03 定稿）

| Token | 取值/规范 | 说明 |
|---|---|---|
| 画布 | 1280×720 固定，不响应式 | 与游戏窗口一致 |
| 背景 | 天空三档蓝线性渐变 `#46afe6 → #3399da → #277fb9` | 替换黑底；顶部椭圆白色柔光 `.bg` |
| 主面板 | 白底 `#f2faff`、蓝框 `#1c9fd7` 3px + 底边深蓝 `#167da8` 7px、圆角 18、大投影 | 大厅/独立整屏共用 |
| 内卡 | 纯白底 `#fff`、浅蓝框 `#d7e9f5`、圆角 12~14、轻投影 | 内容分区 |
| 侧栏 | 浅蓝渐变 `#e9f6fd→#dcedf8`、右缘 `#bfe2f4` | 大厅功能导航 |
| 按钮素材 | Kenney 九宫格 rect 按钮，`border-image-slice:24` | 五色语义，四态（normal/hover/pressed/disabled） |
| 语义色 | 黄=主行动（金语义以黄替金）、蓝=选中/信息、红=警示/返回、绿=成功、灰=中性/禁用 | 对应 UI_LAYOUT §2 |
| 字体 | 站酷快乐体 ZCOOL-Kuaile（免费商用） | 全局，含 Arial 兜底仅英文小字 |
| 头像占位 | 彩色渐变圆 + 姓氏单字；职业/状态色调（金/绿/紫/橙/红/灰） | 立绘未上线前的统一占位 |
| 标签/徽章 | 圆角胶囊：绿=已达成、黄=待达成、灰=锁定、蓝=信息、红=警示 | `.tag.*` |
| 滚动条 | 细蓝 `#7ec8ea` 圆角 thumb + 浅蓝轨道 | 内容超高兜底，防撑爆 |
| 文字层级 | 屏标题 26~27px 深蓝、正文 14~16、辅助 11~12 灰蓝 | 修正"按钮过大字体过小"教训 |

## 4. 概念图清单与映射（11 屏）

| PNG（docs/ui_concept/） | 源码（docs/ui_concept/src/） | 内容一句话 | 排版规范 |
|---|---|---|---|
| `ui_home.png` | `ui_home.html` | 主菜单首页：标题 + 黄/红/灰三大按钮 | UI_LAYOUT §3 |
| `ui_dialog.png` | `ui_dialog.html` | 「新的征程」确认弹窗（55% 遮罩叠加演示） | UI_LAYOUT §3 |
| `ui_button_states.png` | `ui_button_states.html` | 按钮四态演示（normal/hover/pressed/disabled × 五色） | UI_LAYOUT §2 |
| `ui_hub_map.png` | `ui_hub_map.html` | 大厅·地图选关：顶部章节下拉 + 2×4 关卡卡 + 底部关卡预告条 | UI_LAYOUT §4/§5 |
| `ui_develop.png` | `ui_develop.html` | 武将养成：左武将网格 + 技能/转职/信物/特性页签 | UI_LAYOUT §6 |
| `ui_squad.png` | `ui_squad.html` | 出征·编队：武将选择 + 羁绊 + 遗物选带 + 返回/确认出战（卡面费用=底部内嵌通栏，B-025） | UI_LAYOUT §7 |
| `ui_tech.png` | `ui_tech.html` | 科技树：三分支分类展示（滚动兜底） | UI_LAYOUT §8 |
| `ui_inventory.png` | `ui_inventory.html` | 背包：道具分类页签 + 列表（滚动兜底） | UI_LAYOUT §9 |
| `ui_settings.png` | `ui_settings.html` | 设置：页签 + 开关/滑块列表 | UI_LAYOUT §11 |
| `ui_encyclopedia.png` | `ui_encyclopedia.html` | 百科·武将图鉴：左 2 列网格 + 五页签 + 数值模拟器条 | UI_LAYOUT §12 |
| `ui_encyclopedia_enemy.png` | `ui_encyclopedia_enemy.html` | 百科·敌人图鉴：基础/特殊行为/各档难度/出现关卡 | UI_LAYOUT §12 |

## 5. 设计脉络与拍板记录（v0.33.4 → v0.33.8）

- **v0.33.4 风格定稿**：用户给 Kenney UI Pack 压缩包与站酷快乐体字体，要求"从首页开始出概念图"。方向定为 Kenney 亮蓝 + 快乐体 Q 版；黑底程序化占位 UI 由此退役。用户拍板：**黄色用 Kenney 原本的黄色**（不要金色）、补合适背景（黑背景太丑）、按钮缩小/字体放大、"新的征程"弹窗叠加演示。
- **v0.33.5 地图选关改版 + 扩五屏**：章节选择改**顶部下拉框**（原顶部横向章节行方案见 `src/archive/ui_hub_map_v1.html`）；关卡卡满档填充空白（状态/星级/简介/敌人/波次/首通奖励），底部关卡预告条 + 通关统计上移；新增养成/科技/背包/设置/编队五屏；用户要求科技树/背包/编队**滚动条兜底**防撑爆；编队顶部费用移至武将卡并更名**建造费用**。
- **v0.33.6 主菜单落地（换肤基建）**：首页按 `ui_home.png` 在 Godot 实现，Kenney 九宫格三态按钮封装 `UITheme.apply_kenney_rect_button`，「新的征程」弹窗自绘。
- **v0.33.8 百科前置设计**：六张大厅屏侧栏统一加「百科」按钮（设置与返回主菜单之间，随提交 9 开发）；武将养成新增**技能页签**（职业大招 + 职业技能 + 角色专属技能 A/B）；百科两屏（武将图鉴/敌人图鉴）概念图定稿。编队为独立整屏、不含大厅侧栏。

## 6. 复现与维护

- 截图命令（Windows Chrome 示例，参数固定）：

```bat
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu --hide-scrollbars --window-size=1280,720 --force-device-scale-factor=1 --virtual-time-budget=4000 --screenshot=out.png file:///F:/godotProject/TowerDefense/docs/ui_concept/src/ui_home.html
```

- 基线：2026-09-04 已重渲 11 屏并与 `docs/ui_concept/*.png` 逐字节一致（MD5 校验）；其中 `ui_squad.png` 原存档与现行源码不一致，已按现行源码校准覆盖；同日按 B-025 卡面费用样式改版再次重渲覆盖，PNG 与源码始终同源（历史稿在 git 中可回溯）。
- 改版步骤：改 HTML → 重渲 → 用户确认 → 覆盖 PNG → 同步本档与 UI_LAYOUT（版本 + changelog）→ 走版本分支提交。
- 复现细节、素材清单与目录树见 `docs/ui_concept/src/README.md`（随源码自包含）。

## 7. 变更记录

- v0.1（2026-09-04）：建档（同顶部 changelog）。
