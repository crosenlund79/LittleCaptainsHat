extends RefCounted
## Iteration 18, Fishing 2.0 (FISH, FART, SPEC, KEEP, SHRK):
##   - the reel-in dial: checks by rarity, a constant needle speed, Perfect
##     hits, the forgiving miss rule, the press debounce, fairness for a
##     careful and for a sloppy captain;
##   - weights, specimen grades (by weight only) and the Perfect nudge;
##   - the illustrated catches: art for every species and piece of junk,
##     distinct silhouettes, the blink and the tail flick (and their limits:
##     irregular, stop when hidden, reduce motion, no timers), the same
##     picture from bite to result to cool box and trophies;
##   - keep preferences, automatic and manual release, trophies only for kept
##     fish, sharks always released, junk discarded, no duplicates;
##   - bites: R and the action wheel reach the reel-in from anywhere aboard.

const APP_SCENE := preload("res://src/app/app.tscn")
const Reel := preload("res://tests/helpers/reel.gd")

var t: Node
var app: Node
var catalog: FishingCatalog


func run(runner: Node) -> void:
	t = runner
	catalog = FishingCatalog.get_default()
	Simulation.auto_advance = false
	t.use_calm_wind()
	_test_reel_rules()
	_test_reel_fairness()
	_test_weights_and_grades()
	_test_art_coverage()
	app = APP_SCENE.instantiate()
	t.add_child(app)
	app.router.fade_duration = 0.05
	await _settle()
	app.start_new_game()
	await _settle()
	await _test_portrait()
	_test_keep_and_trophies()
	_test_sharks_and_junk()
	await _test_bite_access()
	await _test_menu_flow()
	_test_persistence()
	await _test_anchored_and_fast_time()
	Simulation.auto_advance = true
	app.queue_free()
	await t.frames(2)
	GameSession.end_session()
	t.use_calm_wind()


func _settle() -> void:
	await t.frames(2)
	await t.wait_until(func() -> bool: return not app.router.is_busy(), 5.0)
	await t.physics_frames(3)


func _force_bite(species: String, kg: float) -> void:
	GameSession.expire_bite()
	GameSession._pending_bite = {"species": species, "kg": kg, "time": GameSession.get_game_time(), "mode": "stationary",
		"lure": "spinner", "kind": String(catalog.kind_of(species)), "rarity": catalog.rarity_of(species)}


# --- The dial -------------------------------------------------------------------------

