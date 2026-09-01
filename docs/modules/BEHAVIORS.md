# 动作模组：行为注册表（BEHAVIORS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> v0.8 新立模块：承接总纲原附录"行为 ID 注册表"与 4.6/4.7、5.5 的实现侧约定。
> 效果的完整设计规格见 [CHARACTERS.md](CHARACTERS.md)（大招/特性）与 [ENEMIES.md](ENEMIES.md)（敌人行为）；数值见 [NUMBERS.md](NUMBERS.md) 10.5。

---

## B.1 架构与约定

战斗中的"动作"统一拆为四类行为 ID，由**行为注册表**（脚本按 ID 注册、战斗节点按 ID 分发调用）驱动：

| 行为 ID | 挂载数据 | 含义 | 计划落地 |
|---|---|---|---|
| `behavior_id` | `ProfessionData` | 职业攻击行为（普攻如何打：单体/范围/光环/近战） | ✅ 阶段 1（v0.9 最小注册表） |
| `special_behavior_id` | `EnemyData` | 敌人特殊行为（光环/自爆/召唤等） | 阶段 3 |
| `ultimate_id` | `ProfessionData`（阶段 3 字段） | 职业大招行为（怒气驱动） | 阶段 3 |
| `trait_id` | `CharacterData`（阶段 3 字段） | 角色常驻被动特性 | 阶段 3 |

硬性约定（对应总纲铁律）：

- **禁止**在 `Tower` / `Enemy` / `Bullet` 等战斗脚本中为某个职业、角色、敌人硬编码专属逻辑；战斗脚本只负责"按 ID 取行为并执行"。
- **攻击表现由行为执行器自行触发（v0.9.4）**：弹道类执行器触发枪口闪光，近战类执行器触发武器挥击 + 斩击弧；`Tower.attack()` 本身不统一触发出击特效（避免近战出现"像发弹幕"的观感）。
- 行为参数**不写死在脚本**：从数据资源读取（`CharacterData.trait_params: Dictionary`、`ProfessionData` 数值字段、`EnemyData` 字段等）。
- 行为脚本无副作用留存：怒气、局内升级等级等临时状态只存在于本局（见总纲铁律）。
- 怒气获取模式 `rage_gain_mode`（`hit+damage` / `support`）同属行为层属性，规则见 [CHARACTERS.md](CHARACTERS.md) 4.6。
- **贡献事件流（v0.11 设计，v0.23.0 定稿）**：武将行为产生带类型的贡献事件（`damage_dealt`/`kill`/`buff_applied`/`aura_covered_time`/`debuff_applied`），由 `Enemy.damage_contributors`（输出侧，已有）与塔侧"增益贡献台账"（辅助侧，v0.23.0 定稿，实现随阶段排期）汇成；**经验归属（CHARACTERS.md 4.4）与怒气获取（4.6）订阅同一事件流**，仅换算比例不同；防刷限制（光环分段结算/短时重复不重复给满额/辅助贡献每波上限）见 NUMBERS.md 10.6。新增贡献事件类型须先在本档登记。
- 职业克制（枪兵对 `cavalry` 标签 +15%）按 `EnemyData.tags` 查询实现，同样走行为/规则层，不在塔脚本写死。

## B.2 落地节奏

- **阶段 1（v0.9 已落地）**：最小行为注册表 `scripts/combat/BehaviorRegistry.gd` 上线——`Tower.attack()` 按 `behavior_id` 分发执行器；现有四个职业的弹道攻击迁入注册表（共用单体执行器，视觉差异由弹道造型承载）；新增 `melee_thrust` 近战直伤行为（枪兵，无弹道）与职业克制查询（枪兵对 `cavalry` 标签 +15%，常量 `PIKEMAN_COUNTER_MULTIPLIER`）；`Enemy` 接收 `EnemyData.tags` 供克制查询。
- **阶段 3（✅ v0.11.2/v0.11.3）**：注册表已扩展至 `special_behavior_id` / `ultimate_id` / `trait_id`，数值生效（演出于阶段 5 补全，见下）。
- **阶段 5（✅ v0.15.0/v0.16.0）**：演出差异化（特效/音效/飘字）挂在行为执行结果上，不改注册表结构——大招职业专属视觉/飘字 v0.15.0，技能音效+扩散环 v0.16.0。

