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