func _test_reel_rules() -> void:
	# Checks and arcs by rarity (the data's own four rarities).
	var checks := []
	var arcs := []
	for rarity in FishingCatalog.RARITY_ORDER:
		var entry: Array = FishingCatalog.REEL[rarity]
		checks.append(int(entry[0]))
		arcs.append(float(entry[1]))
	t.check(checks == [1, 2, 3, 4], "[reel] successful checks: common 1, uncommon 2, rare 3, very rare 4 (%s)" % [checks])
	t.check(arcs[0] > arcs[1] and arcs[1] > arcs[2] and arcs[2] > arcs[3] and arcs[3] >= 40.0,
		"[reel] the target arc narrows with rarity but stays fair (%s degrees)" % [arcs])
	t.check_eq(catalog.reel_profile("cod").checks, 2, "[reel] a cod (uncommon) needs two")
	t.check_eq(catalog.reel_profile("yellowfin").checks, 4, "[reel] a yellowfin (very rare) needs four")
	# A constant needle speed, however time is chopped.
	var a := ReelTiming.new(4, 42.0, 1)
	var b := ReelTiming.new(4, 42.0, 1)
	for i in 300:
		a.step(1.0 / 60.0)
	for i in 7:
		b.step(5.0 / 7.0)
	var expected := fposmod(ReelTiming.SPEED_DEG * 5.0, 360.0)
	t.check(absf(a.angle - expected) < 0.01 and absf(b.angle - expected) < 0.01,
		"[reel] the needle turns at one constant speed (%.0f deg/s), whatever the frame steps" % ReelTiming.SPEED_DEG)
	# Hits, Perfects and misses.
	var r := ReelTiming.new(3, 50.0, 7)
	t.check(not r.is_in_arc(), "[reel] the first arc starts well ahead of the needle (%.0f deg away)" % r.distance_to_target())
	r.angle = fposmod(r.target_deg + r.get_perfect_deg() / 2.0 - 0.5, 360.0)
	t.check_eq(r.press(), ReelTiming.PRESS_PERFECT, "[reel] in the gold middle: Perfect")
	t.check(r.distance_to_target() >= 120.0, "[reel] after a good press the next arc moves well ahead (%.0f deg)" % r.distance_to_target())
	t.check_eq(r.press(), ReelTiming.PRESS_NONE, "[reel] a second press within %.2f s does not count (a held or bouncing key)" % ReelTiming.DEBOUNCE)
	r.step(ReelTiming.DEBOUNCE + 0.01)
	r.angle = fposmod(r.target_deg + r.arc_deg / 2.0 - 0.5, 360.0)
	t.check_eq(r.press(), ReelTiming.PRESS_HIT, "[reel] at the arc's edge: a good press, not Perfect")
	r.step(ReelTiming.DEBOUNCE + 0.01)
	r.angle = fposmod(r.target_deg + 180.0, 360.0)
	t.check_eq(r.press(), ReelTiming.PRESS_MISS, "[reel] outside the arc: a miss")
	t.check(not r.is_over() and r.get_line_control() == 2, "[reel] one miss costs one grip; the catch is still on")
	r.step(ReelTiming.DEBOUNCE + 0.01)
	r.angle = fposmod(r.target_deg + 180.0, 360.0)
	r.press()
	t.check(not r.is_over(), "[reel] two misses: still on (forgiving)")
	r.step(ReelTiming.DEBOUNCE + 0.01)
	r.angle = r.target_deg
	r.press()
	t.check(r.result == ReelTiming.RESULT_LANDED and r.perfects == 2 and r.hits == 3,
		"[reel] three good presses land it despite two misses (perfects %d)" % r.perfects)
	var lost := ReelTiming.new(1, 72.0, 3)
	for i in 3:
		lost.step(ReelTiming.DEBOUNCE + 0.01)
		lost.angle = fposmod(lost.target_deg + 180.0, 360.0)
		lost.press()
	t.check_eq(lost.result, ReelTiming.RESULT_ESCAPED, "[reel] the third miss lets it escape")
	var idle := ReelTiming.new(1, 72.0, 3)
	idle.step(ReelTiming.IDLE_SECONDS - 1.0)
	var waiting := not idle.is_over()
	idle.step(1.5)
	t.check(waiting and idle.result == ReelTiming.RESULT_ESCAPED, "[reel] never pressing: it slips the hook after %d s, not before" % roundi(ReelTiming.IDLE_SECONDS))


## A captain who presses with a small timing error lands every rarity nearly
## always; a sloppy one still lands common fish mostly and loses some rare ones.
func _test_reel_fairness() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 18
	var careful := {}
	var sloppy := {}
	var longest := 0.0
	for rarity in FishingCatalog.RARITY_ORDER:
		var entry: Array = FishingCatalog.REEL[rarity]
		for pair in [[careful, 0.6], [sloppy, 1.5]]:
			var landed := 0
			for trial in 200:
				var reel := ReelTiming.new(int(entry[0]), float(entry[1]), trial)
				while not reel.is_over():
					# Wait until the needle is near the arc's middle, then press
					# with an error up to `factor` x the arc's half width.
					var wait := fposmod(reel.target_deg - reel.angle, 360.0) / ReelTiming.SPEED_DEG
					reel.step(maxf(wait, ReelTiming.DEBOUNCE + 0.01))
					reel.angle = fposmod(reel.target_deg + rng.randf_range(-1.0, 1.0) * float(entry[1]) / 2.0 * float(pair[1]), 360.0)
					reel.press()
				if reel.result == ReelTiming.RESULT_LANDED:
					landed += 1
					if pair[1] < 1.0:
						longest = maxf(longest, reel.elapsed)
			pair[0][rarity] = landed / 200.0
	t.check(careful.values().all(func(rate: float) -> bool: return rate >= 0.99),
		"[fairness] a careful captain lands every rarity (%s)" % [careful])
	t.check(float(sloppy.common) >= 0.85 and float(sloppy.very_rare) < float(sloppy.common) and float(sloppy.very_rare) >= 0.3,
		"[fairness] a sloppy one still lands most common fish, fewer very rare ones (%s)" % [sloppy])
	t.check(longest < 12.0, "[fairness] even four checks take a careful captain under 12 s (%.1f s)" % longest)


