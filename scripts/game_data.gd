extends RefCounted
## 静态数值与文案表。所有平衡参数集中在这里，改数值只动这个文件。

const REALMS := ["练气", "筑基", "金丹", "元婴", "化神", "炼虚", "合体", "大乘", "渡劫"]
const STAGES := ["初期", "中期", "后期", "圆满"]
const MAX_LEVEL := 35  # 渡劫圆满，再突破即飞升

const ZONES := ["青云山脚", "落霞谷", "万妖林", "幽冥涧", "天火原", "虚空裂隙", "上古战场", "星海", "天劫之巅"]
const MONSTERS := [
	["野狼", "山魈", "赤尾狐"],
	["铁背熊", "青鳞蟒", "游荡阴魂"],
	["火云雕", "血煞尸", "碧眼金蟾"],
	["玄冥蛟", "噬魂蛛", "鬼面修罗"],
	["天妖狐", "雷翼鹏", "堕落魔修"],
	["虚空兽", "万年树妖", "堕仙残魂"],
	["上古凶兽", "魔尊分身", "冥河龙"],
	["混沌兽", "域外天魔", "星空巨鲸"],
	["心魔化身", "雷劫之灵", "太古魔神"],
]
const BOSSES := ["狼王", "千年熊罴", "金丹妖王", "九幽鬼王", "天狐妖尊", "虚空之主", "魔尊", "天魔主宰", "劫灭古神"]

## 寿元（按大境界的基础寿命，单位：年）
const LIFESPAN := [100, 200, 350, 550, 850, 1400, 2200, 3500, 5500]
const START_AGE := 16.0

## 宗门：筑基后可拜入
const SECTS := [
	{"id": "sword", "name": "青云剑宗", "desc": "以剑入道，攻伐无双。\n攻击 +25%，历练灵石 +20%"},
	{"id": "pill", "name": "丹鼎宗", "desc": "丹道圣地，炉火纯青。\n成丹率 +10%，聚气丹效果 +50%"},
	{"id": "mystic", "name": "玄天道宗", "desc": "玄门正统，道法自然。\n修炼速度 +15%，寿元 +10%"},
]
const SECT_RANKS := ["外门弟子", "内门弟子", "真传弟子", "长老", "太上长老"]
const RANK_NEED := [0, 100, 800, 5000, 30000]
const RANK_BONUS := [0.0, 0.05, 0.12, 0.25, 0.4]

## 法宝装备
const SLOTS := ["weapon", "armor", "trinket"]
const SLOT_NAMES := {"weapon": "兵器", "armor": "护甲", "trinket": "饰品"}
const SLOT_EFFECT := {"weapon": "攻击", "armor": "气血", "trinket": "修炼速度"}
const SLOT_BASE := {"weapon": 0.08, "armor": 0.08, "trinket": 0.03}
const ITEM_BASE := {
	"weapon": ["剑", "刀", "枪", "折扇", "古琴"],
	"armor": ["道袍", "法衣", "软甲"],
	"trinket": ["玉佩", "灵戒", "葫芦"],
}
const ITEM_PREFIX := ["青铜", "赤炎", "寒玉", "紫金", "玄冥", "太虚", "混元", "星辰", "鸿蒙"]
const QUALITY := ["凡品", "灵品", "宝品", "仙品"]
const QUALITY_MULT := [1.0, 1.4, 1.9, 2.6]
const QUALITY_COLOR := ["#6b5a48", "#3f7a52", "#3a5a9a", "#a83a2a"]
const QUALITY_WEIGHT := [60, 28, 10, 2]
const QUALITY_WEIGHT_BOSS := [15, 45, 30, 10]

## ---- 战斗（一念逍遥式回合制）----
## 六维战斗属性，各有对应抗性；实际生效 = 己方属性 − 对方抗性
const CSTATS := ["crit", "combo", "counter", "dodge", "stun", "steal"]
const CSTAT_NAMES := {"crit": "暴击", "combo": "连击", "counter": "反击", "dodge": "闪避", "stun": "击晕", "steal": "吸血"}
const CSTAT_BASE := {"crit": 0.05, "combo": 0.03, "counter": 0.03, "dodge": 0.03, "stun": 0.02, "steal": 0.0}
const SECT_CSTAT := {
	"sword": {"crit": 0.05, "combo": 0.05},
	"pill": {"steal": 0.06, "counter": 0.04},
	"mystic": {"dodge": 0.05, "res_stun": 0.05},
}
## 妖物特性：同一地图三种妖物各擅一项
const MONSTER_TRAIT := ["combo", "stun", "dodge", "counter", "steal", "crit"]

