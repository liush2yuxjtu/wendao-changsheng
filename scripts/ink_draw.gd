extends RefCounted
## 程序绘制工具：SVG 路径子集解析、头像、神通图标。
## 坐标直接照搬设计稿（Design 画布「问道长生 · 俯视角对战」），头像在 100×100 空间，图标在 24×24 空间。

static var _portrait_cache := {}
static var _path_cache := {}
static var _re: RegEx


# ---------------- 路径 ----------------
## 解析 M/L/C/Q/Z（绝对坐标）→ [{pts: PackedVector2Array, closed: bool}]
static func path(d: String) -> Array:
	if _path_cache.has(d):
		return _path_cache[d]
	if _re == null:
		_re = RegEx.new()
		_re.compile("[MLCQZ]|-?[0-9]*\\.?[0-9]+")
	var toks := []
	for m in _re.search_all(d):
		var s := m.get_string()
		toks.append(s if s in ["M", "L", "C", "Q", "Z"] else float(s))
	var out := []
	var cur := PackedVector2Array()
	var pos := Vector2.ZERO
	var start := Vector2.ZERO
	var cmd := ""
	var i := 0
	while i < toks.size():
		if toks[i] is String:
			cmd = toks[i]
			i += 1
			if cmd == "Z":
				if cur.size() > 1:
					if cur[cur.size() - 1].distance_to(cur[0]) < 0.01:
						cur.remove_at(cur.size() - 1)
					out.append({"pts": cur, "closed": true})
				cur = PackedVector2Array()
				pos = start
				continue
		match cmd:
			"M":
				if cur.size() > 1:
					out.append({"pts": cur, "closed": false})
				pos = Vector2(toks[i], toks[i + 1])
				i += 2
				start = pos
				cur = PackedVector2Array([pos])
				cmd = "L"
			"L":
				pos = Vector2(toks[i], toks[i + 1])
				i += 2
				cur.append(pos)
			"C":
				var c1 := Vector2(toks[i], toks[i + 1])
				var c2 := Vector2(toks[i + 2], toks[i + 3])
				var c3 := Vector2(toks[i + 4], toks[i + 5])
				i += 6
				for k in range(1, 13):
					cur.append(cubic(pos, c1, c2, c3, k / 12.0))
				pos = c3
			"Q":
				var q1 := Vector2(toks[i], toks[i + 1])
				var q2 := Vector2(toks[i + 2], toks[i + 3])
				i += 4
				for k in range(1, 9):
					var t := k / 8.0
					cur.append(pos.lerp(q1, t).lerp(q1.lerp(q2, t), t))
				pos = q2
			_:
				i += 1
	if cur.size() > 1:
		out.append({"pts": cur, "closed": false})
	_path_cache[d] = out
	return out


static func cubic(p0: Vector2, p1: Vector2, p2: Vector2, p3: Vector2, t: float) -> Vector2:
	var u := 1.0 - t
	return p0 * u * u * u + p1 * 3.0 * u * u * t + p2 * 3.0 * u * t * t + p3 * t * t * t


static func ellipse(c: Vector2, rx: float, ry: float, n := 28) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in n:
		var a := TAU * k / n
		p.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return p


static func pts(s: String) -> PackedVector2Array:
	var p := PackedVector2Array()
	for pair in s.split(" ", false):
		var xy := pair.split(",")
		p.append(Vector2(float(xy[0]), float(xy[1])))
	return p


## 在 ci 上填充一条路径（闭合子路径逐个填充）
static func fill_path(ci: CanvasItem, d: String, color: Color) -> void:
	for sp in path(d):
		if sp["pts"].size() >= 3:
			ci.draw_colored_polygon(sp["pts"], color)


static func stroke_path(ci: CanvasItem, d: String, color: Color, w: float) -> void:
	for sp in path(d):
		var p: PackedVector2Array = sp["pts"]
		if sp["closed"]:
			p = p.duplicate()
			p.append(p[0])
		ci.draw_polyline(p, color, w, true)


# ---------------- 头像 ----------------
const PLAYER_WHO := ["sword", "pill", "mystic"]
const ACCENT := {"sword": "3f6f78", "pill": "a0522d", "mystic": "5b4a7a"}
const BG := {"sword": "e6dcc6", "pill": "eadbc4", "mystic": "e2dbe0", "wolf": "ddd0b6", "fox": "e8d9c2", "ghost": "d8cfd6"}


