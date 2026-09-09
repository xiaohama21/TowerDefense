# 美术资产规范（ART_ASSETS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)，界面风格见 [UI_LAYOUT.md](UI_LAYOUT.md)。
> 承载总纲原章节：13「美术风格」行实现侧、附录「现有代码与资源映射」。
> 文档版本：v0.11（2026-09-09）
> v0.11 变更（2026-09-09，仓库归档对齐，纯文档/仓库卫生，程序 0.8.11.7 不变）：**Spine 试点素材与工具归档**——①`.gitignore` 落实「素材不入库」约定：`assets/characters/`（D69 试点素材与卡头像，授权口径见 §6）、`assets/spine_test/`（官方对照样例，§5.5）、`bin/`（spine-godot GDExtension 运行时，缺失时按 §5.7 静默回退程序化绘制）均本地存放不入库；②§5 已登记固化管线工具补入库 `tools/`：`spine_upgrade_38_to_43.py`（§5.3 转换器）+ `check_all_anims.gd`（§5.4 全动画冒烟，含 .uid），消除「文档登记但仓库缺失」；③本地一次性探针（check_guan_yu_tres / list_spine_api / probe_* / spine_headless / spine_preview* / prep_spineboy）不入库并 gitignore，孤儿 `probe_spine.gd.uid` 清理。文档版本 v0.10 → v0.11。
> v0.10 变更（阶段 8·提交 12 排期登记，程序 0.8.11.2 不变（0.8.11 修复/延伸期），用户拍板 2026-09-08「按你推荐来」/ GDD v0.37.5 / UI_LAYOUT v0.20.26 §15 / UI_CONCEPT v0.7，纯文档/素材无程序逻辑改动）：**光标素材目录预留 + 来源许可登记（Kenney Cursor Pack）**——①§2 目录树 `assets/ui/` 新增 `cursors/`（当前为空 = 预留，提交 12 落地）；②§3 待入库补注 `ui/cursors/`；③§6 来源许可登记 Kenney Cursor Pack 1.1（CC0，kenney.nl/assets/cursor-pack ）——`Outline/Default` 32px 原图 + 定稿配色 B 重着色（配方见 UI_LAYOUT §15），概念对照图所需 6 图子集随 `docs/ui_concept/src/kenney_cursor_pack/` 归档（仅设计复现用，完整包 729 个 PNG 未入库）。
> v0.9 变更（阶段 8·提交 11 延伸，程序 0.8.11.0 → **0.8.11.1**，用户拍板 2026-09-08「可以 按你推荐的来」/ GDD v0.37.3 / UI_LAYOUT v0.20.24）：**建造卡头像素材落地 + 拖拽虚影实塔小人化（§5.7 更新）**——①**卡头像（v0.9）**：关羽 A 套 Idle 首帧 SubViewport 透明截图 → bbox 裁切 → 圆形与圆角方两尺寸 PNG（`assets/characters/guan_yu/hero_guan_yu_a_avatar.png` / `_square.png`，各 ≈60KB，.import 已生成）；**素材本地存放不入库**（gitignore），UI 注册表 `CHARACTER_AVATAR_TEXTURES` 数据驱动、缺素材回退概念色占位圆；其余角色沿用「每角色截图 + 注册」流程；②**拖拽虚影实塔化**：BuildManager 虚影 = 实塔同款 Tower 渲染（spine 角色直接显 sprite（SpineSprite 转 PROCESS_MODE_ALWAYS 播 Idle）/ 程序化身体+武器回退，`Tower.set_ghost_mode` 跳过怒气条/冷却环/大招、保留射程圈），半透明绿/红染色由 BuildManager modulate；③**怒气条位置修订**：spine 塔条位 y48 → **y30**（胶囊 38×10 收进格内，普通塔 y28，见 UI_LAYOUT v0.20.24）。
> v0.8 变更（阶段 8·提交 11 落地，程序 0.8.10.33 → **0.8.11.0**，用户拍板 2026-09-07「1.接受…把这些放到提交 11 吧」）：**关羽 spine 尺寸调大试点落地 + 底座盘弱化（§5.7 更新）**——SPINE_BASE_SCALE 0.22 → **0.33**（约 1.5×，身体 ≈41px、约半格）/ SPINE_Y_OFFSET 6 → **8**；spine 激活时程序化底座圆盘改**贴地淡阴影**（`_draw_base` spine 分支：scale(1.55,0.5) 椭圆 alpha 0.16，消除脚下「内圈」）；怒气条位 y38 → 48（胶囊化见 UI_LAYOUT v0.20.22）、技能冷却环 r36 → 40 防遮挡；其余角色批量接入沿用 §5.7「每角色调一次 + 实机截图验收」流程（回退开关 = 清空 SPINE_CHARACTERS 注册表不变）。验收截图 build/spine_pilot/c11_{probe,battle_*}.png（gitignored）；同步 GDD v0.37.1 / UI_LAYOUT v0.20.22 / BUGS B-050 / README。
> v0.7 变更（阶段 8·提交 10 延伸·落地，程序 0.8.10.32 → **0.8.10.33**，**关羽 spine 战斗接入试点落地**，用户拍板 2026-09-07「补充文档，然后接入战斗试试吧」）：①§5.7「战斗接入」由登记转 ✅ 落地——`scripts/Tower.gd` 新增 SPINE_CHARACTERS 注册表（guan_yu → hero_guan_yu_a-data-res.tres）与 SPINE_BASE_SCALE 0.22 / SPINE_Y_OFFSET 6 / SPINE_FACE_SWITCH_EPS 6；`apply_character` 末尾 `_setup_spine_visual()` 动态 `add_child` SpineSprite（ClassDB 实例化，Tower.tscn 零改动）；Idle 常驻循环 / `play_melee_hit`·`play_attack_flash` 触发 Attack_A 单次（`get_track(0)` 判重防打断、`is_complete()` 回落 Idle、动画名经 `get_name()` 读取）；`_update_aim` 按目标水平分量刷 `_facing`（默认 -1），渲染 `scale.x = -facing × 0.22`；spine 激活时 `_draw` 跳过程序化身体/武器/挥击弧/枪口闪，怒气条移至脚下（y=38）、技能冷却环外扩（r=36）防遮挡；素材缺失 / SpineSprite 类不可用（无 GDExtension）静默回退程序化绘制；②**实测**——Smoke 全绿；实机战斗（关羽塔 + 黄巾兵/骑兵）验证：部署 Idle(loop)、挥击 Attack_A(once)、播完回落 Idle；目标在塔左 facing=-1（素材原样）、在塔右 facing=+1（镜像朝右）均正常；截图 build/spine_pilot/battle_{cap_idle,cap_shot01,r_shot03}.png（gitignored 验证产物）；③回退开关 = 清空 SPINE_CHARACTERS 注册表。
> v0.6 变更（阶段 8·提交 10 延伸·登记，程序 0.8.10.32，**左右对照验收结论 + 关羽接入战斗试点登记**，用户拍板 2026-09-07「补充文档，然后接入战斗试试吧」，纯文档，无程序逻辑改动）：①§5.6 补**渲染验收结论**——关羽 Idle / Attack_A 左右并排对照渲染（左=素材原样朝左，右=scale.x=-1 镜像朝右，build/spine_pilot/facing_*.png 属 gitignore 验证产物），全帧水平对称像素差 meanAbsDiff=0.000，方案 A 节点翻转渲染零瑕疵；②§5.6 朝向公式澄清为 `scale.x = -facing × 基准缩放`（facing 世界方向：-1 朝左=素材原样 +基准；+1 朝右=镜像 -基准）；③新增 §5.7「战斗接入（关羽试点，v0.6 登记）」——落地时机定为阶段 8·提交 10 延伸（目标程序 0.8.10.33，其余角色批量接入另排期）：Tower 内 character_id→spine 数据注册表数据驱动、素材缺失/无 GDExtension 回退程序化绘制、动画映射最小集（Idle 循环 / Attack_A 单次触发回落）、SpineSprite 代码动态挂载（不入 Tower.tscn）、朝向按 §5.6、spine 激活时程序化身体/武器/挥击弧/枪口闪跳过且怒气条上移与冷却环外扩防遮挡；④试点判定=战斗实机截图交用户验收，观感不达标即回退注册表。
> v0.5 变更（阶段 8·提交 10 延伸·登记，程序 0.8.10.32，**人物朝向镜像方案定稿**，用户拍板 2026-09-07「1.使用A方案；2.ok；3.非战斗界面不用翻转」，纯文档，无程序逻辑改动）：§5.6「人物朝向」由待拍板转定稿——实现方式 = **方案 A 节点翻转**（SpineSprite 所在节点 `scale.x = 朝向(±1) × 基准缩放`，素材与动画零改动）；判定规则 = Tower 增 `facing`（默认 -1 匹配素材朝左），随 `_update_aim` 按目标相对塔的水平分量刷新，|dx| 过小（正上/正下）保持原朝向防抖；**非战斗界面不翻转**（展示立绘保持素材原始朝向）；落地时机 = spine 正式接入战斗时（未排期），实施时 HUD 不挂 SpineSprite 子级、逐角色出左右对照渲染图验收；数据层镜像与双素材不采用（仅个别角色观感不达标时再评估数据层镜像）。
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
│   ├── cursors/            # 鼠标光标（Kenney Cursor Pack 调色定稿 B，提交 12 排期，当前为空=预留）
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

