extends Node
## 全局游戏状态（Autoload: GameState）。纯逻辑，不碰 UI。

const GameData := preload("res://scripts/game_data.gd")

signal changed
signal logged(line: String)
signal choice_event(id: String, text: String)
signal popup(title: String, text: String)
signal sfx(name: String)   # tap / break_ok / break_major / break_fail / event / win / lose / item / craft / death

const SAVE_PATH := "user://save.json"
const YEAR_SECONDS := 12.0          # 现实 12 秒 = 修仙历 1 年
const OFFLINE_CAP := 8 * 3600.0     # 离线收益上限 8 小时
const MAX_LOGS := 60
const SECT_TASK_CD := 60.0

# ---- 进度 ----
var level := 0
var xp := 0.0
var lingshi := 0.0
var herbs := 0
var pill_qi := 0
var pill_break := 0
var gongfa := 0
var rebirths := 0
var reb_bonus := 0.0        # 转世累计加成：飞升 +0.5，坐化 +0.1
var year := 1
var age := GameData.START_AGE
var life_bonus := 0.0       # 延寿丹带来的额外寿元
var ascended := false
# ---- 宗门 ----
var sect := ""
var contrib := 0.0
var contrib_total := 0.0
var sect_task_cd := 0.0
# ---- 装备 ----
var equip := {"weapon": {}, "armor": {}, "trinket": {}}
var enhance := {"weapon": 0, "armor": 0, "trinket": 0}
# ---- 设置 ----
var zone := 0
var auto_adventure := false
var use_break_pills := true
var auto_minor := true       # 自动突破小境界
var muted := false
var adventure_cd := 0.0
var logs: Array[String] = []

var rng := RandomNumberGenerator.new()
var _year_t := 0.0
var _event_t := 15.0
var _save_t := 0.0
var _pending_choice := ""
var _elder_price := 0.0
var _life_warned := false
var _started := false


func _ready() -> void:
	rng.randomize()
	set_process(false)


## 由主场景在连好信号后调用：读档 + 结算离线收益
func start() -> void:
	if _started:
		return
	_started = true
	if not load_game():
		add_log("你本是山野少年，偶得一卷残经，自此踏上仙途。")
	set_process(true)
	changed.emit()


func _notification(what: int) -> void:
	if _started and (what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT):
		save_game()


func _process(delta: float) -> void:
	tick(delta)


func tick(delta: float) -> void:
	gain_xp(xp_speed() * delta)
	lingshi += lingshi_rate() * delta
	if auto_minor and not ascended and not is_major() and is_full():
		breakthrough()
	adventure_cd = maxf(0.0, adventure_cd - delta)
	sect_task_cd = maxf(0.0, sect_task_cd - delta)
	if auto_adventure and adventure_cd <= 0.0 and _pending_choice == "":
		adventure(false)
	_year_t += delta
	while _year_t >= YEAR_SECONDS:
		_year_t -= YEAR_SECONDS
		year += 1
		if not ascended:
			age += 1.0
			_check_life()
	_event_t -= delta
	if _event_t <= 0.0 and _pending_choice == "":
		_event_t = rng.randf_range(25.0, 50.0)
		random_event()
	_save_t += delta
	if _save_t >= 10.0:
		_save_t = 0.0
		save_game()


# ---------------- 派生属性 ----------------
func realm() -> int:
	return GameData.realm_of(level)

func realm_name() -> String:
	return GameData.realm_name(level)

func xp_need() -> float:
	return GameData.xp_need(level)

func rebirth_mult() -> float:
	return 1.0 + reb_bonus

func gongfa_mult() -> float:
	return 1.0 + 0.3 * gongfa

func equip_bonus(slot: String) -> float:
	return GameData.item_bonus(equip[slot]) * (1.0 + 0.1 * int(enhance[slot]))

func rank() -> int:
	return GameData.rank_of(contrib_total) if sect != "" else -1

func sect_xp_bonus() -> float:
	if sect == "":
		return 0.0
	return GameData.RANK_BONUS[rank()] + (0.15 if sect == "mystic" else 0.0)

func xp_speed() -> float:
	return GameData.base_speed(level) * gongfa_mult() * rebirth_mult() * (1.0 + equip_bonus("trinket")) * (1.0 + sect_xp_bonus())

func lingshi_rate() -> float:
	return 0.5 * pow(1.25, level) * rebirth_mult()

