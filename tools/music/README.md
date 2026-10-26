# The soundtrack's sources

The three pieces of Little Captain's Hat's soundtrack are written as Python composition scripts. They are rendered to audio here; the game plays the results from `assets/audio/music/`.

| Track | Script | Game file |
|---|---|---|
| Home Upon the Waves | `tracks/home_upon_the_waves.py` | `assets/audio/music/home_upon_the_waves.ogg` |
| The Wind Knows the Way | `tracks/the_wind_knows_the_way.py` | `assets/audio/music/the_wind_knows_the_way.ogg` |
| Lanterns Across the Water | `tracks/lanterns_across_the_water.py` | `assets/audio/music/lanterns_across_the_water.ogg` |

Each script is the score. It defines the themes (melodies in scale degrees, so they can move key and register), the chord progressions, and the sections in order. For every section it sets the key, metre and tempo, and states who plays the tune and who accompanies it. The shared six-note motif is in `lch_music/motif.py`.

## Rendering

You need Python 3 with `numpy`, `scipy`, `mido` and `tinysoundfont`, plus `ffmpeg` with libvorbis.

```sh
pip install numpy scipy mido matplotlib
pip install --no-deps tinysoundfont       # its pyaudio dependency is only for live playback, not needed here
sh tools/music/get_soundfont.sh           # GeneralUser GS 2.0.3 (32 MB), checked by SHA-256
python3 tools/music/build.py              # all three; --only home renders one
python3 tools/music/check_loops.py        # loop seams and peaks of the game files
python3 tools/music/analyze.py home_upon_the_waves --wav tools/music/work/home_upon_the_waves.wav
```

`build.py` writes four things per track:
- the MIDI file (`midi/`), with the tempo map and one track per instrument, for editing in any MIDI program or notation software;
- the OGG Vorbis file and a small timing sidecar (`.json`: loop length, section and phrase start times) into `assets/audio/music/`;
- an analysis summary into `analysis/`;
- a full-quality WAV into `work/` (not kept in git).

Rendering all three takes about four minutes. The renders are deterministic: the same scripts and SoundFont give the same notes.

## How a track is made

1. **Score.** `lch_music/arrange.py` turns the script into notes. It writes melodies and the accompaniment figures for each section:
   - fingerpicked or strummed guitar;
   - piano broken chords, block chords or a waltz figure;
   - sustained, voice-led string chords;
   - a walking-ish bass, harp arpeggios and very soft brushes;
   - counter-lines that move against the tune.

   It also builds the tempo map: a tempo ramp per section, a small breath at the end of each four-bar phrase, and ritardandos where asked. Timing and velocity are gently humanised, from a fixed seed.
2. **Harmony audit.** Before rendering, `build.py` checks every long melody note on a strong beat against the chord sounding at that moment. All three tracks pass completely.
3. **Synthesis.** `lch_music/render.py` plays each instrument separately through TinySoundFont with the GeneralUser GS SoundFont. Each instrument is then filtered (no harsh highs; the "felt" night piano is the grand piano darkened), panned and levelled.
4. **Space.** All instruments share a soft synthetic hall reverb. The size differs per track: 2.3 s for the cabin, 1.9 s for sailing, 3.2 s for night.
5. **Mastering.**
   - A gentle high-shelf cut above 7.5 kHz.
   - Loudness normalised to −20 LUFS (integrated, BS.1770-style), so the three tracks match each other.
   - A smooth peak limiter with a −3 dBFS ceiling. It never had to act: peaks are −4 to −5.5 dBFS.
6. **Loop.** Each piece ends on the dominant chord, which leads back into the opening. The reverb and release tail after the loop point is folded onto the start of the file. The file is therefore exactly one loop long and plays back seamlessly; `check_loops.py` measures the seam.
7. **Encoding.** OGG Vorbis, quality 5, 44.1 kHz stereo.

## Licence and provenance

- **The music** (melodies, harmonies, arrangements, scripts) is original to this project. It was composed for Little Captain's Hat and contains no borrowed melodies.
- **The SoundFont** is GeneralUser GS v2.0.3 by S. Christian Collins ([licence](soundfont/LICENSE.txt)). It may be used "without restriction" for music creation, private or commercial, and its samples "allow full use in music production, including the ability to make profit from musical recordings". The rendered audio may therefore be distributed with the game.
  - The SoundFont itself is not part of the game and is not in git.
  - The author notes that he cannot be completely certain of every sample's origin, although none came from commercial sample sets. This is recorded in [the soundtrack report](../../docs/artwork/ORIGINAL_SOUNDTRACK_REPORT.md).
- **The tools** are all open source: TinySoundFont (MIT), mido (MIT), NumPy, SciPy and FFmpeg/libvorbis.
