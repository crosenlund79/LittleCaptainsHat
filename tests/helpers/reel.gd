extends RefCounted
## Test helper (Iteration 18): reels in whatever is on in an open FishingMenu
## through its own dial - the needle is stepped round (real time, past the
## press debounce) and the press made while it is inside the target arc
## (`where`: "perfect" in the middle of the arc, "edge" just inside its edge).
## Returns whether the catch was landed.


static func land(menu: FishingMenu, where := "perfect") -> bool:
	var guard := 0
	while menu.is_reeling() and guard < 50:
		guard += 1
		var reel := menu.get_reel()
		menu.step_reel(ReelTiming.DEBOUNCE + 0.01)
		if not menu.is_reeling():
			break
		var offset := 0.0 if where == "perfect" else reel.arc_deg / 2.0 - 1.0
		reel.angle = fposmod(reel.target_deg + offset, 360.0)
		menu.press_reel()
	return bool(menu.get_last_result().get("landed", false))
