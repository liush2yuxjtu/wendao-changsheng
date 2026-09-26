extends Control
## 程序绘制的水墨山水背景：宣纸底色、朱砂日、三层远山、缓慢飘动的云雾。无贴图。

const PAPER := Color("efe6d2")
const INK := Color(0.17, 0.15, 0.13)

var _t := 0.0
var _layers: Array = []
var _mists: Array = []


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(_build)
	_build()


func _build() -> void:
	var w := size.x
	var h := size.y
	if w <= 0.0 or h <= 0.0:
		return
	var noise := FastNoiseLite.new()
	noise.seed = 7
	noise.frequency = 0.0035
	noise.fractal_octaves = 5
	_layers.clear()
	# [山脚高度比例, 墨色浓度, 起伏幅度]
	var specs := [[0.30, 0.07, 170.0], [0.52, 0.11, 210.0], [0.80, 0.17, 260.0]]
	for i in specs.size():
		var sp: Array = specs[i]
		var pts := PackedVector2Array()
		pts.append(Vector2(-10, h + 10))
		var x := -10.0
		while x <= w + 10.0:
			var n := noise.get_noise_2d(x * 0.9 + i * 1300.0, i * 91.0)
			var ridge := 1.0 - absf(noise.get_noise_2d(x * 0.5 + 500.0, i * 33.0))
			var y: float = h * sp[0] - (0.55 * (n * 0.5 + 0.5) + 0.45 * ridge) * sp[2]
			pts.append(Vector2(x, y))
			x += 6.0
		pts.append(Vector2(w + 10, h + 10))
		_layers.append({"pts": pts, "color": Color(INK, sp[1])})
	_mists.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for i in 14:
		_mists.append({
			"x": rng.randf_range(0, w), "y": h * rng.randf_range(0.2, 0.9),
			"rx": rng.randf_range(120, 260), "ry": rng.randf_range(18, 40),
			"v": rng.randf_range(6, 16) * (1 if i % 2 == 0 else -1),
			"a": rng.randf_range(0.25, 0.5), "layer": i % 3,
		})
	queue_redraw()


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	# 朱砂日
	var sun := Vector2(size.x * 0.8, size.y * 0.13)
	draw_circle(sun, 70, Color(0.66, 0.23, 0.16, 0.10))
	draw_circle(sun, 52, Color(0.66, 0.23, 0.16, 0.16))
	for i in _layers.size():
		draw_colored_polygon(_layers[i]["pts"], _layers[i]["color"])
		for m in _mists:
			if m["layer"] == i:
				_draw_mist(m)


func _draw_mist(m: Dictionary) -> void:
	var span: float = size.x + float(m["rx"]) * 2.0
	var x: float = fposmod(m["x"] + m["v"] * _t + m["rx"], span) - m["rx"]
	var y: float = m["y"] + sin(_t * 0.3 + m["x"]) * 6.0
	draw_set_transform(Vector2(x, y), 0.0, Vector2(1.0, m["ry"] / m["rx"]))
	for k in 3:
		draw_circle(Vector2.ZERO, m["rx"] * (1.0 - k * 0.25), Color(PAPER, m["a"] * 0.35))
	draw_set_transform(Vector2.ZERO)
