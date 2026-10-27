class_name AnchorSite
extends RefCounted
## Where the boat can anchor, and how well it holds (Iteration 13; worldwide
## since Revision 0.105b).
##
## Three separate questions (0.105b), never mixed:
##   1. can the boat get there? Water on the fine coastal raster
##      (CoastalGeography), not too close to the shore (clear water, at least
##      ~0.3 nm off), and a short checked approach from the router's water
##      (CoastalGeography.approach) - so a near-shore spot the coarse world
##      routing chart cannot express is still reachable, and a lagoon behind a
##      narrow entrance is not;
##   2. is the water right for the anchor? Depth from DepthService (in this
##      build always a labelled GAME ESTIMATE): the normal anchor works from
##      MIN_DEPTH_M to NORMAL_MAX_DEPTH_M; the Magic Anchor (fictional
##      equipment) anywhere the boat can float, including deep water and the
##      open sea ("emergency": more than COASTAL_NM from land);
##   3. how sheltered is it in this wind? The fetch: open water upwind before
##      land, measured on the fine raster (at most MAX_FETCH_NM). Land close
##      upwind shelters; a long fetch (or the open sea) is exposed. Advisory: a
##      wind shift can turn a good anchorage poor, and no anchor removes the
##      wind.
## Holding (unchanged): what the anchor can hold (more chain, a well-set
## anchor, shelter, heavier gear, a well-placed Magic Anchor) against the wind
## it feels. The holding model has no depth term, so the Magic Anchor uses it
## exactly as the normal one does ("effective depth" = the chosen scope);
## the real (estimated) depth is stored and shown separately.
## The seabed is assumed to be a reasonable mixed bottom everywhere; the game
## does not pretend to know better.

## (Iteration 13 rule, no longer used for eligibility: kept for old notes.)
const MAX_LAND_NM := 2.5
const MAX_FETCH_NM := 8.0
const FETCH_STEP_NM := 0.25
## Too much wind to anchor at all (sustained, knots): normal anchor.
const MAX_ANCHORING_WIND_KN := 34.0
## The Magic Anchor can go down in a storm, but not in a hurricane.
const MAX_MAGIC_WIND_KN := 55.0
## Depth for the normal anchor (m): enough water under the keel, and chain
## enough for the deepest (7:1 scope = 175 m of chain).
const MIN_DEPTH_M := 2.5
const NORMAL_MAX_DEPTH_M := 25.0
## Planning an anchorage keeps at least this far off the shore (nm, ~370 m).
const MIN_SHORE_NM := 0.2
## Further than this from land a Magic Anchor deployment is "offshore":
## holding position, not shelter.
const COASTAL_NM := 3.0

const KIND_NORMAL := &"normal"
const KIND_MAGIC := &"magic"

const SHELTERED := &"sheltered"
const PARTLY := &"partly sheltered"
const EXPOSED := &"exposed"

const CLASS_GOOD := &"good"
const CLASS_FAIR := &"fair"
const CLASS_POOR := &"poor"
const CLASS_UNSUITABLE := &"unsuitable"

## Holding: a base, plus chain (scope), the set and shelter; against the wind.
const BASE_HOLD_KN := 16.0
const SCOPE_BONUS := {3: 0.0, 5: 6.0, 7: 10.0}
const SET_BONUS_KN := 8.0
const SHELTER_BONUS := {SHELTERED: 8.0, PARTLY: 4.0, EXPOSED: 0.0}
## How much of the open-sea wind and gusts reaches a boat in this shelter.
const EXPOSURE := {SHELTERED: 0.55, PARTLY: 0.8, EXPOSED: 1.0}
## Margins (knots) between holding power and wind for each holding level.
const WELL_MARGIN := 8.0
const FAIR_MARGIN := 3.0


