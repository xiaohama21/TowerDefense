# docs/ui_concept/src —— UI 概念图可复现源码

本目录是 `docs/ui_concept/*.png` 概念图的**可复现源码**（HTML + CSS + 字体 + Kenney 素材子集）。
换会话、换电脑后无需原始素材包即可打开、修改、重新截图；生成思路与维护流程见 `docs/modules/UI_CONCEPT.md`。
（例外：`ui_cursor_palette.png` 为素材规范对照图，由 `ui_cursor_palette.py`（PIL）生成而非 HTML，见 §2 / §4。）

## 1. 预览 / 修改

- 直接双击任意 `*.html` 用浏览器打开即可（无构建步骤），固定画布 **1280×720**。
- 共享样式 `concept_ui.css`（v3 视觉语言：背景渐变 / 面板 / 按钮九宫格 / 滚动条 / 头像占位），旧首页两版自带内联样式。
- 字体与 Kenney 素材均在包内相对引用，整个 `src/` 目录可整体拷走使用。

## 2. PNG ↔ HTML 映射（20 屏）

| 归档 PNG（docs/ui_concept/） | 源码 HTML | 内容 |
|---|---|---|
| `ui_home.png` | `ui_home.html` | 主菜单首页 |
| `ui_dialog.png` | `ui_dialog.html` | 「新的征程」确认弹窗（叠加演示） |
| `ui_button_states.png` | `ui_button_states.html` | 按钮四态演示（normal / hover / pressed / disabled） |
| `ui_hub_map.png` | `ui_hub_map.html` | 大厅 · 地图选关（顶部章节下拉 + 关卡预告条） |
| `ui_develop.png` | `ui_develop.html` | 武将养成（技能 / 转职 / 信物 / 特性页签） |
| `ui_develop_job.png` | `ui_develop_job.html` | 武将养成「职业」页签（当前职业信息 + 转职进度 + 转职详情入口，v0.35.3） |
| `ui_develop_promo.png` | `ui_develop_promo.html` | 武将养成「转职详情」叠层（职业级转职树 + 转职操作，v0.35.3） |
| `ui_squad.png` | `ui_squad.html` | 出征 · 编队（v0.10 定稿：3×3 武将网格滚动扩展 + 遗物 pill 悬停详情 + 右「总战力加成」面板；滚动演示屏截图去 `--hide-scrollbars`） |
| `ui_tech.png` | `ui_tech.html` | 科技树 |
| `ui_inventory.png` | `ui_inventory.html` | 背包 |
| `ui_settings.png` | `ui_settings.html` | 设置 |
| `ui_encyclopedia.png` | `ui_encyclopedia.html` | 百科 · 武将图鉴：左 2 列网格 + 五页签 + 数值模拟器条；属性列 = 2 列**胶囊条**（一条数据一枚胶囊 = 左通用 HUD 图徽 · 中标签 · 右数值），模拟器结果卡同款图徽（v0.13 概念稿存档） |
| `ui_encyclopedia_enemy.png` | `ui_encyclopedia_enemy.html` | 百科 · 敌人图鉴：基础属性 4 枚**胶囊**（含生命占位）+ **击杀奖励 3 枚独立胶囊**（金币 / 经验 / 军功）+ 特殊行为 / 各档难度（内联图徽）/ 出现关卡（v0.13 概念稿存档） |
| `ui_battle_hud.png` | `ui_battle_hud.html` | 战斗局内 HUD（贴顶顶栏 0..80 / 底部建造卡条 640..720 常驻 / 怒气胶囊收格三态 / HP 变色图例，v0.36.25 存档；2026-09-08 v0.37.1 移除技能副行；v0.37.8 按 0.8.11.1 运行版式重渲） |
| `ui_battle_hud_v2.png` | `ui_battle_hud_v2.html` | 战斗局内 HUD v2：深墨绿 + 暖金皮肤 / 顶栏图标化 + 出口波次旗帜出怪（取消「开始第 N 波」按钮）/ 底栏 5 卡塔详情（头像 · 伤害 · 攻速 · 升阶 · 回收，费用胶囊同建造位、不显示等阶、取消选中金圈）/ 地图塔去名称 + 阶级角标 / 军需槽局外选带 · 局内金币购买（v0.37.30 定稿；旧稿 `ui_battle_hud.*` 保留为历史存档） |
| `ui_squad_confirm.png` | `ui_squad_confirm.html` | 出征·编队「确认出战」二次确认弹窗（640×557 叠层演示，v0.37.0 存档） |
| `ui_supply.png` | `ui_supply.html` | 战斗局内「军需」面板（悬停/点击详情 + 购买即买即用，v0.37.0 存档） |
| `ui_victory.png` | `ui_victory.html` | 战斗结算 · 胜利页（绿横幅 + 奖励明细 + 战绩/挑战目标星级预留 + 转盘入口，v0.37.2 概念初稿待拍板） |
| `ui_wheel.png` | `ui_wheel.html` | 战斗结算 · 胜利后转盘页（六扇区圆轮 + 顶部指针 + 奖池/规则/入档，v0.37.2 概念初稿待拍板） |
| `ui_defeat.png` | `ui_defeat.html` | 战斗结算 · 战败页（红横幅 + 作废三卡 + 失败规则，v0.37.2 概念初稿待拍板） |
| `ui_cursor_palette.png` | `ui_cursor_palette.py`（PIL，非 HTML） | 光标调色规范对照图（原版 + A/B/C × 浅/深底色，v0.7 存档，非界面屏） |

