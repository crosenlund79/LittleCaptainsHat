# Soundtrack

Original music for Little Captain's Hat. The `MusicDirector` autoload (`src/audio/music_director.gd`) chooses the piece.

| File | Piece | Plays | Length |
|---|---|---|---|
| `home_upon_the_waves.ogg` | Home Upon the Waves | daytime in harbour, in the cabin, at anchor, on the title screen | 8:43 |
| `the_wind_knows_the_way.ogg` | The Wind Knows the Way | daytime underway on deck, including Long Passage | 9:30 |
| `lanterns_across_the_water.ogg` | Lanterns Across the Water | at night, anywhere aboard | 8:13 |

- **Format.** OGG Vorbis, 44.1 kHz stereo, quality 5. Each file is exactly one loop long: the music runs on from the end straight back into the beginning.
- **Sidecars.** Each `.json` holds the loop length and the start times of the sections and of every four-bar phrase. When the game returns to a piece, it resumes at a phrase start.
- **Sources.** The scores, MIDI files and build scripts are in [`tools/music/`](../../../tools/music/README.md). To change a piece, edit its script and run `python3 tools/music/build.py`. To use your own recording instead, replace the `.ogg` and keep the name. The sidecar may then be deleted; the game resumes from the start of the piece instead.
- **Licence.** The music was composed for this project. It was rendered with the GeneralUser GS SoundFont, whose licence allows distributing music made with it, including commercially. See [the soundtrack report](../../../docs/artwork/ORIGINAL_SOUNDTRACK_REPORT.md).
