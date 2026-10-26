#!/bin/sh
# Downloads the GeneralUser GS SoundFont (v2.0.3, S. Christian Collins) used to
# render the soundtrack, and checks it is the exact file the tracks were rendered with.
set -e
cd "$(dirname "$0")"
mkdir -p soundfont
URL=https://raw.githubusercontent.com/mrbumpy409/GeneralUser-GS/main/GeneralUser-GS.sf2
SHA=9575028c7a1f589f5770fccc8cff2734566af40cd26ed836944e9a5152688cfe
[ -f soundfont/GeneralUser-GS.sf2 ] || curl -L -o soundfont/GeneralUser-GS.sf2 "$URL"
echo "$SHA  soundfont/GeneralUser-GS.sf2" | sha256sum -c -
