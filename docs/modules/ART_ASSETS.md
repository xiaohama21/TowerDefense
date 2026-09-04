# 美术资产规范（ART_ASSETS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)，界面风格见 [UI_LAYOUT.md](UI_LAYOUT.md)。
> 承载总纲原章节：13「美术风格」行实现侧、附录「现有代码与资源映射」。
> 文档版本：v0.3（2026-09-04）
> v0.3 变更（阶段 8·提交 9 延伸·修复 3，程序 0.8.9.3，概念图源码归档）：①概念图**可复现源码**随设计图归档——11 屏 HTML/CSS/字体/Kenney 17 图子集自包含存放 docs/ui_concept/src/（重渲与原 PNG 逐字节一致；ui_squad.png 原存档为更早稿——先按现行源码校准、再按 B-025 卡面费用样式改版重渲，PNG 与源码同源）；子集仅供设计稿复现，不入 assets/ 运行时目录；②来源许可表补注 Kenney 完整包下载口径；③概念图复现与维护见 UI_CONCEPT v0.1。
> v0.2 变更（阶段 8·提交 8 延伸·修复 6，v0.33.6，主菜单换肤落地）：①按钮素材投入运行时——`ui/buttons/rect/{yellow,red,grey}` 三态（normal/hover/pressed，原图 384×128、九宫格裁边 24）与 `ui/icons/star.png` / `star_outline.png` / `cross_blue.png` 由 `MainMenu` 首次使用，换肤封装 `UITheme.apply_kenney_rect_button`（后续面板复用同一入口）；②`ui/panels/` 预留说明更新——「新的征程」弹窗面板以程序化 StyleBox 自绘先行，九宫格底图素材仍预留。
> v0.1 变更（阶段 8·提交 8 延伸·修复 4，v0.33.4）：①确立 `assets/` 分类目录规范——fonts / ui / map 三主干，禁止散放；②UI 素材入库：Kenney UI Pack 切片按按钮（rect/round × 五色 × 三态）/ 图标分类，弹窗面板与地图素材目录预留；③地图装饰迁移 `assets/decor` → `assets/map/decor`（代码常量同步，程序化回退保留）。

---

## 1. 定位与原则

1. **先分类后入库**：任何新美术素材先按本规范确定归属目录（或新增分类并登记本档），禁止丢在 `assets/` 根或随意目录；打包产物除外（`build/`）。
2. **按用途分主干**：界面 → `assets/ui/`，战斗地图 → `assets/map/`，字体 → `assets/fonts/`；角色/敌人/特效立绘素材【远期】，首件落地时再建目录并登记。
3. **缺失可回退**：运行时美术一律支持"素材缺失回退程序化绘制"（`GridBackground` 装饰先例），新增美术不阻塞开发、不改变布局数据。
4. **命名**：snake_case（小写下划线）；同一素材的不同用途/状态显式后缀（`normal/hover/pressed`、`_grey` 等）。
5. **设计图与运行时资源分离**：概念图/定稿图属设计存档，PNG 放 `docs/ui_concept/`、可复现源码（HTML/CSS/字体/Kenney 子集）放 `docs/ui_concept/src/`（不入 `assets/`；复现与维护见 [UI_CONCEPT.md](UI_CONCEPT.md)）。

## 2. 目录规范

```
assets/
├── fonts/                  # 全局字体（站酷快乐体 ZCOOL-Kuaile.ttf）
├── ui/                     # 界面素材（Kenney UI Pack，CC0）
│   ├── buttons/
│   │   ├── rect/{yellow,red,grey,blue,green}/{normal,hover,pressed}.png
│   │   └── round/{yellow,red,grey,blue,green}/{normal,hover,pressed}.png
│   ├── icons/              # 星形/勾选/关闭/箭头/输入框/分隔线/滑块
│   ├── panels/             # 弹窗/面板九宫格底图（自绘或素材化，当前为空=预留）
│   └── ui_theme.tres       # 全局主题（默认字体=快乐体，系统字体回退）
├── map/                    # 战斗地图素材
│   ├── decor/              # 装饰（banner/rock/torch/tree，原 assets/decor，v0.33.4 迁移）
│   ├── themes/             # 预留：主题底图/瓦片（grass/fire/night…）
│   ├── terrain/            # 预留：禁建地形（山/河/城墙等）
│   └── landmarks/          # 预留：基地/出入口等标志物
```

