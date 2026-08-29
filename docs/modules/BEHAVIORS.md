# 动作模组：行为注册表（BEHAVIORS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> v0.8 新立模块：承接总纲原附录"行为 ID 注册表"与 4.6/4.7、5.5 的实现侧约定。
> 效果的完整设计规格见 [CHARACTERS.md](CHARACTERS.md)（大招/特性）与 [ENEMIES.md](ENEMIES.md)（敌人行为）；数值见 [NUMBERS.md](NUMBERS.md) 10.5。

---

## B.1 架构与约定

战斗中的"动作"统一拆为四类行为 ID，由**行为注册表**（脚本按 ID 注册、战斗节点按 ID 分发调用）驱动：

| 行为 ID | 挂载数据 | 含义 | 计划落地 |
|---|---|---|---|
| `behavior_id` | `ProfessionData` | 职业攻击行为（普攻如何打：单体/范围/光环/近战） | 阶段 1 起最小注册表 |
| `special_behavior_id` | `EnemyData` | 敌人特殊行为（光环/自爆/召唤等） | 阶段 3 |
| `ultimate_id` | `ProfessionData`（阶段 3 字段） | 职业大招行为（怒气驱动） | 阶段 3 |
| `trait_id` | `CharacterData`（阶段 3 字段） | 角色常驻被动特性 | 阶段 3 |

硬性约定（对应总纲铁律）：

- **禁止**在 `Tower` / `Enemy` / `Bullet` 等战斗脚本中为某个职业、角色、敌人硬编码专属逻辑；战斗脚本只负责"按 ID 取行为并执行"。
- 行为参数**不写死在脚本**：从数据资源读取（`CharacterData.trait_params: Dictionary`、`ProfessionData` 数值字段、`EnemyData` 字段等）。
- 行为脚本无副作用留存：怒气、局内升级等级等临时状态只存在于本局（见总纲铁律）。
- 怒气获取模式 `rage_gain_mode`（`hit+damage` / `support`）同属行为层属性，规则见 [CHARACTERS.md](CHARACTERS.md) 4.6。
- 职业克制（枪兵对 `cavalry` 标签 +15%）按 `EnemyData.tags` 查询实现，同样走行为/规则层，不在塔脚本写死。

## B.2 落地节奏

- **当前（v0.8）**：攻击逻辑在 `Tower._process/attack` + `Bullet`，职业仅视觉与弹道差异；四类行为 ID 已在数据中声明（职业）或预留（其余），但**尚无脚本消费**。
- **阶段 1（枪兵落地时）**：引入**最小行为注册表**——一个按 `behavior_id` 分发攻击执行器的注册点，枪兵成为第一个注册的差异化近战行为；现有四个职业的弹道攻击迁入注册表。
- **阶段 3**：注册表扩展至 `special_behavior_id` / `ultimate_id` / `trait_id`，数值生效（表现占位）。
- **阶段 5**：演出差异化（特效/音效/飘字）挂在行为执行结果上，不改注册表结构。

## B.3 行为规格清单

> 本清单是行为 ID 的**登记与状态台账**：新增行为先在此登记（先文档后代码）。效果概要仅为速查，完整规格以引用章节为准。

### B.3.1 职业攻击行为（`behavior_id`）

| ID | 效果概要 | 使用职业 | 状态 |
|---|---|---|---|
| `single_target_burst` | 单体高伤弹道（斩击刀光） | 骑兵 | 弹道已实现，未走注册表 |
| `single_target_precision` | 长射程单体弹道（箭矢） | 弓箭手 | 弹道已实现，未走注册表 |
| `area_spell` | 范围法术（法球）；**当前按单体结算** | 术士 | 视觉已实现；范围结算随阶段 3 |
| `attack_speed_aura` | 攻速光环增益（音波环）；**当前按单体结算** | 舞娘 | 视觉已实现；光环结算随阶段 3 |
| 【待登记】枪兵近战 | 近战单体、攻速偏快、射程略长 | 枪兵 | 阶段 1，随最小注册表落地 |

### B.3.2 敌人特殊行为（`special_behavior_id`）

| ID | 效果概要 | 规划敌人 | 状态 |
|---|---|---|---|
| `none` | 默认沿路径推进 | 全部现有敌人 | 已实现（默认行为） |
| `fast_charger` | 高速推进、漏怪伤害更高 | 黄巾轻骑 | 数值已体现（145 速 / 漏 2 血），`special_behavior_id` 尚未在 `.tres` 配置 |
| `healer_aura` | 为周围敌人回血 | 黄巾祭酒 | 阶段 3 |
| `armor_aura` | 为周围敌人加护甲 | 黄巾祭酒变体 | 阶段 3 |
| `suicide` | 到点自爆造成范围伤害 | 【远期】 | 未排期 |
| `swarm` | 分裂/召唤小怪 | 【远期】 | 未排期 |

### B.3.3 职业大招行为（`ultimate_id`，阶段 3）

| ID | 职业 | 效果概要（完整规格见 CHARACTERS.md 4.6，数值见 NUMBERS.md 10.5） |
|---|---|---|
| `ultimate_cavalry_breaker` | 骑兵 | 高额单体伤害；击杀返还 50% 怒气 |
| `ultimate_pikeman_sweep` | 枪兵 | 范围横扫伤害 + 击退 |
| `ultimate_archer_volley` | 弓箭手 | 3~5 箭连射，优先低血量 |
| `ultimate_strategist_blaze` | 术士 | 大范围伤害 + 减速 |
| `ultimate_dancer_encourage` | 舞娘 | 范围内友方攻速/伤害提升窗口 |

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

## B.4 新增行为流程（v0.8 细化）

1. **登记**：在 B.3 对应清单登记 ID、效果概要与目标阶段（先文档后代码）。
2. **数据**：需要新字段时先扩展数据类（`CharacterData` / `ProfessionData` / `EnemyData`），并在总纲记录版本变更。
3. **实现**：行为脚本实现并在注册表登记；战斗节点只按 ID 分发。
4. **验证**：`tests/SmokeRunner.gd` 的资源完整性扫描保证配置无断链；为新行为补最小冒烟用例（参照 4.4 经验归属用例的写法）。
5. **回写**：若行为改变了战斗结论（如新的结算规则），同步总纲与相关模块文档。
