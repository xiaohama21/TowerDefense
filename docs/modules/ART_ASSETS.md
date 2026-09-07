# 美术资产规范（ART_ASSETS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)，界面风格见 [UI_LAYOUT.md](UI_LAYOUT.md)。
> 承载总纲原章节：13「美术风格」行实现侧、附录「现有代码与资源映射」。
> 文档版本：v0.4（2026-09-07）
> v0.4 变更（阶段 8·提交 10 延伸·登记，程序 0.8.10.32，**角色 spine 动画试点登记**，用户拍板 2026-09-07「记录文档 / spine_test 保留 / 人物朝向镜像需求登记」，纯文档/素材，无程序逻辑改动）：①新增 §5「角色素材（spine 动画，试点登记）」——D69 素材包（《315 套 Q 版卡通角色 spine 动画》源文件，spine 3.8.75）首件试点关羽（序号 097 / Hero_GuanYu_A）落地 `assets/characters/guan_yu/`（hero_guan_yu_a.png/.atlas/.spine-json/-data-res.tres）；3.8 JSON→4.3 升级转换器 `tools/spine_upgrade_38_to_43.py` 固化（curve 归一化平铺→按值分量分组绝对坐标数组、transform 约束 properties 对象化自链、皮肤名强制 default、rotate angle→value、slot color→rgba、transform mix 键拆分、bendDirection→bendPositive；deform/path 未覆盖仅告警；对照 spine-cpp 4.3 SkeletonJson/CurveTimeline 源码定位三处 DLL 崩溃根因）；SpineSprite（spine-godot GDExtension 4.3 线，`bin/spine_godot_extension.gdextension`）加载验证——12 动画（Idle/Move/Attack_A/Appear/Death/Stiff/Stun/Critical/Active_A/UI_Death/X/XX）全可播放、静态帧与原 png 序列同动作帧轮廓逐像素级一致、骑马姿态**默认朝左**；②`assets/spine_test/spineboy/` 官方 4.x 样例保留作运行时对照（不入游戏资源、不打包）；③目录规范增 `assets/characters/` 与 `assets/spine_test/`；④来源许可表登记 D69 包（包内免责声明「仅供学习研究、不得商用」——商用前需向作者购正版授权）；⑤**人物朝向镜像（朝右）登记为待拍板待办**，方案不落地。
> v0.3 变更（阶段 8·提交 9 延伸·修复 3，程序 0.8.9.3，概念图源码归档）：①概念图**可复现源码**随设计图归档——11 屏 HTML/CSS/字体/Kenney 17 图子集自包含存放 docs/ui_concept/src/（重渲与原 PNG 逐字节一致；ui_squad.png 原存档为更早稿——先按现行源码校准、再按 B-025 卡面费用样式改版重渲，PNG 与源码同源）；子集仅供设计稿复现，不入 assets/ 运行时目录；②来源许可表补注 Kenney 完整包下载口径；③概念图复现与维护见 UI_CONCEPT v0.1。
> v0.2 变更（阶段 8·提交 8 延伸·修复 6，v0.33.6，主菜单换肤落地）：①按钮素材投入运行时——`ui/buttons/rect/{yellow,red,grey}` 三态（normal/hover/pressed，原图 384×128、九宫格裁边 24）与 `ui/icons/star.png` / `star_outline.png` / `cross_blue.png` 由 `MainMenu` 首次使用，换肤封装 `UITheme.apply_kenney_rect_button`（后续面板复用同一入口）；②`ui/panels/` 预留说明更新——「新的征程」弹窗面板以程序化 StyleBox 自绘先行，九宫格底图素材仍预留。
> v0.1 变更（阶段 8·提交 8 延伸·修复 4，v0.33.4）：①确立 `assets/` 分类目录规范——fonts / ui / map 三主干，禁止散放；②UI 素材入库：Kenney UI Pack 切片按按钮（rect/round × 五色 × 三态）/ 图标分类，弹窗面板与地图素材目录预留；③地图装饰迁移 `assets/decor` → `assets/map/decor`（代码常量同步，程序化回退保留）。

---

## 1. 定位与原则

1. **先分类后入库**：任何新美术素材先按本规范确定归属目录（或新增分类并登记本档），禁止丢在 `assets/` 根或随意目录；打包产物除外（`build/`）。
2. **按用途分主干**：界面 → `assets/ui/`，战斗地图 → `assets/map/`，字体 → `assets/fonts/`；角色 spine 动画素材（试点 v0.4 已落地 `assets/characters/` 并登记 §5，正式接入另排期）、敌人/特效立绘素材【远期】，落地时再建目录并登记。
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
├── characters/             # 角色素材：武将 spine 动画试点（guan_yu，见 §5）
└── spine_test/             # 开发对照素材：官方 spine 4.x spineboy 样例（保留，见 §5.5）
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


## 5. 角色素材（spine 动画，试点登记 v0.4）

> 首件试点：关羽（D69 包序号 097 / Hero_GuanYu_A，spine 3.8.75），2026-09-07 转换与加载验证通过。**正式接入战斗与批量导入未排期**；本节固化试点结论与转换管线，防止后续会话重复踩坑。

