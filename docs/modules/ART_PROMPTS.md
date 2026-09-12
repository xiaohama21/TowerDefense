# AI 出图提示词库（ART_PROMPTS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)；美术资产规范/入库目录/许可见 [ART_ASSETS.md](ART_ASSETS.md)；技能来源见 [SKILLS.md](SKILLS.md) 与 [CHARACTER_SKILLS.md](CHARACTER_SKILLS.md)；物品/遗物/掉落来源见 [DROPS_GACHA.md](DROPS_GACHA.md)。
> 承载总纲原章节：13「美术风格」的实现侧补充（AI 出图管线）。
> 文档版本：v0.11（2026-09-11）
> v0.11 变更（2026-09-11，纯文档，程序版本不变，总纲 v0.37.29→v0.37.30）：**§5.1 波次旗帜按出图结果定稿 + 新增 §5.5 已出图登记**（用户确认 2026-09-11 局内 HUD v2 概念稿，图标来源见 [ART_ASSETS.md](ART_ASSETS.md) §3）——①波次旗帜意象「军旗 + 波次星角」→ 实际出图的 **军旗 + 旗下水浪**（用途扩至 顶栏波次胶囊 / **敌人出口出怪按钮**（点击出怪）/ 波次开始横幅），Prompt 同步改写为扁平矢量 + 深藏青圆角底板；②新增 **§5.5 已出图登记**：波次旗帜（`wave_flag` / `wave_flag_plate`）、金币（`coin`）、基地生命（`base_hp`）、伤害类型（`dmg_physical` / `dmg_magic` / `dmg_true`，§5.2 全套）、攻击速度（`stat_attack_speed`，§5.3）共 7 枚已出图并落在局内 HUD v2 概念稿（`docs/ui_concept/src/icons_battle/`）；③§6 补「HUD 图徽续补」待办。v0.10 历史行保留。
> 文档版本：v0.10（2026-09-11）
> v0.10 变更（2026-09-11，纯文档，程序版本不变，总纲 v0.37.28→v0.37.29）：**§5.3 韧性图标定稿**（用户拍板 2026-09-11「韧性可以用一个坚韧的拳头表示」）——韧性 铁砧 + 火花 → **握紧的拳头**（青铜，坚韧有力）；整套网格图与单张提示词同步。
> v0.9 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.27→v0.37.28）：**§5.3 三处再修**（用户反馈 2026-09-10「横杠不是在武器上，是在武器旁边；护甲和穿甲尽量相似，一个是完整护甲、一个是裂开的护甲」）——①攻击速度 速度横杠明确定为**武器旁边**（不在剑身上）；②护甲由「盾牌」改 **完整甲片**、穿甲改 **同款甲片裂开**，二者轮廓一致（并排一眼可辨同件），并注"可同色系仅裂口红橙"；整套网格图与单张提示词同步。
> v0.8 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.26→v0.37.27）：**§5.3 属性图标三处修订**（用户反馈 2026-09-10「攻速、穿甲、韧性都调整一下：攻速用沙漏不合理，改武器加几道横杠；穿甲就是护甲破碎；韧性再优化」）——①**攻击速度** 沙漏 + 两道速度箭 → **短剑 + 三道横杠**（挥击速度线，更贴合"出手快慢"）；②**穿甲** 箭头破甲片 → **碎裂的护甲片**（纯护甲崩裂，去掉箭头）；③**韧性** 相扣双链环 → **铁砧 + 一点火花**（金属耐久语义；韧性在项目尚无正式数值定义=待定属性列，取"坚韧/耐久"义，若后续定义为"控制抗性"可再换为挣断束缚符号）。整套网格图与单张提示词同步。
> v0.7 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.25→v0.37.26）：**UI 图标档防像素风修正**（用户反馈 2026-09-10「伤害的生成了一下，怎么成像素风了」）——根因 = ①负面词未排除像素/复古（`pixel art / 8-bit / dithering`）；②preset/模型选到像素类或分辨率过小；③提示词用 `glyph` / `square tiles` 易被判成位图图块。处理：①§2.2 锁定风格加「平滑矢量风（非像素）」条，`UI-STYLE` 改 `symbol/pictogram` + `smooth anti-aliased vector edges` + `no pixelation` + `rounded-square panel`，负面词前置 `pixel art, pixelated, 8-bit, 16-bit, retro game, dithering, voxel, mosaic, blocky, jagged aliased edges, low resolution`；②一致性做法注明**必须用非像素 preset/模型 + 分辨率 ≥1024**；③新增「常见跑偏与纠正」（像素 / 写实 / 个别不一致）；④§5.2~5.4 三组「整套网格图」改 `symbols` / `rounded-square panels` + `smooth vector` + `No pixelation`。

> v0.6 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.24→v0.37.25）：**§5.2~5.4 风格统一加固**（用户反馈 2026-09-10「5.2-5.4 这块风格没统一，随手生成两张风格差的也太多了」）——根因 = 上一版每条 Prompt 只给「符号 + 颜色」、风格靠模型自由发挥，必然漂移。处理：①§2.2 增「锁定风格」硬约束（2D 正视 / 统一深色描边 `#2b2b33` ≈短边 7% / 平涂单主色 + 一处白高光 / 居中留白 / 统一深藏青底）与**逐字复用的内联风格串 `UI-STYLE`**，负面词补 gradient/bevel/drop shadow 等；②补「一致性做法」——**首选一次出整套网格图**、母版做 Image Guidance/Style Reference、锁定模型+preset+seed、逐张自检；③§5.2/5.3/5.4 每组新增「**整套网格图**」提示词（3 / 7 / 6 枚同图出齐）与「单张 = 符号 + 主色 + `UI-STYLE`」两种用法；④§5 引子说明两种用法。
> v0.6 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.24→v0.37.25）：**§5.2~5.4 风格统一加固**（用户反馈 2026-09-10「5.2-5.4 这块风格没统一，随手生成两张风格差的也太多了」）——根因 = 上一版每条 Prompt 只给「符号 + 颜色」、风格靠模型自由发挥，必然漂移。处理：①§2.2 增「锁定风格」硬约束（2D 正视 / 统一深色描边 `#2b2b33` ≈短边 7% / 平涂单主色 + 一处白高光 / 居中留白 / 统一深藏青底）与**逐字复用的内联风格串 `UI-STYLE`**，负面词补 gradient/bevel/drop shadow 等；②补「一致性做法」——**首选一次出整套网格图**、母版做 Image Guidance/Style Reference、锁定模型+preset+seed、逐张自检；③§5.2/5.3/5.4 每组新增「**整套网格图**」提示词（3 / 7 / 6 枚同图出齐）与「单张 = 符号 + 主色 + `UI-STYLE`」两种用法；④§5 引子说明两种用法。