## 神通：realm=解锁境界，cd=冷却回合，m/ml=倍率及每级成长
## k: dmg 伤害 / heal 回复（气血低于 75% 才用）/ shield 护盾
const SKILLS := [
	{"id": "sword", "name": "御剑术", "realm": 0, "cd": 3, "k": "dmg", "m": 1.8, "ml": 0.15, "desc": "飞剑斩敌，造成 {m} 攻击伤害"},
	{"id": "heal", "name": "回春诀", "realm": 0, "cd": 4, "k": "heal", "m": 0.18, "ml": 0.03, "desc": "气血低于七成时，回复 {m} 最大气血"},
	{"id": "shield", "name": "金刚护体", "realm": 1, "cd": 5, "k": "shield", "m": 0.25, "ml": 0.04, "desc": "凝出护盾，吸收 {m} 最大气血的伤害"},
	{"id": "thunder", "name": "掌心雷", "realm": 1, "cd": 4, "k": "dmg", "m": 1.5, "ml": 0.12, "stun": 0.35, "sl": 0.03, "desc": "造成 {m} 攻击伤害，{s} 几率击晕"},
	{"id": "fire", "name": "烈焰焚天", "realm": 2, "cd": 5, "k": "dmg", "m": 1.2, "ml": 0.1, "burn": 0.35, "bl": 0.05, "desc": "造成 {m} 攻击伤害，并灼烧 3 回合（每回合 {b} 攻击）"},
	{"id": "absorb", "name": "吸星大法", "realm": 3, "cd": 4, "k": "dmg", "m": 1.6, "ml": 0.12, "drain": 0.5, "desc": "造成 {m} 攻击伤害，并将一半伤害化为己用"},
	{"id": "wanjian", "name": "万剑归宗", "realm": 4, "cd": 6, "k": "dmg", "m": 0.7, "ml": 0.07, "hits": 5, "desc": "万剑齐落，连斩 5 次，每次 {m} 攻击伤害"},
	{"id": "tianlei", "name": "九天神雷", "realm": 6, "cd": 7, "k": "dmg", "m": 3.5, "ml": 0.3, "pen": 0.6, "desc": "引九天神雷，造成 {m} 攻击伤害，无视六成防御"},
]
const SKILL_MAX_LV := 10
## 妖王所用神通（按地图）
const BOSS_SKILL := ["sword", "thunder", "fire", "absorb", "wanjian", "fire", "absorb", "wanjian", "tianlei"]
## 装备神通的格数：练气 1，筑基 2，金丹及以上 3
const SKILL_SLOTS := [1, 2, 3]

const GONGFA := ["引气诀", "青木长生功", "紫霞神功", "太虚剑经", "九转玄功", "大衍天书"]

## 自动奇遇：k = 类型，v = 修为/灵石按「秒产出」倍数计，灵草/丹药按个数
const EVENTS := [
	{"t": "山间偶遇一株百年灵芝，你小心将其采下。", "k": "herb", "v": 3},
	{"t": "你于瀑布下参悟水势，心有所得。", "k": "xp", "v": 30},
	{"t": "路遇两名散修斗法，你捡到了对方遗落的储物袋。", "k": "lingshi", "v": 60},
	{"t": "夜观星象，灵台一片清明。", "k": "xp", "v": 20},
	{"t": "坊市里淘到一枚品相尚可的聚气丹。", "k": "pill_qi", "v": 1},
	{"t": "一只灵猴送来几枚野果，入口灵气四溢。", "k": "herb", "v": 1},
	{"t": "你在旧书摊翻到一页残破功法，略有启发。", "k": "xp", "v": 40},
	{"t": "山中骤雨，你于石洞中静坐一夜。", "k": "xp", "v": 15},
	{"t": "替山下村民驱散了一只作祟的小妖，得了些谢礼。", "k": "lingshi", "v": 30},
	{"t": "被坊市骗子卖了一块假灵石，心中郁闷。", "k": "lingshi", "v": -20},
	{"t": "闭关时心魔滋扰，修为略有损耗。", "k": "xp", "v": -10},
	{"t": "梦中见一白衣人舞剑，醒来若有所悟。", "k": "xp", "v": 50},
]


static func realm_of(level: int) -> int:
	return floori(level / 4.0)


static func realm_name(level: int) -> String:
	return REALMS[realm_of(level)] + STAGES[level % 4]


static func xp_need(level: int) -> float:
	return 50.0 * pow(1.8, level)


static func base_speed(level: int) -> float:
	return 2.0 * pow(1.5, level)


## 大境界突破基础成功率（练气→筑基 75%，逐境递减）
static func major_rate(realm: int) -> float:
	return 0.75 - 0.06 * realm


static func gongfa_name(lv: int) -> String:
	var tier := mini(floori(lv / 5.0), GONGFA.size() - 1)
	var layer := lv - tier * 5 + 1
	return "《%s》第%d重" % [GONGFA[tier], layer]


static func fmt(n: float) -> String:
	var a := absf(n)
	var s := ""
	if a >= 1e12:
		s = "%.2f万亿" % (a / 1e12)
	elif a >= 1e8:
		s = "%.2f亿" % (a / 1e8)
	elif a >= 1e4:
		s = "%.1f万" % (a / 1e4)
	elif a >= 100:
		s = str(int(a))
	else:
		s = "%.1f" % a
	return ("-" if n < 0 else "") + s


