class_name ShoreEvents
extends RefCounted
## Go Ashore (Iteration 12): a small library of cozy harbour moments.
##
## Deliberately small. Each event has a title, a short text ({harbour} is the
## harbour's name), a drawn icon and one or two choices; every choice costs at
## most a few euros and a little time. The first time a choice is made for an
## event in a harbour it may pay a little renown and becomes a notable moment
## in the Captain's Log; after that the event is just a pleasant memory (no
## reward). See GameSession.get_shore_event() and apply_shore_choice().
##
## The texts are generic colour, not claims about real places: a harbour
## variant only uses what the game already shows (Copenhagen's colourful
## waterfront houses) or what any small harbour has.

## Game hours after an outing before the same harbour offers a new one.
const REST_HOURS := 6.0
## Prefix of the records kept in ObjectiveProgress.completed ("shore:<port>:<event>").
const RECORD_PREFIX := "shore:"

## A choice: {label, cost (euros), minutes, renown (first time only), outcome}.
const GENERIC: Array[Dictionary] = [
	{"id": "cafe", "icon": "cup", "title": "A harbour café",
		"text": "Just off the quay, a little café smells of coffee and warm bread. A few sailors sit outside with their faces in the sun.",
		"choices": [
			{"label": "Coffee and a pastry", "cost": 6, "minutes": 40, "renown": 3,
				"outcome": "You linger over a coffee and the flakiest pastry in {harbour}. Life aboard can wait half an hour."},
			{"label": "Just a glass of water", "cost": 0, "minutes": 15, "renown": 2,
				"outcome": "The owner fills your glass with a smile and asks where you have sailed from."}]},
	{"id": "bench", "icon": "bench", "title": "A quiet bench",
		"text": "A weathered bench looks out over the moorings. Someone has carved a small anchor into the armrest.",
		"choices": [
			{"label": "Sit a while", "cost": 0, "minutes": 30, "renown": 2,
				"outcome": "You watch the boats nod on their lines. Your own looks rather fine from here."}]},
	{"id": "sailor", "icon": "sailor", "title": "A friendly sailor",
		"text": "On the next pontoon a sailor is coiling lines. They nod at your boat: \"Come far?\"",
		"choices": [
			{"label": "Swap sea stories", "cost": 0, "minutes": 45, "renown": 4,
				"outcome": "Their story about a goat on a ferry beats all of yours. You promise to wave if you meet at sea."},
			{"label": "Ask about the weather", "cost": 0, "minutes": 15, "renown": 2,
				"outcome": "\"Watch the sky in the afternoon,\" they say, sounding very wise. You nod just as wisely."}]},
	{"id": "market", "icon": "basket", "title": "A small market stall",
		"text": "A stall by the harbour sells fruit, honey and things in jars nobody can quite name.",
		"choices": [
			{"label": "Buy a little treat", "cost": 8, "minutes": 20, "renown": 3,
				"outcome": "You leave with a jar of honey and a story about the bees that made it."},
			{"label": "Browse and smile", "cost": 0, "minutes": 15, "renown": 1,
				"outcome": "The stallholder lets you taste a strawberry anyway."}]},
	{"id": "viewpoint", "icon": "view", "title": "A view over the harbour",
		"text": "A short walk uphill brings you to a spot where all of {harbour}'s harbour lies below you.",
		"choices": [
			{"label": "Take in the view", "cost": 0, "minutes": 60, "renown": 3,
				"outcome": "From up here your boat is a little toy among the others. You pick it out at once."}]},
	{"id": "noticeboard", "icon": "board", "title": "The harbour noticeboard",
		"text": "The noticeboard is covered in notes: crew wanted, a bicycle for sale, and \"FOUND: one captain's hat, slightly damp\".",
		"choices": [
			{"label": "Read every note", "cost": 0, "minutes": 20, "renown": 2,
				"outcome": "The hat turns out to be someone else's. Still, it is good to know hats do come back sometimes."}]},
	{"id": "gulls", "icon": "gull", "title": "Gulls with opinions",
		"text": "Three gulls on a bollard are watching your sandwich with great interest.",
		"choices": [
			{"label": "Guard your sandwich", "cost": 0, "minutes": 10, "renown": 1,
				"outcome": "You win, narrowly. The gulls make a note of your face."}]},
	{"id": "old_boat", "icon": "boat", "title": "A well-loved old boat",
		"text": "Two berths down lies an old wooden boat, varnish gleaming. Its owner is polishing a brass porthole.",
		"choices": [
			{"label": "Chat with the owner", "cost": 0, "minutes": 40, "renown": 3,
				"outcome": "She has owned it for thirty years and still finds new places to polish."}]},
]