## The anchorage at `geo` in the wind `sample`, for a boat with (`magic`) or
## without the Magic Anchor aboard. `at_boat`: the boat is already there (it
## got there along its course), so the approach need not be searched.
## Keys: "class", "ok", "kind" (normal / magic / ""), "reason", "land_nm",
## "fetch_nm", "shelter", "water", "reachable", "depth_m", "depth_source",
## "depth_label", "normal_ok", "magic_ok", "offshore", "approach".
static func evaluate(geo: Vector2, sample: WindField.Sample, magic := false, at_boat := true) -> Dictionary:
	var result := {"class": CLASS_UNSUITABLE, "ok": false, "kind": &"", "reason": "", "land_nm": INF, "fetch_nm": MAX_FETCH_NM,
		"shelter": EXPOSED, "water": false, "reachable": false, "depth_m": 0.0, "depth_source": &"", "depth_label": "",
		"normal_ok": false, "magic_ok": false, "offshore": false, "approach": PackedVector2Array()}
	var coast := CoastalGeography.get_default()
	if not coast.is_water(geo):
		result.reason = Loc.t("Land or unsuitable water.")
		return result
	result.water = true
	var depth := DepthService.get_default().sample(geo)
	result.depth_m = float(depth.depth_m)
	result.depth_source = depth.source
	result.depth_label = String(depth.label)
	result.land_nm = float(depth.shore_nm)
	result.offshore = result.land_nm >= COASTAL_NM
	if not at_boat:
		if not coast.is_clear(geo) or result.land_nm < MIN_SHORE_NM:
			result.reason = Loc.t("Too close to the shore for the boat: keep a little further off.")
			return result
		result.approach = coast.approach(geo)
		if result.approach.is_empty():
			result.reason = Loc.t("No safe approach: the boat cannot get in there from open water.")
			return result
	result.reachable = true
	var fetch: float = coast.fetch_nm(geo, sample.from_deg) if not result.offshore else MAX_FETCH_NM
	result.fetch_nm = fetch
	result.shelter = shelter_for(fetch)
	var depth_ok: bool = result.depth_m >= MIN_DEPTH_M and result.depth_m <= NORMAL_MAX_DEPTH_M
	result.normal_ok = depth_ok and sample.speed_kn <= MAX_ANCHORING_WIND_KN
	result.magic_ok = magic and sample.speed_kn <= MAX_MAGIC_WIND_KN
	if result.normal_ok:
		result.kind = KIND_NORMAL
	elif result.magic_ok:
		result.kind = KIND_MAGIC
	if result.kind == &"":
		if sample.speed_kn > (MAX_MAGIC_WIND_KN if magic else MAX_ANCHORING_WIND_KN):
			result.reason = Loc.t("Too much wind to anchor safely (%d kn).") % roundi(sample.speed_kn)
		elif result.depth_m < MIN_DEPTH_M:
			result.reason = Loc.t("Too shallow for the boat here.")
		elif sample.speed_kn > MAX_ANCHORING_WIND_KN:
			result.reason = Loc.t("Too much wind for the normal anchor (%d kn).") % roundi(sample.speed_kn)
		else:
			result.reason = Loc.t("Deep water (%s, %s): too deep for the normal anchor to reach the bottom.%s") % [
				DepthService.describe_depth(result.depth_m), result.depth_label,
				"" if magic else Loc.t(" A Magic Anchor could hold here.")]
		return result
	result.ok = true
	result.class = {SHELTERED: CLASS_GOOD, PARTLY: CLASS_FAIR, EXPOSED: CLASS_POOR}[result.shelter]
	result.reason = describe(result)
	return result


## Only the shelter at `geo` in this wind (cheap: for the anchor checks).
static func shelter_at(geo: Vector2, sample: WindField.Sample) -> StringName:
	var coast := CoastalGeography.get_default()
	if coast.shore_distance_nm(geo, COASTAL_NM) >= COASTAL_NM:
		return EXPOSED
	return shelter_for(coast.fetch_nm(geo, sample.from_deg))


static func shelter_for(fetch: float) -> StringName:
	if fetch <= 1.5:
		return SHELTERED
	if fetch <= 4.0:
		return PARTLY
	return EXPOSED


## Open water upwind of `geo` (nm, at most MAX_FETCH_NM): the wind comes from
## `from_deg`. On the fine coastal raster (0.105b).
static func fetch_nm(geo: Vector2, from_deg: float) -> float:
	return CoastalGeography.get_default().fetch_nm(geo, from_deg)


## The point `nm` from `geo` on bearing `bearing` (radians, true): a flat
## approximation, fine for these few miles.
static func offset(geo: Vector2, bearing: float, nm: float) -> Vector2:
	var lat := geo.y + nm / 60.0 * cos(bearing)
	var lon := geo.x + nm / 60.0 * sin(bearing) / maxf(cos(deg_to_rad(geo.y)), 0.05)
	return Vector2(lon, lat)