## B.3 行为规格清单

> 本清单是行为 ID 的**登记与状态台账**：新增行为先在此登记（先文档后代码）。效果概要仅为速查，完整规格以引用章节为准。

### B.3.1 职业攻击行为（`behavior_id`）

> 攻击表现约定（v0.9.5）：**近战类（骑兵、剑客）**= 武器挥动（约 130° 扫击）+ 渐隐斩击弧，直伤无弹道；**弹道类（弓箭手、术士、舞娘）**= 枪口闪光 + 职业弹道造型；**抛射类（投石车）**= 抛物线弹体 + 落点范围伤害。表现由执行器自行触发。

| ID | 效果概要 | 使用职业 | 状态 |
|---|---|---|---|
| `single_target_burst` | 近战斩击：武器挥动 + 斩击弧表现，直伤（无弹道） | 骑兵 | ✅ v0.9 弹道 → v0.9.5 改近战挥击 |
| `single_target_precision` | 长射程单体弹道（箭矢） | 弓箭手 | ✅ 注册表分发（v0.9），单体结算 |
| `area_spell` | 范围法术（法球）；**当前按单体结算** | 术士 | ✅ 注册表分发（v0.9）；范围结算随阶段 3 |
| `attack_speed_aura` | 攻速光环增益（音波环）；**已光环化（v0.11.2 脉冲增益）** | 舞娘 | ✅ 注册表分发（v0.9）+ 脉冲增益落地（v0.11.2） |
| `melee_thrust` | 近战挥击：武器挥动 + 斩击弧表现，直伤（无弹道），对 `cavalry` 标签 +15% | 剑客 | ✅ 直伤 v0.9 / 挥击表现 v0.9.4 |
| `lob_aoe` | 抛射 AOE：预判落点抛物线弹体，落点范围伤害（首例范围结算）；**受 `ProfessionData.min_range` 约束，目标过近无法攻击** | 投石车 | ✅ 已建（v0.11.1） |

### B.3.2 敌人特殊行为（`special_behavior_id`）

| ID | 效果概要 | 规划敌人 | 状态 |
|---|---|---|---|
| `none` | 默认沿路径推进 | 全部现有敌人 | 已实现（默认行为） |
| `fast_charger` | 高速推进、漏怪伤害更高 | 黄巾轻骑 | ✅ 已配置（v0.19.0：`yellow_turban_cavalry.tres` 补 `special_behavior_id`；数值已体现：145 速 / 漏 2 血） |
| `healer_aura` | 每 2s 治疗周围 120px 友军 15 点 | 黄巾祭酒 | ✅ 已建（v0.11.3，EnemyManager 执行） |
| `summon_guard` | 每 8s 自岔路召唤 2 名步卒（分叉试点） | 黄巾渠帅张梁 | ✅ 已建（v0.11.3，需 StageData.fork_path_points） |
| `armor_aura` | 为周围敌人加护甲 | 黄巾祭酒变体 | 阶段 4+ |
| `suicide` | 到点自爆造成范围伤害 | 【远期】 | 未排期 |
| `swarm` | 分裂/召唤小怪 | 【远期】 | 未排期 |

### B.3.3 职业大招行为（`ultimate_id`，v0.11.2 数值生效；演出 ✅ v0.15.0 职业专属视觉 / v0.16.0 音效）