func attack() -> float:
	return 10.0 * pow(1.42, level) * (1.0 + 0.05 * gongfa) * (1.0 + equip_bonus("weapon")) * (1.25 if sect == "sword" else 1.0)

func max_hp() -> float:
	return 100.0 * pow(1.42, level) * (1.0 + 0.05 * gongfa) * (1.0 + equip_bonus("armor"))

func power() -> float:
	return attack() * 3.0 + max_hp() * 0.5

func lifespan() -> float:
	var base: float = GameData.LIFESPAN[realm()] * (1.1 if sect == "mystic" else 1.0)
	return base + life_bonus

func is_full() -> bool:
	return xp >= xp_need() - 0.001

func is_major() -> bool:
	return level % 4 == 3

func pills_to_use() -> int:
	return mini(pill_break, 3) if use_break_pills else 0

func break_rate() -> float:
	if not is_major():
		return 1.0
	return clampf(GameData.major_rate(realm()) + 0.15 * pills_to_use(), 0.0, 0.98)

func alchemy_bonus() -> float:
	return 0.1 if sect == "pill" else 0.0

func gongfa_cost() -> float:
	return 50.0 * pow(2.0, gongfa)

func qi_pill_cost() -> float:
	return 20.0 * pow(1.25, level)

func break_pill_cost() -> float:
	return 100.0 * pow(2.0, realm())

func life_pill_cost() -> float:
	return 60.0 * pow(2.0, realm())

func enhance_cost(slot: String) -> float:
	var tier := int(equip[slot].get("tier", 0))
	return 80.0 * pow(1.7, int(enhance[slot])) * (tier + 1)

func sect_shop_cost(item: String) -> float:
	match item:
		"break":
			return 60.0 * pow(1.5, realm())
		"herbs":
			return 20.0 * pow(1.5, realm())
	return INF


# ---------------- 修炼与突破 ----------------
func gain_xp(amount: float) -> void:
	xp = clampf(xp + amount, 0.0, xp_need())


## 手动吐纳：点一下得 1 秒修为
func meditate() -> void:
	gain_xp(xp_speed())
	sfx.emit("tap")


func breakthrough() -> void:
	if ascended:
		_ask("rebirth", "你已羽化飞升，位列仙班。\n是否兵解转世，重走仙途？\n（转世后修为、灵石产出永久 +50%%，当前第 %d 世）" % (rebirths + 1))
		return
	if not is_full():
		return
	if not is_major():
		xp = 0.0
		level += 1
		add_log("修为精进，突破至【%s】。" % realm_name())
		sfx.emit("break_ok")
	else:
		var rate := break_rate()
		var used := pills_to_use()
		pill_break -= used
		var target: String = "飞升" if level >= GameData.MAX_LEVEL else GameData.REALMS[realm() + 1]
		var pill_note := "（服下破境丹×%d）" % used if used > 0 else ""
		if rng.randf() < rate:
			sfx.emit("break_major")
			if level >= GameData.MAX_LEVEL:
				ascended = true
				add_log("九九天劫落下，你以肉身硬撼雷霆……劫云散尽，仙光接引，你飞升了！%s" % pill_note)
				popup.emit("飞升成仙", "享寿 %d 岁，你终于渡过天劫，羽化登仙！\n点击「转世重修」可带着感悟重走仙途。" % int(age))
			else:
				xp = 0.0
				level += 1
				_life_warned = false
				add_log("天地灵气倒灌而入，你成功踏入【%s】！寿元增至 %d 年。%s" % [realm_name(), int(lifespan()), pill_note])
				var msg := "恭喜道友晋入「%s」之境！\n寿元上限提升至 %d 年\n新的历练之地已开放：%s" % [target, int(lifespan()), GameData.ZONES[realm()]]
				if realm() == 1 and sect == "":
					msg += "\n\n你已可拜入宗门，去「宗门」页看看吧。"
				popup.emit("突破成功", msg)
		else:
			xp *= 0.7
			add_log("冲击%s失败，经脉受创，修为跌落三成。%s" % [target, pill_note])
			sfx.emit("break_fail")
	changed.emit()
	save_game()


func upgrade_gongfa() -> void:
	var cost := gongfa_cost()
	if lingshi < cost:
		return
	lingshi -= cost
	gongfa += 1
	add_log("你参悟功法，%s 已成。" % GameData.gongfa_name(gongfa))
	sfx.emit("craft")
	changed.emit()


