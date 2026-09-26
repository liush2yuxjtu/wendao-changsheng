extends Control
## 主界面：全部用代码搭建，方便直接改。水墨纸色主题。

const GameData := preload("res://scripts/game_data.gd")
const InkBackground := preload("res://scripts/ink_background.gd")
const AudioManager := preload("res://scripts/audio_manager.gd")
const BattleArena := preload("res://scripts/battle_arena.gd")
const InkDraw := preload("res://scripts/ink_draw.gd")
const FONT_PATH := "res://assets/fonts/NotoSerifSC-wendao.otf"

const C_PAPER := Color("f7f0e0")
const C_INK := Color("2b2520")
const C_SUB := Color("6b5a48")
const C_LINE := Color("8c6d4f")
const C_RED := Color("a83a2a")
const C_BTN := Color("3a2f28")
const C_GOLD := Color("e0b64a")

var ui_theme: Theme
var audio: AudioManager
var content: MarginContainer
var fx_layer: Control
var flash: ColorRect

var realm_label: Label
var title_label: Label
var year_label: Label
var mute_btn: Button
var xp_bar: ProgressBar
var xp_label: Label
var speed_label: Label
var res_labels := {}
var break_btn: Button
var med_btn: Button
var rate_label: Label
# 功法
var gongfa_label: Label
var gongfa_btn: Button
var minor_toggle: CheckBox
# 炼丹
var qi_craft_btn: Button
var qi_use_btn: Button
var br_craft_btn: Button
var life_craft_btn: Button
var br_toggle: CheckBox
# 历练
var zone_opt: OptionButton
var adv_btn: Button
var boss_btn: Button
var auto_toggle: CheckBox
var adv_label: Label
var tower_label: Label
var tower_btn: Button
# 神通
var scroll_label: Label
var skill_rows := {}       # id -> {name, desc, learn, equip}
var stat_label: RichTextLabel
# 战斗回放（俯视斗法台）
var bt_layer: Control
var bt_arena: BattleArena
var bt_names: Array = [null, null]
var bt_subs: Array = [null, null]
var bt_avatars: Array = [null, null]
var bt_bars: Array = [null, null]
var bt_shield_seg: Array = [null, null]
var bt_hp_labels: Array = [null, null]
var bt_chips: Array = [null, null]
var bt_rank_chip: Label
var bt_first_chip: Label
var bt_round: Label
var bt_action: Label
var bt_slots: Array = []        # [{icon, name, sub}]
var bt_log: RichTextLabel
var bt_speed_btn: Button
var bt_skip_btn: Button
var bt_result_box: PanelContainer
var bt_result: RichTextLabel
var _bt: Dictionary = {}
var _bt_i := 0
var _bt_t := 0.0
var _bt_speed := 1.0
var _bt_done := true
var _bt_slot_ids: Array = []
var _bt_slot_cd: Array = []
var _bt_slot_on := -1
var _bt_burn := [0, 0]
# 法宝
var equip_labels := {}
var enhance_btns := {}
# 宗门
var sect_locked: Label
var sect_join_box: VBoxContainer
var sect_home_box: VBoxContainer
var sect_info: Label
var sect_task_btn: Button
var sect_break_btn: Button
var sect_herb_btn: Button

var log_box: RichTextLabel
var choice_dlg: ConfirmationDialog
var info_dlg: AcceptDialog

var _choice_id := ""
var _popup_queue: Array = []
var _zone_realm := -1
var _refresh_t := 0.0


func _ready() -> void:
	ui_theme = _make_theme()
	theme = ui_theme
	audio = AudioManager.new()
	add_child(audio)
	_build_ui()
	GameState.choice_event.connect(_on_choice)
	GameState.popup.connect(_on_popup)
	GameState.changed.connect(_refresh)
	GameState.sfx.connect(_on_sfx)
	GameState.battle.connect(_on_battle)
	GameState.start()
	audio.muted = GameState.muted
	for line in GameState.logs:
		log_box.append_text(line + "\n")
	GameState.logged.connect(_on_logged)  # 先回放历史日志再订阅，避免重复
	_refresh()


func _process(delta: float) -> void:
	_battle_step(delta)
	_refresh_t += delta
	if _refresh_t >= 0.1:
		_refresh_t = 0.0
		_refresh()


# ======================= UI 搭建 =======================
func _build_ui() -> void:
	var bg := InkBackground.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	content = MarginContainer.new()
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		content.add_theme_constant_override("margin_" + side, 20)
	add_child(content)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 10)
	content.add_child(root)

	# --- 头部：印章 / 道号 / 境界 / 修为 ---
	var head := _panel(root)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 6)
	head.add_child(hv)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	hv.add_child(top)
	top.add_child(_make_seal())
	title_label = _label(top, "", 22, C_SUB)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	year_label = _label(top, "", 22, C_SUB)
	mute_btn = _button(top, "", _on_mute)
	mute_btn.custom_minimum_size = Vector2(96, 44)
	mute_btn.add_theme_font_size_override("font_size", 20)
	realm_label = _label(hv, "", 50, C_RED)
	realm_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_bar = ProgressBar.new()
	xp_bar.custom_minimum_size = Vector2(0, 34)
	xp_bar.show_percentage = false
	hv.add_child(xp_bar)
	xp_label = _label(xp_bar, "", 20, C_INK)
	xp_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	xp_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	xp_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	speed_label = _label(hv, "", 20, C_SUB)
	speed_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- 资源 ---
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 4)
	_panel(root).add_child(grid)
	for key in ["灵石", "灵草", "战力", "聚气丹", "破境丹", "寿元"]:
		var l := _label(grid, "", 22, C_INK)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		res_labels[key] = l

	# --- 主操作 ---
	var act := HBoxContainer.new()
	act.add_theme_constant_override("separation", 12)
	root.add_child(act)
	med_btn = _button(act, "吐纳", _on_meditate)
	med_btn.custom_minimum_size = Vector2(0, 76)
	med_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_btn = _button(act, "突破", func(): GameState.breakthrough())
	break_btn.custom_minimum_size = Vector2(0, 76)
	break_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	break_btn.size_flags_stretch_ratio = 1.6
	break_btn.add_theme_stylebox_override("normal", _box(C_RED, 10))
	break_btn.add_theme_stylebox_override("hover", _box(C_RED.lightened(0.1), 10))
	rate_label = _label(root, "", 20, C_SUB)
	rate_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	# --- 分页 ---
	var tabs := TabContainer.new()
	tabs.custom_minimum_size = Vector2(0, 340)
	tabs.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tabs.size_flags_stretch_ratio = 1.5
	root.add_child(tabs)
	_build_gongfa_tab(tabs)
	_build_alchemy_tab(tabs)
	_build_adventure_tab(tabs)
	_build_skill_tab(tabs)
	_build_equip_tab(tabs)
	_build_sect_tab(tabs)

	# --- 日志 ---
	var logp := _panel(root)
	logp.size_flags_vertical = Control.SIZE_EXPAND_FILL
	log_box = RichTextLabel.new()
	log_box.bbcode_enabled = true
	log_box.scroll_following = true
	log_box.add_theme_color_override("default_color", C_INK)
	log_box.add_theme_font_size_override("normal_font_size", 21)
	log_box.add_theme_font_size_override("bold_font_size", 21)
	logp.add_child(log_box)

	# --- 特效层 ---
	fx_layer = Control.new()
	fx_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fx_layer)
	flash = ColorRect.new()
	flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.color = Color(C_GOLD, 0.0)
	fx_layer.add_child(flash)
	_build_battle_layer()
	move_child(bt_layer, fx_layer.get_index())   # 特效层在回放层之上

	# --- 弹窗 ---
	choice_dlg = ConfirmationDialog.new()
	choice_dlg.theme = ui_theme
	choice_dlg.title = "奇遇"
	choice_dlg.ok_button_text = "是"
	choice_dlg.get_cancel_button().text = "否"
	choice_dlg.dialog_autowrap = true
	choice_dlg.min_size = Vector2i(580, 0)
	choice_dlg.confirmed.connect(func(): GameState.resolve_choice(_choice_id, true))
	choice_dlg.canceled.connect(func(): GameState.resolve_choice(_choice_id, false))
	choice_dlg.visibility_changed.connect(_show_next_popup)
	add_child(choice_dlg)
	info_dlg = AcceptDialog.new()
	info_dlg.theme = ui_theme
	info_dlg.ok_button_text = "好"
	info_dlg.dialog_autowrap = true
	info_dlg.min_size = Vector2i(580, 0)
	info_dlg.visibility_changed.connect(_show_next_popup)
	add_child(info_dlg)


