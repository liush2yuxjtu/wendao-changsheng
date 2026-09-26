extends SceneTree
# 数值模拟。用法：godot --headless -s tools/sim_balance.gd
# 策略：满即突破、有钱先升功法、缺破境丹就炼、筑基后入玄天道宗做任务、每次冷却结束就历练、奇遇随机选
# 环境变量 SIM_LAZY=1 模拟「佛系玩家」：只挂机+每 30 秒看一眼（突破/升功法），不历练不做任务
func _initialize():
	var lazy := OS.get_environment("SIM_LAZY") == "1"
	var GS = load("res://scripts/game_state.gd")
	var gs = GS.new()
	root.add_child(gs)
	gs.set_process(false)
	gs.choice_event.connect(func(id, _t): gs.call_deferred("resolve_choice", id, randf() < 0.5))
	var deaths := [0]
	gs.sfx.connect(func(n): if n == "death": deaths[0] += 1)
	var t := 0.0
	var dt := 0.5
	var marks := {}
	var look := 0.0
	while t < 3600.0 * 24 and gs.rebirths - deaths[0] == 0:
		gs.tick(dt); t += dt
		look += dt
		if lazy and look < 30.0: continue
		look = 0.0
		if gs.is_full() or gs.ascended: gs.breakthrough()
		if gs.ascended: gs.resolve_choice("rebirth", true)
		while gs.lingshi >= gs.gongfa_cost(): gs.upgrade_gongfa()
		if gs.is_major() and gs.herbs >= 10 and gs.pill_break < 3 and gs.lingshi >= gs.break_pill_cost(): gs.craft_break_pill()
		if gs.lifespan() - gs.age < 30 and gs.herbs >= 8 and gs.lingshi >= gs.life_pill_cost(): gs.craft_life_pill()
		if not lazy:
			if gs.sect == "" and gs.realm() >= 1: gs.join_sect("mystic")
			gs.sect_task()
			if gs.pill_break < 3: gs.sect_buy("break")
			for s in ["weapon", "armor", "trinket"]:
				if gs.lingshi > gs.enhance_cost(s) * 4: gs.enhance_item(s)
			gs.zone = gs.realm()
			if gs.adventure_cd <= 0: gs.adventure(gs.level % 4 == 3)
		var r = gs.realm() + 100 * (gs.rebirths)
		if not marks.has(r):
			marks[r] = t
			print("%6.1f min  %s  功法%d  寿元%d/%d  宗门%s 职位%d  装备%s  坐化%d" % [t/60.0, gs.realm_name(), gs.gongfa, gs.age, gs.lifespan(), gs.sect, gs.rank(), [gs.equip_bonus("weapon"), gs.equip_bonus("trinket")], deaths[0]])
	print("结束 %.1f 小时 飞升次数=%d 坐化=%d" % [t/3600.0, gs.rebirths - deaths[0], deaths[0]])
	gs.reset_save()
	quit()