# --- Weights and grades ----------------------------------------------------------------

func _test_weights_and_grades() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 4
	var outside := PackedStringArray()
	var grades := {}
	for i in 3000:
		var region_geo: Vector2 = [Vector2(12.6, 55.7), Vector2(-15.4, 28.1), Vector2(-61.0, 14.0), Vector2(5.4, 43.3)][i % 4]
		var fish := catalog.pick(rng, region_geo, FishingState.MODE_TROLLING, "spoon")
		if fish.is_empty():
			continue
		var spec := catalog.get_species(fish.species)
		if float(fish.kg) < float(spec.kg[0]) - 1e-6 or float(fish.kg) > float(spec.kg[1]) + 1e-6:
			outside.append("%s %.2f" % [fish.species, fish.kg])
		var g := catalog.grade(fish.species, float(fish.kg))
		grades[g] = int(grades.get(g, 0)) + 1
	t.check(outside.is_empty(), "[weight] every fish weighs within its species' range%s" % ("" if outside.is_empty() else ": " + outside[0]))
	t.check(grades.size() == 4 and int(grades.get(FishingCatalog.GRADE_GOLD, 0)) < int(grades.get(FishingCatalog.GRADE_NONE, 0)),
		"[grade] all four grades occur, Gold rarer than ordinary (%s)" % [grades])
	# Grades are by weight within the species only.
	t.check_eq(catalog.grade("herring", 0.45), FishingCatalog.GRADE_GOLD, "[grade] a common herring at the top of its range is Gold")
	t.check_eq(catalog.grade("yellowfin", 8.5), FishingCatalog.GRADE_NONE, "[grade] a very rare yellowfin that is small for its kind is ordinary")
	t.check(catalog.grade("cod", lerpf(1.0, 12.0, 0.36)) == FishingCatalog.GRADE_BRONZE and catalog.grade("cod", lerpf(1.0, 12.0, 0.61)) == FishingCatalog.GRADE_SILVER
		and catalog.grade("cod", lerpf(1.0, 12.0, 0.81)) == FishingCatalog.GRADE_GOLD,
		"[grade] Bronze from 35 %, Silver from 60 %, Gold from 80 % of the species' range")
	t.check(catalog.grade("old_boot", 0.0) == FishingCatalog.GRADE_NONE, "[grade] junk has no grade")
	# Perfect hits nudge the weight, within the range, nothing else.
	var base := 3.0
	var one := catalog.landed_kg("cod", base, 1)
	var four := catalog.landed_kg("cod", base, 4)
	var many := catalog.landed_kg("cod", 11.9, 50)
	t.check(catalog.landed_kg("cod", base, 0) == base and one > base and four > one and four < base + (12.0 - base) * 0.3,
		"[perfect] each Perfect adds a little weight (3.0 -> %.2f -> %.2f kg), modestly" % [one, four])
	t.check(many <= 12.0, "[perfect] never beyond the species' largest (%.2f kg)" % many)


# --- Art --------------------------------------------------------------------------------

