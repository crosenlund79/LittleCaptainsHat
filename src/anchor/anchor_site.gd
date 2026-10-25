class_name AnchorSite
extends RefCounted
## Where the boat can anchor, and how well it holds (Iteration 13).
##
## The game has no depth soundings or seabed charts, so this is a
## deliberately conservative gameplay rule built only on the chart's own
## land/water grid (NavGrid, about one arc-minute per cell), never on invented
## depths:
##   - anchoring is offered only near a coast: in open water, with land
##     within MAX_LAND_NM (the bottom is assumed within reach of the chain
##     there, and too deep further out);
##   - shelter is the fetch: how far the wind blows over open water before it
##     reaches the boat (a ray from the boat towards where the wind comes
##     from, until it meets land, at most MAX_FETCH_NM). Land close upwind is
##     a sheltered anchorage; a long fetch is exposed. A wind shift can turn a
##     good anchorage into a poor one;
##   - holding compares what the anchor can hold (more chain, a well-set
##     anchor and shelter help) with the wind it has to hold against.
## The seabed is assumed to be a reasonable mixed bottom everywhere; the game
## does not pretend to know better.

const MAX_LAND_NM := 2.5
const MAX_FETCH_NM := 8.0
const FETCH_STEP_NM := 0.25
## Too much wind to anchor at all (sustained, knots).
const MAX_ANCHORING_WIND_KN := 34.0

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


## The anchorage at `geo` in the wind `sample`: {"class", "ok", "reason",
## "land_nm", "fetch_nm", "shelter"}.
static func evaluate(geo: Vector2, sample: WindField.Sample) -> Dictionary:
	var result := {"class": CLASS_UNSUITABLE, "ok": false, "reason": "", "land_nm": INF, "fetch_nm": MAX_FETCH_NM, "shelter": EXPOSED}
	var grid := SeaRouter.get_default().grid
	if grid == null or not grid.is_navigable(geo):
		result.reason = "This is not open water."
		return result
	var land := HatStory.open_water_nm(geo, MAX_LAND_NM + 0.5)
	result.land_nm = land
	var fetch := fetch_nm(geo, sample.from_deg)
	result.fetch_nm = fetch
	result.shelter = shelter_for(fetch)
	if land > MAX_LAND_NM:
		result.reason = "Too far from the coast: the water is too deep to anchor here. Anchor within %.1f nm of land." % MAX_LAND_NM
		return result
	if sample.speed_kn > MAX_ANCHORING_WIND_KN:
		result.reason = "Too much wind to anchor safely (%d kn)." % roundi(sample.speed_kn)
		return result
	result.ok = true
	result.class = {SHELTERED: CLASS_GOOD, PARTLY: CLASS_FAIR, EXPOSED: CLASS_POOR}[result.shelter]
	result.reason = describe(result)
	return result


static func shelter_for(fetch: float) -> StringName:
	if fetch <= 1.5:
		return SHELTERED
	if fetch <= 4.0:
		return PARTLY
	return EXPOSED


## Open water upwind of `geo` (nm, at most MAX_FETCH_NM): the wind comes from
## `from_deg`.
static func fetch_nm(geo: Vector2, from_deg: float) -> float:
	var grid := SeaRouter.get_default().grid
	if grid == null:
		return MAX_FETCH_NM
	var bearing := deg_to_rad(from_deg)
	var d := FETCH_STEP_NM
	while d <= MAX_FETCH_NM:
		if not grid.is_navigable(offset(geo, bearing, d)):
			return d
		d += FETCH_STEP_NM
	return MAX_FETCH_NM


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
	return {AnchorState.HOLDING_WELL: "Holding well", AnchorState.HOLDING_FAIR: "Fair holding",
		AnchorState.HOLDING_POOR: "Poor holding", AnchorState.HOLDING_DRAGGING: "Anchor dragging"}.get(holding, "")


static func describe(site: Dictionary) -> String:
	var land := "land %.1f nm away" % float(site.land_nm)
	match StringName(site.class):
		CLASS_GOOD:
			return "A good anchorage: sheltered from this wind (%s)." % land
		CLASS_FAIR:
			return "A fair anchorage: partly sheltered from this wind (%s)." % land
		CLASS_POOR:
			return "An exposed anchorage: this wind blows straight in over %.0f+ nm of open water. Holding may be poor." % float(site.fetch_nm)
	return String(site.reason)