## Holding level for an anchor on `scope`:1 chain, set with `set_quality`
## (0..1), in `shelter`, against `sample`'s wind. `bonus_kn`: extra holding
## from heavier ground tackle (Iteration 14 equipment).
static func holding(scope: int, set_quality: float, shelter: StringName, sample: WindField.Sample, bonus_kn := 0.0) -> StringName:
	var margin := holding_margin(scope, set_quality, shelter, sample) + bonus_kn
	if margin >= WELL_MARGIN:
		return AnchorState.HOLDING_WELL
	if margin >= FAIR_MARGIN:
		return AnchorState.HOLDING_FAIR
	if margin >= 0.0:
		return AnchorState.HOLDING_POOR
	return AnchorState.HOLDING_DRAGGING


## Holding power minus the wind the anchor feels (knots; negative: dragging).
static func holding_margin(scope: int, set_quality: float, shelter: StringName, sample: WindField.Sample) -> float:
	var power := BASE_HOLD_KN + float(SCOPE_BONUS.get(scope, 0.0)) + SET_BONUS_KN * clampf(set_quality, 0.0, 1.0) \
		+ float(SHELTER_BONUS.get(shelter, 0.0))
	var gust := sample.speed_kn
	var weather := sample as WeatherSample
	if weather:
		gust = maxf(sample.speed_kn, weather.gust_kn * 0.8)
	return power - gust * float(EXPOSURE.get(shelter, 1.0))


static func holding_text(holding: StringName) -> String:
	return {AnchorState.HOLDING_WELL: Loc.t("Holding well"), AnchorState.HOLDING_FAIR: Loc.t("Fair holding"),
		AnchorState.HOLDING_POOR: Loc.t("Poor holding"), AnchorState.HOLDING_DRAGGING: Loc.t("Anchor dragging")}.get(holding, "")


static func describe(site: Dictionary) -> String:
	var depth := "%s, %s" % [DepthService.describe_depth(float(site.get("depth_m", 0.0))), site.get("depth_label", "")]
	var magic := StringName(site.get("kind", &"")) == KIND_MAGIC
	var prefix := Loc.t("Magic Anchor: ") if magic else ""
	if magic and bool(site.get("offshore", false)):
		return Loc.t("Magic Anchor, open sea (%s): it will hold the boat's position, but there is no shelter out here from wind or waves.") % depth
	match StringName(site.class):
		CLASS_GOOD:
			return Loc.format("%sA good anchorage: sheltered from this wind (depth %s; land %.1f nm away).", [prefix, depth, float(site.land_nm)])
		CLASS_FAIR:
			return Loc.format("%sA fair anchorage: partly sheltered from this wind (depth %s; land %.1f nm away).", [prefix, depth, float(site.land_nm)])
		CLASS_POOR:
			return Loc.format("%sAn exposed anchorage: this wind blows straight in over %.0f+ nm of open water. Holding may be poor (depth %s).", [prefix, float(site.fetch_nm), depth])
	return String(site.reason)


## A friendly line for the chart's anchorage highlights (0.105b): whether the
## spot suits the normal anchor or needs the Magic Anchor, the depth and where
## it came from, and the shelter in the current wind (advisory).
static func describe_for_chart(site: Dictionary, magic_owned: bool) -> String:
	if not bool(site.get("water", false)):
		return Loc.t("Land or unsuitable water.")
	var depth := Loc.t("Depth %s (%s).") % [DepthService.describe_depth(float(site.depth_m)), site.depth_label]
	if not bool(site.get("reachable", false)):
		if String(site.reason).begins_with("Too close"):
			return Loc.t("Too close to the shore for the boat. ") + depth
		return Loc.t("No safe approach from open water. ") + depth
	var shelter: String = {SHELTERED: Loc.t("Sheltered from the current wind."), PARTLY: Loc.t("Partly sheltered from the current wind."),
		EXPOSED: Loc.t("Coast exposed to the current wind.")}.get(site.shelter, "")
	if bool(site.get("offshore", false)):
		shelter = Loc.t("Open sea: no shelter.")
	var deep: bool = float(site.depth_m) > NORMAL_MAX_DEPTH_M
	if bool(site.get("normal_ok", false)):
		return Loc.t("Suitable for ordinary anchoring. %s %s") % [depth, shelter]
	if deep:
		var how := "" if magic_owned else Loc.t(" (fit one free at any boatyard)")
		return Loc.t("Deep water: Magic Anchor required%s. %s %s") % [how, depth, shelter]
	return "%s %s" % [String(site.reason), depth]