**待入库（空目录 = 预留）**：`ui/panels/` 弹窗面板底图（九宫格，Godot StyleBox 用）；`ui/cursors/` 鼠标光标（Kenney Cursor Pack 调色定稿 B，阶段 8·提交 12 排期，规范见 UI_LAYOUT §15）。正式换肤进度：主菜单已落地（v0.33.6——`UITheme.apply_kenney_rect_button` 九宫格按钮 + 自绘白面弹窗），其余面板逐步接入；尚未换肤的面板控件底色仍为程序化。

## 4. 地图素材约定（后续章节/换肤）

1. 主题底图：`map/themes/<theme_id>/`（如 `grass/fire/night`）；整幅底图按 1280×720，瓦片按 80px 网格基准。
2. 禁建地形：`map/terrain/`（山/河/城墙等），与 `StageData.forbidden_cells` 对应；需可辨识"不可建造"。
3. 标志物：`map/landmarks/`（基地城楼、出入口旗帜）。
4. 装饰：沿用 `map/decor/`，`GridBackground` 按 decor_type 确定性哈希选素材，缺失自动回退程序化绘制（树/石）；新装饰类型需同步注册 `GridBackground.DECOR_TYPES` 并登记本档。


## 5. 角色素材（spine 动画，试点登记）

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
6. **人物朝向（2026-09-07 拍板定稿：方案 A 节点翻转）**：试点素材固定朝左，游戏内人物需能镜像朝右。已拍板（用户）：
   - **实现方式 = 方案 A 节点翻转**：SpineSprite 所在节点 `scale.x = -facing × 基准缩放`（facing 为世界方向：-1 朝左 = 素材原样取 +基准；+1 朝右 = 镜像取 -基准）——素材与动画零改动；弹道/技能方向按现有 `_aim_angle` 全角度旋转、与身体朝向解耦，不受翻转影响；
   - **判定规则**：Tower 增 `facing`（1 右 / -1 左，默认 -1 与素材朝左一致），随 `_update_aim()` 按目标相对塔的水平分量刷新；目标在正上/正下（|dx| 小于阈值）保持原朝向防抖；
   - **非战斗界面不翻转**：百科/养成等展示立绘保持素材原始朝向，不提供镜像；
   - **落地时机**：关羽试点接入战斗 = 阶段 8·提交 10 延伸（目标程序 0.8.10.33），其余角色批量接入另排期（约定见 §5.7）。实施注意：塔 HUD（怒气环/选中圈等）不挂 SpineSprite 子级（会随镜像翻转）；spine 缺失/无 GDExtension 回退程序化绘制；逐角色出「同一动作左/右并排」渲染图肉眼验收（风险：非对称附件/素材内文字镜像）；
   - **不采用**：② 数据层镜像、③ 双素材（仅当个别角色节点翻转观感不达标时再评估 ②）。
   - **验收（2026-09-07 渲染对照）**：关羽 Idle / Attack_A 左右并排渲染图全帧水平对称像素差 meanAbsDiff=0.000 —— 节点翻转渲染零差异，方案 A 通过；

