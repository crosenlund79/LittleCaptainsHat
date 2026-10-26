# Original soundtrack: three songs for a life at sea

A music injection for Little Captain's Hat. It adds three original instrumental pieces, the game integration that chooses between them, and the sources to revise them.

- The version stays **0.105b** and the save format stays **12**. Nothing about the music is saved.
- Gameplay, the Captain's Chartroom interface and its colours are unchanged.

> **About listening.** I can render and measure audio but I cannot hear it. Every judgement below comes from the rendered audio, not from listening:
> - piano rolls, spectrograms and loudness curves of each full piece;
> - an automatic check of the melody against the harmony;
> - measured loop seams and peaks;
> - the pieces captured from the game's Music bus.
>
> **No human listening test has been done.** The Captain's own ears decide whether the music is a pleasure to listen to.

## 1. Tracks

| Piece | Plays | Length | Key(s) | Tempo range | File |
|---|---|---|---|---|---|
| **Home Upon the Waves** | daytime harbour, cabin, at anchor, title screen | **8:43** (523 s) | D, waltz in G | 64–90 BPM | 6.8 MB |
| **The Wind Knows the Way** | daytime underway on deck, Long Passage | **9:30** (570 s) | G, lifting to A | 84–112 BPM | 7.8 MB |
| **Lanterns Across the Water** | night, anywhere aboard | **8:12** (492 s) | F, warmed in B♭ | 48–72 BPM | 5.7 MB |

**All three files:**
- OGG Vorbis, 44.1 kHz stereo, quality 5;
- 20.4 MB together, in `assets/audio/music/`;
- each one musical loop long, with no added silence and no slowed playback.

**Mastering:**
- all at **−20.0 LUFS** integrated, so the three match;
- peaks of −4.1, −4.2 and −5.4 dBFS, so nothing clips and there is headroom for game sounds;
- short-term loudness moves gently within about −16 to −30 LUFS.

**Shared motif.** All three share one six-note motif, `1 5 6-5 3 | 2`: up a fifth from home, a small turn, then resting on the open second degree. It appears as:
- a piano phrase in the cabin piece;
- a flute call when the sails go up;
- a music-box line under the stars.

## 2. Composition process

The scores are Python scripts, one per piece, in `tools/music/tracks/`.

**Themes.** I wrote the themes by hand, note by note:
- the melodies in scale degrees;
- the chords bar by bar;
- the order of sections, keys, metres, tempos and instrumentation.

**Arranging.** A small arranging library (`tools/music/lch_music/`) turns each section into notes:
- the melodies, with occasional sung-style ornaments;
- fingerpicked or strummed guitar, piano broken chords, block chords or waltz figures;
- voice-led string chords, a bass with approach notes, harp arpeggios and very soft brushes;
- counter-lines that move against the tune, and harmony a third away.

**Expression.** Timing and dynamics are humanised from a fixed seed, so every render is identical:
- velocities rise and fall over each phrase;
- small timing variations and rolled chords;
- a slight breath in tempo at each four-bar phrase end;
- written ritardandos.

**Harmony check.** Before rendering, every long melody note on a strong beat is checked against the chord sounding at that moment. **All 739 such notes are chord tones** (245, 326 and 168 per piece). The first drafts had 19, 18 and 1 clashes; each was fixed by changing the chord or the note.

**Rendering.** Each instrument is rendered separately with TinySoundFont and the GeneralUser GS SoundFont, then mixed:
- each instrument is filtered (gentle low-passes against harsh highs; the night piano is the grand piano darkened to a "felt" tone), panned and levelled;
- the levels were set by measuring each instrument's loudness per section, not by guesswork;
- all instruments share a soft synthetic hall: 2.3 s for the cabin, 1.9 s for sailing, 3.2 s for night.

**Mastering steps:** a high-shelf cut of −2.5 dB above 7.5 kHz, loudness normalisation (BS.1770-style gating) and a smooth peak limiter at −3 dBFS. The limiter never engaged.

