# Windows acceptance: Visual Identity V01 (0.100a)

For the owner, on Windows with Godot 4.7.2 (standard build). These checks have
**not** been run on Windows: all automated testing was on Linux (see
[VISUAL_IDENTITY_V01_REPORT.md](VISUAL_IDENTITY_V01_REPORT.md)). Tick each box
and note anything that differs.

**Before you start**

- Open the project folder (`project.godot`) in Godot 4.7.2 and press **F5**.
- The game now keeps its files in `%APPDATA%\Little Captains Hat\`. Your Next
  Harbor saves stay in `%APPDATA%\Godot\app_userdata\Next Harbor\saves\`, and
  the new game never writes there. Optional: back that folder up first anyway.
- The diagnostic log of each run is in `%APPDATA%\Little Captains Hat\diagnostics\`
  (or **Settings → Diagnostic logs…**). Please attach the latest file to any
  report.
- One game minute is one real second at 1×.

## 1. Starting the game

- [ ] The window title is **Little Captain's Hat** and the icon is the hat.
- [ ] The title screen shows the hat logo, the hand-lettered name and the
  tagline *Small boat. Wide world. Hold onto your hat.*
- [ ] Bottom right: **Version 0.100a** (with a short commit id when run from
  the editor).
- [ ] If you have Next Harbor saves, **Import Next Harbor saves…** is shown.
  Press it: it asks first, then says which slots it copied into. Check that the
  files in the old folder are unchanged (same dates and sizes), that **Load
  Game** lists the imported saves and that they load (an I006 save gets the
  original hat on its hook). Pressing Import again is not offered.
- [ ] **New Game** starts in Copenhagen as before.

## 2. Finding the hat

- [ ] In the Starling 33's cabin, the captain's hat hangs on a brass hook above
  the forward port locker (top right of the saloon).
- [ ] Walking up to it shows **E Put on captain's hat** and a brass ring.

## 3. Putting it on

- [ ] **E** at the hook: the hat appears on your token, turned the way you
  face; the message says you put it on.

## 4. Removing it

- [ ] **H** anywhere aboard: the hat comes off and is drawn under your arm.
- [ ] **H** again puts it back on. **H** does nothing while a menu is open.

## 5. Storing it

- [ ] **E** at the hook with the hat on (or under your arm) hangs it back up.
- [ ] The controls line at the bottom mentions **H hat**.

## 6. Switching vessels (all three boats)

At the boatyard (pontoon, in harbour), for the Halcyon 40 and the Petrel 36:

- [ ] Hat on the hook → it hangs on the new boat's hook (Halcyon: above the
  owner's sofa, top right hull; Petrel: on the port side, forward of the
  settee).
- [ ] Hat worn → still worn aboard the new boat; never two hats.
- [ ] The hook is reachable on every boat, and the chart table, berth,
  provisions, work station and exit still work as before.

## 7. Strong wind

Easiest with the developer test tools (**pause menu → Developer test tools**,
not F9: F9 is the known freeze from the sea trial), or real weather:

- [ ] Wear the hat **on deck** in calm or fresh wind (below 25 kn): nothing
  happens, however long you stay.

## 8. The warning

- [ ] In a gale (35 kn and more) with the hat on deck, within the first game
  minute: **"Better hold onto your hat! The wind is … kn. Go below, or press H
  to take it off."** Time drops to 1×.
- [ ] The warning is not repeated when you step below and back up soon after.
- [ ] Going below or pressing H keeps the hat safe. Sleeping and remote work
  never lose it.

## 9. Losing the hat

- [ ] Staying on deck in the gale with the hat on: after some game minutes
  (about 13–27 at sea in 40 kn, twice as long in harbour; a few minutes in
  55-kn squall gusts), the hat tumbles away downwind with a short sour note
  and *"Your captain's hat has decided to explore the ocean without you."*
- [ ] No damage, no money lost. The hook in the cabin is now empty
  (**Look at the empty hat hook** says where to buy one).

## 10. Buying a replacement

- [ ] In harbour, the grocery store (pontoon, provisions panel or boatyard)
  has its own row: **Buy captain's hat (€15)**.
- [ ] It is disabled while you have a hat, at sea, or with less than €15.

## 11. The money

- [ ] Buying takes exactly **€15** once (check the HUD before and after). The
  new hat is in your hand: press H to put it on.
- [ ] The provisions price and missing days in the same dialog are exactly as
  before.

## 12. Secret achievements

- [ ] Captain's Log → **Objectives**: *Secret achievements* shows only
  "7 secret achievements are still to discover", no names or rewards.
- [ ] Losing your first hat: a notification **Secret achievement: Captain
  No-Hat. The sea has claimed its most important trophy. +10 renown** with a
  soft chime.
- [ ] It now appears in the list (name in hand lettering, description,
  renown, date); the other six stay hidden. Losing more hats never pays it
  again (Hat Trick comes at the third).

## 13. Captain's Log entries

- [ ] **Log** tab: *Notable moments* lists the hat events with real places
  ("in Copenhagen harbour", "about 12 nm off Skagen, Denmark") and the real
  wind. Recent passages and statistics are unchanged.

## 14. Renown

- [ ] Achievement renown adds to lifetime and unpublished renown and can be
  published as a travel update as before (€2 per renown).

## 15. Saving and loading

- [ ] Save with the hat worn, on the hook, carried or lost; load: the same.
- [ ] Save after an achievement; load: it is still found and not paid again.
- [ ] Quit the game and start it again: Continue works, settings are kept.

## 16. Branding and font readability

- [ ] Hand lettering (Patrick Hand) only on: the title screen, the Captain's
  Log title and headings, found secret achievement names, harbour signs.
- [ ] Everything else (HUD, numbers, chart, settings, dialogs) is still Barlow
  and easy to read, also at **Settings → Interface scale 130 %**.

## 17. Starling visual prototype

- [ ] With **Settings → Artwork: Illustrated (prototype)** the Starling's deck
  and cabin are painted (wood, cushions, ropes, small belongings).
- [ ] **Artwork: Classic** shows the earlier art at once; switch back and forth
  and judge the style. *This is a prototype for your decision.*
- [ ] Walls, furniture, stations, the cat and the provisions display are where
  they were; you cannot walk through anything new or through anything old.

## 18. Copenhagen landmark

- [ ] On deck in Copenhagen (Illustrated): a planked pontoon, mooring ropes, a
  cobbled quay with bollards and lamps, and the colourful Nyhavn houses at the
  bottom of the screen.
- [ ] Sail to another harbour (e.g. Malmö or Kiel): the same harbour style,
  its own name, no landmark.

## 19. Harbour facilities

- [ ] Wooden signs **Groceries** and **Boatyard · Repairs** on the pontoon;
  both still open with E as before. No other services are signposted.
- [ ] The Halcyon 40 and Petrel 36 decks get the same harbour and signs.

## 20. Companions and regression smoke test

- [ ] Pet the cat at its spots in all three cabins (face it and press E); the
  hat hook never takes the focus. (Petting near some berth positions was hard
  before this version too: please note if it is worse, not just still hard.)
- [ ] Plot a course, sail, sleep, arrive; weather warnings, damage, rescue,
  provisions, grocery store, remote work, the Captain's Log, objectives and
  publishing behave as in I006.
- [ ] The chart sidebar and the boatyard panel keep their fixed sizes.

**Known, unchanged from the sea trial** (for the stabilization build): F9 may
freeze (use the pause menu's developer button), cat petting at some berth
positions, Halcyon cabin proportions, grocery price/days rounding, grocery
access differences between vessels, the HUD panel width changing with numbers,
the pause badge moving nearby UI.
