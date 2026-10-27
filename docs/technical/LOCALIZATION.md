# Localization (I019): English and Dansk

The game speaks **English** (the source language) and **Dansk**. There is no
third language. The player chooses at the first launch (a small picker, both
languages side by side) and can switch at any time under **Settings →
Language**; the switch applies at once.

## How it works

- **Catalogue.** gettext: `locale/da.po` (Danish), made from the template
  `locale/messages.pot`. A message's key is its English text (the gettext
  convention). The same English with different meanings gets a context:
  `compass` (N, NE, …), `month`, `weekday`, `date` (date patterns), `money`
  (the money pattern) and `place` (harbour names). Registered in
  `project.godot` under `[internationalization]`, fallback `en`.
- **Controls translate themselves.** A Label, Button, tooltip or OptionButton
  item whose whole text is a message is shown in the current language by
  Godot, and again when the language changes. Code that sets a control's
  whole text sets the English literal (`button.text = "Sail on"`).
- **Built text is translated before it is put together.**
  `Loc.t("You slept %s. It is %s.") % [slept, now]`, never
  `Loc.t("You slept %s." % slept)`. Plurals: `Loc.n("%d hour", "%d hours", n) % n`
  (Danish, like English, has one and other: `nplurals=2; plural=(n != 1)`).
- **Values in the language's own form** (`src/core/loc.gd`): `Loc.decimal`
  (5.5 / 5,5), `Loc.thousands` (10,000 / 10.000), `Loc.month`,
  `Loc.weekday` and their short forms; `Simulation.format_game_time`
  ("Fri 1 May 2026, 08:00 UTC" / "fre. 1. maj 2026, 08:00 UTC"),
  `Simulation.format_duration` ("4 h 50 min" / "4 t 50 min"),
  `GameSession.format_money` ("€1,200" / "1.200 €"), the wind's compass point
  (`WindField.compass_name`: "WSW" / "VSV"), harbour names
  (`PortData.display_name`, context `place`).
- **Data stays English.** Saves, ids, keys, logs and the diagnostic session
  log are language-neutral and unchanged; a save made in Danish loads in
  English and the other way round. Texts already written into the Captain's
  Log (award titles, voyage lines) keep the language they were written in.
- **The language is a preference**, kept in `user://settings.cfg`
  (`[interface] language`), never in a save. Empty until chosen: the first
  launch asks.

## Tools

- `python3 tools/i18n/wrap_strings.py` wraps player-facing phrases in game
  scripts in `Loc.t()` (idempotent; class-level constants, match patterns,
  comparisons, logs, node names and a control's plain text are left alone).
- `python3 tools/i18n/extract.py` writes `locale/messages.pot` from the
  scripts (Loc calls and phrases), scenes and data files.
- `python3 tools/i18n/check.py` checks `locale/da.po` against the template:
  every message translated, the same placeholders (`%s`, `%d`, `%.1f`, …) in
  the same order, the same leading and trailing spaces and line breaks, and
  no Danish line much longer than the English (a rough overflow guard; the
  in-game overflow check is in `tests/suites/test_localization.gd`).

## Glossary (English → Dansk)

Tone: warm, short, plain; the player is "du". Names are never translated:
the game (Little Captain's Hat), boat models (Wing 33, Clam 40, Frogleap 36,
Arctic Wanderer 26), ship names (Nordlys, Freja, …), storm names, Next Harbor.

| English | Dansk |
|---|---|
| boat / vessel / ship / yacht | båd / fartøj / skib / sejlbåd (lystbåd) |
| harbour, moored, moor | havn, fortøjet, fortøje |
| anchor, anchorage, at anchor | anker, ankerplads, for anker |
| drop / weigh anchor | kaste anker / lette anker |
| windlass, chain, scope | ankerspil, kæde, kædelængde |
| holding well / poorly, dragging | holder godt / dårligt, ankeret glider |
| Magic Anchor | Magisk anker |
| deck, cabin, galley | dæk, kahyt, kabys |
| helm, wheel | ror, rat |
| chart, chart table, chartplotter | søkort, kortbord, kortplotter |
| course, heading, bearing | kurs, kurs (styret), pejling |
| waypoint | rutepunkt |
| sail, sail trim, under sail / engine | sejl, sejltrim, for sejl / for motor |
| nm (nautical miles), kn (knots) | sm (sømil), kn (knob) |
| h, min, d | t, min, d |
| wind, gust, calm | vind, vindstød, stille |
| strong winds, gale, storm | hård vind, kuling, storm |
| squall, thunderstorm, hurricane | byge, tordenvejr, orkan |
| tropical storm | tropisk storm |
| forecast | vejrudsigt |
| voyage, passage, Long Passage | sejlads, passage, Lang passage |
| set sail, arrive | sætte sejl, ankomme |
| provisions, food and water, stores | proviant, mad og vand, forråd |
| renown | ry |
| captain, captain's hat | kaptajn, kaptajnshue |
| Captain's Log | Logbogen |
| boatyard, haul-out | bådeværft, optagning |
| hull, antifouling, rigging | skrog, bundmaling, rigning |
| fish, rod, reel, cool box, catch | fisk, fiskestang, hjul, køleboks, fangst |
| trophy board | trofætavle |
| radar, collision risk | radar, kollisionsrisiko |
| VHF radio, channel 16 | VHF-radio, kanal 16 |
| coastguard, stand by | kystvagten, ligge standby |
| save, load, slot | gem, indlæs, plads |
| settings, apply, cancel | indstillinger, anvend, annuller |
| compass N NE E SE S SW W NW | N NØ Ø SØ S SV V NV (16 punkter: NNØ, ØNØ, …) |
| months | januar … december (short: jan., feb., mar., apr., maj, jun., jul., aug., sep., okt., nov., dec.) |
| weekdays | søndag … lørdag (short: søn., man., tirs., ons., tors., fre., lør.) |
| chandlery, sailmaker, fishmonger | skibshandel, sejlmager, fiskehandler |
| sailcloth, tanbark, bend on (sails) | sejldug, barket, slå under |
| Make it home (cabin things) | Gør det hjemligt |
| harbour names | own Danish names where Danes use them: København, Göteborg, Lissabon, Venedig, Neapel, Athen, Rom; otherwise unchanged |
