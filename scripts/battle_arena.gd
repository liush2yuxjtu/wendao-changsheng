extends Control
## 俯视斗法台：敌方在上、己方在下；圆形棋子（头像 + 气血环 + 身份框）与神通特效。
## 全部在设计稿的 390×420 坐标里画，再等比缩放居中到控件大小。
## side 0 = 己方（下），side 1 = 敌方（上）。敌方出手的特效沿台面中线上下镜像。

const InkDraw := preload("res://scripts/ink_draw.gd")

const W := 390.0
const H := 420.0
const CENTER := [Vector2(195, 318), Vector2(195, 118)]
const C_INK := Color("2b2520")
const C_LINE := Color("8c6d4f")
const C_PAPER := Color("f7f0e0")
const C_JADE := Color("3f7f86")
const C_GOLD := Color("e0b64a")
const C_GOLD_D := Color("b08a2a")
const C_FIRE := Color("c0602a")
const C_VIOLET := Color("5a54a8")
const C_PURPLE := Color("6a4a8a")
const C_GREEN := Color("3f7a52")
const RING := [Color("6f9a7a"), Color("b0503c")]

const FLAME_OUT := "M0 -22 C8 -10 9 -2 0 6 C-9 -2 -8 -10 0 -22 Z"
const FLAME_IN := "M0 -12 C4 -6 4 -1 0 3 C-4 -1 -4 -6 0 -12 Z"
const PETAL := "M0 -16 C8 -8 8 4 0 11 C-8 4 -8 -8 0 -16 Z"
## 特效持续时间（秒，×1 速度下）
const FX_DUR := {"sword": 0.7, "thunder": 0.6, "fire": 0.9, "absorb": 0.8, "wanjian": 0.9, "tianlei": 0.8, "shield": 0.5, "heal": 0.7, "slash": 0.28, "drain": 0.5}

var who := ["sword", "wolf"]
var rank := "plain"          # 敌方身份框：plain / elite / boss
var hp := [1.0, 1.0]
var mhp := [1.0, 1.0]
var sh := [0.0, 0.0]
var stunned := [false, false]
var burning := [false, false]
var speed := 1.0

var _fx: Array = []           # {kind, side（施放方）, t}
var _off := [Vector2.ZERO, Vector2.ZERO]
var _dodge_t := [1.0, 1.0]
var _dodge_dir := [1.0, 1.0]
var _shake := [0.0, 0.0]
var _time := 0.0


func setup(whos: Array, foe_rank: String, max_hp: Array) -> void:
	who = whos.duplicate()
	rank = foe_rank
	mhp = max_hp.duplicate()
	hp = max_hp.duplicate()
	sh = [0.0, 0.0]
	stunned = [false, false]
	burning = [false, false]
	_fx.clear()
	_shake = [0.0, 0.0]
	_dodge_t = [1.0, 1.0]
	queue_redraw()


func set_hp(h: Array, s: Array) -> void:
	hp = h.duplicate()
	sh = s.duplicate()


func play(kind: String, side: int) -> void:
	_fx.append({"kind": kind, "side": side, "t": 0.0})


func dodge(side: int) -> void:
	_dodge_t[side] = 0.0
	_dodge_dir[side] = -1.0 if randf() < 0.5 else 1.0


func shake(side: int, amp: float) -> void:
	_shake[side] = amp


func clear_fx() -> void:
	_fx.clear()


## 设计稿坐标 → 本控件坐标（给飘字定位用）
func to_local_pt(p: Vector2) -> Vector2:
	return _xf() * p


func token_scale() -> float:
	return _xf().get_scale().x


func _xf() -> Transform2D:
	var s := minf(size.x / W, size.y / H)
	var off := (size - Vector2(W, H) * s) * 0.5
	return Transform2D(0.0, Vector2(s, s), 0.0, off)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_time += delta
	var d := delta * speed
	for f in _fx:
		f["t"] += d / float(FX_DUR.get(f["kind"], 0.6))
	_fx = _fx.filter(func(f): return f["t"] < 1.0)
	for i in 2:
		_dodge_t[i] = minf(1.0, _dodge_t[i] + d / 0.32)
		_off[i] = Vector2(sin(_dodge_t[i] * PI) * 26.0 * _dodge_dir[i], 0.0)
		if _shake[i] > 0.0:
			_off[i] += Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake[i]
			_shake[i] = maxf(0.0, _shake[i] - d * 60.0)
	queue_redraw()


