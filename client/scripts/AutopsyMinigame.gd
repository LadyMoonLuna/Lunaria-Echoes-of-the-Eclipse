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
# Dificuldade extra (Etapa 2): faixas que andam, ritmos irregulares, nós que se mexem
var trace_idx: int = 0 # segmento mais adiantado já percorrido na linha
var trace_tol: float = 13.0
var fang_center: float = 0.5
var fang_phase: Vector3 = Vector3.ZERO
var band_lo: float = 0.55
var band_hi: float = 0.78
var knot_vel: Array = []
var eye_freq: Vector4 = Vector4(3.1, 4.3, 1.7, 2.9)
var blood_curve: float = 0.35
## Padrões de esfola já usados nesta sessão: nunca se repete o mesmo desenho.
static var used_patterns: Dictionary = {}
static var last_pattern_kind: int = -1

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
	# Partes do corpo usam os mesmos gestos, numa versão mais difícil
	match organ_type:
		13, 14, 15, 17: # cabeça, cauda, asa, barbatana: corte ao longo da articulação
			organ_type = 1
			difficulty = clampi(difficulty + 2, 1, 10)
		12, 16, 18, 20: # patas, bico, pinças, ossos: desarticular puxando
			organ_type = 2
			difficulty = clampi(difficulty + 1, 1, 10)
		19: # antenas: precisão absoluta
			organ_type = 10
			difficulty = clampi(difficulty + 3, 1, 10)
	match organ_type:
		1:
			mode = MODE_SKIN
			time_limit = 13.0 - difficulty * 0.45
			hint = "ESFOLAR: segure o botão no círculo verde e siga a linha até o fim, sem sair dela."
			path_points = _make_skin_path(w, h)
			trace_tol = maxf(7.0, 13.0 - difficulty * 0.6)
			trace_idx = 0
			trace_progress = 0.0
			trace_off_time = 0.0
			trace_on_time = 0.0
		2:
			mode = MODE_FANGS
			time_limit = 12.0
			hint = "ARRANCAR: clique 3 vezes quando a agulha estiver na faixa verde. A faixa muda de lugar a cada puxão!"
			pulls = 0
			pull_scores = []
			tension = 0.0
			fang_center = randf_range(0.3, 0.7)
			fang_phase = Vector3(randf() * TAU, randf() * TAU, randf_range(0.6, 1.4))
		3, 11:
			mode = MODE_VENOM
			time_limit = 4.0 + difficulty * 0.2
			hint = "MÃO FIRME: segure o cursor dentro do círculo até a bolsa se soltar. Sair rompe a bolsa!"
			circle_pos = Vector2(w * 0.5, h * 0.55)
			circle_vel = Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * 80.0 * (0.7 + difficulty * 0.14)
			outside_time = 0.0
			trace_on_time = 0.0
		4:
			mode = MODE_BLOOD
			time_limit = 12.0
			hint = "DRENAR: segure o botão para encher o frasco e solte bem na marca dourada."
			fill_level = 0.0
			fill_target = randf_range(0.5, 0.9)
			blood_curve = randf_range(0.2, 0.7) # cada animal sangra num ritmo
		6:
			mode = MODE_HEART
			time_limit = 7.0
			beat_times = []
			var beats: int = 4 + int(difficulty / 4.0)
			hint = "PULSO: clique quando o anel encostar no coração — %d batidas, e o ritmo é irregular!" % beats
			var bt: float = 1.1
			for i in range(beats):
				bt += randf_range(0.55, 1.2) - difficulty * 0.02 # arritmia: nunca no mesmo compasso
				beat_times.append(bt)
			time_limit = bt + 1.0
			beat_hits = []
			beat_index = 0
		8:
			mode = MODE_GUTS
			time_limit = 9.0 - difficulty * 0.35
			hint = "DESENROLAR: clique nos nós em ordem (1, 2, 3...) antes do tempo acabar."
			knots = []
			var count: int = 6 + int(difficulty / 2.0)
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
			knot_vel = []
			for k in knots:
				knot_vel.append(Vector2(randf_range(-1, 1), randf_range(-1, 1)).normalized() * (8.0 + difficulty * 3.0))
		9:
			mode = MODE_LUNGS
			time_limit = 9.0
			hint = "INFLAR: segure para encher, solte para esvaziar — mantenha a pressão na faixa verde por 3s."
			pressure = 0.3
			band_time = 0.0
			band_lo = 0.55
			band_hi = 0.78
		10:
			mode = MODE_EYES
			time_limit = 6.0
			hint = "ENUCLEAR: um único clique, o mais perto possível do centro do olho que treme."
			target_pos = Vector2(w * 0.5, h * 0.55)
			eye_freq = Vector4(randf_range(2.5, 4.0), randf_range(3.5, 5.5), randf_range(1.0, 2.5), randf_range(2.0, 3.5))
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
				if d > trace_tol:
					trace_off_time += delta
				else:
					trace_on_time += delta
				# avança pela própria linha (serve para curvas, laços e espirais): só os próximos trechos contam
				var best_i: int = trace_idx
				var best_d: float = 99999.0
				for i in range(trace_idx, mini(trace_idx + 6, path_points.size() - 1)):
					var c: Vector2 = Geometry2D.get_closest_point_to_segment(cursor, path_points[i], path_points[i + 1])
					var cd: float = cursor.distance_to(c)
					if cd < best_d:
						best_d = cd
						best_i = i
				if best_d < 30.0:
					trace_idx = maxi(trace_idx, best_i)
				trace_progress = maxf(0.001, float(trace_idx + 1) / float(path_points.size() - 1))
				if trace_progress >= 0.985:
					var off_ratio: float = trace_off_time / max(0.01, trace_on_time + trace_off_time)
					_finish(100.0 - off_ratio * 160.0)
		MODE_FANGS:
			# agulha nervosa: soma de duas ondas, mais rápida quanto mais difícil
			var sp: float = (2.6 + difficulty * 0.3) * fang_phase.z
			tension = clampf(0.5 + 0.32 * sin(t * sp + fang_phase.x) + 0.18 * sin(t * sp * 2.3 + fang_phase.y), 0.0, 1.0)
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
				fill_level += delta * (0.2 + fill_level * blood_curve + difficulty * 0.015 + 0.05 * sin(t * 7.0))
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
			# a faixa boa sobe e desce com a respiração do animal (estreita conforme a dificuldade)
			var mid: float = 0.6 + 0.15 * sin(t * (0.8 + difficulty * 0.08))
			var half: float = maxf(0.06, 0.115 - difficulty * 0.005)
			band_lo = mid - half
			band_hi = mid + half
			if pressure > band_lo and pressure < band_hi:
				band_time += delta
			else:
				errors += delta
			if pressure >= 1.0:
				_finish(10.0) # pulmão estourou
			elif band_time >= 3.0:
				_finish(100.0 - errors * 22.0)
		MODE_EYES:
			var jitter: float = 22.0 + difficulty * 6.0
			target_pos = Vector2(w * 0.5, h * 0.55) + Vector2(sin(t * eye_freq.x) + 0.5 * sin(t * eye_freq.z * 2.0), cos(t * eye_freq.y) + 0.4 * cos(t * eye_freq.w * 1.7)) * jitter * Vector2(1.0, 0.65)
		MODE_GUTS:
			for i in range(knots.size()):
				if i < next_knot:
					continue
				var kp: Vector2 = knots[i] + knot_vel[i] * delta
				if kp.x < 30 or kp.x > w - 30:
					knot_vel[i] = Vector2(-knot_vel[i].x, knot_vel[i].y)
				if kp.y < 45 or kp.y > h - 25:
					knot_vel[i] = Vector2(knot_vel[i].x, -knot_vel[i].y)
				knots[i] = kp
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
			var dist: float = absf(tension - fang_center)
			var score: float = clampf(1.0 - dist / maxf(0.08, 0.16 - difficulty * 0.007), 0.0, 1.0)
			pull_scores.append(score)
			pulls += 1
			fang_center = randf_range(0.25, 0.75) # a resistência muda depois de cada puxão
			if pulls >= 3:
				_finish(_avg(pull_scores) * 100.0)
		MODE_HEART:
			if beat_index < beat_times.size():
				var dt: float = absf(t - beat_times[beat_index])
				beat_hits.append(clampf(1.0 - dt / 0.24, 0.0, 1.0))
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
			_finish(clampf(1.0 - d / 30.0, 0.0, 1.0) * 100.0)

