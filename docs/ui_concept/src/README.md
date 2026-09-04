# docs/ui_concept/src —— UI 概念图可复现源码

本目录是 `docs/ui_concept/*.png` 概念图的**可复现源码**（HTML + CSS + 字体 + Kenney 素材子集）。
换会话、换电脑后无需原始素材包即可打开、修改、重新截图；生成思路与维护流程见 `docs/modules/UI_CONCEPT.md`。

## 1. 预览 / 修改

- 直接双击任意 `*.html` 用浏览器打开即可（无构建步骤），固定画布 **1280×720**。
- 共享样式 `concept_ui.css`（v3 视觉语言：背景渐变 / 面板 / 按钮九宫格 / 滚动条 / 头像占位），旧首页两版自带内联样式。
- 字体与 Kenney 素材均在包内相对引用，整个 `src/` 目录可整体拷走使用。

## 2. PNG ↔ HTML 映射（13 屏）

| 归档 PNG（docs/ui_concept/） | 源码 HTML | 内容 |
|---|---|---|
| `ui_home.png` | `ui_home.html` | 主菜单首页 |
| `ui_dialog.png` | `ui_dialog.html` | 「新的征程」确认弹窗（叠加演示） |
| `ui_button_states.png` | `ui_button_states.html` | 按钮四态演示（normal / hover / pressed / disabled） |
| `ui_hub_map.png` | `ui_hub_map.html` | 大厅 · 地图选关（顶部章节下拉 + 关卡预告条） |
| `ui_develop.png` | `ui_develop.html` | 武将养成（技能 / 转职 / 信物 / 特性页签） |
| `ui_develop_job.png` | `ui_develop_job.html` | 武将养成「职业」页签（当前职业信息 + 转职进度 + 转职详情入口，v0.35.3） |
| `ui_develop_promo.png` | `ui_develop_promo.html` | 武将养成「转职详情」叠层（职业级转职树 + 转职操作，v0.35.3） |
| `ui_squad.png` | `ui_squad.html` | 出征 · 编队 |
| `ui_tech.png` | `ui_tech.html` | 科技树 |
| `ui_inventory.png` | `ui_inventory.html` | 背包 |
| `ui_settings.png` | `ui_settings.html` | 设置 |
| `ui_encyclopedia.png` | `ui_encyclopedia.html` | 百科 · 武将图鉴 |
| `ui_encyclopedia_enemy.png` | `ui_encyclopedia_enemy.html` | 百科 · 敌人图鉴 |

`archive/` = 已被取代的早期草稿（无对应归档 PNG）：`ui_home_v1.html`（首页首版）、`ui_hub_map_v1.html`（地图选关首版——章节顶部行方案，后改顶部下拉）。

## 3. 重新截图（Chrome headless）

```bat
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu ^
  --hide-scrollbars --window-size=1280,720 --force-device-scale-factor=1 ^
  --virtual-time-budget=4000 --screenshot=out.png file:///F:/godotProject/TowerDefense/docs/ui_concept/src/ui_home.html
```

- 参数固定 1280×720；`--virtual-time-budget=4000` 保证快乐体字体加载完成后才截图。
- 基线校验：2026-09-04 用本命令重渲 11 屏 PNG，与 `docs/ui_concept/*.png` **逐字节一致**（ui_squad.png 原存档为更早稿：已按现行源码校准、并按 B-025 卡面费用样式改版重渲，PNG 与源码同源）；同日追加 `ui_develop_job.png` / `ui_develop_promo.png` 两屏（武将养成职业页签 / 转职详情叠层，v0.35.3）同参数重渲，与源码同源。
- 验证脚本思路：重渲后比对 MD5；不一致即视为新版本，需人工确认后覆盖。

## 4. 素材清单与许可

- `fonts/ZCOOL-Kuaile.ttf`：站酷快乐体 2016 修订版（免费商用）；与运行时字体 `assets/fonts/ZCOOL-Kuaile.ttf` 同一文件（MD5 `2347D2B3716F8D584D276992E803CA1A`）。
- `kenney_ui_pack/PNG/`：Kenney UI Pack（CC0，https://kenney.nl/assets/ui-pack ）中概念图用到的 **17 个文件子集**（保留官方目录层级）；完整包 1315 个文件未入库，缺素材时从官方包按同名路径补拷即可（本地原始压缩包：`F:\godotProject\kenney_ui-pack.zip`，属个人机器路径、非仓库基线）。
- 17 文件清单：`Blue/Default/icon_cross.png`；`Blue|Grey|Red|Yellow/Double/button_rectangle_depth_flat.png`（四色）；`Blue|Grey|Red|Yellow/Double/button_rectangle_gloss.png`（四色）；`Yellow/Double/button_rectangle_depth_gloss.png`；`Yellow/Double/arrow_decorative_e.png` / `arrow_decorative_w.png`；`Yellow/Double/star.png` / `star_outline.png` / `star_outline_depth.png`；`Grey/Double/star_outline.png`；`Extra/Double/icon_arrow_down_dark.png`。

## 5. 维护约定

1. 改稿 = 编辑 HTML → 重渲 PNG → 给用户确认 → 覆盖 `docs/ui_concept/ui_*.png` → 同步 `UI_CONCEPT.md` / `UI_LAYOUT.md` 版本与 changelog（文档先行）。
2. 新增屏幕：复制同风格 HTML 起稿；新增 Kenney 素材时同步补进 `kenney_ui_pack/` 并在本 README 清单登记。
3. 本目录是**设计复现基线**，不是运行时资源；游戏内素材归 `assets/`（见 `docs/modules/ART_ASSETS.md`）。
4. `.gitignore` 忽略 `*.import`——Godot 编辑器打开项目时为本目录字体/PNG 生成的导入缓存不入库。
