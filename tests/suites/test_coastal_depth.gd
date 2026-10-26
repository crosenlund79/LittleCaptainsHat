extends RefCounted
## Revision 0.105b (GEO, DEPTH, SHELTER, NANCH): worldwide coastal water,
## depth and anchoring rules, without the game running.
##   - the fine coastal raster loads; land and water where they are;
##   - near-shore water the coarse world routing chart cannot express is
##     reachable through a short, checked approach, and the router plans a
##     course through it; a pool behind a one-cell gap is not reachable, the
##     same pool behind a wider gap is (synthetic coast);
##   - depth: one service, labelled GAME ESTIMATE (no real data in this
##     build), deterministic (a fresh service gives the same numbers), smooth
##     along the water, varied between coasts, not "near land = shallow";
##     the reader for installed real data works (synthetic file);
##   - shelter and depth are independent (same depth, different shelter in
##     different winds);
##   - the anchoring rule: land refused, too close refused, deep water needs
##     the Magic Anchor, open sea for the Magic Anchor is "offshore";
##   - the six acceptance areas each have a normal anchorage near them and a
##     course from the local harbour through it.

var t: Node
var coast: CoastalGeography
var depths: DepthService


func run(runner: Node) -> void:
	t = runner
	coast = CoastalGeography.get_default()
	depths = DepthService.get_default()
	SeaRouter.get_default()
	_test_raster()
	_test_reach()
	_test_enclosed_synthetic()
	_test_depth()
	_test_depth_data_synthetic()
	_test_shelter_and_rule()
	_test_acceptance_areas()


func _test_raster() -> void:
	t.check(coast.loaded and coast.res == 120, "[raster] the fine coastal raster loads (1/120 degree)")
	t.check(not coast.is_water(Vector2(10.0, 50.0)) and not coast.is_water(Vector2(-100.0, 40.0)), "[raster] the middle of continents is land")
	t.check(coast.is_water(Vector2(-30.0, 30.0)) and coast.is_water(Vector2(-140.0, -10.0)), "[raster] the middle of oceans is water")
	t.check(coast.shore_distance_nm(Vector2(10.0, 50.0), 3.0) == 0.0 and coast.shore_distance_nm(Vector2(-30.0, 30.0), 3.0) == 3.0,
		"[raster] shore distance: 0 on land, the cap far out")
	t.check(not coast.is_water(Vector2(0.0, -80.0)) and not coast.is_water(Vector2(0.0, 85.0)), "[raster] beyond the chart's latitudes: land")


func _test_reach() -> void:
	var router := SeaRouter.get_default()
	# Off Antigua's south coast: real water about half a mile out, but no
	# navigable cell of the world routing chart (whole ~5 nm cells).
	var antigua := Vector2(-61.85, 17.0)
	t.check(not router.is_point_navigable(antigua) and coast.is_clear(antigua), "[reach] off Antigua: clear water the routing chart cannot express")
	var path := coast.approach(antigua)
	var clear := path.size() >= 2 and router.is_point_navigable(path[path.size() - 1])
	var length := 0.0
	for i in range(1, path.size()):
		clear = clear and coast.is_line_clear(path[i - 1], path[i])
		length += GeoMath.rhumb_distance_nm(path[i - 1], path[i])
	t.check(clear and length <= CoastalGeography.approach_max_nm(antigua) + 0.01,
		"[reach] a short approach (%.1f nm, clear water all the way) joins the router's water" % length)
	# The router plans a course through it from the local harbour and back.
	var falmouth := PortCatalog.get_default().get_port(&"falmouth_antigua")
	var plan := router.plan_route(falmouth.id, falmouth.get_geo_position(), [antigua] as Array[Vector2], falmouth.id)
	var through := false
	if plan.is_ok():
		for p in plan.route.path:
			through = through or p.distance_to(antigua) < 1e-6
	t.check(plan.is_ok() and through and router.validate_route(plan.route) == "",
		"[reach] the router plans a valid course through it, from Falmouth Harbour and back (%s)" % (plan.error if not plan.is_ok() else "ok"))
	# Too close: a point right by the shore is water but not clear.
	var cell := coast.cell_of(antigua)
	var near_land := Vector2.INF
	for dy in range(-6, 7):
		var c := cell + Vector2i(0, dy)
		if coast.is_water(coast.cell_center(c)) and not coast.is_clear_cell(c):
			near_land = coast.cell_center(c)
			break
	t.check(near_land != Vector2.INF and coast.approach(near_land).is_empty(), "[reach] right by the shore: water, but no approach (too close)")