func _build_gongfa_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "功法")
	gongfa_label = _wrap(_label(v, "", 24, C_INK))
	gongfa_btn = _button(v, "参悟", func(): GameState.upgrade_gongfa())
	minor_toggle = _check(v, "修为圆满时自动突破小境界（大境界仍需手动）")
	minor_toggle.toggled.connect(func(on: bool): GameState.auto_minor = on)
	_wrap(_label(v, "每重功法：修炼速度 +30%，攻击/气血 +5%。\n渡劫圆满后可飞升，飞升后可转世（永久 +50%）。\n寿元耗尽则坐化，被迫转世（永久 +10%）。", 19, C_SUB))


func _build_alchemy_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "炼丹")
	var h1 := HBoxContainer.new()
	v.add_child(h1)
	qi_craft_btn = _button(h1, "", func(): GameState.craft_qi_pill())
	qi_craft_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	qi_use_btn = _button(h1, "服用", func(): GameState.use_qi_pill())
	_label(v, "聚气丹：立得 60 秒修为。成丹率 85%。", 19, C_SUB)
	br_craft_btn = _button(v, "", func(): GameState.craft_break_pill())
	br_toggle = _check(v, "冲击大境界时自动服用破境丹（最多 3 枚，每枚 +15%）")
	br_toggle.toggled.connect(func(on: bool): GameState.use_break_pills = on)
	life_craft_btn = _button(v, "", func(): GameState.craft_life_pill())
	_wrap(_label(v, "延寿丹：寿元 +当前境界基础寿元的 10%。成丹率 75%。", 19, C_SUB))


func _build_adventure_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "历练")
	zone_opt = OptionButton.new()
	zone_opt.item_selected.connect(func(i: int): GameState.zone = i)
	v.add_child(zone_opt)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	adv_btn = _button(h, "外出历练", func(): GameState.adventure(false, true))
	adv_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	boss_btn = _button(h, "挑战妖王", func(): GameState.adventure(true, true))
	boss_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	auto_toggle = _check(v, "自动历练")
	auto_toggle.toggled.connect(func(on: bool): GameState.auto_adventure = on)
	adv_label = _wrap(_label(v, "", 19, C_SUB))
	v.add_child(HSeparator.new())
	tower_label = _wrap(_label(v, "", 21, C_INK))
	tower_btn = _button(v, "", func(): GameState.tower_challenge())
	_wrap(_label(v, "镇妖塔逐层挑战，首通得灵石；每 5 层镇塔妖王另得神通残卷×2，每 10 层得破境丹。", 19, C_SUB))


func _build_skill_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "神通")
	scroll_label = _wrap(_label(v, "", 21, C_INK))
	for sk in GameData.SKILLS:
		var id: String = sk["id"]
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 4)
		v.add_child(box)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		box.add_child(row)
		var nm := _label(row, "", 23, C_INK)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var eq := _button(row, "装备", func(): GameState.toggle_skill(id))
		eq.custom_minimum_size = Vector2(96, 52)
		eq.add_theme_font_size_override("font_size", 19)
		var lb := _button(row, "", func(): _skill_action(id))
		lb.custom_minimum_size = Vector2(230, 52)
		lb.add_theme_font_size_override("font_size", 18)
		var desc := _wrap(_label(box, "", 18, C_SUB))
		skill_rows[id] = {"name": nm, "desc": desc, "learn": lb, "equip": eq}
	v.add_child(HSeparator.new())
	_label(v, "斗法属性", 23, C_RED)
	stat_label = RichTextLabel.new()
	stat_label.bbcode_enabled = true
	stat_label.fit_content = true
	stat_label.scroll_active = false
	stat_label.add_theme_color_override("default_color", C_INK)
	stat_label.add_theme_font_size_override("normal_font_size", 19)
	v.add_child(stat_label)
	_wrap(_label(v, "速度快者先出手。暴击伤害 ×1.5；连击再攻一次；受击时可能反击；击晕令对方跳过一回合；吸血按伤害回血。实际几率 = 己方属性 − 对方对应抗性。%d 回合未分胜负，挑战方判负。" % 20, 18, C_SUB))


func _skill_action(id: String) -> void:
	if GameState.skills.has(id):
		GameState.upgrade_skill(id)
	else:
		GameState.learn_skill(id)


func _build_equip_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "法宝")
	for slot in GameData.SLOTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		v.add_child(row)
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = true
		rt.fit_content = true
		rt.scroll_active = false
		rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rt.add_theme_color_override("default_color", C_INK)
		rt.add_theme_font_size_override("normal_font_size", 21)
		row.add_child(rt)
		equip_labels[slot] = rt
		var b := _button(row, "强化", func(): GameState.enhance_item(slot))
		b.custom_minimum_size = Vector2(210, 58)
		b.add_theme_font_size_override("font_size", 19)
		enhance_btns[slot] = b
	_wrap(_label(v, "历练斩妖有几率掉落法宝（妖王更易出好货）。品质越高战斗词条越多（凡品 1 条…仙品 4 条）。更好的自动装备，旧物自动分解为灵石。每级强化 +10% 主效果、+5% 词条。", 19, C_SUB))