func _test_art_coverage() -> void:
	var missing := PackedStringArray()
	var ids := []
	for fish in catalog.species:
		ids.append(String(fish.id))
	for item in catalog.junk:
		ids.append(String(item.id))
	for id: String in ids:
		var ok := FishArt.has_art(id) and FishArt.thumbnail(id) != null
		if FishArt.is_animated(id):
			ok = ok and FishArt.layer(id, "body") != null and FishArt.layer(id, "tail") != null and FishArt.layer(id, "lid") != null
		else:
			ok = ok and FishArt.layer(id, "art") != null
		if not ok:
			missing.append(id)
	t.check(missing.is_empty(), "[art] every species (%d) and piece of junk (%d) has its illustrated picture%s" % [
		catalog.species.size(), catalog.junk.size(), "" if missing.is_empty() else ": missing " + ", ".join(missing)])
	var kinds_ok := true
	for id: String in ids:
		var expected := "junk" if catalog.kind_of(id) == FishingCatalog.KIND_JUNK else ("shark" if catalog.is_shark(id) else "fish")
		kinds_ok = kinds_ok and String(FishArt.get_info(id).get("kind", "")) == expected
	t.check(kinds_ok, "[art] fish, sharks and junk are drawn as what they are; junk does not blink (%s)" % FishArt.is_animated("old_boot"))
	# Recognizable: no two species share a silhouette (not one shape recoloured).
	var masks := {}
	for fish in catalog.species:
		var image := FishArt.layer(String(fish.id), "body").get_image()
		image.decompress()
		image.resize(128, 64, Image.INTERPOLATE_BILINEAR)
		masks[String(fish.id)] = image
	var closest := 0.0
	var pair := ""
	var keys := masks.keys()
	for i in keys.size():
		for j in range(i + 1, keys.size()):
			var overlap := _silhouette_overlap(masks[keys[i]], masks[keys[j]])
			if overlap > closest:
				closest = overlap
				pair = "%s/%s" % [keys[i], keys[j]]
	t.check(closest < 0.93, "[art] every species has its own body shape (most alike: %s, %.0f %% overlap)" % [pair, closest * 100.0])


static func _silhouette_overlap(a: Image, b: Image) -> float:
	var both := 0
	var either := 0
	for y in a.get_height():
		for x in a.get_width():
			var in_a := a.get_pixel(x, y).a > 0.5
			var in_b := b.get_pixel(x, y).a > 0.5
			if in_a and in_b:
				both += 1
			if in_a or in_b:
				either += 1
	return float(both) / maxf(either, 1.0)


func _test_portrait() -> void:
	var holder := Control.new()
	app.add_child(holder)
	var p1 := FishPortrait.new()
	p1.custom_minimum_size = Vector2(400, 200)
	p1.size = Vector2(400, 200)
	holder.add_child(p1)
	p1.set_species("mackerel")
	var p2 := FishPortrait.new()
	holder.add_child(p2)
	p2.set_species("mackerel")
	await t.frames(1)
	t.check(p1.is_animating(), "[alive] a shown fish portrait animates")
	var blink_at := -1.0
	var opened_at := -1.0
	var flick_max := 0.0
	var flick_ended := false
	var p2_blinks := []
	var clock := 0.0
	for i in 600:  # ten seconds at 60 frames per second
		p1.advance(1.0 / 60.0)
		p2.advance(1.0 / 60.0)
		clock += 1.0 / 60.0
		if p1.is_eye_closed() and blink_at < 0.0:
			blink_at = clock
		if blink_at >= 0.0 and opened_at < 0.0 and not p1.is_eye_closed():
			opened_at = clock
		if p2.is_eye_closed() and (p2_blinks.is_empty() or clock - float(p2_blinks.back()) > 0.5):
			p2_blinks.append(clock)
		flick_max = maxf(flick_max, absf(p1.get_tail_degrees()))
		if flick_max > 1.0 and absf(p1.get_tail_degrees()) < 0.01:
			flick_ended = true
	t.check(blink_at >= 0.0 and blink_at < 7.0, "[alive] the fish blinks within a few seconds (at %.1f s)" % blink_at)
	t.check(opened_at > 0.0 and opened_at - blink_at <= 0.2, "[alive] a quick blink (%.2f s)" % (opened_at - blink_at))
	t.check(flick_max > 5.0 and flick_max <= FishPortrait.FLICK_DEG + 0.1 and flick_ended,
		"[alive] it flicks its tail now and then, modestly (%.1f degrees), and settles" % flick_max)
	t.check(p2_blinks.is_empty() or absf(float(p2_blinks[0]) - blink_at) > 0.05,
		"[alive] two fish do not blink in step (%.2f s vs %s)" % [blink_at, p2_blinks])
	t.check(p1.find_children("*", "Timer", true, false).is_empty(), "[alive] no timers: one light step per frame")
	SettingsManager.set_reduce_motion(true)
	var still_max := 0.0
	var blinked := false
	for i in 600:
		p1.advance(1.0 / 60.0)
		still_max = maxf(still_max, absf(p1.get_tail_degrees()))
		blinked = blinked or p1.is_eye_closed()
	SettingsManager.set_reduce_motion(false)
	t.check(still_max == 0.0 and blinked, "[alive] Reduce motion: the tail stays still (the blink stays)")
	p1.visible = false
	await t.frames(1)
	t.check(not p1.is_animating(), "[alive] a hidden portrait stops animating")
	var boot := FishPortrait.new()
	holder.add_child(boot)
	boot.set_species("old_boot")
	await t.frames(1)
	t.check(not boot.is_animating(), "[alive] junk does not move or blink")
	holder.queue_free()
	await t.frames(2)
	t.check(not is_instance_valid(p1), "[alive] closed with its screen, nothing left running")