1. **目录与文件约定**：按角色建目录 `assets/characters/<角色 snake_id>/`；一套素材一个 base 名（关羽 A 套 = `hero_guan_yu_a`），文件为：
   - `<base>.png`——图集（沿用素材包随附图集）；
   - `<base>.atlas`——图集描述：首行指向同目录 `<base>.png`，region 名沿用源素材前缀（`A/<附件名>`）；
   - `<base>.spine-json`——spine **4.3** 数据（3.8 源必须经转换，见 3）；
   - `<base>-data-res.tres`——SpineSkeletonDataResource，运行时统一经 `SpineSprite.skeleton_data_res` 加载。
   - **皮肤名强制 `"default"`**：4.3 运行时皮肤名非 default 时槽附件解析为空 → 渲染空白且 bounds 失效（试点根因 3）。
2. **素材来源**：D69 包《315 套 Q 版卡通角色 spine 动画》——源文件夹内含 spine 3.8.75 导出的 `*.json` + 配套 `.atlas/.png`；另附逐帧 png 序列仅作验收比对参考，不是运行时资源。授权口径见 §6（⚠️ 包内免责声明为学习研究用途，商用需购正版）。
3. **3.8 → 4.3 转换**（`tools/spine_upgrade_38_to_43.py`；spine-godot GDExtension 4.3 线只接受 4.3 数据，直接改版本号会在 curve 解析崩溃）：
   - 版本头改写 4.3.00；
   - **curve 曲线**：3.8 每帧一条归一化曲线共享整条 timeline → 4.3 按值分量分组的**绝对坐标数组**（rotate/alpha 4 个、translate/scale/shear 8 个、rgba 16 个、transform mix 24 个；控制点 x = time1+(t2−t1)·c1、y = value1+(v2−v1)·c2）；数组长度不足 → 运行时按分量取数空指针崩溃（根因 1）；
   - **transform 约束**改 4.3 对象式 properties 并生成同属性 from→to 自链激活 mix（数组/空对象 → strcmp 崩溃，根因 2）；mix 键拆分（rotateMix→mixRotate、translateMix→mixX/mixY 等）；`bendDirection`→`bendPositive`；
   - **动画键**：rotate 帧 `angle`→`value`；slot color timeline 键 `color`→`rgba`（帧内颜色仍为十六进制）；transform 动画帧 mix 键同约束拆分；
   - **未覆盖**：deform 加权网格与 path 约束/动画（3.8→4.3 结构差异大；当前素材无依赖，遇 deform 仅告警直通，后续遇到需扩展）；
   - 转换产物必须过 4 的验证清单再入库。
4. **验证清单**（每件新素材沿用）：
   - 全动画冒烟：`tools/check_all_anims.gd`（headless 逐动画 `set_animation`，返回非空 track 即通过）；
   - 静态渲染比对：SpineSprite 首帧截图 vs 源 png 序列同动作帧（关羽试点 Idle/Attack_A 轮廓几乎逐像素一致）；
   - 朝向抽检：默认朝向与源素材一致（关羽骑马姿态**固定朝左**），镜像验收见 6。
5. **对照素材（用户拍板保留）**：`assets/spine_test/spineboy/` = 官方 spine 4.x 样例（spine-rt 4.3 运行时 examples 子集），用于区分「素材数据问题」与「运行时问题」；不入游戏资源表、不参与打包。
6. **人物朝向（需求登记，方案待拍板，暂不实现）**：试点素材固定朝左，游戏内需支持人物镜像改变朝向（朝右）。候选方案待拍板后回写本节再开发：
   - ① 节点翻转：SpineSprite 所在节点 `scale.x = ±1 × 基准缩放`——素材与动画零改动；弹道/技能方向按现有 `_aim_angle` 全角度旋转、与身体朝向解耦不受影响；风险 = 非对称附件（披风/肩甲/持械侧）与素材内文字翻转镜像，需出左右对照渲染图肉眼验收；
   - ② 数据层镜像：转换管线加 spine-json 反向输出（附件/骨骼 x 取反、rotate 取反），动画曲线方向一并解决，但非对称附件镜像问题仍在且每角色需复验，成本较高；
   - ③ 双素材：同角色左右两份（素材量翻倍），不推荐。
   - 朝左/朝右判定规则（按目标相对塔的水平分量）在正式接入战斗时一并定义并回写本节。

## 6. 来源与许可登记

| 素材 | 来源 | 许可 | 备注 |
|---|---|---|---|
| Kenney UI Pack 切片 | kenney.nl | CC0 | 全部 UI 按钮/图标；概念图 HTML 所需 17 图子集随 docs/ui_concept/src/kenney_ui_pack 归档（仅设计复现用，完整包按官方 CC0 可随时重下） |
| 站酷快乐体 2016 修订版 | 站酷（ZCOOL） | 免费商用 | 字体；使用声明随原压缩包存档 |
| D69《315 套 Q 版卡通角色 spine 动画》 | 冰糖撞果冻店铺（下载链接见包内免责声明） | ⚠️ 包内声明「仅供学习研究、不得商用，请购买正版」 | 角色 spine 试点（序号 097 关羽）；商用前需购正版授权，当前仅作开发期试点 |

## 7. 变更记录

- v0.1（2026-09-03）：初始建档（目录规范 + UI 素材台账 + 地图预留约定 + 许可登记）。
- v0.2（2026-09-03）：主菜单换肤落地——rect 三色按钮三态与 star / cross 图标投入运行时使用；换肤封装 `UITheme.apply_kenney_rect_button`；弹窗面板自绘先行说明。
- v0.3（2026-09-04）：概念图源码归档与 UI_CONCEPT v0.1 建档（见档头 v0.3 变更行；本档当时漏登，v0.4 补登）。
- v0.4（2026-09-07）：角色 spine 动画试点登记（见档头 v0.4 变更行与新 §5）。