| ID | 职业 | 效果概要（完整规格见 CHARACTERS.md 4.6，数值见 NUMBERS.md 10.5） | 状态 |
|---|---|---|---|
| `ultimate_cavalry_breaker` | 骑兵 | 3×普攻单体伤害；击杀返还 50% 怒气（受 charge 技能强化） | ✅ |
| `ultimate_pikeman_sweep` | 剑客 | 范围内敌人 1.5×普攻伤害 + 击退 40px | ✅ |
| `ultimate_archer_volley` | 弓箭手 | 4 箭连射（0.8×普攻），优先低血量 | ✅ |
| `ultimate_strategist_blaze` | 术士 | 目标区域 2×普攻范围伤害 + 减速 40%/2s | ✅ |
| `ultimate_dancer_encourage` | 舞娘 | 全队攻速 +30%、伤害 +15%，持续 8s | ✅ |
| `ultimate_catapult_barrage` | 投石车 | 3 连发快速抛射轰击目标区域（0.8×普攻/发） | ✅ v0.11.2 新增 |

### B.3.4 角色特性行为（`trait_id`，阶段 3）

| ID | 角色 | 效果概要（完整规格见 CHARACTERS.md 4.7） |
|---|---|---|
| `trait_wusheng` | 关羽 | 对精英/Boss 伤害 +25% |
| `trait_yanyan_roar` | 张飞 | 命中概率短暂减速目标 |
| `trait_hundred_step` | 黄忠 | 连续攻击同一目标伤害逐步提升（至多 +30%） |
| `trait_benevolence` | 刘备 | 光环：全场友方塔伤害 +8%（不可叠加） |
| `trait_moon_veil` | 貂蝉 | 自身大招积怒 +20%，友方大招积怒 +10% |
| `trait_captain` | 周仓 | 对高血量敌人（>70% HP）伤害 +30% |
| `trait_dragon_spirit` | 赵云 | 每击杀叠 4% 攻速（可叠加，脱战重置） |
| `trait_star_gazer` | 诸葛亮 | 射程 +12%，范围内敌人减速 8% |

### B.3.5 转职技能行为（`skill_id`，✅ v0.15.0 落地）

技能 = 转职授予的被动/条件触发能力，由 **`SkillRegistry`**（`scripts/combat/SkillRegistry.gd`）按 `skill_id` 分发，战斗脚本只调用钩子（`on_attack_hit` / `on_kill` / `on_ultimate_cast` / `passive_multipliers`），不写死任何技能逻辑。数值经 `PromotionData.skill_params` 读取；档位系数 `s = 1 + 0.1 × min(battle_level/5, 4)`。完整规格见 CHARACTERS.md 4.5，按职业组织的职业技能清单见 [SKILLS.md](SKILLS.md)。

| skill_id | 触发点 | 效果概要 | 演出 |
|---|---|---|---|
| `charge` | 大招击杀 | 返还怒气 50%×s | 大招名飘字 |
| `ferocity` | 攻击命中 | 15% 概率追加 0.5×s 伤害 | "凶威"飘字 |
| `command` | 常驻 | 周围 150px 友方伤害 +4%×s | —（光环） |
| `steady` | 攻击命中 | 20% 概率追加 0.6×s 伤害 | "稳射"飘字 |
| `inspire` | 大招释放 | 全队攻速 +6%×s 持续 8s | "鼓舞"飘字 |
| `siege` | 常驻 | 对精英/Boss 伤害 +10%×s | — |
| `bulwark` | 击杀 | 金币 +2×s | "斩获"飘字 |
| `dragon_rush` | 击杀 | 下一次攻击伤害 +25%×s | "龙突"飘字 |
| `wisdom` | 大招 | 大招范围 +10%×s | "奇谋"飘字 |

---

## B.4 新增行为流程（v0.8 细化）

1. **登记**：在 B.3 对应清单登记 ID、效果概要与目标阶段（先文档后代码）。
2. **数据**：需要新字段时先扩展数据类（`CharacterData` / `ProfessionData` / `EnemyData`），并在总纲记录版本变更。
3. **实现**：行为脚本实现并在注册表登记；战斗节点只按 ID 分发。
4. **验证**：`tests/SmokeRunner.gd` 的资源完整性扫描保证配置无断链；为新行为补最小冒烟用例（参照 4.4 经验归属用例的写法）。
5. **回写**：若行为改变了战斗结论（如新的结算规则），同步总纲与相关模块文档。