# ---------------- 寿元 ----------------
func _check_life() -> void:
	var left := lifespan() - age
	if left <= 0.0:
		_die()
	elif not _life_warned and left <= lifespan() * 0.1:
		_life_warned = true
		add_log("[color=#a83a2a]你鬓发渐白，气血衰败——寿元只剩 %d 年了！[/color]" % int(left))
		popup.emit("寿元将尽", "寿元只剩 %d 年。\n尽快突破大境界以延寿，或炼制延寿丹续命。" % int(left))


func _die() -> void:
	sfx.emit("death")
	add_log("[color=#a83a2a]寿元耗尽，你于洞府中坐化，享年 %d 岁。[/color]" % int(age))
	popup.emit("坐化", "你止步于%s，享年 %d 岁。\n一缕真灵入轮回，前世感悟化作 +10%% 永久加成。\n（飞升后转世可得 +50%%）" % [realm_name(), int(age)])
	_rebirth(0.1)


func craft_life_pill() -> void:
	var cost := life_pill_cost()
	if herbs < 8 or lingshi < cost:
		return
	herbs -= 8
	lingshi -= cost
	sfx.emit("craft")
	if rng.randf() < 0.75 + alchemy_bonus():
		var add: float = GameData.LIFESPAN[realm()] * 0.1
		life_bonus += add
		_life_warned = false
		add_log("延寿丹入腹，枯木逢春，寿元 +%d 年。" % int(add))
	else:
		add_log("延寿丹炼制失败。")
	changed.emit()


# ---------------- 炼丹 ----------------
func craft_qi_pill() -> void:
	var cost := qi_pill_cost()
	if herbs < 3 or lingshi < cost:
		return
	herbs -= 3
	lingshi -= cost
	sfx.emit("craft")
	if rng.randf() < 0.85 + alchemy_bonus():
		pill_qi += 1
		add_log("丹炉开启，异香扑鼻——聚气丹一枚。")
	else:
		add_log("火候失控，丹炉里只剩一团焦黑。")
	changed.emit()


func use_qi_pill() -> void:
	if pill_qi <= 0 or is_full():
		return
	pill_qi -= 1
	var gain := xp_speed() * 60.0 * (1.5 if sect == "pill" else 1.0)
	gain_xp(gain)
	add_log("服下聚气丹，灵力如潮，修为 +%s。" % GameData.fmt(gain))
	sfx.emit("tap")
	changed.emit()


func craft_break_pill() -> void:
	var cost := break_pill_cost()
	if herbs < 10 or lingshi < cost:
		return
	herbs -= 10
	lingshi -= cost
	sfx.emit("craft")
	if rng.randf() < 0.7 + alchemy_bonus():
		pill_break += 1
		add_log("三日三夜，丹成九转——破境丹一枚！")
	else:
		add_log("破境丹炼制失败，药力散尽。")
	changed.emit()


# ---------------- 历练 ----------------
func adventure(boss: bool) -> void:
	if adventure_cd > 0.0:
		return
	var r := mini(zone, realm())
	var names: Array = GameData.MONSTERS[r]
	var mname: String = GameData.BOSSES[r] if boss else names[rng.randi() % names.size()]
	var mlv: float = r * 4 + (3.5 if boss else rng.randf_range(0.0, 2.5))
	var m_atk := 9.0 * pow(1.42, mlv)
	var m_hp := 95.0 * pow(1.42, mlv)
	var p_atk := attack()
	var p_hp := max_hp()
	var rounds := 0
	while rounds < 30 and p_hp > 0.0 and m_hp > 0.0:
		rounds += 1
		var dmg := p_atk * rng.randf_range(0.8, 1.2)
		if rng.randf() < 0.12:
			dmg *= 2.0
		m_hp -= dmg
		if m_hp <= 0.0:
			break
		p_hp -= m_atk * rng.randf_range(0.8, 1.2)
	var place: String = GameData.ZONES[r]
	if m_hp <= 0.0:
		var ls := 25.0 * pow(2.2, r) * rng.randf_range(0.8, 1.2) * (4.0 if boss else 1.0) * rebirth_mult() * (1.2 if sect == "sword" else 1.0)
		var hb := rng.randi_range(4, 8) if boss else rng.randi_range(1, 3)
		lingshi += ls
		herbs += hb
		var extra := ""
		if rng.randf() < (0.5 if boss else 0.12):
			pill_qi += 1
			extra += "、聚气丹×1"
		if boss and rng.randf() < 0.3:
			pill_break += 1
			extra += "、破境丹×1"
		if sect != "":
			var c := (3.0 if boss else 1.0) * (r + 1)
			contrib += c
			contrib_total += c
		add_log("你于%s遭遇[b]%s[/b]，激战%d回合将其斩杀。获灵石%s、灵草×%d%s。" % [place, mname, rounds, GameData.fmt(ls), hb, extra])
		adventure_cd = 15.0 if boss else 5.0
		sfx.emit("win")
		if rng.randf() < (0.6 if boss else 0.15):
			_drop_item(r, boss)
	else:
		add_log("你于%s遭遇[b]%s[/b]，不敌，负伤遁走，需调息片刻。" % [place, mname])
		adventure_cd = 20.0
		sfx.emit("lose")
	changed.emit()


