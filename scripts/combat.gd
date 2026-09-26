extends RefCounted
## 回合制战斗引擎（一念逍遥式）。纯计算，不碰 UI 和存档。
## - 每回合按速度先后出手；被击晕则跳过一次出手
## - 神通按冷却自动释放（冷却中则普攻）
## - 六维战斗属性：暴击 / 连击 / 反击 / 闪避 / 击晕 / 吸血，实际生效 = 己方属性 − 对方对应抗性
## - MAX_ROUNDS 回合仍未分胜负，挑战方（side 0）判负
## 返回 {win, rounds, timeout, names, mhp, events}；events 逐条记录，供界面回放。

const GameData := preload("res://scripts/game_data.gd")
const MAX_ROUNDS := 20
const CRIT_MULT := 1.5
const PROC_CAP := 0.75


static func fight(a: Dictionary, b: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var f := [_prep(a), _prep(b)]
	var ctx := {"f": f, "ev": [], "rng": rng}
	var rounds := 0
	while rounds < MAX_ROUNDS and _alive(f[0]) and _alive(f[1]):
		rounds += 1
		_push(ctx, -1, "round", rounds, "")
		var first := 0 if float(f[0]["spd"]) >= float(f[1]["spd"]) else 1
		for s in [first, 1 - first]:
			if not (_alive(f[0]) and _alive(f[1])):
				break
			_turn(ctx, s)
	var win := _alive(f[0]) and not _alive(f[1])
	var timeout := _alive(f[0]) and _alive(f[1])
	return {
		"win": win, "rounds": rounds, "timeout": timeout,
		"names": [f[0]["name"], f[1]["name"]],
		"mhp": [f[0]["mhp"], f[1]["mhp"]],
		"events": ctx["ev"],
	}


static func _prep(d: Dictionary) -> Dictionary:
	var sk := []
	for s in d.get("skills", []):
		var def := GameData.skill_def(str(s["id"]))
		if not def.is_empty():
			sk.append({"def": def, "lv": int(s["lv"]), "cd": 0})
	return {
		"name": d["name"], "hp": float(d["hp"]), "mhp": float(d["hp"]),
		"atk": float(d["atk"]), "def": float(d["def"]), "spd": float(d["spd"]),
		"st": d.get("st", {}), "res": d.get("res", {}), "skills": sk,
		"shield": 0.0, "stunned": false, "burn_t": 0, "burn_v": 0.0,
	}


static func _alive(x: Dictionary) -> bool:
	return float(x["hp"]) > 0.0


## 事件：s=行动方（-1 为系统），k=类型，v=数值，tag=附注（神通名/连击/反击/暴击）
static func _push(ctx: Dictionary, s: int, k: String, v: float, tag: String) -> void:
	var f: Array = ctx["f"]
	ctx["ev"].append({
		"s": s, "k": k, "v": v, "tag": tag,
		"hp": [f[0]["hp"], f[1]["hp"]], "sh": [f[0]["shield"], f[1]["shield"]],
	})


## owner 的某项属性 − opp 的对应抗性
static func _eff(owner: Dictionary, opp: Dictionary, key: String) -> float:
	var v := float(owner["st"].get(key, 0.0)) - float(opp["res"].get(key, 0.0))
	return clampf(v, 0.0, PROC_CAP)


static func _roll(ctx: Dictionary, owner: Dictionary, opp: Dictionary, key: String) -> bool:
	var p := _eff(owner, opp, key)
	return p > 0.0 and ctx["rng"].randf() < p


static func _turn(ctx: Dictionary, s: int) -> void:
	var f: Array = ctx["f"]
	var me: Dictionary = f[s]
	for sk in me["skills"]:
		sk["cd"] = maxi(0, int(sk["cd"]) - 1)
	# 灼烧
	if int(me["burn_t"]) > 0:
		me["burn_t"] = int(me["burn_t"]) - 1
		var bd := _take(me, float(me["burn_v"]), true)
		_push(ctx, s, "burn", bd, "")
		if not _alive(me):
			return
	if me["stunned"]:
		me["stunned"] = false
		_push(ctx, s, "stunned", 0.0, "")
		return
	# 神通
	for sk in me["skills"]:
		if int(sk["cd"]) > 0:
			continue
		var def: Dictionary = sk["def"]
		if def["k"] == "heal" and float(me["hp"]) > float(me["mhp"]) * 0.7:
			continue
		if def["k"] == "shield" and float(me["shield"]) > 0.0:
			continue
		sk["cd"] = int(def["cd"])
		_cast(ctx, s, def, int(sk["lv"]))
		return
	# 普攻 + 连击
	_attack(ctx, s, 1.0, "", true, 0.0)
	var op: Dictionary = f[1 - s]
	if _alive(me) and _alive(op) and _roll(ctx, me, op, "combo"):
		_attack(ctx, s, 1.0, "连击", false, 0.0)


static func _cast(ctx: Dictionary, s: int, def: Dictionary, lv: int) -> void:
	var f: Array = ctx["f"]
	var me: Dictionary = f[s]
	var op: Dictionary = f[1 - s]
	var m := GameData.skill_mult(def, lv)
	var nm: String = def["name"]
	match def["k"]:
		"heal":
			var h := minf(float(me["mhp"]) * m, float(me["mhp"]) - float(me["hp"]))
			me["hp"] = float(me["hp"]) + h
			_push(ctx, s, "heal", h, nm)
		"shield":
			me["shield"] = float(me["mhp"]) * m
			_push(ctx, s, "shield", float(me["shield"]), nm)
		_:
			_push(ctx, s, "cast", 0.0, nm)
			var hits := int(def.get("hits", 1))
			var pen := float(def.get("pen", 0.0))
			for i in hits:
				if not (_alive(me) and _alive(op)):
					break
				var dealt := _attack(ctx, s, m, nm, i == hits - 1, pen)
				if dealt > 0.0 and def.has("drain"):
					var h2 := minf(dealt * float(def["drain"]), float(me["mhp"]) - float(me["hp"]))
					if h2 > 0.0:
						me["hp"] = float(me["hp"]) + h2
						_push(ctx, s, "heal", h2, nm)
				if dealt > 0.0 and def.has("stun") and _alive(op):
					var sp := float(def["stun"]) + float(def.get("sl", 0.0)) * (lv - 1) - float(op["res"].get("stun", 0.0))
					if ctx["rng"].randf() < sp:
						op["stunned"] = true
						_push(ctx, s, "stun", 0.0, nm)
				if dealt > 0.0 and def.has("burn") and _alive(op):
					op["burn_t"] = 3
					op["burn_v"] = float(me["atk"]) * (float(def["burn"]) + float(def.get("bl", 0.0)) * (lv - 1))
					_push(ctx, s, "burning", 0.0, nm)


## 一次攻击。can_proc：能否触发击晕与对方反击（连击、反击、多段非末段不触发，避免无限连锁）
## 返回实际造成的伤害（被闪避为 0）
static func _attack(ctx: Dictionary, s: int, mult: float, tag: String, can_proc: bool, pen: float) -> float:
	var f: Array = ctx["f"]
	var rng: RandomNumberGenerator = ctx["rng"]
	var me: Dictionary = f[s]
	var op: Dictionary = f[1 - s]
	if _roll(ctx, op, me, "dodge"):
		_push(ctx, s, "dodge", 0.0, tag)
		return 0.0
	var atk := float(me["atk"])
	var def := float(op["def"]) * (1.0 - pen)
	var d := atk * mult * atk / (atk + def) * rng.randf_range(0.9, 1.1)
	var crit := _roll(ctx, me, op, "crit")
	if crit:
		d *= CRIT_MULT
	var dealt := _take(op, d, false)
	_push(ctx, s, "hit", dealt, ("暴击" if crit else "") + ("·" if crit and tag != "" else "") + tag)
	var steal := _eff(me, op, "steal")
	if steal > 0.0 and dealt > 0.0 and _alive(me):
		var h := minf(dealt * steal, float(me["mhp"]) - float(me["hp"]))
		if h > 0.0:
			me["hp"] = float(me["hp"]) + h
			_push(ctx, s, "heal", h, "吸血")
	if can_proc and _alive(op):
		if _roll(ctx, me, op, "stun"):
			op["stunned"] = true
			_push(ctx, s, "stun", 0.0, "")
		elif _alive(me) and _roll(ctx, op, me, "counter"):
			_attack(ctx, 1 - s, 1.0, "反击", false, 0.0)
	return dealt


## 扣血：护盾先吸收（灼烧无视护盾）。返回实际掉的气血 + 护盾吸收量
static func _take(x: Dictionary, d: float, true_dmg: bool) -> float:
	var left := d
	if not true_dmg and float(x["shield"]) > 0.0:
		var ab := minf(float(x["shield"]), left)
		x["shield"] = float(x["shield"]) - ab
		left -= ab
	x["hp"] = maxf(0.0, float(x["hp"]) - left)
	return d
