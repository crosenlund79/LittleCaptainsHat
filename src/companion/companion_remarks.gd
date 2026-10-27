class_name CompanionRemarks
extends RefCounted
## A kind word when the Captain pets the ship's companion: a short remark
## that fits the animal (cat or dog), in the game's current language.
##
## The companion's identity is read from the authoritative CompanionState
## (identity()), never kept here. Today a companion has a kind only; the
## remarks are written so that, when the companion also has a name and a
## gender ("female", "male" or "other"), those are used: lines with the name
## are chosen, and the dog's lines say "girl" or "boy" where natural. A name
## is inserted exactly as chosen (Danish letters, punctuation and all).
##
## Lines rotate (remark(identity, turn)): consecutive turns never give the
## same line. Translated when they are shown (Loc), so a language switch
## applies to the next remark. The cooldown that keeps the remarks rare lives
## with the companion node (ShipCompanion.take_remark()).

const GENDER_FEMALE := &"female"
const GENDER_MALE := &"male"
const GENDER_OTHER := &"other"

## Without a name. By kind.
const UNNAMED := {
	CompanionState.KIND_CAT: [
		"You're looking especially cozy today.",
		"What a lovely little purr.",
		"There's my favourite little sailor.",
		"The ship's cat, on watch as ever.",
	],
	CompanionState.KIND_DOG: [
		"Who's a good dog?",
		"There's my faithful first mate!",
		"Best crew on the seven seas, that's you.",
		"That tail could power the boat.",
	],
}
## With a name (%s), for every gender.
const NAMED := {
	CompanionState.KIND_CAT: [
		"You're looking especially cozy today, %s.",
		"What a lovely little purr, %s.",
		"The ship's cat, on watch as ever. Good %s.",
	],
	CompanionState.KIND_DOG: [
		"Who's the best companion, %s?",
		"That tail could power the boat, %s.",
	],
}
## With a name (%s), added for a gender where it reads naturally.
const NAMED_BY_GENDER := {
	CompanionState.KIND_CAT: {
		GENDER_FEMALE: ["There's my lovely little sailor, %s."],
		GENDER_MALE: ["There's my handsome little sailor, %s."],
	},
	CompanionState.KIND_DOG: {
		GENDER_FEMALE: ["Who's a good girl, %s?"],
		GENDER_MALE: ["There's my good boy, %s!"],
	},
}
## Without a name, added for a gender.
const UNNAMED_BY_GENDER := {
	CompanionState.KIND_DOG: {
		GENDER_FEMALE: ["Who's a good girl?"],
		GENDER_MALE: ["Who's a good boy?"],
	},
}


## {"kind", "name", "gender"} of a companion, from its state. A field the
## state does not (yet) have is empty.
static func identity(companion: CompanionState) -> Dictionary:
	if companion == null:
		return {"kind": CompanionState.DEFAULT_KIND, "name": "", "gender": &""}
	var name: Variant = companion.get("name") if "name" in companion else ""
	var gender: Variant = companion.get("gender") if "gender" in companion else &""
	return {"kind": companion.kind, "name": String(name).strip_edges() if name is String else "",
		"gender": StringName(gender) if gender is String or gender is StringName else &""}


## The English lines (message keys) for an identity, in a fixed order.
static func lines(who: Dictionary) -> Array[String]:
	var kind: StringName = who.get("kind", CompanionState.DEFAULT_KIND)
	if not kind in CompanionState.KINDS:
		kind = CompanionState.DEFAULT_KIND
	var gender: StringName = who.get("gender", &"")
	var named := String(who.get("name", "")) != ""
	var out: Array[String] = []
	out.assign((NAMED if named else UNNAMED)[kind])
	var extra: Dictionary = (NAMED_BY_GENDER if named else UNNAMED_BY_GENDER).get(kind, {})
	out.append_array(extra.get(gender, []))
	return out


## The remark for turn `turn` (0, 1, 2, …), translated, with the name in.
## Consecutive turns never repeat a line.
static func remark(who: Dictionary, turn: int) -> String:
	var choices := lines(who)
	var line := Loc.t(choices[posmod(turn, choices.size())])
	return line % String(who.name) if line.contains("%s") else line


## When the Captain's hands are full (hat and coffee): the companion gets a
## friendly look instead.
static func hands_full(who: Dictionary) -> String:
	if String(who.get("name", "")) != "":
		return Loc.t("%s gets a friendly look: your hands are full (hat and coffee).") % String(who.name)
	if who.get("kind", &"") == CompanionState.KIND_DOG:
		return Loc.t("The dog gets a friendly look: your hands are full (hat and coffee).")
	return Loc.t("The cat gets a friendly look: your hands are full (hat and coffee).")