## 敌人头像归类：狐类 / 鬼魔人形 / 其余按兽类
static func foe_who(mname: String) -> String:
	if "狐" in mname:
		return "fox"
	if "狼" in mname or "熊" in mname:
		return "wolf"
	for k in ["魂", "魔", "尸", "鬼", "修罗", "仙", "尊", "主", "神", "灵", "身", "王"]:
		if k in mname:
			return "ghost"
	return "wolf"


## 头像的绘制指令：[{fill|line, color, w}]，填充部分已裁剪到 r=50 圆内
static func portrait_ops(who: String) -> Array:
	if _portrait_cache.has(who):
		return _portrait_cache[who]
	var raw := []   # [type, geometry, color, width]
	var ink := Color("2b2520")
	match who:
		"wolf":
			raw = [
				["path", "M18 100 L28 74 L37 88 L44 78 L50 92 L56 78 L63 88 L72 74 L82 100 Z", Color("4a3f36")],
				["poly", "22,18 42,40 30,48", Color("4a3f36")],
				["poly", "78,18 58,40 70,48", Color("4a3f36")],
				["path", "M27 40 C30 29 70 29 73 40 L70 60 L58 80 L50 88 L42 80 L30 60 Z", Color("6b5a48")],
				["path", "M50 34 L45 50 L55 50 Z", Color("4a3f36")],
				["path", "M39 62 L50 88 L61 62 C56 57 44 57 39 62 Z", Color("b8a78c")],
				["ellipse", [50, 80, 5, 3.5], ink],
				["poly", "35,49 45,52 36,56", Color("e0b64a")],
				["poly", "65,49 55,52 64,56", Color("e0b64a")],
			]
		"fox":
			raw = [
				["path", "M22 100 C28 84 40 79 50 79 C60 79 72 84 78 100 Z", Color("8a3b2c")],
				["poly", "26,14 43,40 30,46", Color("8a3b2c")],
				["poly", "74,14 57,40 70,46", Color("8a3b2c")],
				["path", "M29 40 C34 31 66 31 71 40 L66 58 L54 80 L50 84 L46 80 L34 58 Z", Color("b0503c")],
				["path", "M33 55 L46 80 L50 84 L50 66 C44 64 38 60 33 55 Z", Color("f3e9d6")],
				["path", "M67 55 L54 80 L50 84 L50 66 C56 64 62 60 67 55 Z", Color("f3e9d6")],
				["ellipse", [50, 82, 3.5, 2.5], ink],
				["stroke", "M37 50 Q41 46 46 51 M63 50 Q59 46 54 51", ink, 2.0],
			]
		"ghost":
			raw = [
				["path", "M12 100 L20 72 C30 63 70 63 80 72 L88 100 L79 92 L70 100 L61 92 L50 100 L39 92 L30 100 L21 92 Z", ink],
				["path", "M25 66 C22 34 78 34 75 66 C66 59 34 59 25 66 Z", Color("3a2f28")],
				["ellipse", [50, 56, 15, 17], Color("cfc9bd")],
				["path", "M30 42 L34 19 L42 32 L50 10 L58 32 L66 19 L70 42 Z", Color("a83a2a")],
				["stroke", "M30 42 L34 19 L42 32 L50 10 L58 32 L66 19 L70 42 Z", ink, 1.5],
				["ellipse", [50, 45, 2.2, 2.2], Color("a83a2a")],
				["poly", "37,52 47,55 38,58", Color("a83a2a")],
				["poly", "63,52 53,55 62,58", Color("a83a2a")],
				["stroke", "M43 65 L46 67 L50 65 L54 67 L57 65", ink, 1.5],
			]
		_:
			var acc := Color(ACCENT.get(who, "3f6f78"))
			if who == "sword":
				raw.append(["line", [68, 72, 86, 26], Color("8c6d4f"), 3.5])
				raw.append(["line", [72, 50, 85, 55], Color("8c6d4f"), 3.0])
			if who == "mystic":
				raw.append(["line", [24, 80, 30, 52], Color("8c6d4f"), 3.0])
				raw.append(["stroke", "M30 52 C27 42 21 36 15 32 M30 52 C30 42 29 34 26 26 M30 52 C33 43 35 37 37 30", Color("6b5a48"), 1.6])
			raw += [
				["path", "M16 100 C20 78 34 69 50 69 C66 69 80 78 84 100 Z", ink],
				["stroke", "M40 70 L50 86 L60 70", acc, 3.0],
				["path", "M45 57 L55 57 L55 70 L45 70 Z", Color("e2cfae")],
				["ellipse", [50, 46, 14, 16], Color("f0e2c6")],
				["ellipse_line", [50, 46, 14, 16], ink, 1.5],
				["path", "M35 47 C34 29 66 29 65 47 C62 38 56 35 50 35 C44 35 38 38 35 47 Z", ink],
				["ellipse", [50, 26, 7, 7], ink],
				["line", [37, 28, 63, 23], acc, 2.5],
				["stroke", "M42 48 Q45 46 48 48 M52 48 Q55 46 58 48", ink, 1.6],
				["stroke", "M47 55 Q50 56.5 53 55", Color("6b5a48"), 1.4],
			]
			if who == "pill":
				raw += [
					["ellipse", [80, 62, 6, 6], Color("a0522d")],
					["ellipse", [80, 74, 9, 9], Color("a0522d")],
					["line", [74, 67, 86, 67], Color("e0b64a"), 1.6],
				]
	var clip := ellipse(Vector2(50, 50), 50, 50, 48)
	var ops := [{"fill": clip, "color": Color(BG.get(who, "e6dcc6"))}]
	for r in raw:
		var polys := []
		match r[0]:
			"path":
				for sp in path(r[1]):
					if sp["pts"].size() >= 3:
						polys.append(sp["pts"])
			"poly":
				polys.append(pts(r[1]))
			"ellipse":
				polys.append(ellipse(Vector2(r[1][0], r[1][1]), r[1][2], r[1][3]))
			"ellipse_line":
				var e := ellipse(Vector2(r[1][0], r[1][1]), r[1][2], r[1][3])
				e.append(e[0])
				ops.append({"line": e, "color": r[2], "w": r[3]})
			"line":
				ops.append({"line": PackedVector2Array([Vector2(r[1][0], r[1][1]), Vector2(r[1][2], r[1][3])]), "color": r[2], "w": r[3]})
			"stroke":
				for sp in path(r[1]):
					var p: PackedVector2Array = sp["pts"]
					if sp["closed"]:
						p = p.duplicate()
						p.append(p[0])
					ops.append({"line": p, "color": r[2], "w": r[3]})
		for p in polys:
			for c in Geometry2D.intersect_polygons(p, clip):
				if c.size() >= 3:
					ops.append({"fill": c, "color": r[2]})
	_portrait_cache[who] = ops
	return ops


