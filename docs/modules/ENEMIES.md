# 敌人设计（ENEMIES）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 承载总纲原章节：5.5。章节编号沿用全局稳定 ID。
> 特殊行为的实现状态与规格清单见 [BEHAVIORS.md](BEHAVIORS.md) B.3.2。

---

## 5.5 敌人设计

敌人由 `EnemyData` 定义：`max_hp`、`move_speed`、`armor`、`damage_to_base`（漏怪伤害）、`special_behavior_id`（特殊行为，行为脚本按 ID 注册）、`tags`（阵营/兵种标签，用于掉落与克制）。

**护甲减算公式（v0.7 落地实现）**：实际伤害 = `max(伤害 − 护甲, 向上取整(伤害 × 10%))`，即护甲无论如何不会完全免伤。第一章敌人护甲均为 0，第二章"高护甲骑兵"起生效；护甲作用于所有伤害来源（普攻、大招、范围伤害均在 `take_damage` 内统一结算）。

### 5.5.1 敌人维度

- 兵种：步卒 / 轻骑 / 弓手 / 力士 / 妖道（祭酒）。
- 定位：炮灰（低血低伤）、常规（数量中）、精英（高血、漏怪伤害高）、Boss（章节守关）。
- 特殊行为（`special_behavior_id`，逐期实现；实现状态见 [BEHAVIORS.md](BEHAVIORS.md) B.3.2）：
  - `none`：默认走直线。
  - `fast_charger`：速度型，漏怪伤害更高（轻骑已有）。
  - `healer_aura`：为周围敌人回血（黄巾祭酒）。
  - `armor_aura`：为周围敌人加护甲（黄巾祭酒变体）。
  - `suicide`：到点自爆造成范围伤害【远期】。
  - `swarm`：分裂/召唤小怪【远期】。

### 5.5.2 第一章敌人表（黄巾军）

| 敌人 ID | 名称 | 定位 | 数值基调 | 状态 |
|---|---|---|---|---|
| `yellow_turban_soldier` | 黄巾步卒 | 炮灰 | 100HP / 80速 / 漏1血 | 已有 |
| `yellow_turban_cavalry` | 黄巾轻骑 | 快速 | 110HP / 145速 / 漏2血 | 已有 |
| `yellow_turban_sergeant` | 黄巾伍长 | 精英 | 300HP / 65速 / 漏2血 | 已有 |
| `yellow_turban_archer` | 黄巾弓手 | 远程（慢速高漏伤） | 90HP / 60速 / 漏3血 | 已有（v0.9） |
| `yellow_turban_berserker` | 黄巾力士 | 高血坦克 | 450HP / 45速 / 漏2血 | 已有（v0.11.3） |
| `yellow_turban_sorcerer` | 黄巾祭酒 | 光环支援 | 200HP / 55速 / 治疗光环（healer_aura：每 2s 治疗周围 120px 友军 15 点） | 已有（v0.11.3） |
| `yellow_turban_general` | 黄巾渠帅（张梁） | Boss | 3000HP / 30速 / 漏10血 | 已有（v0.11.3，summon_guard：每 8s 自岔路召唤 2 名步卒——s08 分叉试点） |

**敌人规则**：每章敌人必须与章节主题一致（第一章=黄巾军）；新增敌人 = 先建 `EnemyData` 再按需实现 `special_behavior_id`；禁止脱离配置凭空造怪。
