class_name BoatCare
extends RefCounted
## Boat care rules (Iteration 14): four areas, slow and predictable wear, what
## it does, and what the yards charge. Gameplay numbers, kept here in one
## place (see DEV_GUIDES/BOAT_CARE.md).
##
## Areas:
##   hull       hull and structure: the boat's overall condition (weather
##              damage, scrapes; SessionState.vessel_conditions) and the growth
##              on its bottom since the last haul-out;
##   rig        rigging and sails: wear from miles sailed, more in strong wind,
##              and from weather damage;
##   engine     engine hours since the last service;
##   equipment  the fitted upgrades (nothing wears here).
## Each wearing area has a level: good, cosmetic, recommended or needed.
## Wear only matters once it is well along: a little speed is lost, never
## more than a few percent, and the Passage Readiness check mentions it.

const AREA_HULL := &"hull"
const AREA_RIG := &"rig"
const AREA_ENGINE := &"engine"
const AREA_EQUIPMENT := &"equipment"
const AREAS: Array[StringName] = [AREA_HULL, AREA_RIG, AREA_ENGINE, AREA_EQUIPMENT]
const AREA_NAMES := {AREA_HULL: "Hull and bottom", AREA_RIG: "Rigging and sails", AREA_ENGINE: "Engine", AREA_EQUIPMENT: "Equipment"}

const LEVEL_GOOD := &"good"
const LEVEL_COSMETIC := &"cosmetic"
const LEVEL_RECOMMENDED := &"recommended"
const LEVEL_NEEDED := &"needed"
const LEVELS: Array[StringName] = [LEVEL_GOOD, LEVEL_COSMETIC, LEVEL_RECOMMENDED, LEVEL_NEEDED]
const LEVEL_NAMES := {LEVEL_GOOD: "Good", LEVEL_COSMETIC: "Cosmetic wear", LEVEL_RECOMMENDED: "Service recommended",
	LEVEL_NEEDED: "Needs attention"}

# --- Fouling: days in the water since the last haul-out ---------------------------
## Growth per day (the hard antifouling coating slows it).
const FOULING_PER_DAY := 1.0
const ANTIFOULING_FACTOR := 0.4
const FOULING_COSMETIC := 25.0
const FOULING_RECOMMENDED := 50.0
const FOULING_NEEDED := 100.0
## Speed lost to a foul bottom: none up to FOULING_SLOW_FROM, up to
## FOULING_MAX_LOSS at FOULING_SLOW_FROM + FOULING_SLOW_SPAN.
const FOULING_SLOW_FROM := 30.0
const FOULING_SLOW_SPAN := 90.0
const FOULING_MAX_LOSS := 0.06

# --- Rigging and sails: wear 0..100 ---------------------------------------------------
const RIG_WEAR_PER_NM := 0.05
## More wear in a fresh breeze and in strong wind (sustained knots).
const RIG_FRESH_KN := 20.0
const RIG_STRONG_KN := 28.0
const RIG_FRESH_FACTOR := 2.0
const RIG_STRONG_FACTOR := 3.0
## Weather damage (condition percent) also wears the rig.
const RIG_WEAR_PER_DAMAGE := 0.6
const STAINLESS_WEAR_FACTOR := 0.5
const STAINLESS_DAMAGE_FACTOR := 0.9
const RIG_COSMETIC := 15.0
const RIG_RECOMMENDED := 35.0
const RIG_NEEDED := 65.0
const RIG_SLOW_FROM := 40.0
const RIG_MAX_LOSS := 0.05
## A worn rig takes heavy weather a little worse (up to +30 % damage).
const RIG_DAMAGE_FROM := 50.0
const RIG_MAX_EXTRA_DAMAGE := 0.3

# --- Engine hours since service -------------------------------------------------------
const ENGINE_COSMETIC := 50.0
const ENGINE_RECOMMENDED := 80.0
const ENGINE_NEEDED := 160.0
const ENGINE_SLOW_FROM := 120.0
const ENGINE_SLOW_SPAN := 120.0
const ENGINE_MAX_LOSS := 0.1

# --- Services (moored in a harbour that has them) ------------------------------------
const SERVICE_REPAIR := &"repair"
const SERVICE_ENGINE := &"engine_service"
const SERVICE_RIG := &"rig_service"
const SERVICE_HAUL_OUT := &"haul_out"
const SERVICES: Array[StringName] = [SERVICE_REPAIR, SERVICE_RIG, SERVICE_ENGINE, SERVICE_HAUL_OUT]
const SERVICE_NAMES := {SERVICE_REPAIR: "Repair hull and structure", SERVICE_RIG: "Rigging and sail service",
	SERVICE_ENGINE: "Engine service", SERVICE_HAUL_OUT: "Haul out"}
