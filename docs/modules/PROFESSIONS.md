# 职业系统（PROFESSIONS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 承载总纲原章节：4.2。章节编号沿用全局稳定 ID。
> 职业攻击行为的实现侧见 [BEHAVIORS.md](BEHAVIORS.md)；积怒模式规则见 [CHARACTERS.md](CHARACTERS.md) 4.6。

---

## 4.2 职业设计

六职业保留攻击方式、数值参考、behavior_id、普攻伤害类型、最小射程与局内升阶步进。0.9.1 删除转职与职业技能授予；旧职业大招执行器由武将资源 ultimate_id 显式绑定过渡，职业不再有大招字段。完整三技能与积怒参数迁移随 0.9.2。

## 4.2.1 现有职业资源清单（v0.8 细化）

数据来源 `resources/professions/*.tres`；枚举含义：`combat_role` = DAMAGE(0) / CONTROL(1) / SUPPORT(2) / HYBRID(3)，`attack_pattern` = SINGLE_TARGET(0) / AREA(1) / PIERCING(2) / AURA(3)。

| 资源 | 职业 | combat_role | attack_pattern | behavior_id | 伤害乘数 | 射程乘数 | 攻速乘数 |
|---|---|---|---|---|---|---|---|
| `cavalry.tres` | 骑兵 | DAMAGE | SINGLE_TARGET | `single_target_burst` | 1.25 | 0.85 | 1.0 |
| `archer.tres` | 弓箭手 | DAMAGE | SINGLE_TARGET | `single_target_precision` | 1.0 | 1.3 | 0.95 |
| `strategist.tres` | 术士 | HYBRID | AREA | `area_spell` | 0.9 | 1.1 | 1.15 |
| `dancer.tres` | 舞娘 | SUPPORT | AURA | `attack_speed_aura` | 0.35 | 0.95 | 1.0 |
| `tiger_guard.tres`（v0.27.2 更名，原 `pikeman.tres`） | **虎贲**（原剑客） | DAMAGE | SINGLE_TARGET | `melee_thrust` | 0.9 | 1.0 | 1.0（角色攻速偏快承载） |
| `catapult.tres`（v0.11.1） | 投石车 | DAMAGE | AREA | `lob_aoe` | 1.6 | 1.5 | 2.0（min_range 160） |

说明：
- 职业乘数为**设计语言参考**（v0.11.1 澄清）：运行时角色属性以 `.tres` 绝对值为准（`compute_stats_at` 应用等级百分比成长、品阶倍率、旧档成长守护与信物，职业乘数不参与计算）；投石车 `.tres` 已按最终值配置（136 伤/360 程/2.4s）。运行时是否统一应用职业乘数留待数值重构决策。
- 近战类（骑兵 `single_target_burst`、虎贲 `melee_thrust`）均为直伤 + 挥击表现，无弹道；职业克制查询按 profession_id（虎贲对 `cavalry` 标签 +15%）。弹道类（弓箭手/术士/舞娘）仍为单体弹道结算，范围/光环随阶段 3 拆分（见 [BEHAVIORS.md](BEHAVIORS.md) B.2/B.3.1）。
- 虎贲已落地（v0.9 起为剑客）：攻速偏快由角色 `attack_interval` 承载（张飞 0.7s）。v0.9.2 起刘备亦挂该职业（辅助型，`rage_gain_mode=support`，见 4.6/CHARACTERS.md）。
- 积怒模式与参数暂由职业提供默认值；大招由武将 `ultimate_id` 显式绑定，见 [CHARACTERS.md](CHARACTERS.md) 4.7 汇总。