**Problems found by looking at the analysis:**
- **Stuck notes.** The first render held notes that never ended (constant spectrogram lines, rising loudness). Re-struck notes now release first.
- **Bright strings.** Violin and viola were too bright, up to 12 kHz. The low-pass filters were made steeper.
- **Loudness jumps.** Some sections jumped by about 8 LU and the night music-box passage dipped by 12 LU. Levels were rebalanced.
- **Too short.** *The Wind Knows the Way* was first 7.95 min. It gained a calm clarinet passage, a fuller homeward phrase and a playful 3/4 "Dolphins" section.

**Pictures of each piece** (piano roll by instrument with sections marked, spectrogram, short-term loudness):
- [Home Upon the Waves](soundtrack/home_upon_the_waves.png)
- [The Wind Knows the Way](soundtrack/the_wind_knows_the_way.png)
- [Lanterns Across the Water](soundtrack/lanterns_across_the_water.png)

## 3. Structure and tempo maps

These are the composed sections and their tempos (BPM, ramped across the section). Times are from the start of the file.

### Home Upon the Waves (D major, 8:43)

A small, affectionate tune (A) on piano over fingerpicked guitar, a gentler clarinet tune (B), a development, a waltz (C), then home: first fuller, then very simply.

| Time | Section | Key | Metre | Tempo | Bars | Who plays |
|---|---|---|---|---|---|---|
| 0:00 | Intro | D | 4/4 | 70→72 | 8 | guitar; the motif on piano |
| 0:27 | A | D | 4/4 | 76 | 16 | piano tune, guitar, bass joins |
| 1:18 | A cello | D | 4/4 | 76 | 16 | cello tune, rolling piano, flute counter-line, strings |
| 2:08 | Breath | D | 4/4 | 74→70 | 4 | guitar, a piano phrase |
| 2:22 | B | D (B minor colour) | 4/4 | 72 | 16 | clarinet; then harp and cello |
| 3:15 | Interlude | D | 4/4 | 70 | 8 | guitar, flute, harp (very spacious) |
| 3:43 | Development | D | 4/4 | 74 | 16 | the motif passed between clarinet and flute, then piano |
| 4:35 | To the waltz | G | 3/4 | 80→86 | 2 | harp roll |
| 4:39 | Waltz | G | 3/4 | 88 | 16 | flute, guitar waltz, pizzicato |
| 5:12 | Waltz violin | G | 3/4 | 90 | 16 | violin, clarinet in thirds, piano waltz |
| 5:44 | Waltz quiet | G | 3/4 | 86→80 | 16 | piano and guitar only |
| 6:19 | Bridge | D | 4/4 | 74→76 | 4 | clarinet, strings, harp |
| 6:32 | A full | D | 4/4 | 78 | 16 | piano, flute above, violin counter-line (the fullest, still gentle) |
| 7:21 | B cello | D | 4/4 | 72 | 8 | cello, piano |
| 7:48 | A simple | D | 4/4 | 74→72 | 8 | piano and guitar |
| 8:14 | Coda | D | 4/4 | 72→64, ritardando | 8 | motif fragments; ends on the dominant, leading back to the Intro |

### The Wind Knows the Way (G major, 9:30)

A journey: departure, the sails filling, the sailing tune (S), a broad tune (T), a calm middle, a long horizon, islands, dolphins, a lift into A major, and a slowing landing.

