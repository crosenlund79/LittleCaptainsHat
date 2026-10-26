# Weather sounds (Iteration 17)

Original sounds made for Little Captain's Hat: synthesised from noise and
simple envelopes by `tools/generate_weather_audio.py` (deterministic, fixed
random seeds). No recordings, no third-party material, no network service.

**Licence:** made for this project; they may be redistributed with the game
under the project's own terms. Regenerate with
`python3 tools/generate_weather_audio.py`.

| File | Bus | Used for |
|---|---|---|
| `wind_breeze.wav` | Outside → Ambience | Wind aboard, louder with the wind (loop) |
| `water_hull.wav` | Outside → Ambience | Water along the hull, louder underway (loop) |
| `rain.wav` | Outside → Ambience | Rain in showers, gales and thunderstorms (loop) |
| `thunder_near.wav` | Outside → Ambience | Thunder from a storm within ~3 nm (one shot) |
| `thunder_far.wav` | Outside → Ambience | Distant thunder (one shot) |

The strong-wind loop (`assets/audio/placeholder/storm_wind.wav`, from
Iteration 005a, same kind of generated asset) still plays above 20 kn.
The Outside bus has a low-pass filter that closes below deck (muffling).
