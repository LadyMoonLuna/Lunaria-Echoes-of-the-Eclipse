extends SceneTree
## Gera client/assets/world_map.png: todas as zonas abertas (600 x 600 m cada) lado a lado na grade
## do mundo, com relevo sombreado, biomas, o Rio Prateado, lagos, estradas, covis e portais.
## Uso: godot --headless --path client -s ../tools/gen_world_map.gd

const Terrain = preload("res://scripts/world/Terrain.gd")
const Data = preload("res://scripts/world/WorldData.gd")
const PX := 200 # pixels por zona
const OUT := "res://assets/world_map.png"

func _initialize() -> void:
	var min_c := 99
	var max_c := -99
	var min_r := 99
	var max_r := -99
	for id in Data.ZONES:
		var z: Dictionary = Data.ZONES[id]
		min_c = mini(min_c, z["col"])
		max_c = maxi(max_c, z["col"])
		min_r = mini(min_r, z["row"])
		max_r = maxi(max_r, z["row"])
	var w := (max_c - min_c + 1) * PX
	var h := (max_r - min_r + 1) * PX
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color("#0b0e14"))
	for id in Data.ZONES:
		var zi: Dictionary = Data.ZONES[id]
		var ox: int = (int(zi["col"]) - min_c) * PX
		var oy: int = (max_r - int(zi["row"])) * PX # norte para cima
		_draw_zone(img, int(id), ox, oy)
		print("zona %d desenhada" % id)
	img.save_png(OUT)
	var meta := {"min_col": min_c, "max_row": max_r, "px": PX, "w": w, "h": h}
	var f := FileAccess.open("res://assets/world_map.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(meta))
	print("Mapa salvo: %s (%dx%d)" % [OUT, w, h])
	quit()

func _to_px(x: float, z: float, ox: int, oy: int) -> Vector2i:
	return Vector2i(ox + int((x + 300.0) / 600.0 * (PX - 1)), oy + int((300.0 - z) / 600.0 * (PX - 1)))

func _draw_zone(img: Image, zone: int, ox: int, oy: int) -> void:
	Terrain.prepare(zone)
	var b := Terrain.biome(zone)
	var low: Color = b["ground"][0]
	var mid: Color = b["ground"][1]
	var high: Color = b["ground"][2]
	var snow: float = b["snow"]
	for py in range(PX):
		for pxx in range(PX):
			var x := -300.0 + (pxx + 0.5) * 600.0 / PX
			var z := 300.0 - (py + 0.5) * 600.0 / PX
			var hgt := Terrain.height(zone, x, z)
			var hx := Terrain.height(zone, x + 3.0, z) - hgt
			var hz := Terrain.height(zone, x, z + 3.0) - hgt
			var shade := clampf(1.0 - (hx - hz) * 0.08, 0.55, 1.3)
			var col := low.lerp(mid, clampf(hgt / 12.0, 0.0, 1.0)).lerp(high, clampf((hgt - 12.0) / 30.0, 0.0, 1.0))
			if hgt > snow:
				col = col.lerp(Color.WHITE, clampf((hgt - snow) / 8.0, 0.0, 1.0))
			col = Color(col.r * shade, col.g * shade, col.b * shade)
			if Terrain.is_water(zone, x, z):
				col = Color("#3f7fb0") if zone != 16 else Color("#4d5f3a")
			if zone == 0 and maxf(absf(x), absf(z)) < 80.0:
				col = col.lerp(Color("#b8a88a"), 0.55) # cidade murada
			img.set_pixel(ox + pxx, oy + py, col)
	# Estradas
	for road in Terrain.roads_for(zone):
		for p in road:
			var q := _to_px(p.x, p.y, ox, oy)
			for dx in range(-1, 2):
				for dy in range(-1, 2):
					var c := q + Vector2i(dx, dy)
					if c.x >= ox and c.y >= oy and c.x < ox + PX and c.y < oy + PX:
						img.set_pixelv(c, Color("#d9b47a"))
	# Covis (vermelho) e portais (ciano)
	for d in Data.DANGERS.get(zone, []):
		var q := _to_px(float(d[0]), float(d[1]), ox, oy)
		_dot(img, q, 3, Color("#e53935"), ox, oy)
	for p in Data.PORTALS:
		if int(p["from"]) == zone:
			_dot(img, _to_px(float(p["x"]), float(p["z"]), ox, oy), 4, Color("#4dd0e1"), ox, oy)
	# Borda da zona
	for k in range(PX):
		for e in [Vector2i(ox + k, oy), Vector2i(ox + k, oy + PX - 1), Vector2i(ox, oy + k), Vector2i(ox + PX - 1, oy + k)]:
			img.set_pixelv(e, Color(0, 0, 0, 1))

func _dot(img: Image, c: Vector2i, r: int, col: Color, ox: int, oy: int) -> void:
	for dx in range(-r, r + 1):
		for dy in range(-r, r + 1):
			if dx * dx + dy * dy <= r * r:
				var q := c + Vector2i(dx, dy)
				if q.x >= ox and q.y >= oy and q.x < ox + PX and q.y < oy + PX:
					img.set_pixelv(q, col)
