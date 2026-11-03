# 0.9.4.1 商店商品说明与多列货架

2026-11-03，19张1280×720原生Godot窗口截图，由ShopPreviewRunner使用隔离临时存档生成。程序0.9.4.1 / GDD v0.37.76 / SHOP v0.3 / UI_LAYOUT v0.20.78 / UI_CONCEPT v0.34。

常驻物资和装备分区使用两列卡片；军功五遗物使用三列，同屏完整展示；右侧轮换保留三件及刷新。名称、简短用途或效果、礼包内容、价格、限购剩余或持有数直接可读，图徽辅助。商品卡增加内边距，价格和购买按钮对齐，当前子页金色高亮。购买重建网格后保留滚动位置，切页回顶。

|截图|验收内容|
|---|---|
|shop_l1 / shop_l10|两列物资名称/用途、升级锁定与常驻限购，Ⅰ档空位与Ⅱ档三格轮换|
|shop_bought_material / shop_refresh_price|实际购买、余额与限购更新，刷新下一价格|
|shop_equipment_locked|两列装备与对应解锁关卡规则|
|shop_l60_equipment / shop_equipment_full|实际2/3→3/3购买，已满禁用，原滚动位置保留|
|shop_equipment_middle / shop_equipment_bottom|12款装备名称、适用职业与两项属性、单位完整可读|
|shop_merit / shop_merit_owned / shop_merit_bottom|三列五件遗物完整可见，选带效果与永久限购，当前页高亮|
|shop_save_failed / shop_insufficient|失败不扣费、不足禁用，短句与动作区域完整|
|map_economy / map_economy_hard|标准/困难预告与s08奖励边界回看|
|inventory_shop_material / inventory_shop_relic|原背包商店来源保持可读|
|victory_economy_levelup|原经济结算与升级提示保持可读|

复现：Godot --path . res://tests/ShopPreviewRunner.tscn -- --capture-dir=res://build/verify_0.9.4.1

已目视检查物资、两种礼包、全部装备和五遗物的文本与操作区域；没有标题逐字换行、卡片溢出或轮换刷新被挤出窗口。ShopRunner 461项与FlowRunner通过；Windows导出、独立启动、实际Spine DLL、PE0.9.4.1及105项包内检查通过。B-137~B-139已登记。经济规则、商品价格、限购和schema v10保持原规格。
