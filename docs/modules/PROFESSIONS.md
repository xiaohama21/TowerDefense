# 职业系统（PROFESSIONS）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 承载总纲原章节：4.2。章节编号沿用全局稳定 ID。
> 职业攻击行为的实现侧见 [BEHAVIORS.md](BEHAVIORS.md)；积怒模式规则见 [CHARACTERS.md](CHARACTERS.md) 4.6。

---

## 4.2 职业设计

职业决定攻击模式与职责定位，由 `ProfessionData` 的 `combat_role`（伤害/控制/辅助/混合）与 `attack_pattern`（单体/范围/穿透/光环）驱动。

| 职业 | 职责 | 攻击方式 | 数值基调 | 大招（怒气驱动） | 定位 |
|---|---|---|---|---|---|
| 骑兵 | 伤害/爆发 | 短射程单体、高伤害 | 伤害×1.25，射程×0.85 | 单体高爆发/斩杀，击杀返还怒气 | 道路转角压制精英 |
| 枪兵 | 伤害/稳定 | 近战单体、射程略长、攻速偏快 | 伤害×1.0，射程×1.0 | 横扫：范围伤害+击退 | 基础近战万金油 |
| 弓箭手 | 伤害/稳定 | 长射程单体、高攻速 | 射程×1.3 | 连珠齐射，优先锁定低血量 | 覆盖长直道、收割 |
| 术士 | 控制/范围 | 范围法术、减速 | 攻速偏慢、范围伤害 | 大范围法术+减速 | 克制人海 |
| 舞娘 | 辅助 | 光环增益（攻速等） | 低伤害、光环 | 全队攻速/伤害爆发窗口 | 辅助核心 |
| 盾卫【远期】 | 阻挡/肉盾 | 近战阻挡 | 高血量、低伤 | 嘲讽/减伤领域【待定】 | 关卡地形配合 |
| 谋士【远期】 | 控制/减益 | 单体控制 | 高冷却技能 | 全体控制【待定】 | 精英/Boss 对策 |

**枪兵设计说明**：定位是"便宜、稳定、手长的近战基础职业"，与骑兵形成互补（骑兵贵、爆发高、射程短；枪兵便宜、均衡、攻速快）。枪兵对带 `cavalry` 标签的敌人伤害 +15%（职业克制，第一章的黄巾轻骑即属此类；若平衡测试后觉得多余可整体移除）。"步兵"名保留为【远期】第二个近战职业（刀盾兵），暂不开发。

**新增职业规则**：必须先定义 `ProfessionData`（职责+行为 ID），再写行为脚本；不得为单个角色硬编码攻击逻辑。

---

## 4.2.1 现有职业资源清单（v0.8 细化）

数据来源 `resources/professions/*.tres`；枚举含义：`combat_role` = DAMAGE(0) / CONTROL(1) / SUPPORT(2) / HYBRID(3)，`attack_pattern` = SINGLE_TARGET(0) / AREA(1) / PIERCING(2) / AURA(3)。

| 资源 | 职业 | combat_role | attack_pattern | behavior_id | 伤害乘数 | 射程乘数 | 攻速乘数 |
|---|---|---|---|---|---|---|---|
| `cavalry.tres` | 骑兵 | DAMAGE | SINGLE_TARGET | `single_target_burst` | 1.25 | 0.85 | 1.0 |
| `archer.tres` | 弓箭手 | DAMAGE | SINGLE_TARGET | `single_target_precision` | 1.0 | 1.3 | 0.95 |
| `strategist.tres` | 术士 | HYBRID | AREA | `area_spell` | 0.9 | 1.1 | 1.15 |
| `dancer.tres` | 舞娘 | SUPPORT | AURA | `attack_speed_aura` | 0.35 | 0.95 | 1.0 |
| `pikeman.tres`【阶段 1 待建】 | 枪兵 | DAMAGE | SINGLE_TARGET | 近战行为【待定 ID】 | 1.0 | 1.0 | ≤0.9（攻速偏快） |

说明：
- 职业乘数是相对"角色基础属性"的修正（角色 `.tres` 存绝对值，职业乘数在应用时相乘）；数值基调见 [NUMBERS.md](NUMBERS.md) 10.2/10.3。
- 术士与舞娘的 `behavior_id`（`area_spell` / `attack_speed_aura`）当前**仅作数据声明**，实际结算仍是单体弹道；范围/光环结算随阶段 3 行为注册表落地（见 [BEHAVIORS.md](BEHAVIORS.md) B.2/B.3.1）。
- 枪兵落地时（阶段 1）须同步：新建 `pikeman.tres`、注册其近战攻击行为、实现职业克制（对 `cavalry` 标签敌人 +15%）。
- 阶段 3 字段扩展（`ultimate_id`、`rage_gain_mode`、积怒参数）见 [CHARACTERS.md](CHARACTERS.md) 4.7 汇总。