## 3. UI 素材台账（✅ 已入库）

来源：Kenney UI Pack（[kenney.nl/assets/ui-pack](https://kenney.nl/assets/ui-pack)，CC0），切片取 Double（2×）以保证 1280×720 下清晰。

| 文件 | 来源（包内原名，Double） | 说明 |
|---|---|---|
| `ui/buttons/rect|round/<色>/normal.png` | `button_rectangle|round_depth_flat.png` | 普通态 |
| `ui/buttons/rect|round/<色>/hover.png` | `button_rectangle|round_gloss.png` | 悬停态（高光） |
| `ui/buttons/rect|round/<色>/pressed.png` | `depth_flat` 压暗 22%（工具派生） | 按下态 |
| `ui/icons/star.png` | `Yellow/star.png` | 星级·点亮 |
| `ui/icons/star_outline.png` / `star_outline_grey.png` | `Yellow|Grey/star_outline.png` | 星级·未点亮 |
| `ui/icons/check_ok.png` | `Green/check_square_color_checkmark.png` | 已通关/成功 |
| `ui/icons/cross_blue.png` | `Blue/icon_cross.png` | 关闭 |
| `ui/icons/arrow_basic_*_blue.png` | `Blue/arrow_basic_*.png` | 方向导航 |
| `ui/icons/arrow_decorative_*_yellow.png` | `Yellow/arrow_decorative_*.png` | 装饰 |
| `ui/icons/input_rectangle.png` | `Extra/input_rectangle.png` | 输入框 |
| `ui/icons/divider.png` / `divider_edges.png` | `Extra/divider*.png` | 分隔线 |
| `ui/icons/slide_*.png` | `Blue/slide_*.png` | 设置滑块/滚动条 |

**语义色映射**（对齐 UITheme 语义，见 UI_LAYOUT.md 第 2 节）：黄=主行动（金语义，视觉以黄替金）、红=警示、灰=中性/禁用、蓝=信息/选中、绿=成功。按钮四态效果见 `docs/ui_concept/ui_button_states.png`。

**待入库（空目录 = 预留）**：`ui/panels/` 弹窗面板底图（九宫格，Godot StyleBox 用）。正式换肤进度：主菜单已落地（v0.33.6——`UITheme.apply_kenney_rect_button` 九宫格按钮 + 自绘白面弹窗），其余面板逐步接入；尚未换肤的面板控件底色仍为程序化。

## 4. 地图素材约定（后续章节/换肤）

1. 主题底图：`map/themes/<theme_id>/`（如 `grass/fire/night`）；整幅底图按 1280×720，瓦片按 80px 网格基准。
2. 禁建地形：`map/terrain/`（山/河/城墙等），与 `StageData.forbidden_cells` 对应；需可辨识"不可建造"。
3. 标志物：`map/landmarks/`（基地城楼、出入口旗帜）。
4. 装饰：沿用 `map/decor/`，`GridBackground` 按 decor_type 确定性哈希选素材，缺失自动回退程序化绘制（树/石）；新装饰类型需同步注册 `GridBackground.DECOR_TYPES` 并登记本档。

## 5. 来源与许可登记

| 素材 | 来源 | 许可 | 备注 |
|---|---|---|---|
| Kenney UI Pack 切片 | kenney.nl | CC0 | 全部 UI 按钮/图标；概念图 HTML 所需 17 图子集随 docs/ui_concept/src/kenney_ui_pack 归档（仅设计复现用，完整包按官方 CC0 可随时重下） |
| 站酷快乐体 2016 修订版 | 站酷（ZCOOL） | 免费商用 | 字体；使用声明随原压缩包存档 |

## 6. 变更记录

- v0.1（2026-09-03）：初始建档（目录规范 + UI 素材台账 + 地图预留约定 + 许可登记）。
- v0.2（2026-09-03）：主菜单换肤落地——rect 三色按钮三态与 star / cross 图标投入运行时使用；换肤封装 `UITheme.apply_kenney_rect_button`；弹窗面板自绘先行说明。