# ---------------- 装备 ----------------
func make_item(tier: int, boss: bool) -> Dictionary:
	var slot: String = GameData.SLOTS[rng.randi() % GameData.SLOTS.size()]
	var weights: Array = GameData.QUALITY_WEIGHT_BOSS if boss else GameData.QUALITY_WEIGHT
	var roll := rng.randi_range(1, 100)
	var q := 0
	var acc := 0
	for i in weights.size():
		acc += int(weights[i])
		if roll <= acc:
			q = i
			break
	var bases: Array = GameData.ITEM_BASE[slot]
	var iname: String = GameData.ITEM_PREFIX[tier] + bases[rng.randi() % bases.size()]
	return {"slot": slot, "tier": tier, "q": q, "name": iname}


func _drop_item(tier: int, boss: bool) -> void:
	var item := make_item(tier, boss)
	var slot: String = item["slot"]
	var old: Dictionary = equip[slot]
	if GameData.item_bonus(item) > GameData.item_bonus(old):
		equip[slot] = item
		var note := ""
		if not old.is_empty():
			var ls := _salvage_value(old)
			lingshi += ls
			note = "，旧物%s分解得灵石%s" % [GameData.item_label(old), GameData.fmt(ls)]
		add_log("获得法宝%s，已装备（%s +%d%%）%s。" % [GameData.item_label(item), GameData.SLOT_EFFECT[slot], roundi(GameData.item_bonus(item) * 100), note])
		sfx.emit("item")
	else:
		var ls2 := _salvage_value(item)
		lingshi += ls2
		add_log("拾得%s，不如现有之物，分解得灵石%s。" % [GameData.item_label(item), GameData.fmt(ls2)])


func _salvage_value(item: Dictionary) -> float:
	return 20.0 * pow(2.2, int(item["tier"])) * GameData.QUALITY_MULT[int(item["q"])]


func enhance_item(slot: String) -> void:
	if equip[slot].is_empty():
		return
	var cost := enhance_cost(slot)
	if lingshi < cost:
		return
	lingshi -= cost
	enhance[slot] = int(enhance[slot]) + 1
	add_log("你以灵石温养%s，强化至 +%d。" % [GameData.item_label(equip[slot]), enhance[slot]])
	sfx.emit("craft")
	changed.emit()


# ---------------- 宗门 ----------------
func join_sect(id: String) -> void:
	if sect != "" or realm() < 1 or GameData.sect_by_id(id).is_empty():
		return
	sect = id
	add_log("你叩开山门，拜入【%s】，成为外门弟子。" % GameData.sect_by_id(id)["name"])
	popup.emit("拜入宗门", "从此你便是%s弟子。\n完成宗门任务、历练斩妖可积累贡献，提升职位。" % GameData.sect_by_id(id)["name"])
	sfx.emit("break_ok")
	changed.emit()


func sect_task() -> void:
	if sect == "" or sect_task_cd > 0.0:
		return
	var old_rank := rank()
	var c := 8.0 * pow(1.6, realm())
	contrib += c
	contrib_total += c
	var ls := lingshi_rate() * 30.0
	lingshi += ls
	sect_task_cd = SECT_TASK_CD
	var tasks := ["巡守山门", "看护药园", "抄录经卷", "清剿山下妖物", "护送商队", "给长老炼丹打下手"]
	add_log("你完成宗门任务「%s」，贡献 +%s，灵石 +%s。" % [tasks[rng.randi() % tasks.size()], GameData.fmt(c), GameData.fmt(ls)])
	if rank() > old_rank:
		add_log("[color=#a83a2a]功勋卓著，你晋升为%s！修炼速度 +%d%%。[/color]" % [GameData.SECT_RANKS[rank()], roundi(GameData.RANK_BONUS[rank()] * 100)])
		sfx.emit("break_ok")
	changed.emit()