# --- Keeping, releasing, trophies --------------------------------------------------------

func _test_keep_and_trophies() -> void:
	GameSession.set_keep_preferences("common", FishingCatalog.GRADE_NONE)
	_force_bite("herring", 0.2)
	var kept := GameSession.finish_fight(true)
	t.check(kept.kept and kept.released_reason == "" and GameSession.get_fishing().trophies.size() == 1,
		"[keep] by default every fish is kept (and a first catch makes the board)")
	GameSession.set_keep_preferences("rare", FishingCatalog.GRADE_SILVER)
	var fishing := GameSession.get_fishing()
	t.check(fishing.keep_min_rarity == "rare" and fishing.keep_min_grade == FishingCatalog.GRADE_SILVER, "[keep] the preferences are set")
	t.check(FishingMenu.describe_keep(fishing).contains("rare fish or rarer") and FishingMenu.describe_keep(fishing).contains("Silver"),
		"[keep] and explained (%s)" % FishingMenu.describe_keep(fishing))
	var funds := GameSession.get_funds()
	var hold_before := fishing.hold.size()
	var trophies_before := fishing.trophies.size()
	_force_bite("cod", 11.0)  # uncommon (below Rare), Gold
	var auto := GameSession.finish_fight(true)
	fishing = GameSession.get_fishing()
	t.check(auto.landed and not auto.kept and auto.released_reason == "preferences" and String(auto.text).contains("preferences"),
		"[keep] an uncommon cod is released by the rarity rule, with the reason (%s)" % auto.text)
	t.check(fishing.hold.size() == hold_before and fishing.trophies.size() == trophies_before and GameSession.get_funds() == funds,
		"[keep] a released fish: not in the cool box, not a trophy, no money")
	_force_bite("sea_trout", 1.5)  # rare, but small (ordinary)
	var small := GameSession.finish_fight(true)
	t.check(not small.kept and small.released_reason == "preferences", "[keep] a small rare trout is released by the size rule (both must hold)")
	_force_bite("sea_trout", 5.6)  # rare and Gold
	var keeper := GameSession.finish_fight(true)
	fishing = GameSession.get_fishing()
	t.check(keeper.kept and fishing.find_in_hold(int(keeper.fish.uid)) >= 0, "[keep] a big rare trout meets both: kept")
	t.check(fishing.trophies.any(func(trophy: Dictionary) -> bool: return int(trophy.uid) == int(keeper.fish.uid)),
		"[trophies] and goes on the trophy board")
	var stored := fishing.hold.filter(func(fish: Dictionary) -> bool: return int(fish.uid) == int(keeper.fish.uid)).size()
	t.check_eq(stored, 1, "[keep] stored exactly once")
	t.check(GameSession.release_fish(int(keeper.fish.uid)), "[release] released by hand from the cool box")
	fishing = GameSession.get_fishing()
	t.check(not fishing.trophies.any(func(trophy: Dictionary) -> bool: return int(trophy.uid) == int(keeper.fish.uid)),
		"[release] a released fish leaves the trophy board")
	t.check(not GameSession.release_fish(int(keeper.fish.uid)), "[release] and cannot be released twice")
	t.check_eq(GameSession.finish_fight(true).landed, false, "[integrity] finishing again without a bite lands nothing")
	GameSession.set_keep_preferences("common", FishingCatalog.GRADE_NONE)


