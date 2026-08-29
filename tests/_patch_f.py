# -*- coding: utf-8 -*-
import io

def patch(path, pairs):
    s = io.open(path, encoding='utf-8').read()
    for old, new in pairs:
        assert old in s, 'MISSING in %s: %s' % (path, old[:70])
        s = s.replace(old, new)
    io.open(path, 'w', encoding='utf-8', newline='').write(s)
    print('OK', path)

p = 'tests/SmokeRunner.gd'
s = io.open(p, encoding='utf-8').read()

# build_tower 调用改 loadout
pairs = [
    ('''	var leveled_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, 10, charger)''',
     '''	var leveled_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 10, "promotion": charger})'''),
    ('''	var fresh_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, 1, null)''',
     '''	var fresh_tower: Tower = tower_manager.build_tower(Vector2(140, 640), guan_yu, null, {"level": 1})'''),
    ('''	var rage_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, 1, null)''',
     '''	var rage_tower: Tower = tower_manager.build_tower(Vector2(60, 640), guan_yu, null, {"level": 1})'''),
    ('''		var dancer_tower := tower_manager.build_tower(Vector2(60, 100), diao_chan, null, 1, null)
		var ally_tower := tower_manager.build_tower(Vector2(140, 100), guan_yu, null, 1, null)''',
     '''		var dancer_tower: Tower = tower_manager.build_tower(Vector2(60, 100), diao_chan, null, {"level": 1})
		var ally_tower: Tower = tower_manager.build_tower(Vector2(140, 100), guan_yu, null, {"level": 1})'''),
]
for old, new in pairs:
    assert old in s, 'MISSING: %s' % old[:60]
    s = s.replace(old, new)

# 新增：升星 + 信物 + 概率掉落用例（插在 _finish 之前）
anchor = '''		if dancer_tower:
			dancer_tower.queue_free()
'''
add = anchor + '''
	# 升星（v0.13）：碎片逐星消耗 20/40/80/160，成长系数 +5%/星。
	var star_profile := ProfileStore.get_profile()
	star_profile.add_character_shards("guan_yu", 100)
	_check(star_profile.promote_character_star("guan_yu"), "碎片充足时升星应成功")
	_check(star_profile.get_character_stars("guan_yu") == 1, "升星后应为 1 星")
	_check(star_profile.get_character("guan_yu").get("shards", 0) == 80, "升星后应扣除 20 碎片")
	_check(not star_profile.promote_character_star("nonexistent"), "未知武将升星应失败")
	var star_stats := guan_yu.compute_stats_at(10, null, 1, null)
	var star_expected := int(round((guan_yu.base_damage + guan_yu.damage_growth_per_level * 1.05 * 9) * 1.0))
	_check(star_stats.damage == star_expected, "1 星成长系数应 +5%")

	# 信物（v0.13）：装备后 finalize 伤害加成；兑换与装备写入存档。
	var blade := load("res://resources/relics/relic_guanyu_blade.tres") as RelicData
	_check(blade != null, "关羽信物应可加载")
	_check(star_profile.add_relic("relic_guanyu_blade"), "信物首次获得应成功")
	_check(star_profile.set_character_relic("guan_yu", "relic_guanyu_blade"), "装备信物应成功")
	var relic_tower := tower_manager.build_tower(Vector2(220, 640), guan_yu, null, {"level": 1, "stars": 0, "relic": blade})
	_check(relic_tower != null, "应能以信物配置建造")
	if relic_tower:
		_check(is_equal_approx(relic_tower.get("_relic_damage_bonus"), 0.12), "信物伤害加成应传入塔")
		relic_tower.queue_free()

	# 概率掉落数据（v0.13）：s06~s08 应配置概率掉落
	var s06 := GameFlow.load_stage_data(&"ch01_s06") as StageData
	_check(s06 != null and s06.probability_drops.size() == 1, "s06 应配置概率掉落")
	if s06 != null and s06.probability_drops.size() > 0:
		_check(s06.probability_drops[0].chance == 0.5, "概率掉落概率应为 50%")
'''
assert anchor in s
s = s.replace(anchor, add, 1)

io.open(p, 'w', encoding='utf-8', newline='').write(s)
print('OK smoke')