func sect_buy(item: String) -> void:
	var cost := sect_shop_cost(item)
	if sect == "" or contrib < cost:
		return
	contrib -= cost
	match item:
		"break":
			pill_break += 1
			add_log("你在宗门宝库兑换了一枚破境丹。")
		"herbs":
			herbs += 10
			add_log("你在宗门药园兑换了十株灵草。")
	sfx.emit("craft")
	changed.emit()


# ---------------- 奇遇 ----------------
func random_event() -> void:
	var roll := rng.randf()
	sfx.emit("event")
	if roll < 0.12:
		_ask("cave", "你在山崖下发现一处古修洞府，禁制残存，隐有宝光。\n是否闯入一探？")
	elif roll < 0.2 and lingshi > 0.0:
		_elder_price = break_pill_cost() * 1.5
		_ask("elder", "一位鹤发老者拦住去路，自称丹道宗师，\n愿以一枚破境丹换你灵石 %s。\n是否交易？" % GameData.fmt(_elder_price))
	elif roll < 0.28 and herbs >= 2:
		_ask("fox", "路旁一只白狐后腿受伤，哀哀望着你。\n是否用 2 株灵草为它疗伤？")
	else:
		var e: Dictionary = GameData.EVENTS[rng.randi() % GameData.EVENTS.size()]
		var v: float = e["v"]
		var suffix := ""
		match e["k"]:
			"xp":
				var g := xp_speed() * v
				gain_xp(g)
				suffix = "修为%s%s" % ["+" if g >= 0 else "", GameData.fmt(g)]
			"lingshi":
				var g2 := maxf(lingshi_rate() * v, -lingshi)
				lingshi += g2
				suffix = "灵石%s%s" % ["+" if g2 >= 0 else "", GameData.fmt(g2)]
			"herb":
				herbs += int(v)
				suffix = "灵草+%d" % int(v)
			"pill_qi":
				pill_qi += int(v)
				suffix = "聚气丹+%d" % int(v)
		add_log("%s [color=#8a6a3a]（%s）[/color]" % [e["t"], suffix])
	changed.emit()


func _ask(id: String, text: String) -> void:
	_pending_choice = id
	choice_event.emit(id, text)


func resolve_choice(id: String, accept: bool) -> void:
	_pending_choice = ""
	match id:
		"cave":
			if not accept:
				add_log("你按下贪念，绕道而行。")
			elif rng.randf() < 0.6:
				var ls := lingshi_rate() * 300.0
				lingshi += ls
				herbs += 5
				add_log("你破开禁制，得古修遗宝：灵石%s、灵草×5！" % GameData.fmt(ls))
				if rng.randf() < 0.4:
					_drop_item(realm(), true)
			else:
				var loss := xp * 0.2
				xp -= loss
				add_log("禁制骤然反噬，你狼狈逃出，修为 -%s。" % GameData.fmt(loss))
		"elder":
			if not accept:
				add_log("你婉拒了老者，他笑而不语，飘然离去。")
			elif lingshi < _elder_price:
				add_log("你摸了摸储物袋，灵石不够，只得作罢。")
			else:
				lingshi -= _elder_price
				if rng.randf() < 0.8:
					pill_break += 1
					add_log("老者果然是高人，破境丹到手！")
				else:
					add_log("回洞府一看，所谓破境丹竟是一颗泥丸……")
		"fox":
			if not accept:
				add_log("你摇摇头，径自离去。")
			else:
				herbs -= 2
				if rng.randf() < 0.7:
					var g := xp_speed() * 120.0
					gain_xp(g)
					add_log("白狐伤愈，衔来一枚朱果报恩，修为 +%s。" % GameData.fmt(g))
				else:
					add_log("白狐伤愈，回头望了你一眼，消失在林中。")
		"rebirth":
			if accept:
				_rebirth(0.5)
			else:
				add_log("你选择留在仙界，逍遥自在。")
	changed.emit()