## A synthetic tile: open water west of a land wall; behind it a pool reached
## through a gap one cell wide (never passed) or three cells wide (passed).
func _test_enclosed_synthetic() -> void:
	for gap: int in [1, 3]:
		var synthetic := _synthetic_coast(gap)
		var seeds := func(geo: Vector2) -> bool: return geo.x < -149.75  # "routing water": the open west part
		var pool := Vector2(-149.30, 10.5)
		var path := synthetic.approach(pool, seeds, 30.0)
		if gap == 1:
			t.check(synthetic.is_clear(pool) and path.is_empty(), "[reach] a pool behind a one-cell gap is not reachable (no invented passage)")
		else:
			t.check(path.size() >= 2 and seeds.call(path[path.size() - 1]), "[reach] the same pool behind a three-cell gap is reachable")


func _synthetic_coast(gap: int) -> CoastalGeography:
	var res := 120
	var tile := PackedByteArray()
	tile.resize(res * res)
	var wall := 60  # column of the wall
	for y in res:
		for x in res:
			var land := x >= wall and x < wall + 3 and not (y >= 60 and y < 60 + gap)
			tile[y * res + x] = 1 if land else 0
	var packed := PackedByteArray()
	packed.resize(res * res / 8)
	for i in packed.size():
		var byte := 0
		for b in 8:
			byte |= tile[i * 8 + b] << (7 - b)
		packed[i] = byte
	var blob := packed.compress(FileAccess.COMPRESSION_DEFLATE)
	# Tile at 150W..149W, 10N..11N (row 69 from 80N): mixed; all others water.
	var key := (CoastalGeography.NORTH - 11) * CoastalGeography.TILES_X + 30
	var bytes := PackedByteArray()
	bytes.append_array("LCHC".to_ascii_buffer())
	var header := PackedByteArray()
	header.resize(12)
	header.encode_u32(0, 1)
	header.encode_u32(4, res)
	header.encode_u32(8, 1)
	bytes.append_array(header)
	var index := PackedByteArray()
	index.resize(CoastalGeography.TILES_X * CoastalGeography.TILES_Y)
	index[key] = CoastalGeography.MIXED_TILE
	bytes.append_array(index)
	var table := PackedByteArray()
	table.resize(8)
	table.encode_u32(0, bytes.size() + 8)
	table.encode_u32(4, blob.size())
	bytes.append_array(table)
	bytes.append_array(blob)
	var path := "user://test_synthetic_coast.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var synthetic := CoastalGeography.new()
	synthetic.load_file(path)
	return synthetic