| Time | Section | Key | Metre | Tempo | Bars | Who plays |
|---|---|---|---|---|---|---|
| 0:00 | Departure | G | 4/4 | 86→88 | 8 | fingerpicked guitar; the motif on flute |
| 0:22 | Hoisting | G | 4/4 | 92→96 | 8 | strum enters, bass, shaker; piano counter-line |
| 0:43 | Sailing | G | 4/4 | 100 | 16 | flute tune, guitars, bass, brushes |
| 1:21 | Broad | G | 4/4 | 100 | 8 | violin tune, cello below, piano |
| 1:40 | Sailing violin | G | 4/4 | 104 | 16 | violin, flute a third above |
| 2:17 | Sailing piano | G | 4/4 | 100 | 8 | piano and guitar only |
| 2:37 | Easing | G | 4/4 | 98→86 | 4 | guitar, harp |
| 2:47 | Calm | G (E minor colour) | 4/4 | 84 | 16 | oboe, then piano; harp, cello |
| 3:33 | Calm clarinet | G | 4/4 | 84 | 8 | clarinet over harp |
| 3:56 | Horizon | G | 4/4 | 84→90 | 16 | the broad tune at half speed, violin over flowing guitar |
| 4:40 | Islands | G | 4/4 | 94→100 | 16 | new tune: clarinet, then flute; rhythm returns |
| 5:20 | Dolphins | G | 3/4 | 112 | 32 | a quick, light waltz: flute, then violin |
| 6:11 | Rising | G → A | 4/4 | 98→104 | 8 | the motif climbing through the keys |
| 6:31 | Sailing in A | A | 4/4 | 106 | 16 | piano tune, flute an octave above (the brightest part) |
| 7:07 | Broad in A | A | 4/4 | 106 | 16 | violin, then cello |
| 7:43 | Islands in A | A | 4/4 | 104 | 8 | clarinet over guitar |
| 8:02 | Breakdown | A → G | 4/4 | 104 | 8 | guitar and shaker; the motif called and answered |
| 8:20 | Homeward | G | 4/4 | 102 | 16 | piano tune, flute weaving |
| 8:58 | Landing | G | 4/4 | 96→84, ritardando | 12 | guitar, flute motif; ends on the dominant, leading back to Departure |

### Lanterns Across the Water (F major, 8:12)

Mostly a slow 3/4 with room to breathe. The lantern tune (L) on a soft "felt" piano, a slightly more moving 4/4 night song (N), music-box stars, the tune warmed in B♭, and the piano alone.

| Time | Section | Key | Metre | Tempo | Bars | Who plays |
|---|---|---|---|---|---|---|
| 0:00 | Intro | F | 3/4 | 54→56 | 8 | soft piano chords; the motif on music box |
| 0:26 | Lantern | F | 3/4 | 60 | 16 | felt piano tune, rocking left hand |
| 1:15 | Lantern cello | F | 3/4 | 60 | 16 | cello, guitar, strings |
| 2:03 | Ripples | F | 3/4 | 58 | 4 | harp, a music-box answer (a pause for breath) |
| 2:15 | Night song | F (D minor colour) | 4/4 | 68→72 | 16 | viola over guitar, bass joins (the more moving passage) |
| 3:10 | Night song clarinet | F | 4/4 | 72 | 16 | clarinet, harp, strings, cello |
| 4:04 | Return | F | 3/4 | 66→60 | 4 | guitar, warm pad |
| 4:15 | Stars | F | 3/4 | 66 | 16 | music box, then celesta; harp, warm pad |
| 4:59 | Stars piano | F | 3/4 | 66→62 | 16 | piano, cello, guitar |
| 5:44 | Lantern in B♭ | B♭ | 3/4 | 62 | 16 | piano, cello counter-line, guitar |
| 6:31 | Piano alone | F | 3/4 | 60→56 | 8 | piano only, breathing between phrases |
| 6:56 | Lantern together | F | 3/4 | 60 | 16 | piano, music box, cello, guitar, strings (still hushed) |
| 7:44 | Coda | F | 3/4 | 56→48, ritardando | 8 | the motif slowing; rests on the dominant, leading back to the Intro |

## 4. Instrumentation

All instruments are General MIDI presets of GeneralUser GS v2.0.3.

