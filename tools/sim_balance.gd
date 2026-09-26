extends SceneTree
# 数值模拟。用法：godot --headless -s tools/sim_balance.gd
# 策略：满即突破、先学可学的神通、有钱升功法、缺破境丹就炼、筑基后入玄天道宗做任务、
# 每次冷却结束就历练（每 4 次里 1 次闯镇妖塔）、残卷够就升神通、奇遇随机选
# 环境变量 SIM_LAZY=1 模拟「佛系玩家」：只挂机+每 30 秒看一眼（突破/升功法），不历练不做任务
func _initialize():
	var lazy := OS.get_environment("SIM_LAZY") == "1"
	var GS = load("res://scripts/game_state.gd")
	var gs = GS.new()
	root.add_child(gs)
	gs.set_process(false)
	gs.choice_event.connect(func(id, _t): gs.call_deferred("resolve_choice", id, randf() < 0.5))
	var GD = load("res://scripts/game_data.gd")
	var fights := [0]
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
		if not lazy:
			for sk in GD.SKILLS:
				if not gs.skills.has(sk.id) and gs.realm() >= sk.realm and gs.lingshi >= GD.skill_learn_cost(sk.id): gs.learn_skill(sk.id)
			# 装备最新（最强）的几门：按解锁境界倒序
			var owned = []
			for sk in GD.SKILLS:
				if gs.skills.has(sk.id): owned.push_front(sk.id)
			gs.skill_equip = owned.slice(0, gs.skill_slots())
			for id in gs.skill_equip: gs.upgrade_skill(id)
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
			if gs.adventure_cd <= 0:
				fights[0] += 1
				if fights[0] % 4 == 0: gs.tower_challenge()
				else: gs.adventure(gs.level % 4 == 3)
		var r = gs.realm() + 100 * (gs.rebirths)
		if not marks.has(r):
			marks[r] = t
			print("%6.1f min  %s  功法%d  寿元%d/%d  宗门%s 职位%d  装备%s  坐化%d  神通%s  塔%d" % [t/60.0, gs.realm_name(), gs.gongfa, gs.age, gs.lifespan(), gs.sect, gs.rank(), [gs.equip_bonus("weapon"), gs.equip_bonus("trinket")], deaths[0], gs.skills, gs.tower_floor])
	print("结束 %.1f 小时 飞升次数=%d 坐化=%d" % [t/3600.0, gs.rebirths - deaths[0], deaths[0]])
	gs.reset_save()
	quit()
