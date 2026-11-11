#!/bin/bash
# Builds Pakoon-Windows.zip: the three games and the launcher for 64-bit Windows.
#
# Run it anywhere that has zig, curl, tar and python3; Git Bash on Windows and any Linux
# both do:  tools/build-windows.sh
# zig (ziglang.org) is the compiler. SDL2's Windows libraries and the Ogg and Vorbis
# sources are downloaded into the build folder and checked against the sums below. BUILD
# names that folder; the default is build-windows in the repository, kept so the next run
# is quick.
set -eu -o pipefail
repo=$(cd "$(dirname "$0")/.." && pwd)
build=${BUILD:-$repo/build-windows}
mkdir -p "$build/dl" "$build/deps" "$build/obj" "$repo/dist"
# Everything below works from inside the build folder with short names, so a space in the
# path to the repository does no harm.
cd "$build"
export TARGET="-target x86_64-windows-gnu"

# name, version, address, SHA-256
libraries="
SDL2        2.32.10 https://github.com/libsdl-org/SDL/releases/download/release-2.32.10/SDL2-devel-2.32.10-mingw.tar.gz           83a5d74012311edc3c0d40ea6faecbe57ad692aa033fa5dc273cc937e3938ff2
SDL2_image  2.8.12  https://github.com/libsdl-org/SDL_image/releases/download/release-2.8.12/SDL2_image-devel-2.8.12-mingw.tar.gz 85a03645d05c59aa3e76a05347fb94887e4e34d23bae6dd22aa3571a2dde9012
SDL2_ttf    2.24.0  https://github.com/libsdl-org/SDL_ttf/releases/download/release-2.24.0/SDL2_ttf-devel-2.24.0-mingw.tar.gz     3a09e0a967ad53eca3ff2701de4d0df3369c0368739a1088a78d9d74908ef2c3
SDL2_net    2.4.0   https://github.com/libsdl-org/SDL_net/releases/download/release-2.4.0/SDL2_net-devel-2.4.0-mingw.tar.gz       0d6de8d1f9c369beea85d9d7a45a0b3e64eb9288c166b9ea84a961cc34d0ba6f
libogg      1.3.6   https://github.com/xiph/ogg/releases/download/v1.3.6/libogg-1.3.6.tar.gz                                      83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638
libvorbis   1.3.7   https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz                                0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab
"
echo "$libraries" | while read -r name version url sum; do
  [ -n "$name" ] || continue
  [ -d "deps/$name-$version" ] && continue
  echo "Fetching $name $version"
  curl -fsSL -o "dl/$name.tar.gz" "$url"
  echo "$sum  dl/$name.tar.gz" | sha256sum -c - >/dev/null || { echo "$name is not the file expected" >&2; exit 1; }
  tar -xzf "dl/$name.tar.gz" -C deps
done

sdl=deps/SDL2-2.32.10/x86_64-w64-mingw32
image=deps/SDL2_image-2.8.12/x86_64-w64-mingw32
ttf=deps/SDL2_ttf-2.24.0/x86_64-w64-mingw32
net=deps/SDL2_net-2.4.0/x86_64-w64-mingw32
ogg=deps/libogg-1.3.6
vorbis=deps/libvorbis-1.3.7
includes="-I$sdl/include -I$sdl/include/SDL2 -I$image/include/SDL2 -I$ttf/include/SDL2 -I$net/include/SDL2 -I$image/include -I$ttf/include -I$net/include -I$ogg/include -I$vorbis/include"