7. **战斗接入（关羽试点，v0.7 ✅ 落地，程序 0.8.10.33；v0.8 尺寸调大 + 底座弱化，程序 0.8.11.0；v0.9 卡头像 + 虚影实塔化，程序 0.8.11.1）**：接入约定如下（v0.6 先文档登记 → v0.7 实现 → v0.8 微调 → v0.9 卡头像/虚影）：
   - **数据驱动注册**：Tower 内 character_id → spine 数据资源注册表（试点为 `guan_yu` → `hero_guan_yu_a-data-res.tres`）；后续角色批量接入时收敛为角色数据字段/独立表并同步本节；
   - **缺失回退**：注册表无条目 / 资源不存在 / SpineSprite 类不可用（未随包 GDExtension）→ 沿用程序化绘制（`_draw_body`/`_draw_weapon`），游戏不依赖素材；
   - **动画映射（试点最小集）**：常驻 `Idle` 循环；攻击 = `Attack_A` 单次（近战 `play_melee_hit` / 弹道 `play_attack_flash` 处触发，经 `get_track(0)` + `is_complete()` 回落 Idle）；Move / Critical / Death 等随玩法接入再映射；
   - **渲染挂载**：SpineSprite 代码动态 `add_child`（不写进 Tower.tscn）；基准缩放 **0.33**（v0.8 / 0.8.11.0 由 0.22 调大约 1.5× 试点，实机截图验收；其余角色沿用「每角色一调 + 截图验收」流程）、垂直偏移按实机截图微调（±8 内，当前 8）；
   - **朝向**：按 §5.6——`facing` 世界方向（默认 -1 朝左），`scale.x = -facing × 基准缩放`（当前 0.33），随 `_update_aim` 按目标水平分量刷新，|dx| 过小保持原朝向防抖；
   - **遮挡处理**：spine 激活时程序化身体/武器/挥击弧/枪口闪不绘制（_draw 分支跳过）；怒气条上移、技能冷却环外扩，避免被角色素材遮挡；
   - **试点判定**：战斗实机截图（Idle 朝左 / 攻击朝右）交用户验收；观感不达标即清空注册表一键回退程序化绘制。
   - **实现明细（v0.7 / 0.8.10.33；v0.8 / 0.8.11.0 更新）**：Tower 内 SPINE_CHARACTERS 注册表 + SPINE_BASE_SCALE 0.33 / SPINE_Y_OFFSET 8 / SPINE_FACE_SWITCH_EPS 6；`apply_character` 末尾 `_setup_spine_visual()` 动态 add_child SpineSprite（skeleton_data_res 指向 data-res.tres）；`_update_aim` 按目标水平分量刷 `_facing`（±1），`scale.x = -facing × 0.33`；`play_melee_hit` / `play_attack_flash` 触发 Attack_A（get_track(0) 判重 + is_complete() 回落 Idle，动画名经 get_name() 读取）；spine 激活时 _draw 跳过身体/武器/挥击弧/枪口闪，**底座圆盘改贴地淡阴影**（_draw_base spine 分支：scale(1.55,0.5) 椭圆 alpha 0.16，消除脚下「内圈」），怒气条移至脚下（y=48，胶囊化见 UI_LAYOUT v0.20.22）、技能冷却环外扩（r=40）；素材缺失 / SpineSprite 类不存在 → 静默回退程序化绘制；
   - **实测（2026-09-07 首验；2026-09-08 v0.8 复验）**：Smoke 全绿；实机战斗（s01 关羽塔 + 黄巾兵/骑兵）验证——部署后 Idle(loop)、挥击瞬间 Attack_A(once)、播完回落 Idle；目标在塔左 → facing=-1（素材原样朝左）、目标在塔右 → facing=+1（scale.x=-0.33 镜像朝右）均正常；v0.8 尺寸 0.33 / 底座阴影 / 怒气条 / 冷却环 / 虚影头像见 build/spine_pilot/c11_{probe,battle_*}.png（gitignored，提交 11 验收截图）。
   - **卡头像素材（v0.9 / 0.8.11.1）**：SpineSprite Idle 首帧 SubViewport 透明截图 → bbox 裁切 → 圆形 `hero_guan_yu_a_avatar.png` 与圆角方 `_avatar_square.png` 两尺寸（各 ≈60KB，`assets/characters/guan_yu/`，.import 已生成）——**素材本地存放不入库**（gitignore），UI 注册表 `CHARACTER_AVATAR_TEXTURES` 数据驱动（character_id → 路径），缺素材回退概念色占位圆；其余角色沿用「每角色截图 + 注册」流程；
   - **拖拽虚影实塔化（v0.9 / 0.8.11.1）**：BuildManager 虚影 = 实塔同款 Tower——spine 角色直接显示 sprite（SpineSprite 转 PROCESS_MODE_ALWAYS 播 Idle）/ 程序化回退画身体+武器；虚影态（`set_ghost_mode`）跳过怒气条/冷却环/大招/选中圈、保留射程圈；半透明绿/红染色由 BuildManager modulate 控制；
   - **怒气条位置修订（v0.9 / 0.8.11.1）**：spine 塔条位 y48 → **y30**（胶囊 38×10 收进格内，普通塔 y28；冷却环 r40 不变）。