## Prices are for a 30 ft boat and scale with length (BoatCare.size_factor).
const REPAIR_EUR_PER_PERCENT := 3.0
const REPAIR_BASE_MINUTES := 60.0
const REPAIR_MINUTES_PER_PERCENT := 3.0
const ENGINE_SERVICE_EUR := 90.0
const ENGINE_SERVICE_MINUTES := 180.0
const RIG_SERVICE_EUR := 70.0
const RIG_SERVICE_EUR_PER_WEAR := 1.5
const RIG_SERVICE_MINUTES := 120.0
## A haul-out: euros per foot, a day out of the water. Cleans the bottom and
## includes repairing the hull and structure.
const HAUL_OUT_EUR_PER_FT := 10.0
const HAUL_OUT_MINUTES := 24.0 * 60.0
const UPGRADE_MINUTES := 240.0

const DATA_PATH := "res://data/boat/equipment.json"
static var _upgrades: Array[Dictionary] = []


# --- Equipment -------------------------------------------------------------------------

static func get_upgrades() -> Array[Dictionary]:
	if _upgrades.is_empty():
		var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA_PATH))
		if data is Dictionary:
			for entry: Dictionary in data.get("upgrades", []):
				_upgrades.append(entry)
	return _upgrades


static func get_upgrade(id: String) -> Dictionary:
	for entry in get_upgrades():
		if entry.id == id:
			return entry
	return {}


## Price of an upgrade for a boat of `length_ft`.
static func upgrade_price(id: String, length_ft: float) -> int:
	return roundi(float(get_upgrade(id).get("price_per_ft", 0)) * length_ft / 10.0) * 10


## A boat's size relative to a 30 ft reference (prices scale with it).
static func size_factor(length_ft: float) -> float:
	return maxf(length_ft, 10.0) / 30.0


# --- Wear and levels -------------------------------------------------------------------

## Fouling "days" now: days in the water since the last haul-out, slowed by
## the hard antifouling coating.
static func fouling(care: BoatCareState, now: float) -> float:
	var days := maxf(now - care.hull_cleaned_at, 0.0) / 86400.0
	return days * FOULING_PER_DAY * (ANTIFOULING_FACTOR if care.has_upgrade("hard_antifouling") else 1.0)


static func _level(value: float, cosmetic: float, recommended: float, needed: float) -> StringName:
	if value >= needed:
		return LEVEL_NEEDED
	if value >= recommended:
		return LEVEL_RECOMMENDED
	if value >= cosmetic:
		return LEVEL_COSMETIC
	return LEVEL_GOOD


## The level of an area for a boat with `condition` percent and `care`.
static func area_level(area: StringName, care: BoatCareState, condition: float, now: float) -> StringName:
	match area:
		AREA_HULL:
			var by_fouling := _level(fouling(care, now), FOULING_COSMETIC, FOULING_RECOMMENDED, FOULING_NEEDED)
			var by_damage: StringName = {VesselCondition.BAND_SOUND: LEVEL_GOOD if condition >= 95.0 else LEVEL_COSMETIC,
				VesselCondition.BAND_WORN: LEVEL_RECOMMENDED, VesselCondition.BAND_DAMAGED: LEVEL_NEEDED,
				VesselCondition.BAND_CRITICAL: LEVEL_NEEDED}[VesselCondition.band_of(condition)]
			return by_fouling if LEVELS.find(by_fouling) > LEVELS.find(by_damage) else by_damage
		AREA_RIG:
			return _level(care.rig_wear, RIG_COSMETIC, RIG_RECOMMENDED, RIG_NEEDED)
		AREA_ENGINE:
			return _level(care.engine_hours, ENGINE_COSMETIC, ENGINE_RECOMMENDED, ENGINE_NEEDED)
	return LEVEL_GOOD


## One line on an area, for the overview: "Bottom clean, hull 100 % · Sound".
static func describe_area(area: StringName, care: BoatCareState, condition: float, now: float) -> String:
	match area:
		AREA_HULL:
			var growth := fouling(care, now)
			var bottom := "bottom clean" if growth < FOULING_COSMETIC else ("some weed on the bottom" if growth < FOULING_RECOMMENDED
				else ("a good deal of growth on the bottom" if growth < FOULING_NEEDED else "the bottom is badly fouled"))
			return "Hull %s, %s (%d days since the last haul-out)" % [VesselCondition.describe(condition), bottom,
				floori(maxf(now - care.hull_cleaned_at, 0.0) / 86400.0)]
		AREA_RIG:
			return "Rig wear %d %%%s" % [roundi(care.rig_wear), " (stainless rigging)" if care.has_upgrade("stainless_rigging") else ""]
		AREA_ENGINE:
			return "%d engine hours since the last service" % roundi(care.engine_hours)
		AREA_EQUIPMENT:
			var names := PackedStringArray()
			for id in care.upgrades:
				names.append(String(get_upgrade(id).get("name", id)))
			return ", ".join(names) if not names.is_empty() else "Standard equipment"
	return ""


## The worst level over the wearing areas.
static func overall_level(care: BoatCareState, condition: float, now: float) -> StringName:
	var worst := LEVEL_GOOD
	for area in [AREA_HULL, AREA_RIG, AREA_ENGINE]:
		var level := area_level(area, care, condition, now)
		if LEVELS.find(level) > LEVELS.find(worst):
			worst = level
	return worst