func _test_sharks_and_junk() -> void:
	var copenhagen := Vector2(12.6, 55.7)
	var danish := catalog.candidates(copenhagen, FishingState.MODE_TROLLING, "spoon")
	t.check(not danish.any(func(c: Dictionary) -> bool: return catalog.is_shark(c.species)), "[shark] no sharks in Danish waters")
	var caribbean := catalog.candidates(Vector2(-61.0, 14.0), FishingState.MODE_STATIONARY, "soft")
	var canaries := catalog.candidates(Vector2(-15.4, 28.1), FishingState.MODE_TROLLING, "spoon")
	t.check(caribbean.any(func(c: Dictionary) -> bool: return c.species == "blacktip_reef_shark")
		and canaries.any(func(c: Dictionary) -> bool: return c.species == "blue_shark"),
		"[shark] blacktip reef sharks in the Caribbean, blue sharks off the Canaries")
	t.check(catalog.rarity_of("blue_shark") == "rare", "[shark] sharks are rare encounters")
	var fishing := GameSession.get_fishing()
	var hold := fishing.hold.size()
	var trophies := fishing.trophies.size()
	var funds := GameSession.get_funds()
	_force_bite("blue_shark", 60.0)
	var shark := GameSession.finish_fight(true)
	fishing = GameSession.get_fishing()
	t.check(shark.landed and not shark.kept and shark.released_reason == "shark" and String(shark.text).contains("swim free"),
		"[shark] landed, then always released (%s)" % shark.text)
	t.check(fishing.hold.size() == hold and fishing.trophies.size() == trophies and GameSession.get_funds() == funds and fishing.sharks_released == 1,
		"[shark] not food, not for sale, not a trophy; counted as released")
	# Junk.
	_force_bite("old_boot", 0.0)
	var boot := GameSession.finish_fight(true)
	fishing = GameSession.get_fishing()
	t.check(boot.landed and boot.kind == "junk" and boot.released_reason == "junk" and not boot.kept and String(boot.rarity) == "",
		"[junk] an old boot comes up: no rarity, discarded (%s)" % boot.text)
	t.check(fishing.hold.size() == hold and fishing.trophies.size() == trophies and not fishing.records.has("old_boot") and fishing.junk_caught == 1,
		"[junk] no cool box, no trophy, no catch record; just counted")
	# How often junk bites: about junk_chance of the bites.
	var rng := RandomNumberGenerator.new()
	var bites := 0
	var junk := 0
	for i in 4000:
		rng.seed = hash("junk|%d" % i)
		var fish := catalog.pick(rng, copenhagen, FishingState.MODE_STATIONARY, "spinner")
		if fish.is_empty():
			continue
		bites += 1
		if rng.randf() < catalog.junk_chance:
			junk += 1
	var share := float(junk) / maxf(bites, 1.0)
	t.check(share > 0.03 and share < 0.09, "[junk] occasional: %.1f %% of bites" % (share * 100.0))


# --- Reaching the rod ---------------------------------------------------------------

func _test_bite_access() -> void:
	app.modals.clear()
	GameSession.enter_boat_area(SessionState.AREA_INTERIOR, &"start")
	app._show_current_boat_area()
	await _settle()
	_force_bite("mackerel", 0.8)
	GameSession.fish_bite.emit(GameSession.get_pending_bite())
	await t.frames(2)
	t.check("Fish on! Reel in" in app.hud.aboard_badge.get_texts(), "[bite] the HUD says how to reel in")
	var wheel: Array = app.get_wheel_actions().map(func(a: Dictionary) -> StringName: return a.id)
	t.check(wheel.size() > 0 and wheel[0] == &"reel_in", "[bite] in the cabin the action wheel offers \"Reel in!\" first (%s)" % [wheel])
	await t.press_action(&"reel_in")
	await t.frames(2)
	var menu := app.modals.get_top() as FishingMenu
	t.check(menu != null and menu.is_reeling(), "[bite] R from the cabin goes straight to the reel-in")
	if menu:
		menu.let_go()
		t.check(GameSession.get_pending_bite().is_empty() and not menu.is_reeling(), "[bite] Let it go: the catch swims off, nothing landed")
	app.modals.clear()
	await t.frames(2)