## 6. 来源与许可登记

| 素材 | 来源 | 许可 | 备注 |
|---|---|---|---|
| Kenney UI Pack 切片 | kenney.nl | CC0 | 全部 UI 按钮/图标；概念图 HTML 所需 17 图子集随 docs/ui_concept/src/kenney_ui_pack 归档（仅设计复现用，完整包按官方 CC0 可随时重下） |
| Kenney Cursor Pack 切片（光标） | kenney.nl（https://kenney.nl/assets/cursor-pack ） | CC0 | 光标视觉系统素材（阶段 8·提交 12 排期）：`Outline/Default` 32px 原图 + 定稿配色 B 重着色（配方见 UI_LAYOUT §15）；概念对照图所需 6 图子集随 docs/ui_concept/src/kenney_cursor_pack 归档（仅设计复现用，完整包 729 个 PNG 未入库） |
| 站酷快乐体 2016 修订版 | 站酷（ZCOOL） | 免费商用 | 字体；使用声明随原压缩包存档 |
| D69《315 套 Q 版卡通角色 spine 动画》 | 冰糖撞果冻店铺（下载链接见包内免责声明） | ⚠️ 包内声明「仅供学习研究、不得商用，请购买正版」 | 角色 spine 试点（序号 097 关羽）；商用前需购正版授权，当前仅作开发期试点 |