- **Home Upon the Waves:**
  - nylon guitar, grand piano (softened), cello, violin, slow strings;
  - clarinet, flute, acoustic bass, pizzicato strings, harp.
- **The Wind Knows the Way:**
  - nylon guitar (picked), steel guitar (strummed, quiet), grand piano;
  - flute, violin, cello, oboe, clarinet, slow strings, acoustic bass, harp;
  - the Brush drum kit, used only for a shaker and soft brush taps.
- **Lanterns Across the Water:**
  - grand piano darkened to a felt tone, music box, celesta, nylon guitar;
  - cello, viola, clarinet, harp, slow strings, a very quiet warm pad, acoustic bass.

There is no accordion, heavy percussion or cinematic build.

## 5. Source and licence

| Part | Source | Licence | Redistribution |
|---|---|---|---|
| Melodies, harmonies, arrangements, scores, MIDI, tools | written for Little Captain's Hat | the project's own | yes |
| SoundFont: GeneralUser GS v2.0.3 | S. Christian Collins, schristiancollins.com, via the author's GitHub repository (SHA-256 recorded in `tools/music/get_soundfont.sh`) | "use without restriction for your own music creation, private or commercial"; samples "allow full use in music production, including the ability to make profit" ([licence text](../../tools/music/soundfont/LICENSE.txt)) | the rendered music, yes; the SoundFont itself is not shipped |
| TinySoundFont (Python binding) | Bernhard Schelling and the binding's authors | MIT | not shipped (build tool) |
| mido, NumPy, SciPy, FFmpeg/libvorbis | open source | MIT / BSD / LGPL | not shipped (build tools) |

**Provenance and future release:**
- **No external music generation.** No external music-generation service, recorded music or third-party melody was used.
- **No imitation.** The motif and themes were written for this game and were not modelled on any existing tune.
  - An early motif idea that resembled the opening of a well-known sea song was rejected before anything was written.
  - Short stepwise and arpeggio figures like `1 3 5 6` are common musical vocabulary. They are not distinctive melodies.
- **Restriction to note.** GeneralUser GS's author states that he cannot be 100 % sure of every sample's origin, though none came from commercial sample libraries, and that he has received no complaints since 2000.
  - This is the only provenance caveat.
  - For a large commercial release, the Captain may want to re-render the same MIDI with a different licensed library. The scores make that a single command once a SoundFont path is given.
- **Attribution.** The project README's *Credits and licences* section records the pieces, the SoundFont and TinySoundFont. [assets/audio/music/README.md](../../assets/audio/music/README.md) records the same next to the files.

## 6. Audio file locations

| What | Where |
|---|---|
| Game files (OGG, looping) and timing sidecars (`.json`: loop length, sections, phrase starts) | `assets/audio/music/` |
| Scores (one script per piece) and the shared motif | `tools/music/tracks/`, `tools/music/lch_music/motif.py` |
| MIDI (tempo map, one track per instrument) | `tools/music/midi/` |
| Build, analysis and loop-check tools; how to render | `tools/music/` ([README](../../tools/music/README.md)) |
| Analysis summaries (loudness, sections) | `tools/music/analysis/` |
| Analysis pictures | `docs/artwork/soundtrack/` |
| Benchmark with music on and off | `docs/benchmarks/soundtrack_music_*_rendered.json` |

**Listening outside the game.** Open the `.ogg` files in `assets/audio/music/` in any player (VLC, a web browser, most music apps). The section tables above say where each passage begins. The MIDI files open in any MIDI editor or notation program.

## 7. Music integration

`MusicDirector` (`src/audio/music_director.gd`) is an autoload. It reuses the game's own day/night clock (`Daylight.sun_elevation` at the boat's position and game time) and the existing Music bus.

**Which piece:**