`archive/` = 已被取代的早期草稿（无对应归档 PNG）：`ui_home_v1.html`（首页首版）、`ui_hub_map_v1.html`（地图选关首版——章节顶部行方案，后改顶部下拉）。

## 3. 重新截图（Chrome headless）

```bat
"C:\Program Files\Google\Chrome\Application\chrome.exe" --headless=new --disable-gpu ^
  --hide-scrollbars --window-size=1280,720 --force-device-scale-factor=1 ^
  --virtual-time-budget=4000 --screenshot=out.png file:///F:/godotProject/TowerDefense/docs/ui_concept/src/ui_home.html
```

- 参数固定 1280×720；`--virtual-time-budget=4000` 保证快乐体字体加载完成后才截图。
- 基线校验：2026-09-04 用本命令重渲 11 屏 PNG，与 `docs/ui_concept/*.png` **逐字节一致**（ui_squad.png 原存档为更早稿：已按现行源码校准、并按 B-025 卡面费用样式改版重渲，PNG 与源码同源）；同日追加 `ui_develop_job.png` / `ui_develop_promo.png` 两屏（武将养成职业页签 / 转职详情叠层，v0.35.3）同参数重渲，与源码同源；2026-09-07 追加 `ui_battle_hud.png`（战斗局内 HUD，v0.36.25）同参数重渲入库，与源码同源；2026-09-08 追加 `ui_squad_confirm.png` / `ui_supply.png`（编队确认出战弹窗 / 局内军需面板，v0.37.0）同参数重渲入库，与源码同源；2026-09-08 修订重渲 `ui_battle_hud.png`（移除详情面板「职业技能 · 角色技」副行，v0.37.1 / 提交 11 落地），与源码同源；2026-09-08 追加 `ui_victory.png` / `ui_wheel.png` / `ui_defeat.png`（战斗结算三屏：胜利结算 / 结算转盘 / 战败结算，v0.37.2 概念初稿待拍板）同参数重渲入库，与源码同源；2026-09-08 修订重渲 `ui_hub_map.png`（地图详情条胶囊 4→2 收敛：移除经验/推荐、敌人/波次改内容自适应宽，v0.37.7 / UI_CONCEPT v0.8 / 程序 0.8.11.4）同参数重渲入库，与源码同源；2026-09-08 修订重渲 `ui_battle_hud.png`（按 0.8.11.1 起运行版式同步：贴顶顶栏 0..80 + 底部建造卡条 640..720 + 怒气胶囊收格三态，承接 v0.20.24 排期，v0.37.8 / UI_CONCEPT v0.9 / 程序 0.8.11.5）同参数重渲入库，与源码同源2026-09-11 追加 `ui_battle_hud_v2.png`（局内 HUD v2：深墨绿 + 暖金皮肤 / 出口波次旗帜出怪 / 底栏 5 卡塔详情 / 军需槽，v0.37.30 / UI_CONCEPT v0.12 / 程序 0.8.11.13 不变）同参数重渲入库（MD5 33C47F878C31DC27B73095117528297D），与源码同源；2026-09-12 修订重渲 `ui_encyclopedia.png` / `ui_encyclopedia_enemy.png`（百科图鉴概念稿：属性列改**胶囊条**（左图标 · 右数值）+ 接入通用 HUD 图徽 `src/icons_hud/`、敌人金币/经验/军功拆 3 枚独立胶囊，v0.37.31 / UI_CONCEPT v0.13 / UI_LAYOUT v0.20.42 / ENCYCLOPEDIA v0.1.10）同参数重渲入库，与源码同源。
- 验证脚本思路：重渲后比对 MD5；不一致即视为新版本，需人工确认后覆盖。

## 4. 素材清单与许可