## Optional harbour variants: added to the generic events in that harbour.
const BY_HARBOUR := {
	"copenhagen": [
		{"id": "colourful_houses", "icon": "houses", "title": "The colourful waterfront",
			"text": "The tall, colourful houses along the waterfront glow in the late light, and the cafés are filling up.",
			"choices": [
				{"label": "Stroll along the water", "cost": 0, "minutes": 45, "renown": 4,
					"outcome": "You walk the length of the waterfront twice, just to see the colours again."},
				{"label": "An ice cream on the quay", "cost": 5, "minutes": 25, "renown": 3,
					"outcome": "You eat it far too slowly and have to race the drips."}]}],
	"lohals": [
		{"id": "quiet_evening", "icon": "bench", "title": "A quiet island evening",
			"text": "{harbour} is a small harbour. In the evening calm you can hear halyards tapping all along the pontoon.",
			"choices": [
				{"label": "Listen for a while", "cost": 0, "minutes": 30, "renown": 3,
					"outcome": "Tap, tap, tap. You count the boats by their halyards and lose count, happily."}]}],
}


## Regional flavour for the international harbours (Iteration 16): one
## gentle moment per region, generic colour that fits any harbour there.
const BY_REGION := {
	"atlantic_islands": [
		{"id": "island_landfall", "icon": "sailor", "title": "Fellow ocean sailors",
			"text": "The pontoons of {harbour} are full of boats with wind vanes and jerrycans lashed on deck: everyone here is crossing somewhere.",
			"choices": [
				{"label": "Compare passage plans", "cost": 0, "minutes": 45, "renown": 4,
					"outcome": "Charts come out, everyone points at the same patch of ocean, and somebody puts the kettle on."}]}],
	"caribbean": [
		{"id": "steel_band", "icon": "basket", "title": "Music by the water",
			"text": "Somewhere along the waterfront of {harbour} a band is playing, and the stalls are selling fruit you have only read about.",
			"choices": [
				{"label": "A fresh coconut", "cost": 3, "minutes": 30, "renown": 3,
					"outcome": "You drink it straight from the shell while the music drifts over the boats."},
				{"label": "Just listen", "cost": 0, "minutes": 20, "renown": 2,
					"outcome": "Your foot starts tapping long before you notice."}]}],
	"central_america": [
		{"id": "ships_passing", "icon": "view", "title": "Ships waiting their turn",
			"text": "Off {harbour} great ships lie at anchor, waiting their turn for the canal. Your boat looks very small and very proud.",
			"choices": [
				{"label": "Count the ships", "cost": 0, "minutes": 30, "renown": 3,
					"outcome": "You lose count somewhere past twenty and decide your boat is the nicest one anyway."}]}],
	"pacific": [
		{"id": "lagoon_evening", "icon": "bench", "title": "A warm Pacific evening",
			"text": "The evening air in {harbour} smells of flowers and the sea. Children are swimming off the quay, shrieking happily.",
			"choices": [
				{"label": "Sit and watch the sunset", "cost": 0, "minutes": 40, "renown": 4,
					"outcome": "The sky goes gold, then pink, then the first stars come out over the masts. A long way from home, and it feels like it."},
				{"label": "Buy fruit at the stall", "cost": 4, "minutes": 20, "renown": 3,
					"outcome": "You carry a bag of the sweetest fruit back to the boat, already planning breakfast."}]}],
}


## Every event offered in `port_id` (generic first, then the region's and
## the harbour's own).
static func for_port(port_id: StringName) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	events.append_array(GENERIC)
	var port := PortCatalog.get_default().get_port(port_id)
	if port:
		for event: Dictionary in BY_REGION.get(port.region, []):
			events.append(event)
	for event: Dictionary in BY_HARBOUR.get(String(port_id), []):
		events.append(event)
	return events


static func find(port_id: StringName, event_id: String) -> Dictionary:
	for event in for_port(port_id):
		if event.id == event_id:
			return event
	return {}


static func record_id(port_id: StringName, event_id: String) -> String:
	return "%s%s:%s" % [RECORD_PREFIX, port_id, event_id]


## "{harbour}" filled in.
static func fill(text: String, harbour_name: String) -> String:
	return text.replace("{harbour}", harbour_name)