# ======================= 绘制 =======================
func _draw() -> void:
	var xf := _xf()
	draw_set_transform_matrix(xf)
	_draw_floor()
	for side in [1, 0]:
		_draw_token(xf, side)
	for side in 2:
		_draw_status(xf, side)
	for f in _fx:
		var fx_xf := xf if f["side"] == 0 else xf * Transform2D(Vector2(1, 0), Vector2(0, -1), Vector2(0, 436))
		draw_set_transform_matrix(fx_xf)
		_draw_fx(fx_xf, f["kind"], clampf(f["t"], 0.0, 1.0))
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _draw_floor() -> void:
	draw_circle(Vector2(18, 30), 34, Color("8e9a80", 0.35))
	draw_circle(Vector2(52, 14), 22, Color("7d8a74", 0.35))
	draw_circle(Vector2(372, 396), 36, Color("8e9a80", 0.35))
	draw_circle(Vector2(340, 412), 20, Color("7d8a74", 0.35))
	draw_circle(Vector2(376, 44), 18, Color("7d8a74", 0.28))
	draw_colored_polygon(InkDraw.ellipse(Vector2(30, 392), 46, 22), Color("cdbf9f", 0.6))
	var c := Vector2(195, 218)
	draw_circle(c, 186, Color("e8dcc0"))
	draw_arc(c, 186, 0, TAU, 96, C_LINE, 2.0, true)
	for k in 64:   # 虚线圈
		var a := TAU * k / 64.0
		draw_arc(c, 174, a, a + TAU / 64.0 * 0.25, 3, C_LINE, 1.0, true)
	draw_arc(c, 112, 0, TAU, 72, Color("c9b99c"), 1.0, true)
	draw_arc(c, 34, 0, TAU, 32, Color("c9b99c"), 1.0, true)
	for k in 8:
		var dir := Vector2.from_angle(TAU * k / 8.0)
		draw_line(c + dir * 172, c + dir * 186, C_LINE, 2.0, true)
	for e in [[96, 250, 10, 6], [300, 190, 8, 5], [282, 300, 6, 4]]:
		draw_colored_polygon(InkDraw.ellipse(Vector2(e[0], e[1]), e[2], e[3], 16), Color("cdbf9f"))


func _draw_token(xf: Transform2D, side: int) -> void:
	var c: Vector2 = CENTER[side] + _off[side]
	var pct := clampf(hp[side] / maxf(mhp[side], 1.0), 0.0, 1.0)
	# 投影、气血环
	draw_circle(c + Vector2(0, 8), 56, Color(C_INK, 0.14))
	draw_arc(c, 53, 0, TAU, 64, Color(C_INK, 0.16), 6.0, true)
	if pct > 0.0:
		draw_arc(c, 53, -PI / 2, -PI / 2 + TAU * pct, maxi(4, int(64 * pct)), RING[side], 6.0, true)
	# 身份框
	if side == 1 and rank == "boss":
		draw_arc(c, 60.5, 0, TAU, 72, Color("a83a2a"), 3.0, true)
		for k in 4:
			var d := Vector2.from_angle(TAU * k / 4.0) * 62.0
			var q := PackedVector2Array([c + d + Vector2(0, -8), c + d + Vector2(8, 0), c + d + Vector2(0, 8), c + d + Vector2(-8, 0)])
			draw_colored_polygon(q, Color("a83a2a"))
	elif side == 1 and rank == "elite":
		draw_arc(c, 60, 0, TAU, 72, C_GOLD_D, 2.0, true)
		draw_arc(c, 57, 0, TAU, 72, C_GOLD_D, 1.0, true)
	else:
		draw_arc(c, 58, 0, TAU, 72, C_LINE, 2.0, true)
	InkDraw.portrait(self, who[side], xf * Transform2D(0.0, Vector2.ONE, 0.0, c - Vector2(50, 50)), xf)
	draw_arc(c, 50, 0, TAU, 64, C_PAPER, 2.0, true)
	if hp[side] <= 0.0:
		draw_circle(c, 50, Color(C_INK, 0.45))