- `fonts/ZCOOL-Kuaile.ttf`：站酷快乐体 2016 修订版（免费商用）；与运行时字体 `assets/fonts/ZCOOL-Kuaile.ttf` 同一文件（MD5 `2347D2B3716F8D584D276992E803CA1A`）。
- `kenney_ui_pack/PNG/`：Kenney UI Pack（CC0，https://kenney.nl/assets/ui-pack ）中概念图用到的 **17 个文件子集**（保留官方目录层级）；完整包 1315 个文件未入库，缺素材时从官方包按同名路径补拷即可（本地原始压缩包：`F:\godotProject\kenney_ui-pack.zip`，属个人机器路径、非仓库基线）。
- `icons_hud/`：**通用 HUD 图徽**（2026-09-11 随百科图鉴概念稿入库）：伤害类型 3（`dmg_physical` / `dmg_magic` / `dmg_true`）、人物属性 7（`stat_attack_speed` / `stat_range` / `stat_armor` / `stat_exp` / `stat_tenacity` / `stat_armor_pen` / `stat_move_speed`）、负面状态 6（`status_slow` / `status_burn` / `status_vulnerable` / `status_stun` / `status_fear` / `status_knockback`）。均为 160×160 **透明底单符号**（深藏青底板已剥离、边缘噪点已清理，与 `icons_battle/coin_crop.png` 同款落底），供浅色面板直接使用；生成脚本 `prep_icons_hud.py`（PIL，个人机器路径输入，非仓库基线）。风格锚点 = ART_PROMPTS §5.2~5.4（§2.2 简版 UI 图标级）；外部 AI 生成素材，许可以来源为准。**缺口**：敌人生命 / 军功（军需货币）尚无图徽，概念稿以虚线占位；漏怪伤害暂借 `icons_battle/base_hp_crop.png`（立绘级，建议后续补 UI 图标级同款）。
- `icons_battle/`：**局内 HUD 图标集**（2026-09-07 随 `ui_battle_hud` 入库、2026-09-11 随 `ui_battle_hud_v2` 扩充）：`coin.png` 金币（顶栏 + 全部费用胶囊）/ `base_hp.png` 基地生命 / `wave_flag.png` 波次旗帜（顶栏波次胶囊 + 敌人出口出怪按钮）/ `wave_flag_plate.png` 波次旗帜带底板版（备用）/ `dmg_physical.png` · `dmg_magic.png` · `dmg_true.png` 伤害类型 / `stat_attack_speed.png` 攻击速度；早期裁剪件 `coin_crop.png` / `base_hp_crop.png` 与原始大图 `*_source.jpg` 保留备查。**复现**：`python prep_hud_icons.py`（PIL，自本地 `F:\godotProject\leonardo.ai\通用HUD\*.jpg` 去白底 / 去底板 / 裁边输出金币与旗帜，`dmg_*` / `stat_attack_speed` 自同目录 `png/` 直接拷入）。运行时入库目录 = `assets/ui/icons/`（预留，见 ART_ASSETS §3 v0.12）。
- `kenney_cursor_pack/PNG/Outline/Default/`：Kenney Cursor Pack 1.1（CC0，https://kenney.nl/assets/cursor-pack ）光标调色对照图所需 **6 图子集**（pointer_toon_a / pointer_a / hand_point / hand_closed / cross_large / drawing_eraser，保留官方目录层级）；完整包 729 个 PNG 未入库（本地原始压缩包：`F:\godotProject\kenney_cursor-pack.zip`，属个人机器路径、非仓库基线）。
- `ui_cursor_palette.py`：`docs/ui_concept/ui_cursor_palette.png` 生成脚本（PIL，非 HTML/Chrome 流程）——自 `kenney_cursor_pack/` 子集读原图并内联 A/B/C 三色双色重着色、浅/深底色对照合成；标签字体优先 Windows `msyh.ttc`、缺失回退 `fonts/ZCOOL-Kuaile.ttf`（字形有差异）；输出 1280×780。运行：`python ui_cursor_palette.py`。
- 17 文件清单：`Blue/Default/icon_cross.png`；`Blue|Grey|Red|Yellow/Double/button_rectangle_depth_flat.png`（四色）；`Blue|Grey|Red|Yellow/Double/button_rectangle_gloss.png`（四色）；`Yellow/Double/button_rectangle_depth_gloss.png`；`Yellow/Double/arrow_decorative_e.png` / `arrow_decorative_w.png`；`Yellow/Double/star.png` / `star_outline.png` / `star_outline_depth.png`；`Grey/Double/star_outline.png`；`Extra/Double/icon_arrow_down_dark.png`。

## 5. 维护约定

1. 改稿 = 编辑 HTML → 重渲 PNG → 给用户确认 → 覆盖 `docs/ui_concept/ui_*.png` → 同步 `UI_CONCEPT.md` / `UI_LAYOUT.md` 版本与 changelog（文档先行）。
2. 新增屏幕：复制同风格 HTML 起稿；新增 Kenney 素材时同步补进 `kenney_ui_pack/` 并在本 README 清单登记。
3. 本目录是**设计复现基线**，不是运行时资源；游戏内素材归 `assets/`（见 `docs/modules/ART_ASSETS.md`）。
4. `.gitignore` 忽略 `*.import`——Godot 编辑器打开项目时为本目录字体/PNG 生成的导入缓存不入库。
5. `ui_cursor_palette` 例外：PIL 脚本生成（见 §2 / §4），不入 HTML 映射流程。