| Situation | Piece |
|---|---|
| **Night** (the sun at the boat below −4°; day again above −1°), anywhere: cabin, deck, sailing, harbour, at anchor | Lanterns Across the Water (priority) |
| Day, underway on deck (sailing; Long Passage) | The Wind Knows the Way |
| Day otherwise: in harbour, in the cabin (also during a voyage), at anchor or waiting at an anchorage, the title screen | Home Upon the Waves |

**Transitions:**
- **Crossfade.** Changes are crossfaded over **5 s**: the old piece eases out with a sine curve and is then paused, while the new one eases in.
- **Waiting rules.** A new situation must hold for **3 s** (real time) before the music follows. A piece plays at least **25 s** before it can change again. Going briefly below and back does not bounce the music.
- **Resuming.** Each piece has its own player. A piece the game returns to (going below while sailing, then back on deck) resumes **at the start of its four-bar phrase** where it was left, not from the top. The phrase starts come from the build's timing sidecar.
- **Nothing restarts the music.** Opening the pause menu, settings or the chart, petting Snøvs, looking at trophies, saving and loading change nothing. The test checks that playback continues through them.
- **Fast time.** While fast passage time runs (1, 4 or 12 game hours per second), day/night changes of music wait for normal time. 12 h/s through dusk causes no switching.
- **Looping.** Each file is exactly one musical loop: the piece ends on the dominant chord and the opening answers it. The release and reverb tail after the loop point is folded onto the start of the file, so the loop has no gap, cut or click. The OGGs are imported with `loop=true` and the player sets it too.
- **No overlap.** Only one piece is audible once a crossfade ends; the others are paused. A paused player costs no decoding.

