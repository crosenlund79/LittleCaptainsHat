class_name HatStory
extends RefCounted
## Words for the captain's hat: the notifications and the short Captain's Log
## lines about hat mishaps. Every place and figure comes from the game's real
## state (the harbour the boat lies in, the nearest harbour in the catalogue,
## the WeatherModel sample); nothing is invented.

## Harbours within this distance (nm) name the place ("off Skagen").
const NEAR_HARBOUR_NM := 40.0
## Closer than this the hat was lost "just off" the harbour.
const JUST_OFF_NM := 3.0

const LOSS_MESSAGES: Array[String] = [
	"Your captain's hat has decided to explore the ocean without you.",
	"Another captain's hat sets off on a voyage of its own.",
	"Your hat leaves without saying goodbye. The gulls seem impressed.",
	"Somewhere out there, a fish is now very well dressed.",
]


## Where something happened: in a harbour (when `location_id` names the
## harbour the boat lies in), or relative to the nearest harbour in the
## catalogue. {"text", "port_id", "distance_nm"}.
static func describe_place(position: Vector2, location_id: StringName) -> Dictionary:
	var catalog := PortCatalog.get_default()
	var port := catalog.get_port(location_id) if not location_id.is_empty() else null
	if port:
		return {"text": "in %s harbour" % port.display_name, "port_id": String(port.id), "distance_nm": 0.0}
	var nearest: PortData = null
	var best := INF
	for candidate in catalog.ports:
		var nm := GeoMath.distance_nm(position, candidate.get_geo_position())
		if nm < best:
			best = nm
			nearest = candidate
	if nearest == null:
		return {"text": "at sea (%s)" % GeoMath.format_position(position), "port_id": "", "distance_nm": INF}
	var text := ""
	if best < JUST_OFF_NM:
		text = "just off %s, %s" % [nearest.display_name, nearest.country]
	elif best <= NEAR_HARBOUR_NM:
		text = "about %d nm off %s, %s" % [roundi(best), nearest.display_name, nearest.country]
	else:
		text = "far out at sea, %d nm from the nearest harbour (%s)" % [roundi(best), nearest.display_name]
	return {"text": text, "port_id": String(nearest.id), "distance_nm": best}


## The notification when hat number `lost_count` blows away.
static func loss_message(lost_count: int) -> String:
	return LOSS_MESSAGES[(maxi(lost_count, 1) - 1) % LOSS_MESSAGES.size()]


## The Captain's Log line for a lost hat: "Lost another captain's hat about
## 12 nm off Skagen, Denmark. Wind 38 kn, gusting 49."
static func loss_log_line(lost_count: int, place: Dictionary, sample: WeatherSample) -> String:
	var what := "Lost my captain's hat" if lost_count <= 1 else "Lost another captain's hat"
	var wind := "Wind %d kn" % roundi(sample.speed_kn)
	if sample.gust_kn >= sample.speed_kn + 6.0:
		wind += ", gusting %d" % roundi(sample.gust_kn)
	var remark := ""
	if sample.hazard == WeatherModel.HAZARD_NORMAL:
		remark = " Weather otherwise pleasant."
	elif sample.hazard >= WeatherModel.HAZARD_DANGEROUS:
		remark = " It was quite a blow."
	return "%s %s. %s.%s" % [what, place.text, wind, remark]
