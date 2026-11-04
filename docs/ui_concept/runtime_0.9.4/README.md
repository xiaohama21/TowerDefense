# 0.9.4 商店与经济窗口验收

2026-11-03，17张1280×720原生Godot窗口截图。ShopPreviewRunner使用独立临时档案，结束后清理，不修改正式存档。程序0.9.4.0 / GDD v0.37.75 / SHOP v0.2 / UI_LAYOUT v0.20.77 / UI_CONCEPT v0.33。

|截图|验收内容|
|---|---|
|shop_l1|Ⅰ档两件轮换与第三格虚线空位；八导航和返回完整|
|shop_bought_material|实际购买扣8，持有精铁增加，剩余限购次数减少|
|shop_refresh_price|实际刷新扣10，下一次20，货架未重复商品|
|shop_l10|Ⅱ档解锁技能书，轮换补齐三件|
|shop_equipment_locked|装备对应关卡规则常显，禁用购买|
|shop_l60_equipment|通关后装备上架，持有2/3可购买|
|shop_equipment_full|实际购买第三件后3/3，显示已满|
|shop_merit|军功店固定遗物，效果简介与兑换价格|
|shop_merit_owned|实际兑换，军功扣240、元宝不变，显示已购|
|shop_merit_bottom|滚动至末件战鼓，五件完整可达|
|shop_save_failed|保存受阻时余额与限购不变，规则短句提示|
|shop_insufficient|余额0，购买和刷新禁用|
|map_economy|8/8已通关，标准重复经济10/25；s08全部奖励位于卡片内|
|map_economy_hard|困难重复20/38，八卡和预告条同步|
|inventory_shop_material|物资详情补充补给页来源|
|inventory_shop_relic|永久遗物详情补充兑换页来源|
|victory_economy_levelup|真实Main胜利提交，首通30/80与Lv9→Lv10提示|

元宝、主公等级与主公经验图徽使用已登记的虚线圆占位；现有图徽沿统一透明符号入口。技能文字例外继续保留。已目视检查完整货架、按钮、滚动、锁定/限购/失败状态、地图奖励边界与结算升级。

复现：Godot --path . res://tests/ShopPreviewRunner.tscn

13项功能/回归通过，ShopRunner 461项、GearRunner 446项；ShopRunner另检查八卡奖励边界与实际困难一键通关经济。Windows release独立启动、实际Spine DLL与PE0.9.4.0通过；105项包内检查覆盖54项养成/百科技能信息及商店、迁移、回滚、升档轮换、装配、胜利/失败结算显示和首波。B-134~B-136已登记。