**Seam measurements** (`tools/music/check_loops.py` on the game's OGG files):

| Piece | Sample step at the seam | Ordinary step (99.9th percentile) | Last 3 s → first 3 s |
|---|---|---|---|
| Home | 0.0048 | 0.047 | −21.8 → −21.1 LUFS |
| Wind | 0.0028 | 0.040 | −22.8 → −23.2 LUFS |
| Lanterns | 0.0015 | 0.036 | −29.4 → −23.9 LUFS |

The step at each seam is about ten times smaller than an ordinary sample step (no click). Lanterns grows from its quiet coda into the intro, as it does musically.

## 8. Settings

The existing controls are reused. No new sliders were added.

- **Music volume.** Settings → Audio → Music (0–100 %, default 70 %), saved in `settings.cfg` as before.
- **Music off.** At 0 % the Music bus is muted (as before) and the director pauses its players, so nothing is decoded.
- **Independent volumes.** Music, Ambience, Sound Effects and UI keep their own sliders.
- **Default level.** The default stays at 70 %. With the pieces mastered at −20 LUFS this gives roughly −23 LUFS of music before Master: gentle background, below the effects.
- **Music test button.** It plays the old test arpeggio only when the soundtrack is silent. While the soundtrack plays, the soundtrack is the test.
- **Command line.** `-- --no-music` silences the soundtrack (used for the performance comparison).
- **Pause, save, load, main menu.** The music keeps playing through the pause menu, follows the loaded game's time and place, and plays Home on the title screen.

## 9. Tests

All tests were run in this Linux environment with Godot 4.7.2.

| # | Required check | Result |
|---|---|---|
| 1 | Import and startup | `--import` clean; every run below starts the game |
| 2 | The three files load | `test_soundtrack`: OGG, looping, over 8 min each |
| 3 | They produce audible output | captured from the Music bus in-game: RMS 0.052 / 0.084 / 0.049; peaks −4.1 / −4.2 / −5.4 dBFS |
| 4 | Playback duration matches the reported duration | stream lengths equal the sidecars (8.7 / 9.5 / 8.2 min, within 0.1 s) |
| 5 | Selection by daytime and activity | harbour → Home; underway on deck → Wind; underway in the cabin → Home; title screen → Home |
| 6 | Night has priority | night sailing and night cabin → Lanterns |
| 7 | No harsh cuts at day/night | crossfade checked mid-way (both partial) and after (one audible, the other paused) |
| 8 | Re-entering a screen does not restart | pause menu, chart and settings: same piece, playback continues |
| 9 | Volume and mute | mute pauses the player; volume back on resumes it |
| 10 | Music and effects independent | Music 40 % and SFX 90 % set and read back separately |
| 11 | Long Passage and fast time | 12 h/s from noon into night: no switching |
| 12 | No clipping or excessive loudness | −20 LUFS each; peaks ≤ −4.1 dBFS; limiter never engaged |
| 13 | Loop boundaries | seam measurement above; the endings lead into the openings by design |
| 14 | No substantial performance impact | rendered benchmark, see below |
| 15 | Existing saves still load | `test_save_manager` and `test_voyage_persistence` pass; the save format is unchanged |

**Suite runs:**
- `test_soundtrack` on its own: **18/18**.
- With `soundtrack`, `settings_and_audio`, `gameplay_flow`, `save_manager`, `atmosphere`, `branding`, `chartroom_ui`, `long_passage`, `voyage_persistence`, `data_model` and `diagnostics`: **503 passed, 1 failed**. The failure was the title-screen music check, which depended on a session an earlier suite left open. The check now ends that session first. Re-run with `chartroom_ui`, `soundtrack` and `settings_and_audio`: **89/89**.
- `dev_guides` (the guide links, including the updated AUDIO.md): **83/83**.

**Performance.** `benchmark_105b` was rendered twice with music on and twice with `--no-music`. The mean frame time across its 7 scenes was:

| Music on (run 1) | Music on (run 2) | Music off (run 1) | Music off (run 2) |
|---|---|---|---|
| 96.7 ms | 82.8 ms | 85.4 ms | 84.4 ms |

The software renderer's run-to-run spread (the first run of the series was the slowest) is larger than any difference. **There is no measurable cost.** Only one OGG decodes at a time.

**Not run:**
- The full historical regression suite (not required for this injection).
- Windows: **acceptance remains the Captain's**.
- A human listening test (see the note at the top).

## 10. Limitations

- **Synthesised, not recorded.** The instruments are General MIDI samples played by a compact synthesizer. They are expressive enough to carry the melodies, but they are not recorded players. TinySoundFont implements fewer SoundFont modulators than FluidSynth, and GeneralUser GS is designed for a fully standards-compliant synth, so some instruments may sound plainer than the SoundFont can. FluidSynth was not available here.
  - The scores and MIDI are kept, so the same music can be re-rendered later with a richer instrument library or real players without recomposing.
- **Mechanical playing.** The phrasing is shaped by rules (phrase arcs, small breaths, ritardandos, rolled chords), not by a player's hands. Some passages may still feel mechanical.
- **Not heard.** The pieces were evaluated by analysis, not by ear. Balance, instrument character and how cosy the music feels need the Captain's listening.
- **Repetition.** Variety comes from re-orchestration, counter-lines, ornaments, key and metre changes, and new themes. The main tunes do return several times in each piece, by design.
- **Context rules.**
  - The rule for sailing below decks is a choice: by day underway, the cabin plays Home and the deck plays Wind. With the 3 s settle and 25 s minimum, quick trips below do not bounce the music.
  - Night at anchor plays Lanterns, as asked. Bad weather has no music of its own; the existing storm sounds carry it.
- **Missing sidecar.** If a sidecar `.json` is missing (for example after replacing a file), resuming starts from the beginning of the piece.

## 11. Commits

| Commit | What |
|---|---|
| `439690f` | Soundtrack A: the three pieces, scores, renders, MIDI, analysis |
| `2dbab59` | Soundtrack B: music director, settings, tests, attribution, benchmark |
| this report's commit (see `git log`) | Soundtrack C: this report and the final documentation fixes |

The start of this injection was `5c93b33`, verified as the remote HEAD.
