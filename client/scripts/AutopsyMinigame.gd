extends Control
## Minigames de extração da autópsia: um diferente para cada tipo de órgão.
## Cada um mede os erros do jogador e emite `finished(quality)` com a Qualidade de 0 a 100.
##
##   1  Pele / Pelos / Teias / Seda .. ESFOLAR: siga a linha tracejada segurando o botão do mouse
##   2  Presas / Garras .............. ARRANCAR: puxe 3 vezes quando a tensão estiver na faixa verde
##   3/11 Glândula / Bolsa de Veneno . MÃO FIRME: mantenha o cursor dentro do círculo que se move
##   4  Sangue ....................... DRENAR: segure para encher o frasco e solte na marca
##   6  Coração ...................... PULSO: clique no ritmo das batidas
##   8  Intestinos & Tendões ......... DESENROLAR: clique nos nós em ordem antes do tempo acabar
##   9  Pulmões ...................... INFLAR: segure/solte para manter a pressão na faixa verde
##   10 Olhos ........................ ENUCLEAR: um único clique preciso no alvo que treme

signal finished(quality: int)

const MODE_NONE := 0
const MODE_SKIN := 1
const MODE_FANGS := 2
const MODE_VENOM := 3
const MODE_BLOOD := 4
const MODE_HEART := 6
const MODE_GUTS := 8
const MODE_LUNGS := 9
const MODE_EYES := 10

const COL_BG := Color(0.05, 0.03, 0.04, 1.0)
const COL_FLESH := Color(0.45, 0.12, 0.14)
const COL_GOOD := Color("#00e676")
const COL_WARN := Color("#ffb300")
const COL_BAD := Color("#ef5350")

var mode: int = MODE_NONE
var difficulty: int = 3
var running: bool = false
var t: float = 0.0
var time_limit: float = 10.0
var errors: float = 0.0 # acumulador de erros (cada minigame define a escala)
var hint: String = ""
var mouse_down: bool = false
var cursor: Vector2 = Vector2.ZERO

# Estado específico de cada minigame
var path_points: PackedVector2Array = PackedVector2Array()
var trace_progress: float = 0.0 # 0..1 ao longo da linha
var trace_off_time: float = 0.0
var trace_on_time: float = 0.0
var fill_level: float = 0.0
var fill_target: float = 0.78
var beat_times: Array = []
var beat_hits: Array = []
var beat_index: int = 0
var knots: Array = [] # Vector2
var next_knot: int = 0
var pressure: float = 0.4
var band_time: float = 0.0
var target_pos: Vector2 = Vector2.ZERO
var circle_pos: Vector2 = Vector2.ZERO
var circle_vel: Vector2 = Vector2.ZERO
var outside_time: float = 0.0
var pulls: int = 0
var pull_scores: Array = []
var tension: float = 0.0

func _ready() -> void:
	custom_minimum_size = Vector2(460, 240)
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true

## Começa o minigame do tipo de órgão. Retorna false se o tipo usa a barra clássica (pêndulo).
func start(organ_type: int, p_difficulty: int) -> bool:
	difficulty = clampi(p_difficulty, 1, 10)
	t = 0.0
	errors = 0.0
	mouse_down = false
	var w: float = max(size.x, custom_minimum_size.x)
	var h: float = max(size.y, custom_minimum_size.y)
	match organ_type:
		1:
			mode = MODE_SKIN
			time_limit = 14.0 - difficulty * 0.4
			hint = "ESFOLAR: segure o botão no círculo verde e siga a linha até o fim, sem sair dela."
			path_points = PackedVector2Array()
			var amp: float = 30.0 + difficulty * 4.0
			var freq: float = 1.5 + difficulty * 0.18
			for i in range(61):
				var x: float = lerpf(30.0, w - 30.0, float(i) / 60.0)
				path_points.append(Vector2(x, h * 0.52 + sin(float(i) / 60.0 * TAU * freq) * amp))
			trace_progress = 0.0
			trace_off_time = 0.0
			trace_on_time = 0.0
		2:
			mode = MODE_FANGS
			time_limit = 12.0
			hint = "ARRANCAR: clique 3 vezes quando a agulha de tensão estiver na faixa verde."
			pulls = 0
			pull_scores = []
			tension = 0.0
		3, 11:
			mode = MODE_VENOM
			time_limit = 4.0 + difficulty * 0.2
			hint = "MÃO FIRME: segure o cursor dentro do círculo até a bolsa se soltar. Sair rompe a bolsa!"
			circle_pos = Vector2(w * 0.5, h * 0.55)
			circle_vel = Vector2(60, 40) * (0.6 + difficulty * 0.12)
			outside_time = 0.0
			trace_on_time = 0.0
		4:
			mode = MODE_BLOOD
			time_limit = 12.0
			hint = "DRENAR: segure o botão para encher o frasco e solte bem na marca dourada."
			fill_level = 0.0
			fill_target = randf_range(0.62, 0.86)
		6:
			mode = MODE_HEART
			time_limit = 7.0
			hint = "PULSO: clique quando o anel encostar no coração — 4 batidas."
			beat_times = []
			var period: float = 1.05 - difficulty * 0.03
			for i in range(4):
				beat_times.append(1.2 + i * period)
			beat_hits = []
			beat_index = 0
		8:
			mode = MODE_GUTS
			time_limit = 9.0 - difficulty * 0.35
			hint = "DESENROLAR: clique nos nós em ordem (1, 2, 3...) antes do tempo acabar."
			knots = []
			var count: int = 5 + int(difficulty / 3.0)
			var tries := 0
			while knots.size() < count and tries < 400:
				tries += 1
				var p := Vector2(randf_range(40, w - 40), randf_range(50, h - 30))
				var ok := true
				for k in knots:
					if p.distance_to(k) < 60.0:
						ok = false
				if ok:
					knots.append(p)
			next_knot = 0
		9:
			mode = MODE_LUNGS
			time_limit = 9.0
			hint = "INFLAR: segure para encher, solte para esvaziar — mantenha a pressão na faixa verde por 3s."
			pressure = 0.3
			band_time = 0.0
		10:
			mode = MODE_EYES
			time_limit = 6.0
			hint = "ENUCLEAR: um único clique, o mais perto possível do centro do olho que treme."
			target_pos = Vector2(w * 0.5, h * 0.55)
		_:
			mode = MODE_NONE
			running = false
			queue_redraw()
			return false
	running = true
	queue_redraw()
	return true