func _test_depth() -> void:
	var off_madeira := Vector2(-16.92, 32.63)
	var a := depths.sample(off_madeira)
	t.check(a.source == DepthService.SOURCE_ESTIMATE and String(a.label) == "GAME ESTIMATE" and not depths.has_data(),
		"[depth] no real data installed: the depth is labelled GAME ESTIMATE (%s)" % a.label)
	var fresh := DepthService.new(CoastalGeography.get_default())
	t.check(is_equal_approx(float(fresh.sample(off_madeira).depth_m), float(a.depth_m)) and is_equal_approx(float(depths.sample(off_madeira).depth_m), float(a.depth_m)),
		"[depth] deterministic: the same place gives the same depth from a fresh service (%.2f m)" % a.depth_m)
	t.check(DepthService.describe_depth(9.3) == "about 9 m" and DepthService.describe_depth(87.0) == "about 85 m" and DepthService.describe_depth(312.0) == "about 300 m",
		"[depth] shown rounded, never as false precision")
	# Smooth along the water: a line straight out from shore, every 0.02 nm.
	var worst := 0.0
	var samples := 0
	var previous := NAN
	var start := Vector2(-61.85, 17.0)
	for i in 150:
		var p := AnchorSite.offset(start, PI, i * 0.02)
		var d := depths.sample(p)
		if d.source == &"":
			previous = NAN
			continue
		if not is_nan(previous):
			worst = maxf(worst, absf(float(d.depth_m) - previous))
		previous = float(d.depth_m)
		samples += 1
	t.check(samples > 100 and worst < 4.0, "[depth] smooth: no jumps along 3 nm of water (largest step %.2f m in 0.02 nm)" % worst)
	# Varied between coasts: the same distance off gives different depths.
	var at_one_nm := []
	for geo: Vector2 in [Vector2(-61.85, 17.0), Vector2(-16.92, 32.63), Vector2(-149.85, -17.6), Vector2(-17.10, 28.08), Vector2(174.32, -35.29)]:
		at_one_nm.append(DepthService.estimate(geo, 1.0, 0.2))
	at_one_nm.sort()
	t.check(at_one_nm[-1] / at_one_nm[0] > 1.8, "[depth] varied: a mile off, coasts differ (%.0f to %.0f m)" % [at_one_nm[0], at_one_nm[-1]])
	# Not "near land = shallow": some coasts are deep close in, some shallow
	# further out.
	var steep_close := 0.0
	var gentle_far := 1000.0
	for i in 400:
		var geo := Vector2(-180.0 + i * 0.9, -40.0 + (i % 80) * 1.0)
		steep_close = maxf(steep_close, DepthService.estimate(geo, 0.6, 0.2))
		gentle_far = minf(gentle_far, DepthService.estimate(geo, 2.0, 0.2))
	t.check(steep_close > AnchorSite.NORMAL_MAX_DEPTH_M and gentle_far < AnchorSite.NORMAL_MAX_DEPTH_M,
		"[depth] proximity is not depth: %.0f m 0.6 nm off a steep coast, %.0f m 2 nm off a gentle one" % [steep_close, gentle_far])
	t.check(DepthService.estimate(Vector2(1.0, 1.0), 0.5, 0.8) < DepthService.estimate(Vector2(1.0, 1.0), 0.5, 0.0), "[depth] an enclosed bay is shallower than an open coast at the same distance")


func _test_depth_data_synthetic() -> void:
	# A synthetic data file (like tools/navigation/build_depth.py writes): one
	# tile at 30W..29W, 30N..31N at 60 cells per degree, -1000 m everywhere.
	var res := 60
	var values := PackedByteArray()
	values.resize(res * res * 2)
	for i in res * res:
		values.encode_s16(i * 2, -1000)
	var blob := values.compress(FileAccess.COMPRESSION_DEFLATE)
	var key := (DepthData.NORTH - 31) * DepthData.TILES_X + 150
	var bytes := PackedByteArray()
	bytes.append_array("LCHD".to_ascii_buffer())
	var header := PackedByteArray()
	header.resize(16)
	header.encode_u32(0, 1)
	header.encode_u32(4, res)
	header.encode_u32(8, 1)
	header.encode_u32(12, 1)
	bytes.append_array(header)
	var index := PackedByteArray()
	index.resize(DepthData.TILES_X * DepthData.TILES_Y)
	index[key] = 1
	bytes.append_array(index)
	var table := PackedByteArray()
	table.resize(8)
	table.encode_u32(0, bytes.size() + 8)
	table.encode_u32(4, blob.size())
	bytes.append_array(table)
	bytes.append_array(blob)
	var path := "user://test_synthetic_depth.bin"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()
	var service := DepthService.new(CoastalGeography.get_default())
	t.check(service.load_data(path), "[data] an installed depth file loads (synthetic)")
	var inside := service.sample(Vector2(-29.5, 30.5))
	var outside := service.sample(Vector2(-35.5, 30.5))
	t.check(inside.source == DepthService.SOURCE_GLOBAL and is_equal_approx(float(inside.depth_m), 1000.0) and String(inside.label).contains("interpolated"),
		"[data] where data exist they are used and labelled as a model, not soundings (%s)" % inside.label)
	t.check(outside.source == DepthService.SOURCE_ESTIMATE, "[data] elsewhere the game estimate fills in")