func _draw_status(xf: Transform2D, side: int) -> void:
	var c: Vector2 = CENTER[side] + _off[side]
	if sh[side] > 0.0:
		var hexp := _hex(c, 70)
		draw_colored_polygon(hexp, Color(C_GOLD, 0.16 + 0.05 * sin(_time * 4.0)))
		var closed := hexp.duplicate()
		closed.append(hexp[0])
		draw_polyline(closed, C_GOLD_D, 2.5, true)
	if stunned[side]:
		var top := c + Vector2(0, -56 if side == 1 else -58)
		_dashed_ellipse(top, 44, 11, C_GOLD_D)
		for k in 3:
			var a := _time * 2.4 + TAU * k / 3.0
			_star(top + Vector2(cos(a) * 44, sin(a) * 11), 7.0)
	if burning[side]:
		for k in 5:
			var a := TAU * k / 5.0 + _time * 0.8
			var p := c + Vector2.from_angle(a) * 60.0
			var s := 0.55 + 0.12 * sin(_time * 9.0 + k)
			_flame(xf, p, a + PI / 2, s)
		draw_set_transform_matrix(xf)


# ======================= 神通特效（施放方在下 P，目标在上 E） =======================
func _draw_fx(xf: Transform2D, kind: String, t: float) -> void:
	var P: Vector2 = CENTER[0]
	var E: Vector2 = CENTER[1]
	match kind:
		"slash":   # 普攻：一道墨色斩痕
			var a := Vector2(160, 88)
			var b := Vector2(232, 142)
			var k := minf(1.0, t * 2.0)
			var alpha := 1.0 - maxf(0.0, t - 0.5) * 2.0
			draw_line(a, a.lerp(b, k), Color(C_PAPER, alpha), 6.0, true)
			draw_line(a, a.lerp(b, k), Color(C_INK, alpha), 1.8, true)
		"sword":
			var paths := [
				[Vector2(195, 290), Vector2(148, 250), Vector2(150, 190), Vector2(182, 158)],
				[Vector2(195, 290), Vector2(242, 250), Vector2(240, 190), Vector2(208, 158)],
				[Vector2(195, 290), Vector2(195, 250), Vector2(195, 215), Vector2(195, 170)],
			]
			var fly := minf(1.0, t / 0.7)
			for pth in paths:
				var trail := PackedVector2Array()
				for s in 9:
					var u := maxf(0.0, fly - 0.35) + (fly - maxf(0.0, fly - 0.35)) * s / 8.0
					trail.append(InkDraw.cubic(pth[0], pth[1], pth[2], pth[3], u))
				draw_polyline(trail, Color(C_JADE, 0.45), 2.0, true)
				var pos := InkDraw.cubic(pth[0], pth[1], pth[2], pth[3], fly)
				var ahead := InkDraw.cubic(pth[0], pth[1], pth[2], pth[3], minf(1.0, fly + 0.02))
				var dir := (ahead - pos) if ahead != pos else (E - pos)
				_sword(xf, pos, atan2(dir.x, -dir.y), 1.0)
			if t > 0.65:
				var al := 1.0 - (t - 0.65) / 0.35
				for ln in [[Vector2(150, 88), Vector2(240, 150)], [Vector2(240, 90), Vector2(158, 146)]]:
					draw_line(ln[0], ln[1], Color("eef7f5", al), 6.0, true)
					draw_line(ln[0], ln[1], Color(C_JADE, al), 1.5, true)
		"thunder":
			draw_circle(Vector2(195, 262), 16.0 * minf(1.0, t * 4.0), Color("d9d6ff", 0.7))
			if t > 0.12 and sin(t * 60.0) > -0.4:
				var bolt := InkDraw.pts("195,262 181,238 205,222 185,200 207,188 195,176")
				var br := InkDraw.pts("185,200 170,192 175,182")
				draw_polyline(bolt, Color("b9b4ee", 0.55), 12.0, true)
				draw_polyline(br, Color("b9b4ee", 0.5), 6.0, true)
				draw_polyline(bolt, Color("fffbe8"), 3.5, true)
				draw_polyline(br, Color("fffbe8"), 2.0, true)
				draw_polyline(bolt, C_VIOLET, 1.0, true)
				draw_circle(Vector2(195, 176), 10, Color("fffbe8", 0.9))
		"fire":
			if t < 0.45:
				var u := t / 0.45
				var pos := InkDraw.cubic(Vector2(195, 290), Vector2(208, 250), Vector2(182, 222), Vector2(195, 188), u)
				draw_circle(pos, 12, Color(C_GOLD, 0.55))
				draw_circle(pos, 7, C_FIRE)
			else:
				var u := minf(1.0, (t - 0.4) / 0.3)
				var fade := 1.0 - maxf(0.0, t - 0.8) / 0.2
				draw_arc(E, 62, 0, TAU, 64, Color(C_FIRE, 0.16 * fade), 12.0, true)
				for k in 10:
					var a := TAU * k / 10.0
					_flame(xf, E + Vector2(sin(a), -cos(a)) * 62.0 * u, a, u * fade)
				draw_set_transform_matrix(xf)
		"absorb":
			_dashed_ring(E, 60, C_PURPLE)
			draw_circle(P, 66, Color("d8c8e6", 0.35))
			var streams := [
				[Vector2(195, 176), Vector2(250, 205), Vector2(140, 238), Vector2(195, 262)],
				[Vector2(205, 176), Vector2(150, 208), Vector2(256, 232), Vector2(188, 262)],
			]
			for k in streams.size():
				var s: Array = streams[k]
				for j in 8:
					var u := fmod(j / 8.0 + t * 1.5, 1.0)
					draw_circle(InkDraw.cubic(s[0], s[1], s[2], s[3], u), 2.2 if k == 0 else 1.7, C_PURPLE if k == 0 else Color("9b7ab8"))
			var rot := t * TAU
			draw_arc(P, 66, -PI / 2 + rot, rot, 20, C_PURPLE, 2.5, true)
			draw_arc(P, 66, PI / 2 + rot, PI + rot, 20, C_PURPLE, 2.5, true)
		"wanjian":
			draw_circle(E, 50, Color("bfe0dc", 0.25))
			for i in 5:
				var a := deg_to_rad(-60.0 + 30.0 * i)
				var p := clampf((t - i * 0.09) / 0.45, 0.0, 1.0)
				if p <= 0.0:
					continue
				var dir := Vector2(sin(a), -cos(a))
				var r := lerpf(190.0, 40.0, p)
				var pos := E + dir * r
				draw_line(pos + dir * 16, pos + dir * 46, Color(C_JADE, 0.5), 1.5, true)
				_sword(xf, pos, a + PI, 1.0 - maxf(0.0, t - 0.85) / 0.15)
			if t > 0.55:
				var al := 1.0 - (t - 0.55) / 0.45
				draw_line(Vector2(160, 104), Vector2(230, 132), Color(C_JADE, al), 1.5, true)
				draw_line(Vector2(230, 104), Vector2(160, 132), Color(C_JADE, al), 1.5, true)
		"tianlei":
			var fade := 1.0 - maxf(0.0, t - 0.7) / 0.3
			if t > 0.15:
				for crack in ["195,118 150,95 126,102", "195,118 242,78 266,82", "195,118 250,152 270,178", "195,118 138,152 114,160", "195,118 190,58 170,36"]:
					draw_polyline(InkDraw.pts(crack), Color(C_INK, 0.45 * fade), 1.5, true)
			draw_arc(E, lerpf(40, 98, t), 0, TAU, 64, Color(C_GOLD, 0.4 * fade), 1.5, true)
			draw_arc(E, lerpf(30, 74, t), 0, TAU, 64, Color(C_GOLD, 0.65 * fade), 3.0, true)
			draw_circle(E, 52, Color(C_GOLD, 0.3 * fade))
			draw_circle(E, 30, Color("fffbe8", 0.85 * fade))
			var star := InkDraw.pts("195,70 203,86 219,82 211,98 227,106 211,114 219,130 203,126 195,142 187,126 171,130 179,114 163,106 179,98 171,82 187,86 195,70")
			draw_polyline(star, Color(C_GOLD_D, fade), 1.5, true)
		"shield":
			var hexp := _hex(P, 70.0 * (0.6 + 0.4 * t))
			draw_colored_polygon(hexp, Color(C_GOLD, 0.25 * (1.0 - t)))
			var closed := hexp.duplicate()
			closed.append(hexp[0])
			draw_polyline(closed, Color(C_GOLD_D, 1.0 - t * 0.5), 3.0, true)
		"heal":
			var s := sin(t * PI)
			draw_circle(P, 74, Color("9dbba3", 0.22 * s))
			for k in 8:
				var a := TAU * k / 8.0
				var pos := P + Vector2(sin(a), -cos(a)) * 66.0
				draw_set_transform_matrix(xf * Transform2D(a, Vector2(s, s), 0.0, pos))
				InkDraw.fill_path(self, PETAL, Color("b9d3bd"))
				InkDraw.stroke_path(self, PETAL, C_GREEN, 1.5)
			draw_set_transform_matrix(xf)
			for m in [[160, 240], [232, 232], [214, 244]]:
				draw_circle(Vector2(m[0], m[1] - 30.0 * t), 2.5, Color(C_GREEN, 0.7 * s))
		"drain":   # 吸血：小号绿光
			draw_circle(P, 58, Color("9dbba3", 0.25 * sin(t * PI)))


