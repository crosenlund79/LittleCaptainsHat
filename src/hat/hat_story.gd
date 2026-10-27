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
		return {"text": Loc.t("in %s harbour") % port.display_name, "port_id": String(port.id), "distance_nm": 0.0}
	var nearest: PortData = null
	var best := INF
	for candidate in catalog.ports:
		var nm := GeoMath.distance_nm(position, candidate.get_geo_position())
		if nm < best:
			best = nm
			nearest = candidate
	if nearest == null:
		return {"text": Loc.t("at sea (%s)") % GeoMath.format_position(position), "port_id": "", "distance_nm": INF}
	var text := ""
	if best < JUST_OFF_NM:
		text = Loc.t("just off %s, %s") % [nearest.display_name, nearest.country]
	elif best <= NEAR_HARBOUR_NM:
		text = Loc.t("about %d nm off %s, %s") % [roundi(best), nearest.display_name, nearest.country]
	else:
		text = Loc.t("far out at sea, %d nm from the nearest harbour (%s)") % [roundi(best), nearest.display_name]
	return {"text": text, "port_id": String(nearest.id), "distance_nm": best}


## How far open water reaches around `position`, in nm, up to `max_nm`:
## the distance to the nearest chart cell that touches land (the same
## navigability raster routing uses, from the chart's coastline data, small
## islands included). Cells outside the chart count as land, so the answer is
## never too generous.
static func open_water_nm(position: Vector2, max_nm: float) -> float:
	var chart := SeaRouter.get_default().grid
	if chart == null:
		return 0.0
	# On the detailed raster where a region covers the position (Iteration
	# 14); cells beyond that grid's edge are read from the composite chart.
	var grid := chart.grid_at(position)
	var center := grid.geo_to_cell(position)
	var cx := floori(center.x)
	var cy := floori(center.y)
	if grid.get_class_at(cx, cy) != NavGrid.NAVIGABLE:
		return 0.0
	var origin := grid.cell_center_geo(cx, cy)
	var nm_x := maxf(GeoMath.distance_nm(origin, grid.cell_center_geo(cx + 1, cy)), 1e-3)
	var nm_y := maxf(GeoMath.distance_nm(origin, grid.cell_center_geo(cx, cy + 1)), 1e-3)
	var rx := ceili(max_nm / nm_x) + 1
	var ry := ceili(max_nm / nm_y) + 1
	var nearest := max_nm
	for dy in range(-ry, ry + 1):
		for dx in range(-rx, rx + 1):
			var d := Vector2(dx * nm_x, dy * nm_y).length()
			if d >= nearest:
				continue
			var x := cx + dx
			var y := cy + dy
			var inside := x >= 0 and y >= 0 and x < grid.columns and y < grid.rows
			var cell_class := grid.get_class_at(x, y) if inside or grid == chart else chart.cell_class_at_geo(grid.cell_center_geo(x, y))
			if cell_class != NavGrid.NAVIGABLE:
				# The land may start anywhere in that cell: count its near edge.
				nearest = maxf(d - 0.5 * maxf(nm_x, nm_y), 0.0)
	return nearest


## The notification when hat number `lost_count` blows away.
static func loss_message(lost_count: int) -> String:
	return LOSS_MESSAGES[(maxi(lost_count, 1) - 1) % LOSS_MESSAGES.size()]


## The Captain's Log line for a lost hat: "Lost another captain's hat about
## 12 nm off Skagen, Denmark. Wind 38 kn, gusting 49."
static func loss_log_line(lost_count: int, place: Dictionary, sample: WeatherSample) -> String:
	var what := Loc.t("Lost my captain's hat") if lost_count <= 1 else Loc.t("Lost another captain's hat")
	var wind := Loc.t("Wind %d kn") % roundi(sample.speed_kn)
	if sample.gust_kn >= sample.speed_kn + 6.0:
		wind += Loc.t(", gusting %d") % roundi(sample.gust_kn)
	var remark := ""
	if sample.hazard == WeatherModel.HAZARD_NORMAL:
		remark = Loc.t(" Weather otherwise pleasant.")
	elif sample.hazard >= WeatherModel.HAZARD_DANGEROUS:
		remark = Loc.t(" It was quite a blow.")
	return "%s %s. %s.%s" % [what, place.text, wind, remark]