func stop() -> void:
	running = false
	mode = MODE_NONE
	queue_redraw()

func _finish(quality: float) -> void:
	if not running:
		return
	running = false
	finished.emit(clampi(int(round(quality)), 0, 100))
	queue_redraw()

func _process(delta: float) -> void:
	if not running:
		return
	t += delta
	var w: float = size.x
	var h: float = size.y
	match mode:
		MODE_SKIN:
			if mouse_down and trace_progress > 0.0:
				var d: float = _distance_to_path(cursor)
				if d > 13.0:
					trace_off_time += delta
				else:
					trace_on_time += delta
				# avança só no sentido da linha
				var px: float = clampf((cursor.x - path_points[0].x) / (path_points[path_points.size() - 1].x - path_points[0].x), 0.0, 1.0)
				if px > trace_progress and d < 40.0:
					trace_progress = px
				if trace_progress >= 0.985:
					var off_ratio: float = trace_off_time / max(0.01, trace_on_time + trace_off_time)
					_finish(100.0 - off_ratio * 160.0)
		MODE_FANGS:
			tension = 0.5 + 0.5 * sin(t * (2.6 + difficulty * 0.25))
		MODE_VENOM:
			circle_pos += circle_vel * delta
			if circle_pos.x < 50 or circle_pos.x > w - 50:
				circle_vel.x = -circle_vel.x
			if circle_pos.y < 60 or circle_pos.y > h - 40:
				circle_vel.y = -circle_vel.y
			circle_vel = circle_vel.rotated(randf_range(-0.6, 0.6) * delta)
			if t > 1.2 and cursor.distance_to(circle_pos) > _venom_radius(): # 1,2s para posicionar a mão
				outside_time += delta
				if outside_time > 0.8:
					_finish(0.0) # bolsa rompida
			else:
				trace_on_time += delta
		MODE_BLOOD:
			if mouse_down:
				fill_level += delta * (0.22 + fill_level * 0.35 + difficulty * 0.01)
				if fill_level >= 1.0:
					_finish(5.0) # transbordou: sangue derramado
		MODE_HEART:
			if beat_index < beat_times.size() and t > beat_times[beat_index] + 0.35:
				beat_hits.append(0.0) # batida perdida
				beat_index += 1
			if beat_index >= beat_times.size():
				_finish(_avg(beat_hits) * 100.0)
		MODE_LUNGS:
			pressure += (0.55 if mouse_down else -0.45) * delta
			pressure = clampf(pressure, 0.0, 1.0)
			if pressure > 0.55 and pressure < 0.78:
				band_time += delta
			else:
				errors += delta
			if pressure >= 1.0:
				_finish(10.0) # pulmão estourou
			elif band_time >= 3.0:
				_finish(100.0 - errors * 22.0)
		MODE_EYES:
			var jitter: float = 18.0 + difficulty * 4.0
			target_pos = Vector2(w * 0.5, h * 0.55) + Vector2(sin(t * 3.1) * jitter, cos(t * 4.3) * jitter * 0.7)
	if t >= time_limit and running:
		_on_timeout()
	queue_redraw()