func _build_sect_tab(tabs: TabContainer) -> void:
	var v := _tab(tabs, "宗门")
	sect_locked = _wrap(_label(v, "你尚是散修。筑基之后，方有宗门愿意收你入门。", 21, C_SUB))
	sect_join_box = VBoxContainer.new()
	sect_join_box.add_theme_constant_override("separation", 8)
	v.add_child(sect_join_box)
	_label(sect_join_box, "择一宗门拜入（本世不可更改）：", 21, C_INK)
	for s in GameData.SECTS:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		sect_join_box.add_child(row)
		var l := _wrap(_label(row, "【%s】%s" % [s["name"], s["desc"].replace("\n", " ")], 19, C_INK))
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var id: String = s["id"]
		var b := _button(row, "拜入", func(): GameState.join_sect(id))
		b.custom_minimum_size = Vector2(110, 58)
	sect_home_box = VBoxContainer.new()
	sect_home_box.add_theme_constant_override("separation", 8)
	v.add_child(sect_home_box)
	sect_info = _wrap(_label(sect_home_box, "", 21, C_INK))
	sect_task_btn = _button(sect_home_box, "", func(): GameState.sect_task())
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	sect_home_box.add_child(h)
	sect_break_btn = _button(h, "", func(): GameState.sect_buy("break"))
	sect_break_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sect_break_btn.add_theme_font_size_override("font_size", 19)
	sect_herb_btn = _button(h, "", func(): GameState.sect_buy("herbs"))
	sect_herb_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sect_herb_btn.add_theme_font_size_override("font_size", 19)


