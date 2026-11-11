#!/bin/bash
# Builds runtime.tar.xz: the three games and the launcher, compiled for 64-bit Raspberry
# Pi OS, with the files they play from.
#
# Run it on a Raspberry Pi:  tools/build-runtime.sh
# It needs g++ and make, which Raspberry Pi OS comes with. The headers it lacks (SDL2 and
# its add-ons, Vorbis, Ogg) are downloaded as Debian packages and unpacked into the build
# folder, so nothing gets installed. BUILD names that folder; the default is a new one in
# /dev/shm, the Pi's memory disk.
set -eu -o pipefail
repo=$(dirname "$(dirname "$(readlink -f "$0")")")
build=${BUILD:-$(mktemp -d /dev/shm/pakoon-build.XXXXXX)}
arch=$(dpkg-architecture -qDEB_HOST_MULTIARCH)
mkdir -p "$build/dev" "$build/src"

echo "Fetching headers into $build/dev"
(
  cd "$build/dev"
  [ -d root ] || {
    apt-get download libsdl2-dev libsdl2-ttf-dev libsdl2-image-dev libsdl2-net-dev libsdl2-net-2.0-0 libvorbis-dev libogg-dev >/dev/null
    for deb in *.deb; do dpkg-deb -x "$deb" root; done
  }
)
dev=$build/dev/root/usr
# Each library is named by the file a Pi has at run time, so no development links are needed.
# SDL2_net is the one library a fresh Raspberry Pi OS lacks; it travels in lib/ beside the games.
flags="-c -O2 -fsigned-char -fno-strict-aliasing -w -D_REENTRANT -I$dev/include -I$dev/include/SDL2 -I$dev/include/$arch"
libs="-L$dev/lib/$arch -l:libSDL2-2.0.so.0 -l:libSDL2_ttf-2.0.so.0 -l:libSDL2_image-2.0.so.0 -l:libSDL2_net-2.0.so.0 -l:libGL.so.1 -l:libGLU.so.1 -l:libvorbisfile.so.3"
# The games look in lib/ beside their own folder first. The doubled dollar and the quotes carry
# $ORIGIN through make and its shell to the linker as it is.
libs="$libs -Wl,-rpath,'\$\$ORIGIN/../lib'"

rm -rf "$build/runtime"
mkdir -p "$build/runtime/lib"
for game in pakoon0 pakoon1 pakoon2; do
  echo "Building $game"
  rm -rf "$build/src/$game"
  cp -r "$repo/src/$game" "$build/src/$game"
  make -C "$build/src/$game" -j"$(nproc)" CFLAGS="$flags" LDFLAGS="$libs" >"$build/$game.log" 2>&1 ||
    { tail -20 "$build/$game.log"; exit 1; }
  strip "$build/src/$game/Pakoon"
  # Everything the game opens: the whole folder apart from its source code.
  (cd "$build/src" && find "$game" -type f ! -name '*.cpp' ! -name '*.h' ! -name '*.o' ! -name '*.rc2' ! -name Makefile -print0 |
    xargs -0 cp --parents -t "$build/runtime")
done

echo "Building the launcher"
g++ -O2 -Wall ${flags#-c } -o "$build/runtime/launcher" "$repo/src/launcher/launcher.cpp" \
  -L"$dev/lib/$arch" -l:libSDL2-2.0.so.0 -l:libSDL2_image-2.0.so.0 -l:libSDL2_ttf-2.0.so.0
strip "$build/runtime/launcher"
cp -r "$repo/pakoon" "$repo/shots" "$repo/fonts" "$build/runtime/"
cp -L "$dev/lib/$arch/libSDL2_net-2.0.so.0" "$build/runtime/lib/"
chmod 755 "$build/runtime/pakoon" "$build/runtime/launcher" "$build/runtime"/pakoon?/Pakoon

tar -cJf "$repo/runtime.tar.xz" --owner=0 --group=0 --sort=name -C "$build/runtime" .
echo "Wrote runtime.tar.xz: $(du -h "$repo/runtime.tar.xz" | cut -f1), $(tar -tJf "$repo/runtime.tar.xz" | wc -l) entries (RUNTIME_FILES in install.sh)"