func _test_menu_flow() -> void:
	app.modals.clear()
	_force_bite("cod", 7.0)
	var menu: FishingMenu = app.open_fishing()
	await t.frames(2)
	if not t.check(menu != null and menu.is_reeling(), "[menu] the rod opens on the reel-in when a fish is on"):
		return
	var badge := menu.find_child("ReelBadge", true, false) as CatchBadge
	t.check(badge.get_text().contains("Uncommon") and not badge.get_text().contains("Gold"),
		"[reveal] the rarity is shown in words before landing; the grade is not known yet (%s)" % badge.get_text())
	t.check(menu.get_reel_portrait().species_id == "cod" and menu.get_reel_portrait().is_animating(), "[reveal] the cod's own picture, alive")
	var hold_before := GameSession.get_fishing().hold.size()
	t.check(Reel.land(menu), "[menu] landed through the dial")
	var result: Dictionary = menu.get_last_result()
	t.check(menu.get_result_portrait().species_id == "cod" and not menu.get_reel_portrait().is_animating(),
		"[result] the same cod on the result card; the reel-in picture stops")
	var text: String = menu.get_outcome_text()
	t.check(text.contains("kg") and text.contains("specimen") and text.contains("Perfect"), "[result] weight, grade and the Perfect hits (%s)" % text)
	t.check(float(result.fish.kg) > 7.0, "[result] Perfect hits made it a little heavier (%.2f kg)" % float(result.fish.kg))
	t.check_eq(menu.press_reel(), ReelTiming.PRESS_NONE, "[integrity] pressing after the catch does nothing")
	t.check_eq(GameSession.get_fishing().hold.size(), hold_before + 1, "[integrity] one cod in the cool box, once")
	(menu.find_child("ReleaseCatch", true, false) as Button).pressed.emit()
	t.check(GameSession.get_fishing().find_in_hold(int(result.fish.uid)) < 0
		and not GameSession.get_fishing().trophies.any(func(tr: Dictionary) -> bool: return int(tr.uid) == int(result.fish.uid)),
		"[release] Release on the result card: out of the cool box and off the board")
	menu.close()
	await t.frames(2)


func _test_persistence() -> void:
	GameSession.set_keep_preferences("uncommon", FishingCatalog.GRADE_BRONZE)
	GameSession.set_passage_posture(FishingState.PASSAGE_KEEPERS)
	var data := GameSession.get_state_snapshot().to_dict()
	var errors: Array[String] = []
	var restored := SessionState.from_dict(JSON.parse_string(JSON.stringify(data)), errors)
	t.check(restored != null and restored.fishing.keep_min_rarity == "uncommon" and restored.fishing.keep_min_grade == FishingCatalog.GRADE_BRONZE
		and restored.fishing.passage_posture == FishingState.PASSAGE_KEEPERS and restored.fishing.junk_caught == GameSession.get_fishing().junk_caught,
		"[save] keep preferences, the fast-time choice and the counters round-trip")
	# A 0.104a save has none of them: defaults.
	var old := data.duplicate(true)
	for key in ["keep_min_rarity", "keep_min_grade", "passage_posture", "sharks_released", "junk_caught"]:
		old.fishing.erase(key)
	var from_old := SessionState.from_dict(JSON.parse_string(JSON.stringify(old)), errors)
	t.check(from_old != null and from_old.fishing.keep_min_rarity == "common" and from_old.fishing.keep_min_grade == FishingCatalog.GRADE_NONE
		and from_old.fishing.passage_posture == FishingState.PASSAGE_ALL, "[save] a 0.104a save loads with keep-everything defaults")
	t.check(not GameSession.get_state_snapshot().to_dict().has("pending_bite"), "[save] a bite on the line is never saved (no repeat after loading)")
	GameSession.set_keep_preferences("common", FishingCatalog.GRADE_NONE)
	GameSession.set_passage_posture(FishingState.PASSAGE_ALL)


