#ifndef SDLHELPERS_H
#define SDLHELPERS_H

#include <SDL2/SDL.h>
#include <SDL2/SDL_ttf.h>
#include <vector>
#include <string>

static const char *font_paths[] = {"C:/windows/fonts/", "/usr/share/fonts/TTF/", "/usr/share/fonts/truetype/freefont/", "/usr/share/fonts/truetype/dejavu/", "./"};
static const short font_path_count = 5;

static SDL_Rect getRect(Sint16 x, Sint16 y, Uint16 w, Uint16 h) {
	SDL_Rect rect;
	rect.x = x;
	rect.y = y;
	rect.w = w;
	rect.h = h;
	return rect;
}

static SDL_Color getColor(Uint8 r, Uint8 g, Uint8 b) {
	SDL_Color color;
	color.r = r;
	color.g = g;
	color.b = b;
	return color;
}

// Holds the game to 100 frames a second. The games do a whole number of physics steps
// per frame, 200 or 300 steps a second divided by the frame rate, so on a machine quick
// enough to draw more frames than that the count comes to nothing and the world stands
// still.
static void waitForNextFrame() {
	static Uint32 last = 0;
	Uint32 now = SDL_GetTicks();
	if (now - last < 10) {
		SDL_Delay(10 - (now - last));
	}
	last = SDL_GetTicks();
}

// The game's window. It fills the screen unless PAKOON_WINDOW gives a size, such as
// 1280x720, for a plain window on the desktop.
//
// With PAKOON_HEIGHT set, say to 720, the full-screen game draws at that height in the
// display's own shape and the display scales the picture up to fill the screen. Fewer
// pixels to draw is what makes a Raspberry Pi 400 quick enough. This needs SDL's Wayland
// driver, which does the scaling; anywhere else, and without the setting, the game draws
// at the display's own size.
static SDL_Window *openGameWindow(const char *title) {
	int w = 0, h = 0;
	const char *wanted = SDL_getenv("PAKOON_WINDOW");
	if (wanted && SDL_sscanf(wanted, "%dx%d", &w, &h) == 2 && w >= 320 && h >= 240) {
		SDL_Window *window = SDL_CreateWindow(title, SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, w, h, SDL_WINDOW_OPENGL);
		if (window) {
			return window;
		}
	}
	wanted = SDL_getenv("PAKOON_HEIGHT");
	h = wanted ? SDL_atoi(wanted) : 0;
	SDL_DisplayMode desktop;
	if (h >= 240 && SDL_strcmp(SDL_GetCurrentVideoDriver(), "wayland") == 0 &&
			SDL_GetDesktopDisplayMode(0, &desktop) == 0 && h < desktop.h) {
		w = (desktop.w * h / desktop.h + 1) & ~1;
		SDL_Window *window = SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, w, h, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN);
		if (window) {
			return window;
		}
	}
	return SDL_CreateWindow(title, SDL_WINDOWPOS_UNDEFINED, SDL_WINDOWPOS_UNDEFINED, 0, 0, SDL_WINDOW_OPENGL | SDL_WINDOW_FULLSCREEN_DESKTOP);
}

static TTF_Font *openFont(std::vector<std::string> fonts, int size) {
	TTF_Font *font = NULL;
	for (int x = 0; x < fonts.size(); x++) {
		for (int y = 0; y < font_path_count; y++) {
			std::string val(font_paths[y]);
			val.append(fonts[x]);
			font = TTF_OpenFont(val.c_str(), size);
			if (font)
				return font;
		}
	}
	return NULL;
}

#endif