static func sect_by_id(id: String) -> Dictionary:
	for s in SECTS:
		if s["id"] == id:
			return s
	return {}


static func rank_of(total: float) -> int:
	var r := 0
	for i in RANK_NEED.size():
		if total >= RANK_NEED[i]:
			r = i
	return r


## 装备加成（小数，0.3 = +30%），不含强化
static func item_bonus(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	return SLOT_BASE[item["slot"]] * (int(item["tier"]) + 1) * QUALITY_MULT[int(item["q"])]


static func item_label(item: Dictionary) -> String:
	if item.is_empty():
		return "（空）"
	return "[color=%s]%s·%s[/color]" % [QUALITY_COLOR[int(item["q"])], QUALITY[int(item["q"])], item["name"]]


# ---------------- 战斗 ----------------
static func skill_def(id: String) -> Dictionary:
	for sk in SKILLS:
		if sk["id"] == id:
			return sk
	return {}


static func skill_mult(sk: Dictionary, lv: int) -> float:
	return float(sk["m"]) + float(sk["ml"]) * (lv - 1)


static func skill_desc(id: String, lv: int) -> String:
	var sk := skill_def(id)
	var d: String = sk["desc"]
	d = d.replace("{m}", "%d%%" % roundi(skill_mult(sk, lv) * 100))
	d = d.replace("{s}", "%d%%" % roundi((float(sk.get("stun", 0.0)) + float(sk.get("sl", 0.0)) * (lv - 1)) * 100))
	d = d.replace("{b}", "%d%%" % roundi((float(sk.get("burn", 0.0)) + float(sk.get("bl", 0.0)) * (lv - 1)) * 100))
	return d + "（冷却 %d 回合）" % int(sk["cd"])


static func skill_learn_cost(id: String) -> float:
	return 100.0 * pow(3.0, int(skill_def(id)["realm"]))


static func skill_up_cost(id: String, lv: int) -> float:
	return skill_learn_cost(id) * 0.5 * pow(1.6, lv)


static func skill_slots(realm: int) -> int:
	return SKILL_SLOTS[mini(realm, SKILL_SLOTS.size() - 1)]


static func cstat_name(key: String) -> String:
	if key.begins_with("res_"):
		return "抗" + CSTAT_NAMES[key.substr(4)]
	return CSTAT_NAMES[key]


## 妖物：r=地图，mlv=等效等级，idx=妖物序号（决定特性），boss=妖王
static func monster(r: int, mlv: float, idx: int, boss: bool, mname: String) -> Dictionary:
	var st := {}
	var res := {}
	for k in CSTATS:
		st[k] = 0.02 + 0.01 * r if k != "steal" else 0.0
		res[k] = 0.01 * r
	st["crit"] = 0.05 + 0.01 * r
	var feat: String = MONSTER_TRAIT[(idx + r) % MONSTER_TRAIT.size()]
	st[feat] = float(st[feat]) + 0.1 + 0.01 * r
	var skills := []
	if boss:
		skills.append({"id": BOSS_SKILL[r], "lv": r + 1})
		for k in CSTATS:
			res[k] = float(res[k]) + 0.03
	return {
		"name": mname, "boss": boss,
		"atk": 9.0 * pow(1.42, mlv), "hp": 95.0 * pow(1.42, mlv),
		"def": 4.0 * pow(1.42, mlv), "spd": 9.0 + 2.0 * mlv,
		"st": st, "res": res, "skills": skills, "trait": feat,
	}


## 镇妖塔第 f 层（从 1 开始）
static func tower_monster(f: int) -> Dictionary:
	var mlv := 0.9 * f
	var r := mini(floori(mlv / 4.0), ZONES.size() - 1)
	var guard := f % 5 == 0
	var names: Array = MONSTERS[r]
	var mname: String = ("镇塔·" + BOSSES[r]) if guard else ("塔中" + names[f % names.size()])
	return monster(r, mlv + (0.5 if guard else 0.0), f, guard, mname)


## 首通灵石 ≈ 同级历练 5 场，镇塔妖王层翻倍
static func tower_reward(f: int) -> float:
	return 125.0 * pow(2.2, 0.9 * f / 4.0) * (2.0 if f % 5 == 0 else 1.0)


## 法宝战斗词条：凡品 1 条 … 仙品 4 条
static func affix_value(tier: int, q: int) -> float:
	return (0.01 + 0.004 * tier) * (1.0 + 0.5 * q)


static func item_score(item: Dictionary) -> float:
	if item.is_empty():
		return 0.0
	var s := item_bonus(item)
	var aff: Dictionary = item.get("aff", {})
	for k in aff:
		s += float(aff[k]) * 0.5
	return s


static func affix_text(item: Dictionary) -> String:
	var aff: Dictionary = item.get("aff", {})
	var parts := []
	for k in aff:
		parts.append("%s+%.1f%%" % [cstat_name(k), float(aff[k]) * 100])
	return " ".join(parts)