## Rod fishing at anchor (a still boat, not trolling), and the fast-time
## choice: "only fish worth keeping" lets the others swim off without
## stopping anything (and gives nothing).
func _test_anchored_and_fast_time() -> void:
	app.modals.clear()
	t.set_wind(90.0, 9.0)
	GameSession.plan_route_to(&"malmo")
	t.check_eq(GameSession.depart(), "", "(setup) depart for Malmö")
	var near := false
	for i in 120:
		Simulation.advance(300.0)
		if GameSession.evaluate_anchorage().ok:
			near = true
			break
	if not t.check(near and GameSession.drop_anchor(5, 0.9).error == "", "(setup) at anchor off the coast"):
		return
	t.check_eq(GameSession.get_fishing_mode(), FishingState.MODE_STATIONARY, "[still] at anchor one fishes with a rod from a still boat, not trolling")
	GameSession.set_line(true, "spinner")
	var menu: FishingMenu = app.open_fishing()
	await t.frames(2)
	t.check(menu != null and menu.get_info_text().begins_with("Rod fishing from the anchored boat"), "[still] the rod says so (%s)" % (menu.get_info_text() if menu else ""))
	app.modals.clear()
	var bit := false
	for i in 300:
		if Simulation.advance(300.0).bite:
			bit = true
			break
	var bite := GameSession.get_pending_bite()
	t.check(bit and String(bite.get("mode", "")) == "stationary", "[still] fish bite at anchor (%s)" % bite.get("species", "none"))
	GameSession.expire_bite()
	t.check_eq(GameSession.raise_anchor(), "", "(setup) anchor up, sailing on")
	# Fast time with "only fish worth keeping" (very rare only).
	GameSession.set_keep_preferences("very_rare", FishingCatalog.GRADE_NONE)
	GameSession.set_passage_posture(FishingState.PASSAGE_KEEPERS)
	GameSession.set_line(true, "spinner")
	GameSession.take_quiet_nibbles()
	GameSession.set_time_scale(20)
	var interrupted := 0
	for i in 72:  # six hours
		var result := Simulation.advance(300.0, true)
		if result.stopped_by == Simulation.STOP_BITE:
			interrupted += 1
			var keeper := GameSession.get_pending_bite()
			t.check(String(keeper.get("rarity", "")) == "very_rare", "[fast] it stopped only for a keeper (%s)" % keeper.get("species", "?"))
			GameSession.expire_bite()
		if not GameSession.is_underway():
			break
	var nibbles := GameSession.take_quiet_nibbles()
	t.check(nibbles > 0, "[fast] bites from fish not worth keeping swam off without stopping the passage (%d, stops %d)" % [nibbles, interrupted])
	var caught := GameSession.get_fishing().total_caught
	GameSession.set_passage_posture(FishingState.PASSAGE_ALL)
	var stopped := false
	for i in 72:
		if Simulation.advance(300.0, true).stopped_by == Simulation.STOP_BITE:
			stopped = true
			break
	t.check(stopped and GameSession.get_fishing().total_caught == caught, "[fast] \"Stop for every bite\": the next bite stops time; nothing was caught unattended")
	GameSession.expire_bite()
	# No storm of stops: for a few game hours after one, bites nibble quietly.
	GameSession.take_quiet_nibbles()
	var again := false
	var elapsed := 0.0
	while elapsed < GameSession.FAST_BITE_COOLDOWN_S - 600.0:
		if Simulation.advance(300.0, true).stopped_by == Simulation.STOP_BITE:
			again = true
		elapsed += 300.0
	t.check(not again, "[fast] after a bite stop, no further bite stops for %d game hours (%d nibbled quietly)" % [
		roundi(GameSession.FAST_BITE_COOLDOWN_S / 3600.0), GameSession.take_quiet_nibbles()])
	GameSession.set_time_scale(1)
	GameSession.set_line(false)
	GameSession.set_keep_preferences("common", FishingCatalog.GRADE_NONE)