> v0.5 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.23→v0.37.24）：**风格拆两档 + §5.2~5.4 改简版 UI 图标标准**（用户反馈 2026-09-10「5.2-5.4 的提示词都需要调整，这些都是简单的 UI 贴图（可以参考 kingdomrush 的属性图标风格），与技能和物品图片不能使用同一个标准」）——①§2 由单一底座拆为 **2.1 立绘级（技能/物品）** 与 **2.2 简版 UI 图标级（Kingdom Rush 式极简符号，单符号/粗描边/纯色块/无场景无角色）** 两档 + 各自负面词，§2.3 参数合并（UI 图标级不加径向光晕）；②§1 规则补「两档风格不可混用」铁律、范围与识别位补 HUD 图标；③§5.2 伤害类型 / 5.3 人物属性 / 5.4 负面状态全部改写为单符号极简 Prompt（主色编码：物理钢灰·魔法紫蓝·真实白金；攻速琥珀·射程青蓝·护甲钢蓝·经验金·韧性青铜·穿甲橙红·移速绿；减速冰蓝·灼烧橙红·易伤洋红·眩晕亮黄·恐惧暗紫·击退褐钢）；5.1 波次旗帜保持立绘级。
> v0.5 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.23→v0.37.24）：**风格拆两档 + §5.2~5.4 改简版 UI 图标标准**（用户反馈 2026-09-10「5.2-5.4 的提示词都需要调整，这些都是简单的 UI 贴图（可以参考 kingdomrush 的属性图标风格），与技能和物品图片不能使用同一个标准」）——①§2 由单一底座拆为 **2.1 立绘级（技能/物品）** 与 **2.2 简版 UI 图标级（Kingdom Rush 式极简符号，单符号/粗描边/纯色块/无场景无角色）** 两档 + 各自负面词，§2.3 参数合并（UI 图标级不加径向光晕）；②§1 规则补「两档风格不可混用」铁律、范围与识别位补 HUD 图标；③§5.2 伤害类型 / 5.3 人物属性 / 5.4 负面状态全部改写为单符号极简 Prompt（主色编码：物理钢灰·魔法紫蓝·真实白金；攻速琥珀·射程青蓝·护甲钢蓝·经验金·韧性青铜·穿甲橙红·移速绿；减速冰蓝·灼烧橙红·易伤洋红·眩晕亮黄·恐惧暗紫·击退褐钢）；5.1 波次旗帜保持立绘级。
> v0.4 变更（2026-09-10，纯文档，程序版本不变，总纲 v0.37.22→v0.37.23）：**新增 §5「通用 HUD 图徽」**——波次旗帜、伤害类型（物理/魔法/真实，口径 NUMBERS 10.12）、人物属性（攻速/射程/护甲/经验/韧性/穿甲/移速）、负面状态（减速/灼烧/易伤/眩晕/恐惧/击退拖回，口径 STATS_PIPELINE §6）；原 §5 待办 → §6、原 §6 变更记录 → §7。
> v0.3 变更（2026-09-10，经验池 + 军功/军需重构定稿同步 / GDD v0.37.22 / DESIGN_REVIEW v0.4.7 / NUMBERS 10.14·10.15，纯文档，程序 0.8.11.13 不变，排期 0.8.15 / 0.8.16）：**§4.1 练兵令转历史 + §4.3 新增两件军需提示词（id 草案）**——①`exp_scroll` 随 0.8.15 经验池删除（图标**不再出图**，条目作历史保留）；②§4.3 增补「掷石齐射」`stone_volley`（全场 60 物理伤害）与「犒军」`reward_troops`（全队怒气 +20）提示词与图标意象（军需池 6 件制，坚壁 / 伤药 / 火油罐本就未建档、无需处理）。
> v0.2 变更（2026-09-09，信物重构定稿同步 / GDD v0.37.20 / CHARACTERS 4.8 / DESIGN_REVIEW v0.4.6，纯文档，程序 0.8.11.12 不变，排期 0.8.14）：**§4.4 武将信物口径更新**——旧 3 件信物转专属槽占位（锁住、暂不出图）；新增 Boss 签名信物「天公雷诏」「太平要术·残卷」提示词随 0.8.14 按本模板补入（命名/效果见 CHARACTERS 4.8 / NUMBERS 10.13）。**§4.6 通用碎片作历史保留**——碎片功能整体删除、不再出图。
> v0.1 变更（2026-09-08，首次建档，纯文档/素材、无程序逻辑改动）：**AI（Leonardo.ai）出图提示词库建档**——面向"技能图标 + 物品图标"的运行时图徽生成管线：统一 Q 版卡通三国风格底座 + 通用负面词 + 出图规范；职业技能核心 6 + 二转新技能 6 + 职业大招 6 + 角色技能 9 + 材料/道具、局内遗物、局内军需、武将信物、羁绊徽记等物品分类提示词；登记 0.1 模块索引。程序版本号不变。

---

## 1. 定位与原则

