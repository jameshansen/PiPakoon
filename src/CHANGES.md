# Changes to the Pakoon sources

`pakoon0`, `pakoon1` and `pakoon2` are the SDL ports of Pakoon 0.03a, 1.ONE and 2.MANY from GitHub, taken at these commits:

| Folder | Source | Commit |
| --- | --- | --- |
| `pakoon0` | [tunp/Pakoon0](https://github.com/tunp/Pakoon0) | `6530831c60ea76ae0fe60bed606853874248b22d` |
| `pakoon1` | [tunp/Pakoon1](https://github.com/tunp/Pakoon1) | `bd32825c3e2c78a861d7812e8223715db5d32c66` |
| `pakoon2` | [tunp/Pakoon2](https://github.com/tunp/Pakoon2) | `7f707360141a553a38b518ac61cccb26317bf535` |

Every other file is byte for byte as it is there. The files below were changed on 10 November 2026 for PiPakoon, and the changes are under the same licence as the games, the GNU General Public License version 2 or later (`gpl.txt` and `Copyright.txt` in each folder).

| File | Change |
| --- | --- |
| `pakoon0/Makefile`, `pakoon1/Makefile`, `pakoon2/Makefile` | Libraries follow the object files on the link line. Before, the linker dropped them and the link failed. |
| `pakoon0/SoundModule.h`, `pakoon1/SoundModule.h`, `pakoon2/SourceCode/SoundModule.h` | `Sound::getSamples` reads straight from the sound and wraps as often as a short looping sound needs. Before, a high engine pitch read past the end of the sound and the game crashed in its sound thread. |
| `pakoon0/SDLHelpers.h`, `pakoon1/SDLHelpers.h`, `pakoon2/SourceCode/SDLHelpers.h` | Fonts are also looked for in `/usr/share/fonts/truetype/freefont` and `/usr/share/fonts/truetype/dejavu`, where Raspberry Pi OS keeps them. New `openGameWindow`, which opens a plain window of the size named by `PAKOON_WINDOW`, or the full-screen window at the height named by `PAKOON_HEIGHT` when SDL's Wayland driver is in use. New `waitForNextFrame`, which holds the game to 100 frames a second. |
| `pakoon0/main2.cpp`, `pakoon1/main.cpp`, `pakoon2/SourceCode/main.cpp` | The window is opened with `openGameWindow`, and the main loop calls `waitForNextFrame` after each frame. The games do a whole number of physics steps per frame, 200 or 300 a second divided by the frame rate, so on a machine that drew more frames than that the world stood still. In `pakoon2`, the browser build's loop function is compiled only for the browser build, so the game compiles for Linux again. |
| `pakoon0/GetawayView.cpp` | `getFirstDialogOfType<DlgOnScreenKbd *>` is instantiated explicitly, so the game links when built with optimization. |
| `pakoon1/HeightMap.cpp`, `pakoon1/PerlinNoise.cpp`, `pakoon2/SourceCode/HeightMap.cpp`, `pakoon2/SourceCode/PerlinNoise.cpp` | Member functions used from other files are no longer marked `inline`, so the game links when built with optimization. |

The Windows build compiles the same files with two extra definitions on the command line, `GL_BGR` and `GL_BGRA`, which Windows' own OpenGL header lacks. `tools/build-windows.sh` has them.

`launcher` is new and is not part of the Pakoon sources. It is under the MIT licence in the repository's `LICENSE`.
