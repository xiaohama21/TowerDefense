# AI 出图提示词库（ART_PROMPTS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)；美术资产规范/入库目录/许可见 [ART_ASSETS.md](ART_ASSETS.md)；技能来源见 [SKILLS.md](SKILLS.md) 与 [CHARACTER_SKILLS.md](CHARACTER_SKILLS.md)；物品/遗物/掉落来源见 [DROPS_GACHA.md](DROPS_GACHA.md)。
> 承载总纲原章节：13「美术风格」的实现侧补充（AI 出图管线）。
> 文档版本：v0.3（2026-09-10）
> v0.3 变更（2026-09-10，经验池 + 军功/军需重构定稿同步 / GDD v0.37.22 / DESIGN_REVIEW v0.4.7 / NUMBERS 10.14·10.15，纯文档，程序 0.8.11.13 不变，排期 0.8.15 / 0.8.16）：**§4.1 练兵令转历史 + §4.3 新增两件军需提示词（id 草案）**——①`exp_scroll` 随 0.8.15 经验池删除（图标**不再出图**，条目作历史保留）；②§4.3 增补「掷石齐射」`stone_volley`（全场 60 物理伤害）与「犒军」`reward_troops`（全队怒气 +20）提示词与图标意象（军需池 6 件制，坚壁 / 伤药 / 火油罐本就未建档、无需处理）。
> v0.2 变更（2026-09-09，信物重构定稿同步 / GDD v0.37.20 / CHARACTERS 4.8 / DESIGN_REVIEW v0.4.6，纯文档，程序 0.8.11.12 不变，排期 0.8.14）：**§4.4 武将信物口径更新**——旧 3 件信物转专属槽占位（锁住、暂不出图）；新增 Boss 签名信物「天公雷诏」「太平要术·残卷」提示词随 0.8.14 按本模板补入（命名/效果见 CHARACTERS 4.8 / NUMBERS 10.13）。**§4.6 通用碎片作历史保留**——碎片功能整体删除、不再出图。
> v0.1 变更（2026-09-08，首次建档，纯文档/素材、无程序逻辑改动）：**AI（Leonardo.ai）出图提示词库建档**——面向"技能图标 + 物品图标"的运行时图徽生成管线：统一 Q 版卡通三国风格底座 + 通用负面词 + 出图规范；职业技能核心 6 + 二转新技能 6 + 职业大招 6 + 角色技能 9 + 材料/道具、局内遗物、局内军需、武将信物、羁绊徽记等物品分类提示词；登记 0.1 模块索引。程序版本号不变。

---

## 1. 定位与原则

