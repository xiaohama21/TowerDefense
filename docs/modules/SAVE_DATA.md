# 存档与数据模型（SAVE_DATA）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 承载总纲原章节：8。章节编号沿用全局稳定 ID。

---

## 8. 存档与数据模型

- 存档文件：`user://profile.json`（主档）+ `.bak` 备份 + `.tmp` 原子写（`SaveManager` 已实现，损坏自动隔离并恢复备份）。
- 存档结构（`PlayerProfile`）：

| 字段 | 内容 |
|---|---|
| `schema_version` | 存档版本，迁移用（当前 v3，v0.33.1 起：新增 `squad_character_ids` / `squad_relic_ids` 编队记忆；v2→v3 迁移旧档补空数组；**0.8.14 / 0.8.15 / 0.8.16 各自落地时按需升版并迁移**——碎片字段清理 / `exp_pool` / 军功 + 军需字段） |
| `characters` | 武将字典：`total_exp`（总经验，等级由此推导）、`promotion_path`（转职历史）、`shards`（碎片；**随信物重构删除**——2026-09-09 定稿、排期 0.8.14 清理迁移）、`stars`（星级，✅ v0.13）、`relic`（装备信物，✅ v0.13；0.8.14 起扩展双槽装配映射） |
| `stage_progress` | 关卡完成记录（首通/重复、成绩；v0.14.1 起按难度分键 `difficulties`：normal/hard（v0.31.2 移除 easy，旧档 easy 键忽略），解锁读取上一档通关记录） |
| `items` | 道具数量字典（✅ v0.15.1 新增测试道具 `exp_scroll` 练兵令，经背包发放，不进掉落表；✅ v0.19.0 局内遗物库存复用本字典，`relic_id` 即 item_id；✅ v0.33.1 遗物改**永久使用**——数量 ≥1 即解锁、选带/结算均不消耗；**`exp_scroll` 随 0.8.15 删除**——发放按钮 / 使用行移除、旧档残留数量清理） |
| `relics` | 已获信物列表（✅ v0.13；2026-09-09 重构定稿：Boss 签名信物按 s08 难度首通唯一获取，可选槽装配映射随 0.8.14 实现） |
| `tech_points` / `tech_unlocks` | 科技点余额与已解锁科技（✅ v0.14/v0.14.1；发放=首通+2/重复+1 × 难度材料倍率，胜利提交时经 `BattleSession.pending_tech_points` 写入） |
| `gacha_state` | 抽奖状态（✅ v0.14.1 启用：保底计数/总抽数；求贤令数量存 `items.gacha_token`） |
| `last_committed_run_id` | 防重复提交（一场战斗只结算一次） |
| `squad_character_ids` / `squad_relic_ids` | 出战编队持久记忆（✅ v0.33.1：`squad_character_ids`=上次确认出战的武将列表、`squad_relic_ids`=上次选带的局内遗物列表；编队页再次出征自动预填——武将须仍拥有、遗物须仍有库存） |
| `exp_pool` | **经验池余额**（2026-09-10 定稿、排期 0.8.15）：胜利结算按 `(本局击杀经验 + participant_xp×出战人数)×50%` **额外注入**（不扣武将所得）；池内经验分配给任意已拥有武将即写入 `characters[id].total_exp`、**不可逆**；失败 / 退出 / 崩溃不带出；旧档迁移补 0。规则见 CHARACTERS 4.4 / NUMBERS 10.14 |
| `military_merit` | **军功余额**（2026-09-10 定稿、排期 0.8.16）：击杀掉落固定值（困难 ×1.5）、失败 / 退出不带出；消耗于**军需解锁 / 强化**；不占 `items` 物品位（货币余额）；旧档迁移补 0。数值见 NUMBERS 10.15 |
| `supply_unlocks` / `supply_levels` | **军需解锁与强化等级**（0.8.16）：`supply_unlocks` = 已解锁军需 id 列表（基础 4 件默认解锁、掷石齐射 / 犒军需军功解锁）、`supply_levels` = 军需 id → 强化等级（L1~L3）；旧档迁移补基础 4 件已解锁、等级 L1 |
| `supply_loadout_ids` | **局外军需选带记忆**（0.8.16）：出征前选带的军需列表（默认 **2 槽**、科技 +1 → **3 槽**），随战斗进入局内"军需带"；与 `squad_*` 同为持久记忆（旧档迁移补空数组） |

- **结算流程（已实现，禁止改动核心语义）**：`BattleSession`（会话内 pending：经验/掉落/解锁/信物/**科技点**/难度标记；**0.8.15 起 + 经验池注入，0.8.16 起 + 军功**）→ 胜利 `mark_victory` → `PlayerProfile.apply_battle_session()`（写经验/掉落/解锁/关卡进度/科技点/难度通关记录；**0.8.15 / 0.8.16 起一并写 `exp_pool` / `military_merit`**）→ `SaveManager.save_profile()`（原子写）；局内遗物**永久使用**（✅ v0.33.1：选带与结算均不消耗库存，v0.22.0"胜利扣库存各 1 件"作废，见 BUGS B-019）。
- 失败/放弃：`mark_defeat` / `abandon` / `mark_discarded`，pending 数据清空，**不写入任何成长**。
- **局内临时状态**：怒气、大招就绪、特性触发、局内塔升级等级（见 modules/STAGES.md 5.4）等**只存在于本局**，不写入存档；存档只持久化等级经验、转职路径、信物、道具与关卡进度。
- **契约测试**：`tests/Stage0Runner.tscn` 覆盖存档事务（原子写、损坏恢复、非法结算拒绝）；改动本模块后必须重跑。