func _on_timeout() -> void:
	match mode:
		MODE_SKIN:
			var off_ratio: float = trace_off_time / max(0.01, trace_on_time + trace_off_time)
			_finish(trace_progress * 100.0 - off_ratio * 160.0 - 25.0)
		MODE_FANGS:
			_finish(_avg(pull_scores) * 100.0 * float(pulls) / 3.0)
		MODE_VENOM:
			_finish(100.0 - outside_time * 90.0) # sobreviveu: a bolsa se soltou
		MODE_BLOOD:
			_finish(0.0)
		MODE_GUTS:
			_finish(float(next_knot) / max(1, knots.size()) * 70.0 - errors)
		MODE_LUNGS:
			_finish(band_time / 3.0 * 80.0 - errors * 10.0)
		MODE_EYES:
			_finish(0.0)
		_:
			_finish(0.0)

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		cursor = event.position
	if not running:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		cursor = event.position
		mouse_down = event.pressed
		if event.pressed:
			_on_click(event.position)
		else:
			_on_release()
		accept_event()

func _on_click(pos: Vector2) -> void:
	match mode:
		MODE_SKIN:
			if trace_progress <= 0.0 and pos.distance_to(path_points[0]) < 22.0:
				trace_progress = 0.001
		MODE_FANGS:
			var dist: float = absf(tension - 0.5)
			var score: float = clampf(1.0 - dist / 0.18, 0.0, 1.0)
			pull_scores.append(score)
			pulls += 1
			if pulls >= 3:
				_finish(_avg(pull_scores) * 100.0)
		MODE_HEART:
			if beat_index < beat_times.size():
				var dt: float = absf(t - beat_times[beat_index])
				beat_hits.append(clampf(1.0 - dt / 0.3, 0.0, 1.0))
				beat_index += 1
		MODE_GUTS:
			if next_knot < knots.size():
				if pos.distance_to(knots[next_knot]) < 22.0:
					next_knot += 1
					if next_knot >= knots.size():
						var time_bonus: float = (time_limit - t) / time_limit * 20.0
						_finish(80.0 + time_bonus - errors)
				else:
					errors += 15.0 # nó errado: rasgou o intestino
		MODE_EYES:
			var d: float = pos.distance_to(target_pos)
			_finish(clampf(1.0 - d / 34.0, 0.0, 1.0) * 100.0)

func _on_release() -> void:
	match mode:
		MODE_SKIN:
			if trace_progress > 0.0 and trace_progress < 0.985:
				errors += 1.0 # soltou no meio: precisa recomeçar do ponto atual
		MODE_BLOOD:
			if fill_level > 0.05:
				var d: float = absf(fill_level - fill_target)
				_finish(clampf(1.0 - d / 0.25, 0.0, 1.0) * 100.0)

func _venom_radius() -> float:
	return 46.0 - difficulty * 2.0

func _avg(values: Array) -> float:
	if values.is_empty():
		return 0.0
	var s := 0.0
	for v in values:
		s += float(v)
	return s / float(values.size())

func _distance_to_path(p: Vector2) -> float:
	var best := 99999.0
	for i in range(path_points.size() - 1):
		var c: Vector2 = Geometry2D.get_closest_point_to_segment(p, path_points[i], path_points[i + 1])
		best = min(best, p.distance_to(c))
	return best

# ---------------------------------------------------------------------------
# Desenho
# ---------------------------------------------------------------------------