# --- Effects -----------------------------------------------------------------------------

## Speed multipliers {"sail", "engine"} and weather damage multiplier
## {"damage"} from the boat's wear (1 = no effect).
static func effects(care: BoatCareState, now: float) -> Dictionary:
	var foul := clampf((fouling(care, now) - FOULING_SLOW_FROM) / FOULING_SLOW_SPAN, 0.0, 1.0) * FOULING_MAX_LOSS
	var rig := clampf((care.rig_wear - RIG_SLOW_FROM) / (100.0 - RIG_SLOW_FROM), 0.0, 1.0) * RIG_MAX_LOSS
	var engine := clampf((care.engine_hours - ENGINE_SLOW_FROM) / ENGINE_SLOW_SPAN, 0.0, 1.0) * ENGINE_MAX_LOSS
	var damage := 1.0 + clampf((care.rig_wear - RIG_DAMAGE_FROM) / (100.0 - RIG_DAMAGE_FROM), 0.0, 1.0) * RIG_MAX_EXTRA_DAMAGE
	if care.has_upgrade("stainless_rigging"):
		damage *= STAINLESS_DAMAGE_FACTOR
	return {"sail": (1.0 - foul) * (1.0 - rig), "engine": (1.0 - foul) * (1.0 - engine), "damage": damage}


## Rig wear for `nm` sailed in a sustained wind of `wind_kn`.
static func rig_wear_for(nm: float, wind_kn: float, care: BoatCareState) -> float:
	var factor := RIG_STRONG_FACTOR if wind_kn >= RIG_STRONG_KN else (RIG_FRESH_FACTOR if wind_kn >= RIG_FRESH_KN else 1.0)
	return nm * RIG_WEAR_PER_NM * factor * (STAINLESS_WEAR_FACTOR if care.has_upgrade("stainless_rigging") else 1.0)


# --- Prices and times --------------------------------------------------------------------

## {"cost", "minutes"} of a service for a boat of `length_ft` in this state.
static func quote(service: StringName, care: BoatCareState, condition: float, length_ft: float) -> Dictionary:
	var size := size_factor(length_ft)
	match service:
		SERVICE_REPAIR:
			var missing := maxf(VesselCondition.FULL - condition, 0.0)
			return {"cost": ceili(missing * REPAIR_EUR_PER_PERCENT * size), "minutes": REPAIR_BASE_MINUTES + missing * REPAIR_MINUTES_PER_PERCENT}
		SERVICE_ENGINE:
			return {"cost": roundi(ENGINE_SERVICE_EUR * size), "minutes": ENGINE_SERVICE_MINUTES}
		SERVICE_RIG:
			return {"cost": roundi((RIG_SERVICE_EUR + care.rig_wear * RIG_SERVICE_EUR_PER_WEAR) * size), "minutes": RIG_SERVICE_MINUTES}
		SERVICE_HAUL_OUT:
			return {"cost": roundi(HAUL_OUT_EUR_PER_FT * length_ft), "minutes": HAUL_OUT_MINUTES}
	return {"cost": 0, "minutes": 0.0}


# --- Wording for the overview and the Log ----------------------------------------------

## Text colours of the levels on the dark panels.
const LEVEL_COLOURS := {LEVEL_GOOD: Color(0.75, 0.92, 0.7), LEVEL_COSMETIC: Color(0.93, 0.92, 0.86),
	LEVEL_RECOMMENDED: Color(1.0, 0.86, 0.62), LEVEL_NEEDED: Color(1.0, 0.62, 0.55)}


## What the Captain could do about an area at this level ("" when nothing).
static func advice(area: StringName, level: StringName) -> String:
	if level == LEVEL_GOOD or area == AREA_EQUIPMENT:
		return ""
	if level == LEVEL_COSMETIC:
		return "Nothing urgent."
	return {AREA_HULL: "A haul-out cleans the bottom; any boatyard can repair the hull.",
		AREA_RIG: "Any boatyard can service the rigging and sails.",
		AREA_ENGINE: "Any boatyard can service the engine."}.get(area, "")


## One line for a care history entry: "Haul out, Copenhagen, €260".
static func history_text(entry: Dictionary) -> String:
	var kind := String(entry.get("kind", ""))
	var what := ""
	if kind.begins_with("upgrade:"):
		what = "Fitted: %s" % String(get_upgrade(kind.get_slice(":", 1)).get("name", kind.get_slice(":", 1)))
	elif kind.begins_with("haul_out_extra:"):
		var extra := kind.get_slice(":", 1)
		what = "While out: %s" % (String(get_upgrade(extra).get("name", extra)) if not get_upgrade(extra).is_empty()
			else String(SERVICE_NAMES.get(StringName(extra), extra)).to_lower())
	else:
		what = String(SERVICE_NAMES.get(StringName(kind), kind))
	var port := PortCatalog.get_default().get_display_name(StringName(entry.get("port", "")))
	return "%s, %s, %s" % [what, port, GameSession.format_money(int(entry.get("cost", 0)))]