## 7. 变更记录

- v0.1（2026-09-03）：初始建档（目录规范 + UI 素材台账 + 地图预留约定 + 许可登记）。
- v0.2（2026-09-03）：主菜单换肤落地——rect 三色按钮三态与 star / cross 图标投入运行时使用；换肤封装 `UITheme.apply_kenney_rect_button`；弹窗面板自绘先行说明。
- v0.3（2026-09-04）：概念图源码归档与 UI_CONCEPT v0.1 建档（见档头 v0.3 变更行；本档当时漏登，v0.4 补登）。
- v0.4（2026-09-07）：角色 spine 动画试点登记（见档头 v0.4 变更行与新 §5）。
- v0.5（2026-09-07）：人物朝向方案定稿（方案 A 节点翻转 + facing 判定规则 + 非战斗界面不翻转），见 §5.6。
- v0.6（2026-09-07）：左右对照验收结论 + 关羽接入战斗试点登记（见档头 v0.6 变更行与 §5.7）。
- v0.7（2026-09-07）：关羽 spine 战斗接入试点落地（程序 0.8.10.33，见档头 v0.7 变更行与 §5.7）。
- v0.8（2026-09-08，补登）：关羽 spine 尺寸调大 + 底座盘弱化落地（程序 0.8.11.0，见档头 v0.8 变更行与 §5.7）。
- v0.9（2026-09-08）：建造卡头像素材 + 拖拽虚影实塔小人化 + 怒气条收格（程序 0.8.11.1，见档头 v0.9 变更行与 §5.7）。
