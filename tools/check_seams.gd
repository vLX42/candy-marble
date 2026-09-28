extends SceneTree
## Scans a level for height seams: places where a ramp tile and its neighbour
## disagree about the surface height on their shared edge. Steps between flat
## tiles are walls by design and aren't reported.
##   godot --headless -s tools/check_seams.gd -- --level=1
##   godot --headless -s tools/check_seams.gd -- --quest=res://quests/marble_madness.json --level=2


func _initialize() -> void:
	var n := 1
	var quest := ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--level="):
			n = int(a.get_slice("=", 1))
		if a.begins_with("--quest="):
			quest = a.get_slice("=", 1)
	var lvl: LevelBase
	if quest != "":
		lvl = Quest.load_file(quest).make_level(n - 1)
	else:
		lvl = load("res://scripts/levels/level_%d.gd" % n).new()
	lvl.build()
	var worst := 0.0
	var count := 0
	for j in lvl.rows:
		for i in lvl.cols:
			if not lvl.is_tile_ground(i, j):
				continue
			for k in 9:
				var f := k / 8.0 * LevelBase.TILE
				for side in 2:
					var ni := i + 1 if side == 0 else i
					var nj := j if side == 0 else j + 1
					if not lvl.is_tile_ground(ni, nj):
						continue
					var x := (i + 1) * LevelBase.TILE if side == 0 else i * LevelBase.TILE + f
					var z := j * LevelBase.TILE + f if side == 0 else (j + 1) * LevelBase.TILE
					var a := lvl.surface(i, j, x, z)
					var b := lvl.surface(ni, nj, x, z)
					var gap := absf(a - b)
					if gap > 0.01 and (lvl.is_ramp(i, j) or lvl.is_ramp(ni, nj)):
						count += 1
						worst = maxf(worst, gap)
						if count <= 12:
							print("seam %.2f at tile (%d, %d) '%s' vs (%d, %d) '%s' at (%.1f, %.1f): %.2f vs %.2f" % [
								gap, i, j, lvl.tile_char(i, j), ni, nj, lvl.tile_char(ni, nj), x, z, a, b])
	print("%s: %d ramp seams, worst %.2f" % [lvl.title, count, worst])
	quit()