func _make_seal() -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(C_RED, 4, Color.TRANSPARENT, 4))
	p.custom_minimum_size = Vector2(44, 44)
	var l := Label.new()
	l.text = "问\n道"
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", C_PAPER)
	l.add_theme_constant_override("line_spacing", -6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	p.add_child(l)
	p.rotation_degrees = -4
	return p


# ======================= 刷新 =======================
func _refresh() -> void:
	var gs := GameState
	title_label.text = "散修 · 第%d世 ×%.1f" % [gs.rebirths + 1, gs.rebirth_mult()]
	year_label.text = "修仙历%d年" % gs.year
	mute_btn.text = "音：关" if gs.muted else "音：开"
	realm_label.text = "已飞升 · 仙人" if gs.ascended else gs.realm_name()
	xp_bar.max_value = gs.xp_need()
	xp_bar.value = gs.xp
	xp_label.text = "修为  %s / %s" % [GameData.fmt(gs.xp), GameData.fmt(gs.xp_need())]
	speed_label.text = "修炼 +%s/秒　灵石 +%s/秒" % [GameData.fmt(gs.xp_speed()), GameData.fmt(gs.lingshi_rate())]

	res_labels["灵石"].text = "灵石 %s" % GameData.fmt(gs.lingshi)
	res_labels["灵草"].text = "灵草 %d" % gs.herbs
	res_labels["战力"].text = "战力 %s" % GameData.fmt(gs.power())
	res_labels["聚气丹"].text = "聚气丹 %d" % gs.pill_qi
	res_labels["破境丹"].text = "破境丹 %d" % gs.pill_break
	var life_left: float = gs.lifespan() - gs.age
	res_labels["寿元"].text = "寿元 %d/%d" % [int(gs.age), int(gs.lifespan())]
	res_labels["寿元"].add_theme_color_override("font_color", C_RED if life_left < gs.lifespan() * 0.1 else C_INK)

	# 突破按钮
	if gs.ascended:
		break_btn.text = "转世重修"
		break_btn.disabled = false
		rate_label.text = "你已位列仙班"
	elif gs.is_major():
		var target: String = "飞升" if gs.level >= GameData.MAX_LEVEL else GameData.REALMS[gs.realm() + 1]
		break_btn.text = ("渡劫飞升" if target == "飞升" else "冲击" + target)
		break_btn.disabled = not gs.is_full()
		var pills: int = gs.pills_to_use()
		rate_label.text = "成功率 %d%%%s　失败则修为 -30%%" % [roundi(gs.break_rate() * 100), ("（含破境丹×%d）" % pills) if pills > 0 else ""]
	else:
		break_btn.text = "突破"
		break_btn.disabled = not gs.is_full()
		rate_label.text = "修为圆满即可突破小境界" if not gs.is_full() else "瓶颈已至，可以突破"

	# 功法
	gongfa_label.text = "当前功法：%s\n修炼倍率 ×%.1f" % [GameData.gongfa_name(gs.gongfa), gs.gongfa_mult()]
	gongfa_btn.text = "参悟下一重（灵石 %s）" % GameData.fmt(gs.gongfa_cost())
	gongfa_btn.disabled = gs.lingshi < gs.gongfa_cost()
	minor_toggle.set_pressed_no_signal(gs.auto_minor)

	# 炼丹
	qi_craft_btn.text = "炼聚气丹（灵草3 + 灵石%s）" % GameData.fmt(gs.qi_pill_cost())
	qi_craft_btn.disabled = gs.herbs < 3 or gs.lingshi < gs.qi_pill_cost()
	qi_use_btn.disabled = gs.pill_qi <= 0 or gs.is_full()
	br_craft_btn.text = "炼破境丹（灵草10 + 灵石%s）" % GameData.fmt(gs.break_pill_cost())
	br_craft_btn.disabled = gs.herbs < 10 or gs.lingshi < gs.break_pill_cost()
	life_craft_btn.text = "炼延寿丹（灵草8 + 灵石%s）" % GameData.fmt(gs.life_pill_cost())
	life_craft_btn.disabled = gs.herbs < 8 or gs.lingshi < gs.life_pill_cost() or gs.ascended
	br_toggle.set_pressed_no_signal(gs.use_break_pills)

	# 历练
	if gs.realm() != _zone_realm:
		_zone_realm = gs.realm()
		zone_opt.clear()
		for i in range(_zone_realm + 1):
			zone_opt.add_item("%s（%s期妖物）" % [GameData.ZONES[i], GameData.REALMS[i]])
		gs.zone = clampi(gs.zone, 0, _zone_realm)
	if zone_opt.selected != gs.zone:
		zone_opt.select(gs.zone)
	var cd: float = gs.adventure_cd
	adv_btn.disabled = cd > 0.0
	boss_btn.disabled = cd > 0.0
	auto_toggle.set_pressed_no_signal(gs.auto_adventure)
	adv_label.text = ("调息中… %.1f 秒" % cd) if cd > 0.0 else "攻击 %s　防御 %s　气血 %s　速度 %d\n妖王更强且会施展神通，掉落破境丹、神通残卷与好法宝。" % [GameData.fmt(gs.attack()), GameData.fmt(gs.defense()), GameData.fmt(gs.max_hp()), int(gs.speed())]
	var tm: Dictionary = GameData.tower_monster(gs.tower_floor + 1)
	tower_label.text = "镇妖塔：已通 %d 层\n下一层守关：%s（战力约 %s）" % [gs.tower_floor, tm["name"], GameData.fmt(float(tm["atk"]) * 3.0 + float(tm["hp"]) * 0.5 + float(tm["def"]) * 2.0)]
	tower_btn.text = "挑战第 %d 层" % (gs.tower_floor + 1)
	tower_btn.disabled = cd > 0.0

	# 神通
	scroll_label.text = "神通残卷 %d　已装备 %d/%d（按装备顺序优先释放）" % [gs.scrolls, gs.skill_equip.size(), gs.skill_slots()]
	for sk in GameData.SKILLS:
		var id: String = sk["id"]
		var row: Dictionary = skill_rows[id]
		var learned: bool = gs.skills.has(id)
		var locked: bool = gs.realm() < int(sk["realm"])
		var lv: int = int(gs.skills.get(id, 1))
		var eqd: bool = gs.skill_equip.has(id)
		row["name"].text = ("%s　第%d层%s" % [sk["name"], lv, "　·已装备" if eqd else ""]) if learned else sk["name"]
		row["name"].add_theme_color_override("font_color", C_RED if eqd else (C_SUB if locked else C_INK))
		row["desc"].text = ("%s解锁　" % GameData.REALMS[int(sk["realm"])] if locked else "") + GameData.skill_desc(id, lv)
		var lb: Button = row["learn"]
		var eb: Button = row["equip"]
		eb.visible = learned
		eb.text = "卸下" if eqd else "装备"
		eb.disabled = not eqd and gs.skill_equip.size() >= gs.skill_slots()
		if not learned:
			var c := GameData.skill_learn_cost(id)
			lb.text = "习得 灵石%s" % GameData.fmt(c)
			lb.disabled = locked or gs.lingshi < c
		elif lv >= GameData.SKILL_MAX_LV:
			lb.text = "已臻圆满"
			lb.disabled = true
		else:
			var uc := GameData.skill_up_cost(id, lv)
			lb.text = "升级 残卷%d 灵石%s" % [lv, GameData.fmt(uc)]
			lb.disabled = gs.scrolls < lv or gs.lingshi < uc
	var cs: Dictionary = gs.cstats()
	var st := "攻击 %s　防御 %s　气血 %s　速度 %d\n" % [GameData.fmt(gs.attack()), GameData.fmt(gs.defense()), GameData.fmt(gs.max_hp()), int(gs.speed())]
	var i := 0
	for k in GameData.CSTATS:
		st += "%s %.1f%%　[color=#6b5a48]抗%s %.1f%%[/color]" % [GameData.CSTAT_NAMES[k], float(cs[k]) * 100, GameData.CSTAT_NAMES[k], float(cs["res_" + k]) * 100]
		i += 1
		st += "\n" if i % 2 == 0 else "　　"
	if stat_label.text != st:
		stat_label.text = st

	# 法宝
	for slot in GameData.SLOTS:
		var it: Dictionary = gs.equip[slot]
		var enh: int = gs.enhance[slot]
		var txt := "%s：%s" % [GameData.SLOT_NAMES[slot], GameData.item_label(it)]
		if not it.is_empty():
			txt += " +%d\n[color=#6b5a48]%s +%d%%　%s[/color]" % [enh, GameData.SLOT_EFFECT[slot], roundi(gs.equip_bonus(slot) * 100), GameData.affix_text(it)]
		if equip_labels[slot].text != txt:
			equip_labels[slot].text = txt
		var b: Button = enhance_btns[slot]
		b.visible = not it.is_empty()
		b.text = "强化 %s" % GameData.fmt(gs.enhance_cost(slot))
		b.disabled = gs.lingshi < gs.enhance_cost(slot)

	# 宗门
	var joined: bool = gs.sect != ""
	sect_locked.visible = not joined and gs.realm() < 1
	sect_join_box.visible = not joined and gs.realm() >= 1
	sect_home_box.visible = joined
	if joined:
		var s: Dictionary = GameData.sect_by_id(gs.sect)
		var rk: int = gs.rank()
		var next_txt := "已至最高职位"
		if rk + 1 < GameData.RANK_NEED.size():
			next_txt = "距%s还差 %s 功勋" % [GameData.SECT_RANKS[rk + 1], GameData.fmt(GameData.RANK_NEED[rk + 1] - gs.contrib_total)]
		sect_info.text = "【%s】%s（修炼 +%d%%）\n可用贡献 %s　%s\n%s" % [s["name"], GameData.SECT_RANKS[rk], roundi(GameData.RANK_BONUS[rk] * 100), GameData.fmt(gs.contrib), next_txt, s["desc"].replace("\n", "　")]
		sect_task_btn.text = ("宗门任务（%d 秒后可接）" % ceili(gs.sect_task_cd)) if gs.sect_task_cd > 0.0 else "接取宗门任务"
		sect_task_btn.disabled = gs.sect_task_cd > 0.0
		sect_break_btn.text = "兑换破境丹（%s 贡献）" % GameData.fmt(gs.sect_shop_cost("break"))
		sect_break_btn.disabled = gs.contrib < gs.sect_shop_cost("break")
		sect_herb_btn.text = "灵草×10（%s 贡献）" % GameData.fmt(gs.sect_shop_cost("herbs"))
		sect_herb_btn.disabled = gs.contrib < gs.sect_shop_cost("herbs")


# ======================= 信号 =======================
func _on_logged(line: String) -> void:
	log_box.append_text(line + "\n")


func _on_choice(id: String, text: String) -> void:
	_choice_id = id
	choice_dlg.title = "转世" if id == "rebirth" else "奇遇"
	choice_dlg.dialog_text = text
	info_dlg.hide()
	choice_dlg.popup_centered()


func _on_popup(title: String, text: String) -> void:
	_popup_queue.append([title, text])
	_show_next_popup()


func _show_next_popup() -> void:
	if _popup_queue.is_empty() or choice_dlg.visible or info_dlg.visible or not is_inside_tree():
		return
	var p: Array = _popup_queue.pop_front()
	info_dlg.title = p[0]
	info_dlg.dialog_text = p[1]
	info_dlg.call_deferred("popup_centered")


func _on_sfx(sfx_name: String) -> void:
	audio.play_sfx(sfx_name)
	match sfx_name:
		"break_ok":
			_burst(18, 0.12)
		"break_major":
			_burst(60, 0.45)
			_bounce(realm_label)
		"break_fail", "death":
			_shake()
			_flash(C_RED, 0.3)


func _on_meditate() -> void:
	GameState.meditate()
	_pulse(xp_bar)
	_float_text("+" + GameData.fmt(GameState.xp_speed()), med_btn)


func _on_mute() -> void:
	GameState.muted = not GameState.muted
	audio.muted = GameState.muted
	_refresh()


# ======================= 战斗回放（俯视斗法台） =======================
const C_HP_ME := Color("6f9a7a")
const C_HP_FOE := Color("b0503c")
const C_BT_BG := Color("efe6d2")
const BT_STEP := 0.36   # ×1 时每条事件的间隔（秒）


func _build_battle_layer() -> void:
	bt_layer = Control.new()
	bt_layer.set_anchors_preset(Control.PRESET_FULL_RECT)
	bt_layer.mouse_filter = Control.MOUSE_FILTER_STOP
	bt_layer.visible = false
	add_child(bt_layer)
	var bg := ColorRect.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.color = C_BT_BG
	bt_layer.add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right"]:
		m.add_theme_constant_override("margin_" + side, 26)
	for side in ["top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 20)
	bt_layer.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)

	# --- 敌方 ---
	var foe := HBoxContainer.new()
	foe.add_theme_constant_override("separation", 14)
	v.add_child(foe)
	foe.add_child(_bt_avatar(1))
	var fv := VBoxContainer.new()
	fv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fv.add_theme_constant_override("separation", 2)
	fv.alignment = BoxContainer.ALIGNMENT_CENTER
	foe.add_child(fv)
	var fn := HBoxContainer.new()
	fn.add_theme_constant_override("separation", 10)
	fv.add_child(fn)
	bt_names[1] = _label(fn, "", 36, C_INK)
	bt_rank_chip = _chip(fn, "妖王", C_RED, C_PAPER)
	bt_subs[1] = _label(fv, "", 20, C_SUB)
	var rv := VBoxContainer.new()
	rv.alignment = BoxContainer.ALIGNMENT_CENTER
	rv.add_theme_constant_override("separation", 0)
	foe.add_child(rv)
	bt_round = _label(rv, "", 36, C_LINE)
	bt_round.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var rl := _label(rv, "/ %d 回合" % 20, 19, C_SUB)
	rl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_bt_hp_row(v, 1)

	# --- 斗法台 ---
	bt_arena = BattleArena.new()
	bt_arena.size_flags_vertical = Control.SIZE_EXPAND_FILL
	bt_arena.custom_minimum_size = Vector2(0, 360)
	bt_arena.clip_contents = true
	v.add_child(bt_arena)
	bt_action = _label(bt_arena, "", 30, C_RED)
	bt_action.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	bt_action.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	bt_action.add_theme_color_override("font_outline_color", C_PAPER)
	bt_action.add_theme_constant_override("outline_size", 8)
	bt_result_box = PanelContainer.new()
	bt_result_box.add_theme_stylebox_override("panel", _box(Color(C_PAPER, 0.94), 12, C_LINE, 22))
	bt_result_box.set_anchors_preset(Control.PRESET_CENTER)
	bt_result_box.grow_horizontal = Control.GROW_DIRECTION_BOTH
	bt_result_box.grow_vertical = Control.GROW_DIRECTION_BOTH
	bt_result_box.custom_minimum_size = Vector2(520, 0)
	bt_result_box.visible = false
	bt_arena.add_child(bt_result_box)
	bt_result = RichTextLabel.new()
	bt_result.bbcode_enabled = true
	bt_result.fit_content = true
	bt_result.scroll_active = false
	bt_result.add_theme_color_override("default_color", C_INK)
	bt_result.add_theme_font_size_override("normal_font_size", 22)
	bt_result.add_theme_font_size_override("bold_font_size", 64)
	bt_result_box.add_child(bt_result)

	# --- 己方 ---
	var me := HBoxContainer.new()
	me.add_theme_constant_override("separation", 14)
	v.add_child(me)
	me.add_child(_bt_avatar(0))
	var mv := VBoxContainer.new()
	mv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	mv.add_theme_constant_override("separation", 6)
	mv.alignment = BoxContainer.ALIGNMENT_CENTER
	me.add_child(mv)
	var mn := HBoxContainer.new()
	mn.add_theme_constant_override("separation", 10)
	mv.add_child(mn)
	bt_names[0] = _label(mn, "你", 34, C_INK)
	bt_subs[0] = _label(mn, "", 19, C_SUB)
	bt_subs[0].size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bt_subs[0].clip_text = true
	bt_first_chip = _chip(mn, "先手", C_BTN, C_PAPER)
	_bt_hp_row(mv, 0)

	# --- 神通槽 ---
	var sl := HBoxContainer.new()
	sl.alignment = BoxContainer.ALIGNMENT_CENTER
	sl.add_theme_constant_override("separation", 40)
	v.add_child(sl)
	for i in 3:
		var box := VBoxContainer.new()
		box.add_theme_constant_override("separation", 2)
		box.custom_minimum_size = Vector2(180, 0)
		sl.add_child(box)
		var icon := Control.new()
		icon.custom_minimum_size = Vector2(0, 104)
		icon.draw.connect(_bt_draw_slot.bind(i, icon))
		box.add_child(icon)
		var nm := _label(box, "", 22, C_INK)
		nm.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var sub := _label(box, "", 18, C_SUB)
		sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		bt_slots.append({"icon": icon, "name": nm, "sub": sub})

	# --- 战报 ---
	var lp := PanelContainer.new()
	lp.add_theme_stylebox_override("panel", _box(C_PAPER, 8, Color("c9b99c"), 12))
	v.add_child(lp)
	bt_log = RichTextLabel.new()
	bt_log.bbcode_enabled = true
	bt_log.scroll_following = true
	bt_log.custom_minimum_size = Vector2(0, 62)
	bt_log.add_theme_color_override("default_color", C_INK)
	bt_log.add_theme_font_size_override("normal_font_size", 19)
	bt_log.add_theme_font_size_override("bold_font_size", 19)
	lp.add_child(bt_log)

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	bt_speed_btn = _button(h, "", _on_bt_speed)
	bt_speed_btn.custom_minimum_size = Vector2(170, 76)
	bt_skip_btn = _button(h, "", _on_bt_skip)
	bt_skip_btn.custom_minimum_size = Vector2(0, 76)
	bt_skip_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL


func _bt_avatar(side: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(88, 88)
	c.draw.connect(func():
		var who: String = _bt.get("who", ["sword", "wolf"])[side]
		var r := c.size.x * 0.5
		var ring := C_HP_ME if side == 0 else (C_RED if _bt.get("rank", "") == "boss" else C_LINE)
		InkDraw.portrait(c, who, Transform2D(0.0, Vector2(r - 4, r - 4) / 50.0, 0.0, Vector2(4, 4)))
		c.draw_arc(Vector2(r, r), r - 2, 0, TAU, 48, ring, 3.0, true))
	bt_avatars[side] = c
	return c


func _bt_hp_row(parent: Node, side: int) -> void:
	var bar := ProgressBar.new()
	bar.custom_minimum_size = Vector2(0, 22)
	bar.show_percentage = false
	bar.add_theme_stylebox_override("fill", _box(C_HP_FOE if side == 1 else C_HP_ME, 8, Color.TRANSPARENT, 0))
	parent.add_child(bar)
	var seg := ColorRect.new()
	seg.color = C_GOLD
	seg.visible = false
	bar.add_child(seg)
	var row := HBoxContainer.new()
	parent.add_child(row)
	var chips := HBoxContainer.new()
	chips.add_theme_constant_override("separation", 8)
	chips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chips.custom_minimum_size = Vector2(0, 30)
	row.add_child(chips)
	var hl := _label(row, "", 19, C_SUB)
	bt_bars[side] = bar
	bt_shield_seg[side] = seg
	bt_hp_labels[side] = hl
	bt_chips[side] = chips


func _chip(parent: Node, text: String, bg: Color, fg: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 18)
	l.add_theme_color_override("font_color", fg)
	var sb := _box(bg, 6, Color.TRANSPARENT, 0)
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 2
	sb.content_margin_bottom = 2
	l.add_theme_stylebox_override("normal", sb)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	parent.add_child(l)
	return l


func _on_battle(rec: Dictionary) -> void:
	_bt = rec
	_bt_i = 0
	_bt_t = 0.0
	_bt_done = false
	_bt_burn = [0, 0]
	var who: Array = rec.get("who", ["sword", "wolf"])
	var rk: String = rec.get("rank", "plain")
	bt_arena.setup(who, rk, rec["mhp"])
	bt_arena.speed = _bt_speed
	var subs: Array = rec.get("subs", ["", rec.get("title", "")])
	for s in 2:
		bt_subs[s].text = subs[s]
		bt_bars[s].max_value = rec["mhp"][s]
		_bt_set_hp(s, rec["mhp"][s], 0.0)
		bt_avatars[s].queue_redraw()
	bt_names[1].text = rec["names"][1]
	bt_rank_chip.visible = rk != "plain"
	bt_rank_chip.text = "妖王" if rk == "boss" else "精英"
	var spd: Array = rec.get("spd", [1, 0])
	bt_first_chip.visible = float(spd[0]) >= float(spd[1])
	_bt_slot_ids = rec.get("skills", [[], []])[0].slice(0, 3)
	_bt_slot_cd = [0, 0, 0]
	_bt_slot_on = -1
	_bt_refresh_slots()
	_bt_refresh_chips()
	bt_round.text = "第 0"
	bt_action.text = ""
	bt_log.clear()
	bt_result_box.visible = false
	bt_speed_btn.visible = true
	bt_speed_btn.text = "×%d" % int(_bt_speed)
	bt_skip_btn.text = "跳过"
	bt_layer.visible = true
	for c in bt_arena.get_children():
		if c != bt_action and c != bt_result_box:
			c.queue_free()


func _bt_set_hp(s: int, hp: float, sh: float) -> void:
	var bar: ProgressBar = bt_bars[s]
	bar.value = hp
	var mx := maxf(bar.max_value, 1.0)
	var seg: ColorRect = bt_shield_seg[s]
	seg.visible = sh > 0.0
	if sh > 0.0:
		seg.position = Vector2(bar.size.x * clampf(hp / mx, 0.0, 1.0), 0)
		seg.size = Vector2(bar.size.x * clampf(sh / mx, 0.0, 1.0 - hp / mx), bar.size.y)
	bt_hp_labels[s].text = "%s / %s" % [GameData.fmt(hp), GameData.fmt(bar.max_value)]


func _bt_refresh_chips() -> void:
	for s in 2:
		var box: HBoxContainer = bt_chips[s]
		for c in box.get_children():
			c.queue_free()
		if bt_arena.stunned[s]:
			_chip(box, "眩晕", C_GOLD, C_INK)
		if _bt_burn[s] > 0:
			_chip(box, "灼烧 %d" % _bt_burn[s], Color("b4531f"), C_PAPER)
		if bt_arena.sh[s] > 0.0:
			_chip(box, "护盾 %s" % GameData.fmt(bt_arena.sh[s]), Color("8a6a1f"), C_PAPER)


func _bt_refresh_slots() -> void:
	for i in 3:
		var sl: Dictionary = bt_slots[i]
		if i < _bt_slot_ids.size():
			var sk := GameData.skill_def(_bt_slot_ids[i])
			sl["name"].text = sk.get("name", "")
			var cd: int = _bt_slot_cd[i]
			if i == _bt_slot_on:
				sl["sub"].text = "释放中"
				sl["sub"].add_theme_color_override("font_color", C_RED)
			else:
				sl["sub"].text = ("冷却 %d 回合" % cd) if cd > 0 else "就绪"
				sl["sub"].add_theme_color_override("font_color", C_SUB)
		else:
			sl["name"].text = "空"
			sl["sub"].text = "未装备"
			sl["sub"].add_theme_color_override("font_color", C_SUB)
		sl["icon"].queue_redraw()


func _bt_draw_slot(i: int, c: Control) -> void:
	var ctr := c.size * 0.5
	var r := minf(c.size.x, c.size.y) * 0.5 - 4
	if i >= _bt_slot_ids.size():
		for k in 24:
			var a := TAU * k / 24.0
			c.draw_arc(ctr, r, a, a + TAU / 48.0, 3, C_LINE, 2.0, true)
		return
	var on := i == _bt_slot_on
	if on:
		c.draw_circle(ctr, r + 4, Color(C_GOLD, 0.35))
	c.draw_circle(ctr, r, C_INK)
	c.draw_arc(ctr, r - 2, 0, TAU, 48, C_GOLD if on else C_LINE, 4.0, true)
	var g := r * 1.1 / 24.0
	InkDraw.skill_glyph(c, _bt_slot_ids[i], Transform2D(0.0, Vector2(g, g), 0.0, ctr - Vector2(12, 12) * g), C_PAPER)
	var cd: int = _bt_slot_cd[i]
	if cd > 0 and not on:
		c.draw_circle(ctr, r - 4, Color(C_INK, 0.62))
		var f := get_theme_default_font()
		c.draw_string(f, ctr + Vector2(-r, 12), str(cd), HORIZONTAL_ALIGNMENT_CENTER, r * 2, 36, C_PAPER)


func _bt_slot_cast(skill_name: String) -> void:
	for i in _bt_slot_ids.size():
		var sk := GameData.skill_def(_bt_slot_ids[i])
		if sk.get("name", "") == skill_name:
			_bt_slot_cd[i] = int(sk["cd"])
			_bt_slot_on = i
	_bt_refresh_slots()


func _bt_skill_id(skill_name: String) -> String:
	for sk in GameData.SKILLS:
		if sk["name"] == skill_name:
			return sk["id"]
	return ""


func _battle_step(delta: float) -> void:
	if _bt_done or not bt_layer.visible:
		return
	_bt_t -= delta * _bt_speed
	while _bt_t <= 0.0 and not _bt_done:
		var evs: Array = _bt["events"]
		if _bt_i >= evs.size():
			_bt_finish()
			return
		var e: Dictionary = evs[_bt_i]
		_bt_i += 1
		_bt_show(e, true)
		var k: String = e["k"]
		_bt_t += BT_STEP * (0.5 if k == "round" or k == "burning" else (2.0 if k == "cast" else 1.0))


func _bt_show(e: Dictionary, animate: bool) -> void:
	var names: Array = _bt["names"]
	var s: int = e["s"]
	var k: String = e["k"]
	var v: float = e["v"]
	var tag: String = e["tag"]
	bt_arena.set_hp(e["hp"], e["sh"])
	for i in 2:
		_bt_set_hp(i, e["hp"][i], e["sh"][i])
	var actor: String = names[s] if s >= 0 else ""
	var target: String = names[1 - s] if s >= 0 else ""
	var line := ""
	match k:
		"round":
			bt_round.text = "第 %d" % int(v)
			line = "[color=#8c6d4f]—— 第 %d 回合 ——[/color]" % int(v)
			for i in 3:
				_bt_slot_cd[i] = maxi(0, _bt_slot_cd[i] - 1)
			_bt_slot_on = -1
			_bt_refresh_slots()
		"cast":
			line = "%s施展[color=#a83a2a]【%s】[/color]" % [actor, tag]
			if s == 0:
				_bt_slot_cast(tag)
			if animate:
				_bt_announce("%s施展【%s】" % [actor, tag])
				var id := _bt_skill_id(tag)
				bt_arena.play(id, s)
				audio.play_sfx("event")
				if id == "tianlei":
					_flash(Color.WHITE, 0.45)
					bt_arena.shake(1 - s, 10.0)
		"hit":
			var crit := tag.begins_with("暴击")
			var how := tag.trim_prefix("暴击").trim_prefix("·")
			var crit_txt := "[color=#b08a2a]暴击！[/color]" if crit else ""
			if how == "":
				line = "%s攻击，%s%s受到 [b]%s[/b] 伤害" % [actor, crit_txt, target, GameData.fmt(v)]
			elif how == "连击" or how == "反击":
				line = "%s%s，%s%s受到 [b]%s[/b] 伤害" % [actor, how, crit_txt, target, GameData.fmt(v)]
			else:
				line = "【%s】命中%s，%s造成 [b]%s[/b] 伤害" % [how, target, crit_txt, GameData.fmt(v)]
			if animate:
				if how == "" or how == "连击" or how == "反击":
					bt_arena.play("slash", s)
				_bt_float(1 - s, ("%s -%s" % [tag, GameData.fmt(v)]) if tag != "" else "-" + GameData.fmt(v), C_GOLD.darkened(0.3) if crit else C_RED, 40 if crit else 32)
				bt_arena.shake(1 - s, 9.0 if crit else 4.0)
				audio.play_sfx("tap")
		"dodge":
			line = "%s闪身避开了%s的%s" % [target, actor, tag if tag != "" else "攻击"]
			if animate:
				bt_arena.dodge(1 - s)
				_bt_float(1 - s, "闪避", C_SUB, 30)
		"heal":
			line = "%s%s，回复 [color=#3f7a52]%s[/color] 气血" % [actor, "吸血" if tag == "吸血" else "运转" + tag, GameData.fmt(v)]
			if s == 0 and tag != "吸血":
				_bt_slot_cast(tag)
			if animate:
				var id := _bt_skill_id(tag)
				if id == "heal":
					_bt_announce("%s运转【%s】" % [actor, tag])
					bt_arena.play("heal", s)
				elif tag == "吸血":
					bt_arena.play("drain", s)
				_bt_float(s, "+" + GameData.fmt(v), Color("2f6a45"), 30 if tag != "吸血" else 24)
		"shield":
			line = "%s施展【%s】，护盾 %s" % [actor, tag, GameData.fmt(v)]
			if s == 0:
				_bt_slot_cast(tag)
			if animate:
				_bt_announce("%s施展【%s】" % [actor, tag])
				bt_arena.play("shield", s)
				_bt_float(s, "护盾 " + GameData.fmt(v), Color("7a5d12"), 28)
		"stun":
			line = "%s被击晕了！" % target
			bt_arena.stunned[1 - s] = true
			if animate:
				_bt_float(1 - s, "眩晕", C_RED, 34)
		"stunned":
			line = "%s头晕目眩，无法行动" % actor
			bt_arena.stunned[s] = false
		"burning":
			line = "%s身陷烈焰" % target
			_bt_burn[1 - s] = 3
			bt_arena.burning[1 - s] = true
		"burn":
			line = "%s被灼烧，损失 %s 气血" % [actor, GameData.fmt(v)]
			_bt_burn[s] = maxi(0, _bt_burn[s] - 1)
			bt_arena.burning[s] = _bt_burn[s] > 0
			if animate:
				_bt_float(s, "灼烧 -" + GameData.fmt(v), Color("b4531f"), 26)
	if k in ["stun", "stunned", "burning", "burn", "shield", "hit"]:
		_bt_refresh_chips()
	if line != "":
		bt_log.append_text(line + "\n")


func _bt_announce(text: String) -> void:
	# 放在两枚棋子之间的台面中线上
	var mid := bt_arena.to_local_pt(Vector2(195, 218))
	bt_action.size = Vector2(bt_arena.size.x, 50)
	bt_action.position = Vector2(0, mid.y - 25)
	bt_action.text = text
	bt_action.modulate.a = 1.0
	var tw := bt_action.create_tween()
	tw.tween_interval(0.6 / _bt_speed)
	tw.tween_property(bt_action, "modulate:a", 0.0, 0.35 / _bt_speed)


func _bt_float(side: int, text: String, color: Color, size: int) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", C_PAPER)
	l.add_theme_constant_override("outline_size", 8)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bt_arena.add_child(l)
	# 飘字出现在棋子右侧，敌方向下飘、己方向上飘，避开中线的神通名
	var anchor: Vector2 = BattleArena.CENTER[side] + Vector2(64, -24 if side == 1 else -30)
	var p0 := bt_arena.to_local_pt(anchor) + Vector2(randf_range(-10, 30), randf_range(-12, 12))
	l.position = p0
	var dy := 26.0 if side == 1 else -26.0
	var tw := l.create_tween().set_parallel()
	tw.tween_property(l, "position:y", p0.y + dy, 0.8 / _bt_speed)
	tw.tween_property(l, "modulate:a", 0.0, 0.8 / _bt_speed).set_delay(0.4 / _bt_speed)
	tw.chain().tween_callback(l.queue_free)


func _bt_finish() -> void:
	_bt_done = true
	var win: bool = _bt["win"]
	var evs: Array = _bt["events"]
	var hp: Array = evs[-1]["hp"] if not evs.is_empty() else _bt["mhp"]
	bt_arena.stunned = [false, false]
	bt_arena.burning = [false, false]
	bt_arena.set_hp(hp, [0.0, 0.0])
	_bt_burn = [0, 0]
	for i in 2:
		_bt_set_hp(i, hp[i], 0.0)
	_bt_refresh_chips()
	_bt_slot_on = -1
	_bt_refresh_slots()
	bt_action.text = ""
	var head := "[center][b][color=#a83a2a]胜[/color][/b][/center]" if win else "[center][b][color=#6b5a48]败[/color][/b][/center]"
	bt_result.text = "%s\n[center]%d 回合\n%s[/center]" % [head, int(_bt["rounds"]), _bt.get("reward", "")]
	bt_result_box.visible = true
	bt_speed_btn.visible = false
	bt_skip_btn.text = "收下" if win else "离开"
	audio.play_sfx("win" if win else "lose")
	if win:
		_burst(24, 0.15)
	else:
		_flash(C_RED, 0.2)


func _on_bt_speed() -> void:
	_bt_speed = 2.0 if _bt_speed < 2.0 else (4.0 if _bt_speed < 4.0 else 1.0)
	bt_arena.speed = _bt_speed
	bt_speed_btn.text = "×%d" % int(_bt_speed)


func _on_bt_skip() -> void:
	if _bt_done:
		bt_layer.visible = false
		return
	var evs: Array = _bt["events"]
	while _bt_i < evs.size():
		_bt_show(evs[_bt_i], false)
		_bt_i += 1
	bt_arena.clear_fx()
	_bt_finish()


# ======================= 特效 =======================
func _burst(amount: int, flash_alpha: float) -> void:
	_flash(C_GOLD, flash_alpha)
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = amount
	p.lifetime = 1.4
	p.explosiveness = 0.95
	p.spread = 180.0
	p.gravity = Vector2(0, -60)
	p.initial_velocity_min = 120.0
	p.initial_velocity_max = 420.0
	p.damping_min = 80.0
	p.damping_max = 160.0
	p.scale_amount_min = 4.0
	p.scale_amount_max = 9.0
	var grad := Gradient.new()
	grad.set_color(0, Color(1.0, 0.9, 0.55, 1.0))
	grad.set_color(1, Color(C_GOLD, 0.0))
	p.color_ramp = grad
	fx_layer.add_child(p)
	p.global_position = realm_label.global_position + realm_label.size * 0.5
	p.emitting = true
	get_tree().create_timer(2.0).timeout.connect(p.queue_free)


func _flash(c: Color, alpha: float) -> void:
	flash.color = Color(c, alpha)
	create_tween().tween_property(flash, "color:a", 0.0, 0.6)


func _shake() -> void:
	var tw := create_tween()
	for i in 6:
		tw.tween_property(content, "position", Vector2(randf_range(-12, 12), randf_range(-8, 8)), 0.04)
	tw.tween_property(content, "position", Vector2.ZERO, 0.05)


func _bounce(c: Control) -> void:
	c.pivot_offset = c.size * 0.5
	c.scale = Vector2(1.35, 1.35)
	create_tween().tween_property(c, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)


func _pulse(c: Control) -> void:
	c.modulate = Color(1.25, 1.15, 0.9)
	create_tween().tween_property(c, "modulate", Color.WHITE, 0.25)


func _float_text(text: String, from: Control) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 26)
	l.add_theme_color_override("font_color", Color("4f6b5a"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(l)
	l.global_position = from.global_position + Vector2(from.size.x * 0.5 - 30 + randf_range(-30, 30), 0)
	var tw := create_tween().set_parallel()
	tw.tween_property(l, "position:y", l.position.y - 90, 0.8)
	tw.tween_property(l, "modulate:a", 0.0, 0.8)
	tw.chain().tween_callback(l.queue_free)


# ======================= 小工具 =======================
func _label(parent: Node, text: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	parent.add_child(l)
	return l


func _wrap(l: Label) -> Label:
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


func _button(parent: Node, text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.pressed.connect(cb)
	parent.add_child(b)
	return b


func _check(parent: Node, text: String) -> CheckBox:
	var c := CheckBox.new()
	c.text = text
	c.add_theme_font_size_override("font_size", 19)
	for k in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color", "font_focus_color"]:
		c.add_theme_color_override(k, C_INK)
	parent.add_child(c)
	return c


func _panel(parent: Node) -> PanelContainer:
	var p := PanelContainer.new()
	parent.add_child(p)
	return p


func _tab(tabs: TabContainer, title: String) -> VBoxContainer:
	var sc := ScrollContainer.new()
	sc.name = title
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	tabs.add_child(sc)
	var m := MarginContainer.new()
	m.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 14)
	sc.add_child(m)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	m.add_child(v)
	return v


func _box(color: Color, radius: int, border := Color.TRANSPARENT, pad := 12) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(pad)
	if border.a > 0.0:
		s.border_color = border
		s.set_border_width_all(2)
	return s


func _make_theme() -> Theme:
	var t := Theme.new()
	var f: Font
	if ResourceLoader.exists(FONT_PATH):
		f = load(FONT_PATH)
	else:
		var sf := SystemFont.new()
		sf.font_names = PackedStringArray(["Noto Serif CJK SC", "Source Han Serif SC", "Songti SC", "SimSun", "Noto Sans CJK SC", "PingFang SC", "Microsoft YaHei"])
		f = sf
	t.default_font = f
	t.default_font_size = 22
	ThemeDB.fallback_font = f

	var paper := Color(C_PAPER, 0.86)
	t.set_stylebox("panel", "PanelContainer", _box(paper, 10, C_LINE, 14))
	for st in ["normal", "focus"]:
		t.set_stylebox(st, "Button", _box(C_BTN, 10))
	t.set_stylebox("hover", "Button", _box(C_BTN.lightened(0.12), 10))
	t.set_stylebox("pressed", "Button", _box(C_BTN.darkened(0.25), 10))
	t.set_stylebox("disabled", "Button", _box(Color("b8ab96"), 10))
	for c in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		t.set_color(c, "Button", C_PAPER)
	t.set_color("font_disabled_color", "Button", Color("efe6d2"))

	t.set_stylebox("background", "ProgressBar", _box(Color("d9ccb3"), 8, Color.TRANSPARENT, 0))
	t.set_stylebox("fill", "ProgressBar", _box(Color("9dbba3"), 8, Color.TRANSPARENT, 0))
	for st in ["normal", "hover", "pressed", "focus", "hover_pressed", "disabled"]:
		t.set_stylebox(st, "CheckBox", StyleBoxEmpty.new())

	t.set_stylebox("panel", "TabContainer", _box(paper, 10, C_LINE, 0))
	t.set_stylebox("tab_selected", "TabContainer", _box(C_LINE, 8, Color.TRANSPARENT, 10))
	t.set_stylebox("tab_unselected", "TabContainer", _box(Color("d9ccb3"), 8, Color.TRANSPARENT, 10))
	t.set_stylebox("tab_hovered", "TabContainer", _box(Color("c9b99c"), 8, Color.TRANSPARENT, 10))
	t.set_color("font_selected_color", "TabContainer", C_PAPER)
	t.set_color("font_unselected_color", "TabContainer", C_INK)
	t.set_color("font_hovered_color", "TabContainer", C_INK)
	t.set_font_size("font_size", "TabContainer", 24)

	t.set_stylebox("normal", "OptionButton", _box(C_BTN, 10))
	t.set_stylebox("hover", "OptionButton", _box(C_BTN.lightened(0.12), 10))
	t.set_color("font_color", "OptionButton", C_PAPER)

	t.set_stylebox("panel", "AcceptDialog", _box(C_PAPER, 0, C_LINE, 20))
	var win := _box(C_LINE, 10, Color.TRANSPARENT, 0)
	win.set_expand_margin(SIDE_LEFT, 6)
	win.set_expand_margin(SIDE_RIGHT, 6)
	win.set_expand_margin(SIDE_BOTTOM, 6)
	win.expand_margin_top = 52
	t.set_stylebox("embedded_border", "Window", win)
	t.set_stylebox("embedded_unfocused_border", "Window", win)
	t.set_constant("title_height", "Window", 46)
	t.set_color("title_color", "Window", C_PAPER)
	t.set_font_size("title_font_size", "Window", 26)
	t.set_constant("buttons_min_width", "AcceptDialog", 180)
	t.set_constant("buttons_min_height", "AcceptDialog", 60)
	t.set_color("font_color", "Label", C_INK)
	return t
