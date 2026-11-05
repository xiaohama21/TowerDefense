# 0.9.6.2 原生界面验收（2026-11-04）

GDD v0.37.85 / CHARACTER_SKILLS v0.18 / UI_LAYOUT v0.20.87 / ENCYCLOPEDIA v0.1.31 / UI_CONCEPT v0.43 / BUGS v0.82。

典韦宛城死战：基础攻击×4，命中前目标生命≤50%时追加攻击×4，取消基地生命条件。技能ID、怒气、自动/手动模式保持。

27技能共用触发说明、效果项/Lv1基础/等级加成/养成加成/当前值表、伤害预览和规则。预览按面板攻击与实际倍率拆分并注明每击/每目标/斩杀条件；固定值不伪造加成，未计科技、敌方护甲/易伤、伤害类天赋与临时增益的边界直接常显。

动作/圆形动作统一Kenney素材，选择卡与科技/天赋树保留形状并补完整状态和金色焦点；默认下拉/开关/菜单/确认框同源。确认/取消、技能升级、购买扣款/发货、升阶、满阶禁用、回收、军需关闭和转盘禁用均已验证。地图编辑插件沿用Godot编辑器主题，仅检查玩家入口。

16项功能回归（含技能/按钮专项）、19064项原生窗口检查、45张1280×720截图和418项包内检查通过；Windows独立启动、实际Spine DLL加载及PE版本0.9.6.2通过。

按钮巡检共1688条记录，同一按钮在不同界面状态中重复巡检，不能解释为独立按钮数量。原有395枚图标保持；身份替换与旧档兼容回归通过。

| 截图 | 验收内容 |
|---|---|
| [main_menu_buttons.png](main_menu_buttons.png) | 主菜单导航与新档/继续动作 |
| [buttons_map.png](buttons_map.png) | 地图/难度/出战按钮 |
| [buttons_develop.png](buttons_develop.png) | 养成与角色/动作按钮 |
| [buttons_tech.png](buttons_tech.png) | 科技树节点、强化与重置动作 |
| [buttons_supply.png](buttons_supply.png) | 局外军需卡、解锁与选带按钮 |
| [buttons_shop.png](buttons_shop.png) | 余额不足与未解锁购买状态 |
| [buttons_inventory.png](buttons_inventory.png) | 背包分类、物品卡及详情 |
| [buttons_settings.png](buttons_settings.png) | 显示模式与玩法勾选控件 |
| [buttons_encyclopedia.png](buttons_encyclopedia.png) | 百科筛选、页签和模拟控件 |
| [diao_chan_skills.png](diao_chan_skills.png) | 貂蝉技能顶部、触发与基础/加成表 |
| [diao_chan_ultimate.png](diao_chan_ultimate.png) | 貂蝉大招滚动、伤害分解与升级动作 |
| [guan_yu_skills.png](guan_yu_skills.png) | 关羽技能顶部、触发与基础/加成表 |
| [guan_yu_ultimate.png](guan_yu_ultimate.png) | 关羽大招滚动、伤害分解与升级动作 |
| [huang_fu_song_skills.png](huang_fu_song_skills.png) | 皇甫嵩技能顶部、触发与基础/加成表 |
| [huang_fu_song_ultimate.png](huang_fu_song_ultimate.png) | 皇甫嵩大招滚动、伤害分解与升级动作 |
| [huang_zhong_skills.png](huang_zhong_skills.png) | 孙尚香技能顶部、触发与基础/加成表 |
| [huang_zhong_ultimate.png](huang_zhong_ultimate.png) | 孙尚香大招滚动、伤害分解与升级动作 |
| [liu_bei_skills.png](liu_bei_skills.png) | 刘备技能顶部、触发与基础/加成表 |
| [liu_bei_ultimate.png](liu_bei_ultimate.png) | 刘备大招滚动、伤害分解与升级动作 |
| [zhang_fei_skills.png](zhang_fei_skills.png) | 张飞技能顶部、触发与基础/加成表 |
| [zhang_fei_ultimate.png](zhang_fei_ultimate.png) | 张飞大招滚动、伤害分解与升级动作 |
| [zhao_yun_skills.png](zhao_yun_skills.png) | 赵云技能顶部、触发与基础/加成表 |
| [zhao_yun_ultimate.png](zhao_yun_ultimate.png) | 赵云大招滚动、伤害分解与升级动作 |
| [zhou_wei_skills.png](zhou_wei_skills.png) | 典韦技能顶部、触发与基础/加成表 |
| [zhou_wei_ultimate.png](zhou_wei_ultimate.png) | 典韦大招滚动、伤害分解与升级动作 |
| [zhou_wei_ultimate_top.png](zhou_wei_ultimate_top.png) | 典韦大招标题、触发、斩杀门槛与五列数值表 |
| [zhuge_liang_skills.png](zhuge_liang_skills.png) | 诸葛亮技能顶部、触发与基础/加成表 |
| [zhuge_liang_ultimate.png](zhuge_liang_ultimate.png) | 诸葛亮大招滚动、伤害分解与升级动作 |
| [talent_buttons.png](talent_buttons.png) | 独立天赋树、节点及重置/关闭动作 |
| [talent_detail_buttons.png](talent_detail_buttons.png) | 天赋详情、分配及关闭动作 |
| [encyclopedia_skill_numbers.png](encyclopedia_skill_numbers.png) | 百科模拟属性、局内阶数及技能同源数值 |
| [shop_available_buttons.png](shop_available_buttons.png) | 足额购买可用状态，随后验证真实扣款与发货 |
| [shop_exchange_buttons.png](shop_exchange_buttons.png) | 军功兑换筛选与按钮 |
| [confirmation_buttons.png](confirmation_buttons.png) | 浅底确认正文、标题背景、中文确认/取消按钮 |
| [squad_buttons.png](squad_buttons.png) | 编队角色/遗物选择与动作 |
| [squad_confirm_buttons.png](squad_confirm_buttons.png) | 编队确认弹窗 |
| [battle_buttons.png](battle_buttons.png) | 战斗初始HUD与剧情按钮 |
| [battle_dialogue.png](battle_dialogue.png) | 浅底对白及跳过动作 |
| [battle_tower_buttons.png](battle_tower_buttons.png) | 升阶/回收/手动大招圆形按钮、整图缩放 |
| [battle_tower_max_buttons.png](battle_tower_max_buttons.png) | 满阶禁用灰色圆盘与手动大招 |
| [battle_menu_buttons.png](battle_menu_buttons.png) | 暂停/设置/重开/退出菜单 |
| [battle_supply_buttons.png](battle_supply_buttons.png) | 局内军需、购买与红色圆盘关闭按钮 |
| [victory_buttons.png](victory_buttons.png) | 胜利、转盘、下一关/重试/返回按钮 |
| [victory_claimed_buttons.png](victory_claimed_buttons.png) | 领取后转盘按钮禁用 |
| [defeat_buttons.png](defeat_buttons.png) | 战败、重试与返回按钮 |

复现：Godot运行`res://tests/PolishRunner.tscn`并传入`--capture-dir=res://build/verify_0.9.6.2`，采用隔离测试档。

[manifest.json](manifest.json)记录验收与截图哈希，[button_audit.json](button_audit.json)记录逐屏按钮状态，[SHA256SUMS.txt](SHA256SUMS.txt)核对截图。
