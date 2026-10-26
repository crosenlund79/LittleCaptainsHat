# Windows smoke test: 0.102b, Life at Anchor

About 15 minutes. Nothing here has been tried on Windows yet; this check is
the acceptance. Tick what works, note what does not (a screenshot helps:
Windows + Shift + S).

**Get the project:** GitHub branch `claude/friendly-fermat-dey23f` →
**Code → Download ZIP** → extract → open `project.godot` in Godot 4.7 →
**Run** (F5). The main menu shows **Version 0.102b**.

1. [ ] **Load a 0.102a save** (or start a new game). It opens normally.
2. [ ] **Anchor somewhere safe.** In Copenhagen plot a course to Malmö, set
   sail, and drop anchor near the Øresund coast when the windlass says the
   anchorage is good. The HUD says *At anchor · Holding well*.
3. [ ] **A quiet line.** Let time run (5× or 20×): after a little while one
   short line appears, such as "The anchor holds. The sea is quiet." It does
   not repeat.
4. [ ] **Evening ambience.** Keep time running into the evening (around 18:00
   at the boat; about 17:00 UTC near Copenhagen). On deck the light turns
   gently warm; below deck the cabin lamp glows softly. The HUD adds *a quiet
   evening*, and one evening line appears.
5. [ ] **The companion settles.** Below deck the cat (or dog) stretches and
   curls up, and keeps napping. Pet it: a soft line, once.
6. [ ] **Sleep at anchor.** Sleep at the berth for 8–10 hours. Nothing pops up
   while asleep.
7. [ ] **Wake up.** After the "You slept…" notice, a morning line follows
   ("A new day aboard…"); the cabin light is softly pale; the HUD says *a still
   morning*.
8. [ ] **Make coffee.** At the galley stove the prompt says *Cook a meal or
   make coffee*. Press **Make coffee**: the pot steams, ten minutes pass, a
   warm line appears, and the first morning coffee at anchor is written in the
   Captain's Log (+2 renown). A second cup is just coffee.
9. [ ] **Save and reload** at anchor. Still at anchor, still settled; no line
   repeats, the coffee moment is in the Log once.
10. [ ] **Nothing obvious broke.** Raise the anchor and sail on: the warm
    light goes away; fishing, cooking, the anchor alarm (try the F9 developer
    tests) and the boatyard work as before.

**Result:** ☐ Accepted  ☐ Accepted with notes  ☐ Needs a revision

Notes:
