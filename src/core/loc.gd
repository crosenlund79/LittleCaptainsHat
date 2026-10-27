class_name Loc
extends RefCounted
## Localization helpers (I019): the game speaks English or Dansk.
##
## The translation catalogue is gettext (locale/da.po, from the template
## locale/messages.pot made by tools/i18n/extract.py). A message's key is its
## English source text (the gettext convention), with a context where the same
## English means different things ("compass", "month", "place"). English is
## the source and the fallback: an untranslated message shows in English.
##
## Godot translates a control's text by itself when the text is a message
## (labels, buttons, tooltips). Text that is built (a value inside a sentence)
## must be translated before the values go in:
##   Loc.t("%d nm to go") % miles      not      Loc.t("%d nm to go" % miles)
## Plurals use Loc.n (Danish and English both have one and other).

const ENGLISH := &"en"
const DANISH := &"da"
## The languages offered, in order: [locale, name in that language].
const LANGUAGES := [[&"en", "English"], [&"da", "Dansk"]]

const MONTHS := ["January", "February", "March", "April", "May", "June", "July", "August", "September", "October",
	"November", "December"]
const MONTHS_SHORT := ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
const WEEKDAYS := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
const WEEKDAYS_SHORT := ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]


## `text` in the current language (or `text` itself when not translated).
static func t(text: String, context := "") -> String:
	return String(TranslationServer.translate(text, context))


## The singular or plural form for `count`, in the current language.
static func n(singular: String, plural: String, count: int, context := "") -> String:
	return String(TranslationServer.translate_plural(singular, plural, count, context))


static func month(index_1: int) -> String:
	return t(MONTHS[clampi(index_1, 1, 12) - 1], "month")


static func month_short(index_1: int) -> String:
	return t(MONTHS_SHORT[clampi(index_1, 1, 12) - 1], "month")


static func weekday(index_0: int) -> String:
	return t(WEEKDAYS[posmod(index_0, 7)], "weekday")


static func weekday_short(index_0: int) -> String:
	return t(WEEKDAYS_SHORT[posmod(index_0, 7)], "weekday")


## `text` in the current language, formatted with `values` (one value or an
## Array), decimals with the language's mark: Loc.format("%.1f nm", 5.5) is
## "5.5 nm" / "5,5 sm". For texts with decimal placeholders (%.1f).
static func format(text: String, values: Variant, context := "") -> String:
	return format_translated(t(text, context), values)


static func format_plural(singular: String, plural: String, count: int, values: Variant, context := "") -> String:
	return format_translated(n(singular, plural, count, context), values)


## Formats an already translated text, each decimal placeholder with the
## language's decimal mark.
static func format_translated(text: String, values: Variant) -> String:
	var args: Array = values if values is Array else [values]
	if not is_danish():
		return text % args
	var out := ""
	var last := 0
	var index := 0
	for m in _placeholder().search_all(text):
		out += text.substr(last, m.get_start() - last)
		var spec := m.get_string()
		if spec == "%%":
			out += "%"
		else:
			var piece := spec % [args[index]]
			out += piece.replace(".", ",") if spec.ends_with("f") else piece
			index += 1
		last = m.get_end()
	return out + text.substr(last)


static var _placeholder_re: RegEx


static func _placeholder() -> RegEx:
	if _placeholder_re == null:
		_placeholder_re = RegEx.create_from_string("%(?:[-+ 0#]*\\d*(?:\\.\\d+)?[sdifxXc]|%)")
	return _placeholder_re


static func is_danish() -> bool:
	return TranslationServer.get_locale().begins_with("da")


## A whole number with the language's thousands separator (10,000 / 10.000).
static func thousands(value: int) -> String:
	var text := str(absi(value))
	var out := ""
	var sep := "." if is_danish() else ","
	while text.length() > 3:
		out = sep + text.substr(text.length() - 3) + out
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + out


## A decimal with the language's decimal mark (5.5 / 5,5).
static func decimal(value: float, places := 1) -> String:
	var text := String.num(value, places) if places > 0 else str(roundi(value))
	if places > 0 and not "." in text:
		text += "." + "0".repeat(places)
	return text.replace(".", ",") if is_danish() else text