func _on_release() -> void:
	match mode:
		MODE_SKIN:
			if trace_progress > 0.0 and trace_progress < 0.985:
				errors += 1.0 # soltou no meio: precisa recomeçar do ponto atual
		MODE_BLOOD:
			if fill_level > 0.05:
				var d: float = absf(fill_level - fill_target)
				_finish(clampf(1.0 - d / 0.18, 0.0, 1.0) * 100.0)

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
			for i in range(mini(trace_idx + 1, path_points.size() - 1)):
				draw_line(path_points[i], path_points[i + 1], COL_GOOD, 5.0)
			draw_circle(path_points[0], 14.0, Color(COL_GOOD, 0.5))
			draw_circle(path_points[path_points.size() - 1], 10.0, Color(COL_WARN, 0.6))
			if mouse_down:
				draw_circle(cursor, 5.0, COL_BAD if _distance_to_path(cursor) > trace_tol else Color(1, 1, 1))
		MODE_FANGS:
			var bar := Rect2(Vector2(40, h * 0.5 - 14), Vector2(w - 80, 28))
			draw_rect(bar, Color(0.15, 0.05, 0.05), true)
			var green_w: float = (w - 80) * 2.0 * maxf(0.08, 0.16 - difficulty * 0.007)
			var gx: float = 40 + (w - 80) * fang_center
			draw_rect(Rect2(Vector2(gx - green_w * 0.5, bar.position.y), Vector2(green_w, 28)), Color(COL_GOOD, 0.6), true)
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
			draw_string(font, Vector2(14, h - 22), "Batidas: %d/%d" % [beat_hits.size(), beat_times.size()], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
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
			var y1: float = bar2.end.y - bar2.size.y * band_hi
			var y2: float = bar2.end.y - bar2.size.y * band_lo
			draw_rect(Rect2(Vector2(bar2.position.x, y1), Vector2(60, y2 - y1)), Color(COL_GOOD, 0.45), true)
			var py: float = bar2.end.y - bar2.size.y * pressure
			draw_rect(Rect2(Vector2(bar2.position.x + 8, py), Vector2(44, bar2.end.y - py)), Color(1.0, 0.6, 0.65, 0.9), true)
			draw_string(font, Vector2(14, h - 22), "Na faixa: %.1fs / 3.0s" % band_time, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(1, 1, 1))
		MODE_EYES:
			draw_circle(target_pos, 30.0, Color(0.95, 0.95, 0.9))
			draw_circle(target_pos, 16.0, Color(0.3, 0.5, 0.9))
			draw_circle(target_pos, 7.0, Color(0.02, 0.02, 0.05))

# ---------------------------------------------------------------------------
# Padrões de esfola: 8 famílias de traçado com parâmetros sorteados. A assinatura de cada desenho
# fica guardada e nenhum se repete (nem a mesma família duas vezes seguidas).
# ---------------------------------------------------------------------------
const SKIN_KINDS := 8

func _make_skin_path(w: float, h: float) -> PackedVector2Array:
	for _attempt in range(40):
		var kind: int = randi() % SKIN_KINDS
		if kind == last_pattern_kind:
			continue
		var seed_val: int = randi()
		var sig := "%d:%d" % [kind, seed_val % 100000]
		if used_patterns.has(sig):
			continue
		used_patterns[sig] = true
		last_pattern_kind = kind
		var rng := RandomNumberGenerator.new()
		rng.seed = seed_val
		var pts := _skin_pattern(kind, rng, w, h)
		if rng.randf() < 0.5:
			pts.reverse() # da direita para a esquerda
		return pts
	return _skin_pattern(0, RandomNumberGenerator.new(), w, h)

func _skin_pattern(kind: int, rng: RandomNumberGenerator, w: float, h: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var x0: float = 30.0
	var x1: float = w - 30.0
	var y0: float = 52.0
	var y1: float = h - 24.0
	var cy: float = (y0 + y1) * 0.5
	var amp: float = (y1 - y0) * 0.5 * rng.randf_range(0.55, 0.95) * (0.8 + difficulty * 0.03)
	var n := 90
	match kind:
		0: # onda simples com fase e frequência sorteadas
			var f: float = rng.randf_range(1.2, 2.6) + difficulty * 0.15
			var ph: float = rng.randf() * TAU
			for i in range(n + 1):
				var u: float = float(i) / n
				pts.append(Vector2(lerpf(x0, x1, u), cy + sin(u * TAU * f + ph) * amp))
		1: # duas ondas somadas (batimento): amplitudes que crescem e somem
			var f1: float = rng.randf_range(1.0, 2.0)
			var f2: float = rng.randf_range(3.0, 5.5)
			for i in range(n + 1):
				var u: float = float(i) / n
				pts.append(Vector2(lerpf(x0, x1, u), cy + (sin(u * TAU * f1) * 0.65 + sin(u * TAU * f2) * 0.35) * amp))
		2: # zigue-zague de cantos vivos
			var segs: int = rng.randi_range(5, 8) + int(difficulty / 3.0)
			var corners := PackedVector2Array()
			for k in range(segs + 1):
				var yy: float = cy + (amp if k % 2 == 0 else -amp) * rng.randf_range(0.5, 1.0)
				corners.append(Vector2(lerpf(x0, x1, float(k) / segs), yy))
			pts = _densify(corners, 6)
		3: # curva suave por pontos sorteados (Catmull-Rom)
			var ctrl := PackedVector2Array()
			var cn: int = rng.randi_range(5, 8)
			for k in range(cn):
				ctrl.append(Vector2(lerpf(x0, x1, float(k) / (cn - 1)), rng.randf_range(y0 + 8, y1 - 8)))
			for k in range(cn - 1):
				var p0: Vector2 = ctrl[maxi(k - 1, 0)]
				var p1: Vector2 = ctrl[k]
				var p2: Vector2 = ctrl[k + 1]
				var p3: Vector2 = ctrl[mini(k + 2, cn - 1)]
				for s in range(14):
					var tt: float = float(s) / 14.0
					pts.append(0.5 * ((2.0 * p1) + (-p0 + p2) * tt + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * tt * tt + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * tt * tt * tt))
			pts.append(ctrl[cn - 1])
		4: # degraus arredondados (onda quadrada suavizada)
			var steps: int = rng.randi_range(4, 7)
			var sharp: float = rng.randf_range(3.0, 6.0)
			for i in range(n + 1):
				var u: float = float(i) / n
				var sq: float = tanh(sin(u * TAU * steps * 0.5) * sharp)
				pts.append(Vector2(lerpf(x0, x1, u), cy + sq * amp * 0.85))
		5: # laçadas (trocoide): a linha dá voltas sobre si mesma
			var loops: int = rng.randi_range(2, 4)
			var r: float = minf(amp * 0.75, (x1 - x0) / (loops * 4.5)) * rng.randf_range(0.7, 1.0)
			var stretch: float = rng.randf_range(1.0, 1.6)
			var ph: float = rng.randf() * TAU
			var yoff: float = rng.randf_range(-amp * 0.25, amp * 0.25)
			for i in range(n * 2 + 1):
				var u: float = float(i) / (n * 2)
				var a: float = u * TAU * loops + ph
				pts.append(Vector2(lerpf(x0 + r, x1 - r, u) - sin(a) * r * stretch, cy + yoff + cos(a) * r - r * 0.5))
		6: # espiral que abre do centro para a borda
			var turns: float = rng.randf_range(1.4, 2.2)
			var c := Vector2((x0 + x1) * 0.5, cy)
			var rmax: float = minf((y1 - y0) * 0.48, (x1 - x0) * 0.45)
			for i in range(n * 2 + 1):
				var u: float = float(i) / (n * 2)
				var a2: float = u * TAU * turns
				pts.append(c + Vector2(cos(a2), sin(a2)) * lerpf(10.0, rmax, u))
		7: # serpente com amplitude crescente e trechos retos
			var f3: float = rng.randf_range(2.0, 3.5)
			for i in range(n + 1):
				var u: float = float(i) / n
				var env: float = clampf(u * u * 1.2, 0.15, 1.0)
				pts.append(Vector2(lerpf(x0, x1, u), cy + sin(u * TAU * f3) * amp * env))
	return pts

func _densify(corners: PackedVector2Array, per: int) -> PackedVector2Array:
	var out := PackedVector2Array()
	for k in range(corners.size() - 1):
		for s in range(per):
			out.append(corners[k].lerp(corners[k + 1], float(s) / per))
	out.append(corners[corners.size() - 1])
	return out