1. **目的**：给 AI（默认 [Leonardo.ai](https://leonardo.ai)）生成"需要玩家在 UI 上识别"的技能/物品图徽提供一套可复现、画风统一的提示词，避免逐张临时拼词导致成套图标风格漂移。
2. **范围**：本档覆盖两类图徽——①**技能 / 物品立绘级图徽**；②**通用 HUD 图标**（伤害类型、人物属性、负面状态等）。UI 系统图标（按钮/星标/光标等）仍沿用 Kenney CC0 素材（[ART_ASSETS.md](ART_ASSETS.md) §3/§6）；角色战斗立绘走 spine（[ART_ASSETS.md](ART_ASSETS.md) §5）；敌人/特效立绘【远期】——以上**不在本档**出图。
3. **识别位**（图标要落在哪些 UI）：养成 / 百科的"技能页签"技能徽；背包 / 编队遗物 / 局内军需的物品徽与遗物徽；武将信物徽、羁绊徽记徽；HUD 属性列 / 伤害数值标注 / 敌人状态条（承载 UI 以运行版为准，本档只定图徽本体）。
4. **两档风格不可混用（铁律）**：技能 / 物品走 §2.1**立绘级底座**（Q 版卡通，有场景感、有主角）；伤害类型 / 属性 / 负面状态等 HUD 图标走 §2.2**简版 UI 图标底座**（Kingdom Rush 式极简符号，单符号、无场景、无出场角色），**二者不得共用同一套标准**。同档内共用底座与负面词；建议同一模型 + 固定 seed 批量出。**文字一律不进图**——AI 生成中文十有八九乱写，名称/数值进 UI 后用快乐体叠加（与全局字体一致）；故所有 Prompt 都要求无文字无字母。
5. **强化/状态不进图**：职业技能 `+` 强化态、满怒/大招就绪/冷却等一律由引擎叠层（金边/呼吸光/冷却环）表达，不重复出图。
6. **落地流程**：出图 → 定稿后透明抠底裁小（与 `assets/characters/*_avatar*.png` 同流程）→ 按 [ART_ASSETS.md](ART_ASSETS.md) §2 目录登记入库（技能/物品图标落 `assets/ui/icons/` 预留位）；**本地素材不入库**（gitignore，沿用 ART_ASSETS §5.7 头像先例）。
7. **许可**：AI 生成内容的版权/商用条款随平台而定，需自行核实；如涉"学习研究不得商用"类素材（D69 spine 包前例）必须商用前购授权后再替换。

---

## 2. 统一风格与出图规范（两档）

> **两档标准不可混用**：技能 / 物品 = §2.1 立绘级；伤害类型 / 属性 / 负面状态等 HUD 图标 = §2.2 简版 UI 图标级。所有条目 Prompt =「条目主体段」+「对应档位底座」，负面词按档位单独填 Leonardo 负面栏。

### 2.1 立绘级底座（技能 / 物品图徽）

**底座（每张技能/物品 Prompt 末尾追加）**
```text
Mobile game icon, chibi Q-version Three Kingdoms cartoon style, cel shaded with bold clean dark outline, flat clean vector coloring, single centered emblem, strong clear silhouette readable at small icon size, subtle radial glow, dark deep-navy vignette background, high contrast, crisp edges, 1:1 square. No text, no letters, no numbers, no watermark, no frame.
```

**负面词（Negative Prompt 栏整段粘贴）**
```text
text, letters, numbers, Chinese characters, calligraphy, watermark, logo, signature, photo, realistic, extra characters, messy clutter, thin unreadable details, hands with fingers, background scenery.
```

### 2.2 简版 UI 图标底座（伤害类型 / 人物属性 / 负面状态等 HUD 图标）

> 定位 = **Kingdom Rush 式属性图标**：极简单符号、粗描边、平涂纯色、高对比，32px 下仍一眼可辨；**无场景、无出场角色、无光晕、无材质细节**。与技能/物品立绘**分开出**、不共用 2.1 底座。

**锁定风格（全册逐字一致，禁止逐图变形）**
- **平滑矢量风（非像素）**：曲线平滑、边缘抗锯齿；**无像素化 / 无网点抖动 / 无马赛克 / 非 8·16bit / 非复古**。
- 2D 正视符号：**无 3D / 无透视 / 无投影 / 无渐变 / 无纹理 / 无景深**。
- 描边：统一深色描边（≈ `#2b2b33`），线宽 ≈ 画布短边 7%，整册一致。
- 填色：平涂**单一主色** + 至多一处白色高光点缀；不做第二层明暗/色阶。
- 构图：符号居中、约占画布 70%、四周等距留白；端点/转角统一圆角。
- 底：整册同一底色（深藏青圆角方形面板 `#1f2430`，或统一纯色/透明感底）。
- 主色仅作"区分编码"；**除主色外的一切风格参数全部锁死**。

> ⚠️ **防风格漂移核心**：不要给模型只丢"符号 + 颜色"就自由发挥（这是 5.2~5.4 上一版两张图风格差太多的根因）；必须让每条 Prompt 复用**逐字相同**的风格串。

**内联风格串 `UI-STYLE`（每条单张 Prompt 末尾逐字追加，禁止改写）**
```text
flat 2D game UI symbol, single bold pictogram, thick uniform dark outline, smooth anti-aliased vector edges, flat solid single-color fill with one white highlight accent, no gradient, no shadow, no 3D, no perspective, no texture, no pixelation, centered with even margin, plain dark navy rounded-square panel background, clean high-resolution game attribute icon, 1:1 square. No text, no letters, no numbers, no watermark, no frame.
```

**负面词（Negative Prompt 栏整段粘贴）**
```text
pixel art, pixelated, 8-bit, 16-bit, retro game, dithering, voxel, mosaic, blocky, jagged aliased edges, low resolution, text, letters, numbers, Chinese characters, watermark, logo, signature, detailed illustration, chibi character, person, scene, background scenery, radial glow, gradient, 3D render, bevel, drop shadow, painterly, texture noise, thin lines, many objects, cluttered, realistic, photo.
```

**一致性做法（关键）**
1. **一次出整套（首选）**：用 §5.2/5.3/5.4 的「整套网格图」提示词，一张图出齐整组再切分——同图内风格天然统一，比逐张出稳得多。
2. **图像引导**：先定稿 1 张母版，其余单张全部以该母版为 Image Guidance / Style Reference。
3. **参数锁定**：同一模型 + 同一 preset + 同一 seed + 同一尺寸；**务必用非像素类 preset/模型**（Flat / Vector Illustration / Illustration 类），**不要选 Pixel Art / Retro 类 preset 或像素模型**；分辨率 ≥1024，勿用小尺寸（小图 + 粗描边易被判成像素风）。
4. **逐张自检**：描边粗细 / 是否平涂 / 是否居中 / 底色是否同一——不符的重出，不要将就。

> **常见跑偏与纠正**
> - **出成像素风**：① 负面词补 `pixel art, pixelated, 8-bit, dithering, voxel, blocky`；② 换掉 Pixel Art / Retro 类 preset 与像素模型；③ 提高分辨率到 ≥1024；④ 正向补 `smooth anti-aliased vector edges, high-resolution`。
> - **出成写实/3D**：负面词已含 `realistic, photo, 3D render`；正向强调 `flat 2D`。
> - **一组里个别不一样**：重出该张（同 seed），或用母版做 Image Guidance。

### 2.3 出图参数建议（通用）

- 尺寸：1:1 方形；主体居中约占画面 60%~70%（图标最终在小尺寸 UI 槽内显示，外圈会被裁/盖）。
- 底色：立绘级 = 深色径向渐变（贴合 UI_LAYOUT §2 深底语义）；UI 图标级 = 纯平底色（或纯色/透明感底），**不加径向光晕**。
- 一致性：同一模型 + 同 seed 重 roll 出一套；两档各自成套，批量前各先出 1 张定调再铺开。
- 调优：某图反复出现同一坏毛病（如乱加字幕），单独把该词补进对应档位负面栏即可，不必加重叠。

**识别优先级**：立绘级 = 大字剪影 > 单一主角 > 亮色点缀；UI 图标级 = 单一符号 > 粗描边 > 高对比。两档都要避开细线、复杂背景、多余元素。

---

## 3. 技能图标清单

> 技能来源与机制权威见 [SKILLS.md](SKILLS.md)（职业技能）与 [CHARACTER_SKILLS.md](CHARACTER_SKILLS.md)（角色技能）；下表中的技能 id 供开发者回溯。

### 3.1 职业技能核心（一转授予，每职业 1 个）——已建档提示词

| 职业 | 技能 | skill_id | 图标意象 |
|---|---|---|---|
| 骑兵 | 蓄力 | `charge` | 战马攒力、枪尖聚金，一次高伤爆发 |
| 虎贲 | 军旗 | `command` | 插地军旗 + 金色士气光环扩散 |
| 弓箭手 | 稳射 | `steady` | 拉满长弓 + 精确涟漪准环 |
| 术士 | 奇谋 | `wisdom` | 羽扇 + 八卦法阵外扩 + 冰蓝符文 |
| 舞娘 | 鼓舞 | `inspire` | 舞袖转圈 + 金色共振光环 |
| 投石车 | 破城 | `siege` | 投石车轰塌城墙、碎石四溅 |

- **骑兵·蓄力** `charge`（单体高伤攒力、击杀返怒循环）：战马仰蹄、枪尖聚起一点爆发金芒。Prompt（拼 §2 底座）：`A sturdy chibi armored Chinese war horse rearing up, a cavalry lance held high whose spearhead gathers blazing golden energy into one focused point, golden power-lines and sparks, a small impact star below, single heavy empowered strike, warm gold and steel tones, heroic.`
- **虎贲·军旗** `command`（150px 常驻士气光环）：插地红旗 + 金虎徽记 + 光环扩散。Prompt：`A tall crimson war banner planted on the field with an embroidered golden tiger-head emblem, rippling cloth radiating a soft expanding gold morale aura ring from the flagpole, brave frontline spirit, red and gold tones.`
- **弓箭手·稳射** `steady`（每 5 次命中必追加）：拉满弓 + 稳定涟漪准环。Prompt：`A chibi archer drawing a wooden longbow to full draw, nocked arrow, precise target reticle with faint steady concentric ripple rings ahead, calm focused marksman, spare arrows leaning beside, wood-green and cold-steel blue tones.`
- **术士·奇谋** `wisdom`（大招范围 +10%×s）：羽扇 + 扩圈法阵 + 冰缓符文。Prompt：`A chibi Taoist strategist waving a feather fan above a glowing expanding bagua spell-formation, swirling icy-blue and gold runic energy with frost essence, mysterious wise mood, blue gold and faint violet magic tones.`
- **舞娘·鼓舞** `inspire`（大招后全队攻速 +6%×s）：舞袖中旋 + 金色共振波。Prompt：`A graceful chibi dancer in flowing hanfu sleeves caught mid-twirl, golden resonance ring-waves and sparkles spreading outward to allies, warm gold-rose cheerful aura of rousing the whole team.`
- **投石车·破城** `siege`（对精英/Boss +10%×s）：巨石轰城墙崩裂。Prompt：`A chibi catapult siege machine hurling a heavy flaming boulder that smashes into a crumbling city wall, bricks and rubble bursting outward, cracks and fiery impact, massive demolishing power, stone-grey earth-brown and orange-fire tones.`

### 3.2 职业技能强化态 `+`（二转强化线，6）——复用，不出新图

| 职业 | 二转强化分支 | 图标 = 核心技能 + 引擎金边 |
|---|---|---|
| 骑兵 | 玄甲 | 蓄力+ |
| 虎贲 | 陷阵 | 军旗+ |
| 弓箭手 | 穿云 | 稳射+ |
| 术士 | 智囊 | 奇谋+ |
| 舞娘 | 凤仪 | 鼓舞+ |
| 投石车 | 拔城 | 破城+ |

> 复用 §3.1 同款图标，`+` 强化态由引擎叠金色描边/高光表达，AI 只出一份底图。

### 3.3 二转新技能（二转新技能线，6）——待出图

| 职业 | 二转分支 | 新技能 | skill_id | 图标意象 |
|---|---|---|---|---|
| 骑兵 | 骁骑 | 突袭 | `assault` | 骑兵连突、叠层刀光、连击攒力 |
| 虎贲 | 虎卫 | 护卫 | `guard` | 持盾将敌沿路拖回、锚地抗线 |
| 弓箭手 | 连弩 | 连矢 | `chain_arrow` | 连弩一矢接一矢、直线串射 |
| 术士 | 天师 | 奇门 | `mystic_gate` | 符箓法门落点 + 易伤印记 |
| 舞娘 | 绕梁 | 余音 | `echo` | 余音绕梁、金色音波回响加持 |
| 投石车 | 震山 | 震地 | `tremor` | 落点环形地裂 + 眩晕星纹 |

- **骑兵·突袭** `assault`（击杀/命中精英叠层上限 3、普攻消耗增伤）：战骑一冲而过、三道叠层残影。Prompt：`A fast chibi cavalry lancer dashing through motion lines with three layered after-image strikes stacking at the lance tip, combo charge building up, momentum and swiftness, steel and electric-gold tones.`
- **虎贲·护卫** `guard`（近战命中 25%×s 概率沿路拖回 20px、内置冷却 2.5s）：盾戟把敌往回拖、地面拖痕。Prompt：`A chibi tiger-guard warrior planting a heavy shield and wrenching an enemy backward along the road with a hooked halberd, ground drag marks, frontline anchoring and control, red iron and earth tones.`
- **弓箭手·连矢** `chain_arrow`（命中 20% 概率追加 0.5×s、目标死顺延）：连弩串联一串飞矢。Prompt：`A chibi repeating crossbow loosing a linked volley of arrows chained tip-to-tail in one quick straight burst, swift arrow trails, rapid chain precision, wood and white-arrow tones.`
- **术士·奇门** `mystic_gate`（大招后落点范围内易伤 +10%×s）：符箓法门 + 易伤符印。Prompt：`A chibi heavenly-master Taoist casting a glowing mystic-gate sigil of talisman runes and a bagua doorway that brands the target zone with a vulnerability emblem, arcane blue-violet spellwork.`
- **舞娘·余音** `echo`（大招后全队伤害 +8%×s 持续 5s）：绕梁余音、金色回响漫过全员。Prompt：`A graceful chibi dancer's lingering afterglow, resonant golden sound ripples and music-note sparkles echoing across the field like a lasting melody boosting the whole team, gold and soft-rose tones.`
- **投石车·震地** `tremor`（大招每发落点眩晕 0.5s×s、同敌内置冷却）：落石砸出环形地裂晕纹。Prompt：`A catapult boulder impact shattering the ground into a ring of tremor cracks and a shockwave star-flash stunning the area, flying stone shards, earth-brown and impact-white tones.`

### 3.4 职业大招（怒气驱动，每职业 1 个）——待出图

| 职业 | 大招（ultimate_id） | 定位/效果 | 图标意象 |
|---|---|---|---|
| 骑兵 | `ultimate_cavalry_breaker` | 单体斩杀、击杀返还 50% 怒气 | 一记决定胜负的怒斩 + 返怒回流 |
| 虎贲 | `ultimate_tiger_guard_sweep` 破阵 | 范围 1.5× 普攻 + 击退 + 附近友方激励 | 大范围荡扫冲击 + 激励光环 |
| 弓箭手 | `ultimate_archer_volley` | 快速连射 3~5 箭、优先低血量 | 箭雨连珠、残血收割 |
| 术士 | `ultimate_strategist_blaze` | 区域 2× 范围伤害 + 减速 40%/2s | 烈焰法阵 + 蓝冰缓速外环 |
| 舞娘 | `ultimate_dancer_encourage` | 全队攻速/伤害爆发窗口 | 金色鼓舞爆发普照全队 |
| 投石车 | `ultimate_catapult_barrage` | 3 连发快速抛射轰击区域 | 三连巨石同落压制 |

- **骑兵大招**（单体斩杀、击杀返怒）：一记致命怒斩 + 金色怒气回流枪身。Prompt：`A charged chibi cavalry cleaving a single decisive finishing strike, crimson execution slash burst with returned-rage golden energy flowing back into the blade, one-kill momentum, gold-crimson tones.`
- **虎贲大招·破阵**：荡扫震退 + 激励光环援护友方。Prompt：`A tiger-guard warrior sweeping a great arc that knocks enemies back in a shockwave while a motivating golden aura lifts nearby allies, breakthrough charge with rallying banner, red-gold tones.`
- **弓箭手大招**（连珠收割）：漫天箭矢收敛向目标。Prompt：`A volley of many swift glowing arrows raining down and converging on weakened enemies, harvest-storm of bolts, focused rapid fire, cold steel-blue and white-arrow tones.`
- **术士大招**（烈焰 + 减速控场）：法阵爆焰 + 冰缓外环。Prompt：`A strategist erupting a wide blazing spell-formation over the target area, fiery core ringed by icy slow-mist, big area fire-field with a frost slowing rim, orange-fire and ice-blue tones.`
- **舞娘大招**（全队爆发）：金色鼓舞浪潮漫过全员。Prompt：`A dancer unleashing a grand golden burst of encouragement, resonance rings and radiance washing over the whole team empowering everyone, festival of high morale, radiant gold tones.`
- **投石车大招**（三连轰击）：三颗巨石同落一片区域。Prompt：`A catapult rapid-firing three flaming boulders in quick succession onto one target zone, stacked barrage impacts suppressing the area from afar, stone and orange-fire tones.`

### 3.5 角色技能（武将专属，9 名）——待出图

| 武将 | 技能（典故） | 类型/效果 | 图标意象 |
|---|---|---|---|
| 关羽 | 青龙偃月（温酒斩华雄） | A·CD18s·2.5× 单体、击杀 -CD 6s | 青龙偃月刀 + 青绿龙形刀光 |
| 张飞 | 当阳桥（喝退曹军） | A·CD22s·恐惧 1s → 减速 60%/2s | 怒喝声波 + 紫色恐惧环 |
| 刘备 | 携民渡江 | B·每波首漏·全队攻速 +15% 5s | 携民渡江 + 金色援护 |
| 黄忠 | 定军山（斩夏侯渊） | A·CD18s·2.5× 单体 + "定军"易伤标记 | 神箭 + 定军符印 |
| 貂蝉 | 月下舞（拜月） | A·CD25s·全队怒气 +10 | 月下起舞 + 月华注怒 |
| 皇甫嵩 | 焚营（长社火攻） | A·CD20s·区域 1.5× + 灼烧 3s | 焚营烈焰 + 灼烧余烬 |
| 赵云 | 七进七出（长坂坡） | B·每波首漏·范围反击 + 攻速 +30% | 银枪七进七出、反身横扫 |
| 周仓 | 死战（麦城） | B·基地 ≤50%·攻速 +30% 常驻 | 死战不退、残刃怒吼 |
| 诸葛亮 | 借东风（赤壁） | A·CD30s·全图攻速 +20%、弹道 +50% 8s | 祭坛借东风、青绿气流卷全场 |

- **关羽·青龙偃月**：青绿龙形刀光一刀落。Prompt：`A heroic warrior's green-dragon crescent-blade cleaving with a coiling emerald dragon arc, one decisive heavy cut in cold calm, jade-green blade-light and drifting sparks.`
- **张飞·当阳桥**（恐惧=紫色呼吸圆环表现，v0.35.2）：声浪慑退敌军。Prompt：`A bellowing bearded warrior roaring across a river bridge, booming deep-purple shockwave rings that turn enemies to flee backward in fear, sonorous terror, deep purple tones.`
- **刘备·携民渡江**（每波首漏反制、全队攻速）：仁主携民 + 金辉援护。Prompt：`A benevolent ruler escorting common folk across a river under a warm gold protective canopy, humane rally lifting allied morale, warm gold and jade-green tones.`
- **黄忠·定军山**：山巅神箭落点 + 定军易伤符。Prompt：`An aged master archer loosing a brilliant piercing arrow from a mountain peak, striking and branding the target with a fixed-fort vulnerability seal, decisive and precise, steel-gold and wood tones.`
- **貂蝉·月下舞**（拜月灌怒）：月下长袖、月光化金注全队。Prompt：`A beautiful dancer under a full moon, silvery moonlight weaving into golden rage-essence orbs that flow to nearby allies, moonlit bestowal of energy, silver-blue and gold tones.`
- **皇甫嵩·焚营**（长社火攻 + 灼烧）：火攻焚营烈焰冲天。Prompt：`A strategist igniting an enemy camp in roaring flames, burning siege spreading with lingering scorch afterglow on the ground, fierce orange-red fire and ash tones.`
- **赵云·七进七出**（漏怪范围反击 + 攻速）：银枪冲杀、回身横扫漏怪。Prompt：`A silver-armored spear general weaving a seven-fold charge, sweeping back against leaking foes in a wide counter arc while gaining speed, undying momentum, silver and storm-white tones.`
- **周仓·死战**（基地低血常驻暴攻速）：强弩之末仍奋战。Prompt：`A steadfast loyal warrior fighting a desperate last stand, cracked blade held high as the stronghold falls into danger, unyielding fierce will, blood-red and worn-iron tones.`
- **诸葛亮·借东风**（全图攻速 + 弹道提速）：祭坛借风、青绿气流助推。Prompt：`A wise strategist on a ritual altar summoning the east wind, cyan-green wind streams sweeping across the whole field to speed allied projectiles, heavenly wind aid, cyan and pale-green tones.`

---

## 4. 物品图标清单

> 物品正式名称/描述以 `resources/items|battle_relics|battle_supplies|bonds|relics/*.tres` 为准（item_id / relic_id 见下表）。

### 4.1 材料与道具

| 物品 | item_id | 说明 | 图标意象 |
|---|---|---|---|
| 黄巾布 | `yellow_turban_cloth` | 转职/养成材料（第一章掉落） | 黄色头巾布束 |
| 练兵令【❌ 随 0.8.15 删除】 | `exp_scroll` | 测试消耗品（升 1 级，不进掉落）；**经验池「直接升级」取代，图标不再出图** | 木质练兵令卷（历史条目） |
| 求贤令 | `gacha_token` | 抽奖消耗（⏸ v0.30.0 移除，资源保留） | 求贤令牌 |

- **黄巾布** `yellow_turban_cloth`（黄巾军遗留材料）：一束明黄头巾布。Prompt：`A folded bundle of yellow-turban cloth tied as a headband roll, rustic loot material from rebel soldiers, warm mustard-yellow fabric with simple weave.`
- **练兵令** `exp_scroll`【历史保留 · 已删除（0.8.15）】（测试用，练级）：一块练兵木令/竹简。Prompt：`A wooden training command tally with tied cord, simple drill scroll for leveling troops, wood-brown and ink tones.`
- **求贤令** `gacha_token`（求贤招募，资源保留）：一枚求贤令牌（羽饰金边）。Prompt：`An ornate recruit talisman token for seeking worthies, gold-trimmed jade tablet with a small feather tassel, ceremonial blue-gold tones.`

### 4.2 局内遗物（背包/编队选带，永久使用）

| 物品 | relic_id / item_id | 效果 | 图标意象 |
|---|---|---|---|
| 铁盾徽记 | `iron_shield` | 基地生命 +10 | 铁盾徽章 |
| 军粮袋 | `provision_bag` | 初始金币 +50 | 扎口军粮袋 |
| 鹰眼符 | `scout_eye` | 射程 +10% | 鹰羽护符 |
| 战鼓 | `war_drums` | 攻速 ×0.95 | 牛皮战鼓 |
| 狼牙符 | `wolf_tooth` | 全伤害 +5% | 狼牙符坠 |

- **铁盾徽记** `iron_shield`：边军铁盾徽记、守御加固。Prompt：`A front-line iron shield badge of regular border troops, riveted heavy shield emblem, sturdy defense, iron-grey with rivet highlights.`
- **军粮袋** `provision_bag`：辎重先行、装满出征口粮。Prompt：`A bulging military grain sack tied at the neck, supply-first logistics, burlap tan with cloth patches.`
- **鹰眼符** `scout_eye`：斥候鹰羽护符、目力过人。Prompt：`A talisman charm made from a scout hawk's feather with a keen eagle-eye motif, grey-blue feather and small amber eye.`
- **战鼓** `war_drums`：擂动牛皮战鼓、士气高昂。Prompt：`A leather war drum with golden studs and crossed drumsticks, morale drumming, warm brown drum with gold ring.`
- **狼牙符** `wolf_tooth`：磨制狼牙、出手更狠。Prompt：`A sharp wolf-fang talisman bound with a leather cord and coarse fur, fierce predator strength, bone-white fang and grey tones.`

### 4.3 局内军需（战备，军需面板消耗；2026-09-10 定稿 6 件池 / 排期 0.8.16）

| 物品 | item_id | 效果 | 图标意象 |
|---|---|---|---|
| 火攻 | `fire_attack` | 全场 50 伤 + 灼烧 3s | 引燃全场火种 |
| 修整 | `repair` | 基地生命 +10 | 锤具修整城防 |
| 缓兵 | `slow_down` | 全场减速 40%/5s | 缓兵疑雾/滞行符 |
| 擂鼓 | `war_drum` | 全队攻速 +30%/8s | 重擂战鼓 |
| 掷石齐射【新】 | `stone_volley`（id 草案） | 全场敌人各受 60 物理伤害 | 漫空飞石齐落 |
| 犒军【新】 | `reward_troops`（id 草案） | 全队怒气 +20 | 犒赏酒肉 + 士气金光 |

- **火攻** `fire_attack`：火种引燃全场敌军 + 灼烧。Prompt：`An igniting fire-brand setting the whole battlefield ablaze, burning spread with lingering scorch on enemies, fierce orange flames and sparks.`
- **修整** `repair`：紧急修整城防。Prompt：`A hammer and trowel repairing a city-wall segment, reinforcement and repair tools, warm wood handle with stone and mortar.`
- **缓兵** `slow_down`：疑兵烟雾、全场滞行。Prompt：`Deceptive decoys and drifting fog slowing an entire marching column, a slow-down ward with trailing mist, grey-blue cold tones.`
- **擂鼓** `war_drum`：重擂鼓点普照全队提速。Prompt：`A great war drum being struck with glowing percussion ring-waves rallying all allies, red-gold drumbeats radiating morale.`
- **掷石齐射** `stone_volley`【0.8.16 新增】：漫天飞石齐落敌阵。Prompt：`A volley of hurled boulders arcing across the battlefield in mid-flight with dust trails, massed stone-throwing barrage from the whole army, grey stone and dusty ochre tones.`
- **犒军** `reward_troops`【0.8.16 新增】：犒赏三军、怒气高涨。Prompt：`A reward feast for the troops with wine jars and grain sacks under a golden morale glow, cheering soldier silhouettes and rising fury, warm amber and gold tones.`

### 4.4 武将信物（现有入库 3；2026-09-09 重构定稿、排期 0.8.14：旧 3 件转专属槽占位锁住；Boss 签名信物「天公雷诏」「太平要术·残卷」提示词待补；兑换途径删除）

| 信物 | relic_id | 意象 |
|---|---|---|
| 青龙偃月断刃 | `relic_guanyu_blade` | 断刃含龙纹 |
| 蛇矛精锻 | `relic_zhangfei_spear` | 蛇形矛头 |
| 火攻图卷 | `relic_huangfusong_torch` | 火攻批注图卷 |

> **续补规则**：信物按"武将典故 + 信物名"续补（关羽信物=青龙偃月断刃先例）；其余武将信物命名/掉落随各章节规划定稿后，按 §4.4 同模板补提示词，无需改架构。

- **青龙偃月断刃** `relic_guanyu_blade`（广宗缴获、刀锋犹带龙吟）：缠龙纹断刀。Prompt：`A broken shard of the Green-Dragon crescent blade still faintly dragon-voiced, coiled jade dragon motif on the steel, relic of a great hero, jade-green and aged steel tones.`
- **蛇矛精锻** `relic_zhangfei_spear`（重铸矛头、出刺更快）：盘蛇精锻矛头。Prompt：`A reforged serpent spear-head with a coiling viper curve in polished steel, sharper thrusting relic, iron with subtle green glint.`
- **火攻图卷** `relic_huangfusong_torch`（皇甫嵩亲批方略）：火攻兵法图卷。Prompt：`A battle-scroll of fire-attack strategy personally annotated, rolled parchment bound with a flame-red seal, strategic relic, parchment and cinnabar tones.`

### 4.5 羁绊徽记（编队标签）

| 羁绊 | bond_id | 意象 |
|---|---|---|
| 桃园结义 | `taoyuan_oath` | 桃枝下三结义金徽 |
| 五虎将 | `five_tigers` | 五虎啸聚徽记 |

- **桃园结义** `taoyuan_oath`（刘关张同队 +5% 攻击）：桃园三结义。Prompt：`An oath emblem of three brothers clasping hands beneath a blooming peach tree, peach-pink blossom and jade tones, sworn-brotherhood seal.`
- **五虎将** `five_tigers`（同队 +6% 攻击）：五虎啸聚。Prompt：`A crest of five roaring tiger generals, bold tiger-head emblem ringed by five stars, gold and crimson tones, elite vanguard crest.`

### 4.6 通用碎片【❌ 已删除（2026-09-09 信物重构定稿，排期 0.8.14）——碎片功能整体删除，本节提示词作历史保留】

| 物品 | 说明 | 意象 |
|---|---|---|
| 武将碎片 | 重复角色 → `shards`（20/40 档） | 发光角色碎晶 |

- **武将碎片**：一块迸裂出的角色残影碎晶。Prompt：`A single glowing crystalline character-shard crackling with a faint silhouette of the hero inside, generic fragment loot, cyan-gold crystal tones.`

---

## 5. 通用 HUD 图徽（波次 / 伤害类型 / 人物属性 / 负面状态）

> 本节图标落在 HUD / 属性面板 / 敌人状态条等通用位，非技能/物品本体。**5.1 波次旗帜属旗帜本体、用 §2.1 立绘级；5.2~5.4 属 HUD 属性/状态符号，一律用 §2.2 简版 UI 图标级（Kingdom Rush 式）。** 5.2~5.4 每组给两种用法：①「整套网格图」= 一张图出齐整组再切分（**首选，同组风格天然统一**）；②「单张」= 符号 + 主色 + §2.2 的 `UI-STYLE` 逐字追加（个别精修用）。负面词一律填 §2.2 负面栏。属性与状态口径以 [NUMBERS.md](NUMBERS.md) 10.12、[STATS_PIPELINE.md](STATS_PIPELINE.md) §6 为准。

### 5.1 波次旗帜（下一波敌人预告条）

| 图徽 | 用途 | 图标意象 |
|---|---|---|
| 波次旗帜 | 战斗顶栏波次胶囊 · **敌人出口出怪按钮**（点击出怪）· 波次开始横幅 | 招展的军旗 + 旗下**水浪**（代"波"，2026-09-11 出图定稿） |

- **波次旗帜（2026-09-11 按出图定稿修订）**：一面猎猎招展的三国军旗，旗杆下卷起一道水浪（代"波"），喻示"下一波来袭"。出图 = 扁平矢量风 + 深藏青圆角底板（`docs/ui_concept/src/icons_battle/wave_flag.png` 仅旗帜用于出怪按钮 / `wave_flag_plate.png` 带底板版备用），顶栏波次胶囊与出口出怪按钮同用一枚。Prompt：`A single bold Three-Kingdoms war banner on a pole streaming to the right with a curling water wave beneath it, next-wave incoming call, strong simple flag silhouette, crimson and gold tones, flat 2D game UI icon with smooth anti-aliased vector edges and thick dark outline, on a plain dark navy rounded-square panel. No pixelation. 1:1 square. No text, no letters, no numbers, no watermark, no frame, no scene.`

### 5.2 伤害类型（伤害数值/技能说明标注，口径 NUMBERS 10.12；§2.2 UI 图标级）

| 类型 | 结算口径 | 图标符号（单符号） | 主色 |
|---|---|---|---|
| 物理 | 算全部护甲 | 交叉双剑 | 钢灰 |
| 魔法 | 算 50% 护甲 | 符文法球/星芒 | 紫蓝 |
| 真实 | 无视护甲、不可减伤 | 亮白星芒斩 | 白·金 |

**整套网格图（推荐先出这张定调，不追加 `UI-STYLE`）**
```text
A single row of 3 flat 2D game UI symbols for damage types, all identical smooth vector cartoon style with thick uniform dark outline, smooth anti-aliased edges and flat solid single-color fill, plain dark navy rounded-square panels, same size, evenly spaced: crossed swords in steel grey, a rune orb in violet-blue, a radiant starburst slash in white-gold. No pixelation. 1:1 square. No text, no letters, no numbers, no watermark, no frame, no scene.
```

**单张（符号 + 主色 + `UI-STYLE`，§2.2 逐字追加）**
- **物理伤害**（近战/箭/投石普攻）：`Two crossed swords, steel grey, ` + `UI-STYLE`
- **魔法伤害**（术士类/火攻 DoT）：`A single rune orb, violet-blue, ` + `UI-STYLE`
- **真实伤害**（关羽·青龙偃月 / 骑兵大招，无视护甲）：`A radiant starburst slash, white-gold, ` + `UI-STYLE`

### 5.3 人物属性（养成/图鉴/塔详情属性列；§2.2 UI 图标级）

| 属性 | 图标符号（单符号） | 主色 |
|---|---|---|
| 攻击速度 | 短剑 + 武器**旁边**三道横杠（速度线） | 琥珀 |
| 射程 | 准星 + 虚线射程弧 | 青蓝 |
| 护甲 | 完整甲片（与穿甲同款轮廓） | 钢蓝 |
| 经验 | 五角星 | 金 |
| 韧性 | 握紧的拳头（坚韧有力） | 青铜 |
| 穿甲 | 同款甲片**裂开/碎裂** | 橙红 |
| 移速 | 战靴 + 三道速度线 | 绿 |

> **护甲 / 穿甲为"同款甲片"一对**：轮廓完全一致，仅"完整 vs 裂开"不同；两者并排应一眼看出是同一件甲片。若想更贴近，可用同色系（如都走钢色，仅裂口处改红橙）。

**整套网格图（推荐先出这张定调，不追加 `UI-STYLE`）**
```text
A single row of 7 flat 2D game UI symbols for character stats, all identical smooth vector cartoon style with thick uniform dark outline, smooth anti-aliased edges and flat solid single-color fill, plain dark navy rounded-square panels, same size, evenly spaced: a short sword with three horizontal bars beside it (amber), a target reticle with a dotted range arc (teal), an intact armor plate (steel blue), a five-pointed star (gold), a clenched strong fist (bronze), the exact same armor plate shape cracked and split (red-orange), a boot with three speed lines (green). No pixelation. 1:1 square. No text, no letters, no numbers, no watermark, no frame, no scene.
```

**单张（符号 + 主色 + `UI-STYLE`，§2.2 逐字追加）**
- **攻击速度**：`A short sword with three horizontal speed bars beside it, amber, ` + `UI-STYLE`
- **射程**：`A target reticle with a dotted range arc, teal-blue, ` + `UI-STYLE`
- **护甲**：`An intact armor plate, steel blue, ` + `UI-STYLE`
- **经验**：`A five-pointed star, gold, ` + `UI-STYLE`
- **韧性**：`A clenched strong fist, bronze, ` + `UI-STYLE`
- **穿甲**：`The same armor plate cracked and split open, red-orange, ` + `UI-STYLE`
- **移速**：`A boot with three speed lines, green, ` + `UI-STYLE`

### 5.4 负面状态（敌人状态条，口径 STATS_PIPELINE §6；§2.2 UI 图标级）

| 状态 | 语义/叠加 | 图标符号（单符号） | 主色 |
|---|---|---|---|
| 减速 | 多源取最强、时长刷新 | 雪花 | 冰蓝 |
| 灼烧 | 取更大 DPS、时长刷新 | 火焰 | 橙红 |
| 易伤 | 不叠加、时长刷新 | 裂盾 + 下箭头 | 洋红 |
| 眩晕 | 同目标内置冷却 | 环绕小星 | 亮黄 |
| 恐惧 | 反向行军、时长刷新 | 骷髅 + 惊惧线 | 暗紫 |
| 击退/拖回 | 位移，距离受 Boss 抗性折减 | 冲击箭头 + 拖痕 | 褐钢 |

**整套网格图（推荐先出这张定调，不追加 `UI-STYLE`）**
```text
A single row of 6 flat 2D game UI symbols for enemy status effects, all identical smooth vector cartoon style with thick uniform dark outline, smooth anti-aliased edges and flat solid single-color fill, plain dark navy rounded-square panels, same size, evenly spaced: a snowflake (ice blue), a flame (orange-red), a cracked shield with a downward arrow (magenta), a star with two orbit rings (bright yellow), a skull with two wavy fear lines (dark purple), a knockback arrow with a drag line (brown-steel). No pixelation. 1:1 square. No text, no letters, no numbers, no watermark, no frame, no scene.
```

**单张（符号 + 主色 + `UI-STYLE`，§2.2 逐字追加）**
- **减速**：`A snowflake, ice blue, ` + `UI-STYLE`
- **灼烧**：`A flame, orange-red, ` + `UI-STYLE`
- **易伤**：`A cracked shield with a downward arrow, magenta, ` + `UI-STYLE`
- **眩晕**：`A star with two orbit rings, bright yellow, ` + `UI-STYLE`
- **恐惧**：`A skull with two wavy fear lines, dark purple, ` + `UI-STYLE`
- **击退/拖回**：`A knockback arrow with a drag line, brown-steel, ` + `UI-STYLE`

---

### 5.5 已出图登记（HUD 图徽，2026-09-11）

落在局内 HUD v2 概念稿（[UI_CONCEPT.md](UI_CONCEPT.md) v0.12 / [UI_LAYOUT.md](UI_LAYOUT.md) §10 v0.20.41 / [ART_ASSETS.md](ART_ASSETS.md) §3），设计源 + 抠透明脚本归档 `docs/ui_concept/src/icons_battle/`，运行时入库目录 `assets/ui/icons/` 预留：

| 图徽 | 文件（`icons_battle/`） | 用在哪 | 对应 Prompt |
|---|---|---|---|
| 波次旗帜 | `wave_flag.png`（仅旗帜）/ `wave_flag_plate.png`（带底板） | 顶栏波次胶囊 · 敌人出口出怪按钮 · 波次开始横幅 | §5.1 |
| 金币 | `coin.png` | 顶栏金币胶囊 · 建造 / 升阶 / 回收 / 军需购买等全部费用胶囊 | §2.2 UI 图标级风格出图（单张条目待回填） |
| 基地生命 | `base_hp.png` | 顶栏基地生命胶囊（≤30% 危急变红） | §2.2 UI 图标级风格出图（单张条目待回填） |
| 物理 / 魔法 / 真实伤害 | `dmg_physical.png` / `dmg_magic.png` / `dmg_true.png` | 塔详情伤害值 · 图鉴属性列 | §5.2 整套网格图 |
| 攻击速度 | `stat_attack_speed.png` | 塔详情攻速值 · 图鉴属性列 | §5.3 整套网格图（短剑 + 速度杠） |
---

## 6. 待办与续补

- **生成次序建议**：① §3.1 职业技能核心 6（已建档，先定全套风格）→ ② §3.5 角色技能 9（典故辨识度最高）→ ③ §3.3 二转新技能 6 + §3.4 职业大招 6 → ④ §4 物品各分类。
- **续补前置**：后续武将信物、新增材料/掉落、远期货币（军功/铜钱）等，先在其设计文档（CHARACTERS / DROPS_GACHA / NUMBERS）登记并定稿名称，再按对应小节模板补提示词并升本档版本。
- **HUD 图徽续补（2026-09-11 状态）**：§5.5 已出图 7 枚（波次旗帜 1 / 金币 / 基地生命 / 伤害类型 3 / 攻速 1）——待补 ①§5.3 其余 6 枚（射程 / 护甲 / 经验 / 韧性 / 穿甲 / 移速）；②§5.4 负面状态 6 枚；③局内尚缺图徽（军需面板图标 / 塔阶级角标 / 漏怪伤害 / 军功货币）。
- **入库**：定稿图标按 [ART_ASSETS.md](ART_ASSETS.md) §2 入 `assets/ui/icons/`（技能/物品预留位），并同步 [ART_ASSETS.md](ART_ASSETS.md) §3 台账登记来源（含 AI 平台许可核实）。
- 本档为设计/生产参考，不承载数值与机制；机制以 SKILLS / CHARACTER_SKILLS / DROPS_GACHA 为准。

---

## 7. 变更记录

- v0.1（2026-09-08）：首次建档——统一风格底座与负面词、出图规范；职业技能核心 6（3.1）+ 强化态复用说明（3.2）+ 二转新技能 6（3.3）+ 职业大招 6（3.4）+ 角色技能 9（3.5）；物品分类提示词（4.1 材料道具 / 4.2 局内遗物 / 4.3 局内军需 / 4.4 武将信物 / 4.5 羁绊徽记 / 4.6 通用碎片）；0.1 模块索引登记 ART_PROMPTS 行；总纲 v0.37.8→v0.37.9、README 当前状态同步。程序版本号不变（0.8.11.5）。
- v0.2（2026-09-09）：信物重构定稿同步——§4.4 旧 3 件信物转专属槽占位（锁住、暂不出图）、Boss 签名信物提示词随 0.8.14 补；§4.6 碎片作历史保留。程序版本号不变（0.8.11.12）。
- v0.3（2026-09-10）：经验池 + 军功/军需重构定稿同步——§4.1 `exp_scroll` 随 0.8.15 删除（不再出图）；§4.3 新增掷石齐射 `stone_volley` / 犒军 `reward_troops`（id 草案）提示词与图标意象。程序版本号不变（0.8.11.13）。
- v0.4（2026-09-10，纯文档，程序版本不变）：**新增 §5「通用 HUD 图徽」**——波次旗帜（5.1）、伤害类型 物理/魔法/真实（5.2，口径 NUMBERS 10.12）、人物属性 攻速/射程/护甲/经验/韧性/穿甲/移速（5.3）、负面状态 减速/灼烧/易伤/眩晕/恐惧/击退拖回（5.4，口径 STATS_PIPELINE §6）；原 §5 待办 → §6、原 §6 变更记录 → §7。
- v0.5（2026-09-10）：**风格拆两档**——§2 拆为 2.1 立绘级（技能/物品）与 2.2 简版 UI 图标级（Kingdom Rush 式极简符号）+ 各自负面词，§2.3 参数合并；§1 补「两档不可混用」铁律；§5.2 伤害类型 / 5.3 人物属性 / 5.4 负面状态改写为单符号极简 Prompt 并附主色编码；5.1 波次旗帜维持立绘级。总纲 v0.37.23→v0.37.24、README 同步。程序版本号不变。
- v0.6（2026-09-10）：**§5.2~5.4 风格统一加固**——§2.2 增锁定风格硬约束 + 逐字复用的内联风格串 `UI-STYLE` + 一致性做法（首选整套网格图 / 母版图像引导 / 锁 seed·preset / 逐张自检）；§5.2/5.3/5.4 各增「整套网格图」提示词与「单张 = 符号 + 主色 + `UI-STYLE`」；负面词补 gradient / bevel / drop shadow。总纲 v0.37.24→v0.37.25、README 同步。程序版本号不变。
- v0.7（2026-09-10）：**UI 图标档防像素风修正**——§2.2 锁定风格增「平滑矢量风（非像素）」，`UI-STYLE` 改 `symbol` + `smooth anti-aliased vector edges` + `no pixelation` + `rounded-square panel`，负面词前置像素/复古类词；一致性做法注明须用非像素 preset/模型 + 分辨率 ≥1024；新增「常见跑偏与纠正」；§5.2~5.4 三组「整套网格图」同步改词。总纲 v0.37.25→v0.37.26、README 同步。程序版本号不变。
- v0.8（2026-09-10）：**§5.3 属性图标三处修订**——攻击速度 沙漏 → 短剑 + 三道横杠；穿甲 箭头破甲片 → 碎裂的护甲片；韧性 相扣双链环 → 铁砧 + 一点火花（韧性暂无正式数值定义，取坚韧/耐久义）。整套网格图与单张提示词同步。总纲 v0.37.26→v0.37.27、README 同步。程序版本号不变。
- v0.9（2026-09-10）：**§5.3 再修**——攻速速度横杠明确置于**武器旁边**（非剑身）；护甲改「完整甲片」、穿甲改「同款甲片裂开」，二者同款轮廓一对（可同色系仅裂口红橙）。整套网格图与单张提示词同步。总纲 v0.37.27→v0.37.28、README 同步。程序版本号不变。
- v0.10（2026-09-11）：**§5.3 韧性定稿**——铁砧 + 火花 → **握紧的拳头**（青铜，坚韧有力）。整套网格图与单张提示词同步。总纲 v0.37.28→v0.37.29、README 同步。程序版本号不变。
- v0.11（2026-09-11）：**§5.1 波次旗帜按出图定稿 + 新增 §5.5 已出图登记**——意象「军旗 + 波次星角」→「军旗 + 旗下水浪」，用途扩至顶栏波次胶囊 / 敌人出口出怪按钮 / 波次开始横幅；登记已出图 7 枚（同顶部 changelog）。总纲 v0.37.29→v0.37.30、README 同步。程序版本号不变。
