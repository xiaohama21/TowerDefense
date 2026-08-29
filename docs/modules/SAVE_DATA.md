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
| `characters` | 武将字典：`total_exp`（总经验，等级由此推导）、`promotion_path`（转职历史）、`shards`（碎片）、`stars`（星级【阶段4】） |
| `stage_progress` | 关卡完成记录（首通/重复、成绩；【阶段4】起按难度分键） |
| `items` | 道具数量字典 |
| `relics` | 已获信物列表【阶段4】 |
| `tech_points` / `tech_unlocks` | 科技点余额与已解锁科技【阶段4】 |
| `gacha_state` | 抽奖状态【阶段4 启用】 |
| `last_committed_run_id` | 防重复提交（一场战斗只结算一次） |

- **结算流程（已实现，禁止改动核心语义）**：`BattleSession`（会话内 pending）→ 胜利 `mark_victory` → `PlayerProfile.apply_battle_session()`（写经验/掉落/解锁/关卡进度）→ `SaveManager.save_profile()`（原子写）。
- 失败/放弃：`mark_defeat` / `abandon` / `mark_discarded`，pending 数据清空，**不写入任何成长**。
- **局内临时状态**：怒气、大招就绪、特性触发、局内塔升级等级（见 modules/STAGES.md 5.4）等**只存在于本局**，不写入存档；存档只持久化等级经验、转职路径、碎片、道具与关卡进度。
- **契约测试**：`tests/Stage0Runner.tscn` 覆盖存档事务（原子写、损坏恢复、非法结算拒绝）；改动本模块后必须重跑。
