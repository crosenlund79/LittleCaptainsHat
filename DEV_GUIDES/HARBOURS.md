# Harbours: services, walking ashore and Go Ashore

Iteration 12. How a harbour decides which services it has, how the gangplank
and the shore work on every boat, and how to add a Go Ashore event.

## 1. Which services a harbour has

Every harbour has the grocery store, the boatyard and Go Ashore unless it says
otherwise. To change one harbour, add a file named after its port id:

```
data/harbours/facilities/<port_id>.tres
```

```
[gd_resource type="Resource" script_class="HarbourFacilities" format=3]

[ext_resource type="Script" path="res://src/harbour/harbour_facilities.gd" id="1_fac"]

[resource]
script = ExtResource("1_fac")
grocery = true
boatyard = false
go_ashore = true
```

That is all: the shore shows only the services that are there, their signs
appear or disappear, and every way into a missing service (the station, the
boatyard and provisions panels, buying, repairing, changing boats) is refused
with a short message and costs nothing. Examples in the repository:
`copenhagen.tres` (everything) and `lohals.tres` (no boatyard).

These are game definitions, not claims about real businesses.

## 2. The gangplank and the shore

Nothing per boat is needed. `ShoreAccess` (`src/harbour/shore_access.gd`)
builds everything from the deck scene:

| It uses | From the deck scene |
|---|---|
| where the gangplank lands | `Layout/SpawnPoints/from_boatyard` (its x); put this point just inside the rail on the pontoon side |
| the rail it opens | `Layout/Collision/Lifeline/CollisionPolygon2D` (the closed walkable outline) |
| the shore | `Surroundings/Mooring/Pontoon` (a rectangle polygon) |

For a new boat, check with the vessel tests (`test_vessels`, `test_harbour_life`):
the shore stations must be reachable, and from the pontoon the cockpit must be
reachable again. The plank is 68 units wide (the player is 40 across).

## 3. Go Ashore events

Events live in `src/harbour/shore_events.gd`:

- `GENERIC`: offered in every harbour;
- `BY_HARBOUR`: extras for one harbour, by port id.

An event:

```
{"id": "bench", "icon": "bench", "title": "A quiet bench",
	"text": "A weathered bench looks out over the moorings…",
	"choices": [
		{"label": "Sit a while", "cost": 0, "minutes": 30, "renown": 2,
			"outcome": "You watch the boats nod on their lines."}]}
```

| Field | Meaning |
|---|---|
| `id` | stable: rewards are remembered per event and harbour, so never rename one that has shipped |
| `icon` | one of `cup`, `bench`, `sailor`, `basket`, `view`, `board`, `gull`, `boat`, `houses` (drawn in `GoAshoreMenu`) |
| `title` | the event's title |
| `text` | the event's description; `{harbour}` is replaced by the harbour's name |
| choices | one or two per event |
| `cost` | euros |
| `minutes` | game time that passes |
| `renown` | paid only the first time the event is enjoyed in that harbour |
| `outcome` | what happened |

Keep it small and cozy:

- the costs are a few euros, the times under about an hour and the renown 1–4;
- no quests, chains or new currencies;
- harbour variants use only what any small harbour has, or what the game
  already shows. Do not invent facts about real places.
