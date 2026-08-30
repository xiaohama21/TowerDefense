# 存档与数据模型（SAVE_DATA）

> 隶属《烽火连营·三国塔防》设计文档体系，总纲见 [../GAME_DESIGN.md](../GAME_DESIGN.md)。
> 承载总纲原章节：8。章节编号沿用全局稳定 ID。

---

## 8. 存档与数据模型

- 存档文件：`user://profile.json`（主档）+ `.bak` 备份 + `.tmp` 原子写（`SaveManager` 已实现，损坏自动隔离并恢复备份）。
- 存档结构（`PlayerProfile`）：

| 字段 | 内容 |
|---|---|
| `schema_version` | 存档版本，迁移用 |
| `characters` | 武将字典：`total_exp`（总经验，等级由此推导）、`promotion_path`（转职历史）、`shards`（碎片）、`stars`（星级，✅ v0.13）、`relic`（装备信物，✅ v0.13） |
| `stage_progress` | 关卡完成记录（首通/重复、成绩；v0.14.1 起按难度分键 `difficulties`：easy/normal/hard，困难解锁读取标准通关记录） |
| `items` | 道具数量字典（✅ v0.15.1 新增测试道具 `exp_scroll` 练兵令，经背包发放，不进掉落表；✅ v0.19.0 局内遗物库存复用本字典，`relic_id` 即 item_id，出战消耗各 1 件） |
| `relics` | 已获信物列表（✅ v0.13） |
| `tech_points` / `tech_unlocks` | 科技点余额与已解锁科技（✅ v0.14/v0.14.1；发放=首通+2/重复+1 × 难度材料倍率，胜利提交时经 `BattleSession.pending_tech_points` 写入） |
| `gacha_state` | 抽奖状态（✅ v0.14.1 启用：保底计数/总抽数；求贤令数量存 `items.gacha_token`） |
| `last_committed_run_id` | 防重复提交（一场战斗只结算一次） |

- **结算流程（已实现，禁止改动核心语义）**：`BattleSession`（会话内 pending：经验/掉落/解锁/信物/**科技点**/难度标记）→ 胜利 `mark_victory` → `PlayerProfile.apply_battle_session()`（写经验/掉落/解锁/关卡进度/科技点/难度通关记录）→ `SaveManager.save_profile()`（原子写）。
- 失败/放弃：`mark_defeat` / `abandon` / `mark_discarded`，pending 数据清空，**不写入任何成长**。
- **局内临时状态**：怒气、大招就绪、特性触发、局内塔升级等级（见 modules/STAGES.md 5.4）等**只存在于本局**，不写入存档；存档只持久化等级经验、转职路径、碎片、道具与关卡进度。
- **契约测试**：`tests/Stage0Runner.tscn` 覆盖存档事务（原子写、损坏恢复、非法结算拒绝）；改动本模块后必须重跑。