# ---------------- 小部件 ----------------
func _sword(xf: Transform2D, pos: Vector2, ang: float, a: float) -> void:
	draw_set_transform_matrix(xf * Transform2D(ang, pos))
	draw_colored_polygon(InkDraw.ellipse(Vector2(0, -4), 10, 30, 20), Color("bfe0dc", 0.45 * a))
	var blade := InkDraw.pts("0,-26 3.5,-4 0,12 -3.5,-4")
	draw_colored_polygon(blade, Color("eef7f5", a))
	var closed := blade.duplicate()
	closed.append(blade[0])
	draw_polyline(closed, Color(C_JADE, a), 1.5, true)
	draw_line(Vector2(-7, 8), Vector2(7, 8), Color(C_JADE, a), 2.5, true)
	draw_line(Vector2(0, 8), Vector2(0, 18), Color(C_INK, a), 2.5, true)
	draw_set_transform_matrix(xf)


func _flame(xf: Transform2D, pos: Vector2, ang: float, s: float) -> void:
	if s <= 0.01:
		return
	draw_set_transform_matrix(xf * Transform2D(ang, Vector2(s, s), 0.0, pos))
	InkDraw.fill_path(self, FLAME_OUT, C_FIRE)
	InkDraw.fill_path(self, FLAME_IN, C_GOLD)


func _star(p: Vector2, r: float) -> void:
	var q := r * 0.3
	var poly := PackedVector2Array([p + Vector2(0, -r), p + Vector2(q, -q), p + Vector2(r, 0), p + Vector2(q, q), p + Vector2(0, r), p + Vector2(-q, q), p + Vector2(-r, 0), p + Vector2(-q, -q)])
	draw_colored_polygon(poly, C_GOLD)


func _hex(c: Vector2, r: float) -> PackedVector2Array:
	var p := PackedVector2Array()
	for k in 6:
		p.append(c + Vector2.from_angle(-PI / 2 + TAU * k / 6.0) * r)
	return p


func _dashed_ellipse(c: Vector2, rx: float, ry: float, col: Color) -> void:
	var e := InkDraw.ellipse(c, rx, ry, 36)
	for k in range(0, e.size(), 2):
		draw_line(e[k], e[(k + 1) % e.size()], col, 1.2, true)


func _dashed_ring(c: Vector2, r: float, col: Color) -> void:
	for k in 40:
		var a := TAU * k / 40.0
		draw_arc(c, r, a, a + TAU / 40.0 * 0.3, 3, Color(col, 0.7), 1.5, true)