## 以 xf（100×100 空间 → 画布）绘制头像；调用后变换复位为 back
static func portrait(ci: CanvasItem, who: String, xf: Transform2D, back := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(xf)
	for op in portrait_ops(who):
		if op.has("fill"):
			ci.draw_colored_polygon(op["fill"], op["color"])
		else:
			ci.draw_polyline(op["line"], op["color"], op["w"], true)
	ci.draw_set_transform_matrix(back)


# ---------------- 神通图标（24×24，描边） ----------------
static func skill_glyph(ci: CanvasItem, id: String, xf: Transform2D, col: Color, back := Transform2D.IDENTITY) -> void:
	ci.draw_set_transform_matrix(xf)
	var w := 1.8
	match id:
		"sword":
			ci.draw_line(Vector2(5, 19), Vector2(18, 6), col, w, true)
			ci.draw_line(Vector2(7, 13), Vector2(11, 17), col, w, true)
		"heal":
			stroke_path(ci, "M12 20 C6 16 5 10 12 4 C19 10 18 16 12 20 Z M12 20 L12 10", col, w)
		"shield":
			var h := pts("12,3 20,7.5 20,16.5 12,21 4,16.5 4,7.5 12,3")
			ci.draw_polyline(h, col, w, true)
		"thunder":
			ci.draw_polyline(pts("13,2 6,13 11,13 9,22 18,10 13,10 15,2"), col, w, true)
		"fire":
			stroke_path(ci, "M12 21 C6 19 5 13 9 9 C9 12 11 13 12 13 C11 9 13 5 16 3 C16 8 20 11 19 15 C18 19 15 21 12 21 Z", col, w)
		"absorb":
			stroke_path(ci, "M12 12 C12 10 15 10 15 12 C15 15 9 15 9 12 C9 8 18 8 18 12 C18 18 6 18 6 12 C6 6 12 4 17 5", col, w)
		"wanjian":
			for k in 3:
				var dx := k * 5.0
				ci.draw_line(Vector2(3 + dx, 20), Vector2(11 + dx, 4), col, w, true)
		"tianlei":
			ci.draw_arc(Vector2(12, 12), 9.5, 0, TAU, 24, col, w * 0.7, true)
			ci.draw_polyline(pts("13,4 8,13 12,13 10,20 16,10 12,10 14,4"), col, w, true)
		_:
			ci.draw_arc(Vector2(12, 12), 3, 0, TAU, 12, col, w, true)
	ci.draw_set_transform_matrix(back)