func _rebirth(bonus: float) -> void:
	rebirths += 1
	reb_bonus += bonus
	level = 0
	xp = 0.0
	lingshi = 0.0
	herbs = 0
	pill_qi = 0
	pill_break = 0
	gongfa = 0
	zone = 0
	year = 1
	age = GameData.START_AGE
	life_bonus = 0.0
	ascended = false
	sect = ""
	contrib = 0.0
	contrib_total = 0.0
	sect_task_cd = 0.0
	equip = {"weapon": {}, "armor": {}, "trinket": {}}
	enhance = {"weapon": 0, "armor": 0, "trinket": 0}
	_life_warned = false
	add_log("[color=#a83a2a]第 %d 世[/color]：前尘如梦，唯道心不灭。永久加成 ×%.1f。" % [rebirths + 1, rebirth_mult()])
	changed.emit()
	save_game()


# ---------------- 日志 ----------------
func add_log(text: String) -> void:
	var line := "[color=#8c6d4f]第%d年[/color]  %s" % [year, text]
	logs.append(line)
	if logs.size() > MAX_LOGS:
		logs.pop_front()
	logged.emit(line)


# ---------------- 存档 ----------------
func to_dict() -> Dictionary:
	return {
		"v": 2, "level": level, "xp": xp, "lingshi": lingshi, "herbs": herbs,
		"pill_qi": pill_qi, "pill_break": pill_break, "gongfa": gongfa,
		"rebirths": rebirths, "reb_bonus": reb_bonus, "year": year,
		"age": age, "life_bonus": life_bonus, "zone": zone,
		"sect": sect, "contrib": contrib, "contrib_total": contrib_total,
		"equip": equip, "enhance": enhance,
		"auto_adventure": auto_adventure, "use_break_pills": use_break_pills, "auto_minor": auto_minor, "muted": muted,
		"ascended": ascended, "logs": logs,
		"last_time": Time.get_unix_time_from_system(),
	}


func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(to_dict()))


func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		return false
	var d: Dictionary = parsed
	level = clampi(int(d.get("level", 0)), 0, GameData.MAX_LEVEL)
	xp = float(d.get("xp", 0.0))
	lingshi = float(d.get("lingshi", 0.0))
	herbs = int(d.get("herbs", 0))
	pill_qi = int(d.get("pill_qi", 0))
	pill_break = int(d.get("pill_break", 0))
	gongfa = int(d.get("gongfa", 0))
	rebirths = int(d.get("rebirths", 0))
	reb_bonus = float(d.get("reb_bonus", 0.5 * rebirths))   # v1 存档兼容
	year = int(d.get("year", 1))
	age = float(d.get("age", GameData.START_AGE))
	life_bonus = float(d.get("life_bonus", 0.0))
	zone = int(d.get("zone", 0))
	sect = str(d.get("sect", ""))
	contrib = float(d.get("contrib", 0.0))
	contrib_total = float(d.get("contrib_total", 0.0))
	var eq: Variant = d.get("equip", {})
	for slot in GameData.SLOTS:
		var it: Variant = eq.get(slot, {}) if eq is Dictionary else {}
		equip[slot] = it if it is Dictionary and it.has("slot") else {}
	var en: Variant = d.get("enhance", {})
	for slot in GameData.SLOTS:
		enhance[slot] = int(en.get(slot, 0)) if en is Dictionary else 0
	auto_adventure = bool(d.get("auto_adventure", false))
	use_break_pills = bool(d.get("use_break_pills", true))
	muted = bool(d.get("muted", false))
	auto_minor = bool(d.get("auto_minor", true))
	ascended = bool(d.get("ascended", false))
	logs.clear()
	for l in d.get("logs", []):
		logs.append(str(l))
	# 离线收益：修为、灵石照常结算；闭关时以龟息之法护住寿元，不增岁数
	var now := Time.get_unix_time_from_system()
	var off := clampf(now - float(d.get("last_time", now)), 0.0, OFFLINE_CAP)
	if off >= 60.0:
		var xp_before := xp
		gain_xp(xp_speed() * off)
		var ls := lingshi_rate() * off
		lingshi += ls
		var years := int(off / YEAR_SECONDS)
		year += years
		var msg := "你以龟息之法闭关 %d 年，寿元未损。\n修为 +%s，灵石 +%s" % [years, GameData.fmt(xp - xp_before), GameData.fmt(ls)]
		add_log("出关。" + msg.replace("\n", "，"))
		popup.emit("闭关归来", msg)
	return true


func reset_save() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
