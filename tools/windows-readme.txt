Pakoon 0, 1 and 2 for Windows
=============================

Three driving games by Mikko Oksalahti, built for 64-bit Windows from their source code.

To play, run Pakoon.exe. It opens a launcher. Pick a game with the arrow keys and Enter,
or with the mouse. Leaving a game brings the launcher back, and Esc closes it.

Keep this folder together. The launcher starts the games from the pakoon0, pakoon1 and
pakoon2 folders beside it.


Keys
----

In all three games:

  Arrow keys    Steer, accelerate and reverse
  Left Ctrl     Brake
  Esc           Menu

Pakoon 0:  J and H turn the car into a jet or a helicopter. F1 to F5 change the camera.
           Home takes you back to the start. Its menus are worked with the mouse.
Pakoon 1:  F1 is help, F2 to F5 change the camera and F8 is the map. Enter and Left Shift
           work the plane's propeller.

Settings, scores and progress are kept in each game's folder.

The games fill the screen. To play in a window, set PAKOON_WINDOW to a size before
starting Pakoon.exe, in a Command Prompt for example:

  set PAKOON_WINDOW=1280x720
  Pakoon.exe


Where it comes from
-------------------

Source code, the Raspberry Pi version and the list of changes made to the games:
https://github.com/jameshansen/PiPakoon

The games are Copyright (C) 2004 Mikko Oksalahti and are free software under the GNU
General Public License, version 2 or later. They were ported to SDL by tunp
(https://github.com/tunp). This is an unofficial build and is not affiliated with either.

The licences folder holds the licences of the games, the launcher and the libraries that
travel with them. SDL2_ttf.dll also contains FreeType (https://freetype.org, FreeType
Licence) and HarfBuzz (https://harfbuzz.github.io, MIT licence).