1. **目的**：给 AI（默认 [Leonardo.ai](https://leonardo.ai)）生成"需要玩家在 UI 上识别"的技能/物品图徽提供一套可复现、画风统一的提示词，避免逐张临时拼词导致成套图标风格漂移。
2. **范围**：本档只覆盖**技能类 + 物品类**图标。UI 系统图标（按钮/星标/光标等）沿用 Kenney CC0 素材（[ART_ASSETS.md](ART_ASSETS.md) §3/§6）；角色战斗立绘走 spine（[ART_ASSETS.md](ART_ASSETS.md) §5）；敌人/特效立绘【远期】——以上均**不在本档**出图。
3. **识别位**（图标要落在哪些 UI）：养成 / 百科的"技能页签"技能徽；背包 / 编队遗物 / 局内军需的物品徽与遗物徽；武将信物徽、羁绊徽记徽（承载 UI 以运行版为准，本档只定图徽本体）。
4. **一致性铁律**：一套图标共用 §2 的统一风格底座与负面词，建议同一模型 + 固定 seed 批量出。**文字一律不进图**——AI 生成中文十有八九乱写，技能名/数值进 UI 后用快乐体叠加（与全局字体一致）；故所有 Prompt 都要求无文字无字母。
5. **强化/状态不进图**：职业技能 `+` 强化态、满怒/大招就绪/冷却等一律由引擎叠层（金边/呼吸光/冷却环）表达，不重复出图。
6. **落地流程**：出图 → 定稿后透明抠底裁小（与 `assets/characters/*_avatar*.png` 同流程）→ 按 [ART_ASSETS.md](ART_ASSETS.md) §2 目录登记入库（技能/物品图标落 `assets/ui/icons/` 预留位）；**本地素材不入库**（gitignore，沿用 ART_ASSETS §5.7 头像先例）。
7. **许可**：AI 生成内容的版权/商用条款随平台而定，需自行核实；如涉"学习研究不得商用"类素材（D69 spine 包前例）必须商用前购授权后再替换。

---

## 2. 统一风格与出图规范

> 下列风格/负面词为**全局常量**：所有条目 Prompt =「条目主体段」+「统一风格底座」，负面词单独填 Leonardo 负面栏。

**统一风格底座（每张 Prompt 末尾追加）**
```text
Mobile game icon, chibi Q-version Three Kingdoms cartoon style, cel shaded with bold clean dark outline, flat clean vector coloring, single centered emblem, strong clear silhouette readable at small icon size, subtle radial glow, dark deep-navy vignette background, high contrast, crisp edges, 1:1 square. No text, no letters, no numbers, no watermark, no frame.
```

**通用负面词（Negative Prompt 栏整段粘贴）**
```text
text, letters, numbers, Chinese characters, calligraphy, watermark, logo, signature, photo, realistic, extra characters, messy clutter, thin unreadable details, hands with fingers, background scenery.
```

**出图参数建议**
- 尺寸：1:1 方形；主体居中约占画面 60%~70%（图标最终在小尺寸 UI 槽内显示，外圈会被裁/盖）。
- 底色：深色径向渐变（贴合 UI_LAYOUT §2 深底语义），浅色高亮主体，落槽后由界面叠槽叠字。
- 一致性：同一模型 + 同 seed 重 roll 出一套；批量前先出 1 张定调再铺开。
- 调优：某图反复出现同一坏毛病（如乱加字幕），单独把该词补进负面栏即可，不必加重叠。

**识别优先级**：大字剪影 > 单一主角 > 亮色点缀；避开细线、复杂背景、多余小人、手指细节。

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

## 5. 待办与续补

- **生成次序建议**：① §3.1 职业技能核心 6（已建档，先定全套风格）→ ② §3.5 角色技能 9（典故辨识度最高）→ ③ §3.3 二转新技能 6 + §3.4 职业大招 6 → ④ §4 物品各分类。
- **续补前置**：后续武将信物、新增材料/掉落、远期货币（军功/铜钱）等，先在其设计文档（CHARACTERS / DROPS_GACHA / NUMBERS）登记并定稿名称，再按对应小节模板补提示词并升本档版本。
- **入库**：定稿图标按 [ART_ASSETS.md](ART_ASSETS.md) §2 入 `assets/ui/icons/`（技能/物品预留位），并同步 [ART_ASSETS.md](ART_ASSETS.md) §3 台账登记来源（含 AI 平台许可核实）。
- 本档为设计/生产参考，不承载数值与机制；机制以 SKILLS / CHARACTER_SKILLS / DROPS_GACHA 为准。

---

## 6. 变更记录

- v0.1（2026-09-08）：首次建档——统一风格底座与负面词、出图规范；职业技能核心 6（3.1）+ 强化态复用说明（3.2）+ 二转新技能 6（3.3）+ 职业大招 6（3.4）+ 角色技能 9（3.5）；物品分类提示词（4.1 材料道具 / 4.2 局内遗物 / 4.3 局内军需 / 4.4 武将信物 / 4.5 羁绊徽记 / 4.6 通用碎片）；0.1 模块索引登记 ART_PROMPTS 行；总纲 v0.37.8→v0.37.9、README 当前状态同步。程序版本号不变（0.8.11.5）。
- v0.2（2026-09-09）：信物重构定稿同步——§4.4 旧 3 件信物转专属槽占位（锁住、暂不出图）、Boss 签名信物提示词随 0.8.14 补；§4.6 碎片作历史保留。程序版本号不变（0.8.11.12）。
- v0.3（2026-09-10）：经验池 + 军功/军需重构定稿同步——§4.1 `exp_scroll` 随 0.8.15 删除（不再出图）；§4.3 新增掷石齐射 `stone_volley` / 犒军 `reward_troops`（id 草案）提示词与图标意象。程序版本号不变（0.8.11.13）。