# compile NAME COMPILER FLAGS [FOLDER], with the files to compile on standard input, each
# ended by a NUL. Every file becomes an object in obj/NAME, four at a time. An object is
# left alone if it is newer than its source and than every header in FOLDER.
compile() {
  mkdir -p "obj/$1"
  local newest=""
  [ -z "${4:-}" ] || newest=$(find "$4" -name '*.h' -printf '%T@ %p
' | sort -n | tail -1 | cut -d' ' -f2-)
  OUT=obj/$1 COMPILER=$2 FLAGS=$3 NEWEST=$newest xargs -0 -P 4 -n 1 sh -c '
    o="$OUT/${1##*/}.o"
    if [ "$o" -nt "$1" ] && { [ -z "$NEWEST" ] || [ "$o" -nt "$NEWEST" ]; }; then exit 0; fi
    for attempt in 1 2 3 4; do
      zig $COMPILER $TARGET $FLAGS -c "$1" -o "$o" 2>"$o.log" && exit 0
      sleep 2
    done
    cat "$o.log" >&2
    exit 255' sh
}

# On Windows zig now and then fails to open one of its own files while several copies of
# it run at once. Trying again gets past it, here and in compile above.
patiently() { "$@" 2>/dev/null || { sleep 2; "$@" 2>/dev/null; } || { sleep 4; "$@"; }; }

echo "Building Ogg and Vorbis"
{ printf '%s\0' $ogg/src/bitwise.c $ogg/src/framing.c
  find $vorbis/lib -name '*.c' ! -name psytune.c ! -name tone.c ! -name barkmel.c -print0; } |
  compile vorbis cc "-O2 -w -I$ogg/include -I$vorbis/include -I$vorbis/lib"
rm -f libvorbisfile.a
patiently zig ar rcs libvorbisfile.a obj/vorbis/*.o

patiently zig rc "$repo/src/launcher/pakoon.rc" pakoon.res

# Windows' own OpenGL header stops at version 1.1, so the two later names the games use
# are given here. C++14 keeps the standard library's byte out of the way of Windows'.
flags="-std=gnu++14 -O2 -fno-strict-aliasing -w -Wno-nullability-completeness -DGL_BGR=0x80E0 -DGL_BGRA=0x80E1 $includes"
libs="libvorbisfile.a $sdl/lib/libSDL2main.a $sdl/lib/libSDL2.dll.a $image/lib/libSDL2_image.dll.a $ttf/lib/libSDL2_ttf.dll.a $net/lib/libSDL2_net.dll.a -lmingw32 -lopengl32 -lglu32 -lshell32 -Wl,--subsystem,windows -s"

rm -rf Pakoon
mkdir -p Pakoon/licences
for game in pakoon0 pakoon1 pakoon2; do
  echo "Building $game"
  # BSceneModule.cpp is not part of the game; the Makefile leaves it out too.
  find "$repo/src/$game" -name '*.cpp' ! -name BSceneModule.cpp -print0 | compile "$game" c++ "$flags" "$repo/src/$game"
  # Everything the game opens: the whole folder apart from its source code.
  (cd "$repo/src" && find "$game" -type f ! -name '*.cpp' ! -name '*.h' ! -name '*.o' ! -name '*.rc2' ! -name Makefile -print0 |
    xargs -0 cp --parents -t "$build/Pakoon")
  patiently zig c++ $TARGET -O2 obj/"$game"/*.o pakoon.res -o "Pakoon/$game/Pakoon.exe" $libs
  cp $sdl/bin/SDL2.dll $image/bin/SDL2_image.dll $ttf/bin/SDL2_ttf.dll $net/bin/SDL2_net.dll "Pakoon/$game/"
done

echo "Building the launcher"
printf '%s\0' "$repo/src/launcher/launcher.cpp" | compile launcher c++ "$flags"
patiently zig c++ $TARGET -O2 obj/launcher/*.o pakoon.res -o Pakoon/Pakoon.exe $libs
cp $sdl/bin/SDL2.dll $image/bin/SDL2_image.dll $ttf/bin/SDL2_ttf.dll Pakoon/
cp -r "$repo/shots" "$repo/fonts" Pakoon/
find Pakoon -name '*.pdb' -delete

cp "$repo/src/pakoon0/gpl.txt" "Pakoon/licences/Pakoon - GNU GPL 2.txt"
cp "$repo/src/pakoon0/Copyright.txt" "Pakoon/licences/Pakoon - copyright.txt"
cp "$repo/LICENSE" "Pakoon/licences/Launcher - MIT.txt"
cp "$repo/fonts/OFL.txt" "Pakoon/licences/Launcher font - OFL.txt"
cp deps/SDL2-2.32.10/LICENSE.txt Pakoon/licences/SDL2.txt
cp deps/SDL2_image-2.8.12/LICENSE.txt Pakoon/licences/SDL2_image.txt
cp deps/SDL2_ttf-2.24.0/LICENSE.txt Pakoon/licences/SDL2_ttf.txt
cp deps/SDL2_net-2.4.0/LICENSE.txt Pakoon/licences/SDL2_net.txt
cp $ogg/COPYING Pakoon/licences/Ogg.txt
cp $vorbis/COPYING Pakoon/licences/Vorbis.txt
cp "$repo/tools/windows-readme.txt" Pakoon/README.txt

rm -f Pakoon-Windows.zip
python3 -c "
import os, zipfile
with zipfile.ZipFile('Pakoon-Windows.zip', 'w', zipfile.ZIP_DEFLATED, compresslevel=9) as z:
    for folder, _, files in sorted(os.walk('Pakoon')):
        for name in sorted(files):
            z.write(os.path.join(folder, name))
"
mv Pakoon-Windows.zip "$repo/dist/Pakoon-Windows.zip"
echo "Wrote dist/Pakoon-Windows.zip: $(du -h "$repo/dist/Pakoon-Windows.zip" | cut -f1)"