func _test_shelter_and_rule() -> void:
	var spot := GameSession.nearest_anchorage_spot(Vector2(-61.85, 17.0), 6.0)
	if not t.check(spot != Vector2.INF, "(setup) an anchorage off Antigua"):
		return
	# Depth does not change with the wind; shelter does.
	var shelters := {}
	var depth_values := {}
	for from_deg in [0.0, 90.0, 180.0, 270.0]:
		var site := AnchorSite.evaluate(spot, WindField.Sample.make(from_deg, 12.0), false, false)
		shelters[site.shelter] = true
		depth_values[snappedf(float(site.depth_m), 0.01)] = true
	t.check(depth_values.size() == 1 and shelters.size() >= 2, "[shelter] same depth in every wind, shelter changes with it (%s)" % [shelters.keys()])
	var storm := AnchorSite.evaluate(spot, WindField.Sample.make(0.0, 45.0), false, false)
	t.check(not storm.ok and String(storm.reason).contains("wind"), "[shelter] a storm: too much wind for the normal anchor (%s)" % storm.reason)
	var storm_magic := AnchorSite.evaluate(spot, WindField.Sample.make(0.0, 45.0), true, false)
	t.check(storm_magic.ok and storm_magic.kind == AnchorSite.KIND_MAGIC, "[shelter] the Magic Anchor can still go down in a storm (no promise it holds)")
	# The rule.
	var land := AnchorSite.evaluate(Vector2(10.0, 50.0), WindField.Sample.make(0.0, 8.0), true, false)
	t.check(not land.ok and String(land.reason).contains("Land"), "[rule] land is refused, with or without the Magic Anchor")
	var open_sea := AnchorSite.evaluate(Vector2(-30.0, 30.0), WindField.Sample.make(0.0, 8.0), false, false)
	t.check(not open_sea.ok and String(open_sea.reason).contains("too deep"), "[rule] the open ocean is too deep for the normal anchor (%s)" % open_sea.reason)
	var magic_sea := AnchorSite.evaluate(Vector2(-30.0, 30.0), WindField.Sample.make(0.0, 8.0), true, true)
	t.check(magic_sea.ok and magic_sea.kind == AnchorSite.KIND_MAGIC and magic_sea.offshore and String(magic_sea.reason).contains("no shelter"),
		"[rule] with the Magic Anchor the open sea is possible: offshore, no shelter (%s)" % magic_sea.reason)
	var normal := AnchorSite.evaluate(spot, WindField.Sample.make(90.0, 10.0), false, false)
	t.check(normal.normal_ok and normal.kind == AnchorSite.KIND_NORMAL and float(normal.depth_m) <= AnchorSite.NORMAL_MAX_DEPTH_M,
		"[rule] the anchorage off Antigua suits the normal anchor (%s)" % normal.reason)


## The six areas of the assignment: an anchorage for the normal anchor near
## each, and a course from the local harbour through it.
func _test_acceptance_areas() -> void:
	var areas := [
		["Denmark (the Belts)", Vector2(10.95, 55.35), &"nyborg"],
		["Iberia", Vector2(-8.45, 43.40), &"a_coruna"],
		["Canaries", Vector2(-15.40, 28.15), &"las_palmas"],
		["Caribbean", Vector2(-61.85, 17.0), &"falmouth_antigua"],
		["French Polynesia", Vector2(-149.60, -17.50), &"papeete"],
		["New Zealand", Vector2(174.45, -35.75), &"whangarei"],
	]
	var router := SeaRouter.get_default()
	for area: Array in areas:
		var spot := GameSession.nearest_anchorage_spot(area[1], 12.0)
		var ok: bool = spot != Vector2.INF and GameSession.anchorage_spot(spot).ok
		var port := PortCatalog.get_default().get_port(area[2])
		var routed := "no harbour"
		if ok and port:
			var plan := router.plan_route(port.id, port.get_geo_position(), [spot] as Array[Vector2], port.id)
			routed = "ok" if plan.is_ok() else plan.error
		t.check(ok and routed == "ok", "[areas] %s: a normal anchorage at %s (%s), on a course from %s (%s)" % [area[0],
			GeoMath.format_position(spot) if spot != Vector2.INF else "-", GameSession.anchorage_spot(spot).reason if spot != Vector2.INF else "", area[2], routed])