func _draw() -> void:
	var w: float = size.x
	var h: float = size.y
	draw_rect(Rect2(Vector2.ZERO, size), COL_BG, true)
	draw_rect(Rect2(Vector2(6, 6), size - Vector2(12, 12)), COL_FLESH.darkened(0.55), true)
	var font := get_theme_default_font()
	if mode == MODE_NONE:
		draw_string(font, Vector2(16, h * 0.5), "Selecione um órgão para começar.", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(0.8, 0.8, 0.8))
		return
	draw_multiline_string(font, Vector2(14, 20), hint, HORIZONTAL_ALIGNMENT_LEFT, w - 28, 12, 2, Color(1, 0.92, 0.8))
	# Barra de tempo
	var left: float = clampf(1.0 - t / time_limit, 0.0, 1.0)
	draw_rect(Rect2(Vector2(12, h - 12), Vector2((w - 24) * left, 5)), COL_WARN if left > 0.3 else COL_BAD, true)
	match mode:
		MODE_SKIN:
			for i in range(path_points.size() - 1):
				if i % 2 == 0:
					draw_line(path_points[i], path_points[i + 1], Color(1, 0.85, 0.6, 0.85), 3.0)
			var done_idx: int = int(trace_progress * (path_points.size() - 1))
			for i in range(min(done_idx, path_points.size() - 1)):
				draw_line(path_points[i], path_points[i + 1], COL_GOOD, 5.0)
			draw_circle(path_points[0], 14.0, Color(COL_GOOD, 0.5))
			draw_circle(path_points[path_points.size() - 1], 10.0, Color(COL_WARN, 0.6))
			if mouse_down:
				draw_circle(cursor, 5.0, COL_BAD if _distance_to_path(cursor) > 13.0 else Color(1, 1, 1))
		MODE_FANGS:
			var bar := Rect2(Vector2(40, h * 0.5 - 14), Vector2(w - 80, 28))
			draw_rect(bar, Color(0.15, 0.05, 0.05), true)
			var green_w: float = (w - 80) * 0.36 * (1.0 - difficulty * 0.04)
			draw_rect(Rect2(Vector2(w * 0.5 - green_w * 0.5, bar.position.y), Vector2(green_w, 28)), Color(COL_GOOD, 0.6), true)
			var nx: float = 40 + (w - 80) * tension
			draw_line(Vector2(nx, bar.position.y - 8), Vector2(nx, bar.end.y + 8), Color(1, 1, 1), 4.0)
			draw_string(font, Vector2(40, bar.end.y + 34), "Puxões: %d/3" % pulls, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color(1, 1, 1))
		MODE_VENOM:
			var r: float = _venom_radius()
			var inside: bool = cursor.distance_to(circle_pos) <= r
			draw_circle(circle_pos, r, Color(0.4, 0.9, 0.3, 0.25))
			draw_arc(circle_pos, r, 0, TAU, 48, COL_GOOD if inside else COL_BAD, 3.0)
			draw_circle(circle_pos, 10.0, Color(0.55, 1.0, 0.3))
			draw_string(font, Vector2(14, h - 22), "Fora do círculo: %.1fs / 0.8s" % outside_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, COL_BAD if outside_time > 0.4 else Color(1, 1, 1))
		MODE_BLOOD:
			var flask := Rect2(Vector2(w * 0.5 - 40, 46), Vector2(80, h - 76))
			draw_rect(flask, Color(0.8, 0.9, 1.0, 0.15), true)
			draw_rect(flask, Color(0.8, 0.9, 1.0, 0.8), false, 2.0)
			var fh: float = flask.size.y * fill_level
			draw_rect(Rect2(Vector2(flask.position.x, flask.end.y - fh), Vector2(flask.size.x, fh)), Color(0.65, 0.02, 0.05), true)
			var ty: float = flask.end.y - flask.size.y * fill_target
			draw_line(Vector2(flask.position.x - 16, ty), Vector2(flask.end.x + 16, ty), Color(1.0, 0.82, 0.3), 3.0)
		MODE_HEART:
			var c := Vector2(w * 0.5, h * 0.56)
			draw_circle(c, 26.0, Color(0.75, 0.08, 0.12))
			draw_arc(c, 34.0, 0, TAU, 40, Color(1, 1, 1, 0.6), 2.0)
			if beat_index < beat_times.size():
				var until: float = beat_times[beat_index] - t
				var ring_r: float = 34.0 + max(0.0, until) * 90.0
				draw_arc(c, ring_r, 0, TAU, 48, COL_WARN, 3.0)
			draw_string(font, Vector2(14, h - 22), "Batidas: %d/4" % beat_hits.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		MODE_GUTS:
			for i in range(knots.size() - 1):
				draw_line(knots[i], knots[i + 1], Color(0.85, 0.55, 0.55, 0.5), 6.0)
			for i in range(knots.size()):
				var col: Color = COL_GOOD if i < next_knot else (COL_WARN if i == next_knot else Color(0.9, 0.6, 0.6))
				draw_circle(knots[i], 16.0, col)
				draw_string(font, knots[i] + Vector2(-5, 6), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color(0, 0, 0))
		MODE_LUNGS:
			var bar2 := Rect2(Vector2(w * 0.5 - 30, 46), Vector2(60, h - 76))
			draw_rect(bar2, Color(0.15, 0.1, 0.12), true)
			var y1: float = bar2.end.y - bar2.size.y * 0.78
			var y2: float = bar2.end.y - bar2.size.y * 0.55
			draw_rect(Rect2(Vector2(bar2.position.x, y1), Vector2(60, y2 - y1)), Color(COL_GOOD, 0.45), true)
			var py: float = bar2.end.y - bar2.size.y * pressure
			draw_rect(Rect2(Vector2(bar2.position.x + 8, py), Vector2(44, bar2.end.y - py)), Color(1.0, 0.6, 0.65, 0.9), true)
			draw_string(font, Vector2(14, h - 22), "Na faixa: %.1fs / 3.0s" % band_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		MODE_EYES:
			draw_circle(target_pos, 34.0, Color(0.95, 0.95, 0.9))
			draw_circle(target_pos, 16.0, Color(0.3, 0.5, 0.9))
			draw_circle(target_pos, 7.0, Color(0.02, 0.02, 0.05))
