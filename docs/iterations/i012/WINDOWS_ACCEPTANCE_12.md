# Windows sea trial: Iteration 12, A Little Harbour Life (0.100c)

A short, focused trial for the Captain and Skipper, about 20 minutes. Tick what
works and note what does not, ideally with a screenshot (Windows + Shift + S).

**Get the project:** open the GitHub branch `claude/friendly-fermat-dey23f`,
choose **Code → Download ZIP**, extract it, open `project.godot` in Godot 4.7
and press **Run** (F5).

Turn the **sound off** for steps 1 and 2: everything there should be clear
without it.

## 1. Hat, without sound

- [ ] Start a **New Game**, wear the hat (**E** at the hook) and go on deck.
- [ ] Wait for windy weather. With the developer tools, **F9 → "Strong winds"**
  is quickest.
- [ ] When the warning comes, a small **fluttering hat** appears top-left:
  "Hold onto your hat! [H]". The warning message stays a few seconds.
- [ ] Stay on deck until the hat goes. The tumble away is easy to see, and
  **"Hat overboard! …"** stays up for about 9 seconds.
- [ ] Go below: a quiet **"Hat missing"** badge stays in the corner.
- [ ] Buy a new hat at the grocery store: the badge goes away.

## 2. Readable shortcuts

- [ ] The shortcut strip at the bottom left (WASD, E, H, L, Esc) is easy to read
  over the pontoon, the quay and Copenhagen's houses, and in the cabin.
- [ ] Settings → Interface scale 130 %: still readable, still small.

## 3. Walk ashore, on all four boats

- [ ] On deck in Copenhagen a **gangplank** leads to the pontoon. Walk down and
  back up. Nothing gets you stuck, and the view follows you ashore.
- [ ] On the pontoon: **Groceries**, **Boatyard · Repairs** and **Go Ashore**
  signs. Walking up to one makes the **sign glow**, with its prompt.
- [ ] Repeat on the **Wing 33**, **Clam 40** and **Frogleap 36** (change boats at
  the boatyard).

## 4. No more circles

- [ ] In the cabin, walk to the chart table, the berth, the galley, the hat hook
  and the steps. **The object itself glows**; no ring.
- [ ] Interactions are still easy to reach. Petting the cat or dog still
  works.

## 5. Harbours differ

- [ ] **Copenhagen** has its boatyard.
- [ ] Sail to **Lohals** (new, on Langeland): **no boatyard sign** and no
  boatyard station. Groceries and Go Ashore are there.

## 6. Go Ashore

- [ ] At the Go Ashore sign press **E**: a small event with a picture and one
  or two choices.
- [ ] Pick one: the cost and the time are as shown, and the first time there is
  a little renown. The event appears under *Notable moments* in the Captain's
  Log (**L**).
- [ ] Go straight back: "a pleasant stroll", with nothing to gain.
- [ ] A few hours later something new is offered.
- [ ] Save, load: the outing is remembered.

## 7. The boat faces its course

- [ ] Set sail. Over a couple of seconds the deck turns so the **bow points
  along the course** (north is up), and it zooms to fit.
- [ ] The HUD stays upright. **W/A/S/D move up/left/down/right on screen.** The
  waves still look right with the wind.
- [ ] Sailing roughly **north or south** (for example towards Gothenburg), the
  boat stands upright on screen. Is the deck still readable?
- [ ] On arrival the boat turns back to its harbour position.
- [ ] Settings → **Sailing view**: untick *Boat faces its course* to compare
  with the old fixed view.

## 8. Report

- [ ] What felt cozy, what felt fiddly, and anything that looked wrong, with
  screenshots.
- [ ] The diagnostic log (Settings → Diagnostic logs…), if anything went
  wrong.

Windows acceptance is the Captain's call. Nothing here has been tested on
Windows by the developer.
