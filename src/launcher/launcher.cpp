// The Pakoon launcher: shows the three games and starts the one picked.
//
// On Raspberry Pi OS it prints the number of the game picked (0, 1 or 2) and ends, and
// the pakoon script starts that game and opens the launcher again afterwards. Exit status
// 1 means the window was closed. On Windows there is no script: the launcher starts the
// game itself, waits for it and comes back.
//
//   launcher [N]      opens with game N selected
//   launcher --check  loads everything without showing the window, for the installer
//
// Beside it are shots/pakoon0.png, pakoon1.png and pakoon2.png, the fonts folder, and the
// games in pakoon0, pakoon1 and pakoon2.
#include <SDL2/SDL.h>
#include <SDL2/SDL_image.h>
#include <SDL2/SDL_ttf.h>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <unistd.h>
#ifdef _WIN32
#define WIN32_LEAN_AND_MEAN
#define NOMINMAX
#include <windows.h>
#endif

static const int W = 920, H = 480;
static const int SHOT_W = 272, SHOT_H = 153, GAP = 24, PAD = 10;
static const int LEFT = (W - 3 * SHOT_W - 2 * GAP) / 2, TOP = 112, TILE_H = SHOT_H + 118;
static const int HINT_Y = H - 58, LINK_Y = H - 32;

// The project's page, shown at the bottom of the window and opened in the browser by a click.
static const char *const LINK_TEXT = "github.com/jameshansen/PiPakoon";
static const char *const LINK_URL = "https://github.com/jameshansen/PiPakoon";

static const char *const names[3] = {"Pakoon 0", "Pakoon 1", "Pakoon 2"};
static const char *const about[3] = {
  "The first one, from 2001. An island to explore in a car that turns into a jet or a helicopter.",
  "Pizza delivery across wild terrain, from 2002. Six worlds and three vehicles, one of them a plane.",
  "Downhill racing in a 1957 Chevrolet, from 2003. Speed races, slalom and air time in seven places around the world.",
};

// The title and the games' names are set in a font that travels with the launcher. The
// rest is set in a plain font the system has. Each list is tried in order.
static const char *const DISPLAY_FONT[] = {
  "fonts/Bungee-Regular.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "C:/Windows/Fonts/arialbd.ttf", NULL};
static const char *const TEXT_FONT[] = {
  "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", "C:/Windows/Fonts/segoeui.ttf", "C:/Windows/Fonts/arial.ttf", NULL};

struct Picture { SDL_Texture *texture; int w, h; };

static SDL_Renderer *ren;

static void fail(const char *what) {
  fprintf(stderr, "Pakoon launcher: %s: %s\n", what, SDL_GetError());
  SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Pakoon", what, NULL);
  exit(2);
}

static TTF_Font *font(const char *const *files, int size) {
  for (; *files; files++) {
    TTF_Font *f = TTF_OpenFont(*files, size);
    if (f) return f;
  }
  fail("The launcher could not find a font to use.");
  return NULL;
}

// Text as a picture. A `wrap` above zero breaks it into lines of that width.
static Picture text(TTF_Font *f, const char *s, SDL_Color colour, int wrap) {
  SDL_Surface *surface = wrap ? TTF_RenderUTF8_Blended_Wrapped(f, s, colour, wrap) : TTF_RenderUTF8_Blended(f, s, colour);
  if (!surface) fail("The launcher could not draw its text.");
  Picture p = {SDL_CreateTextureFromSurface(ren, surface), surface->w, surface->h};
  SDL_FreeSurface(surface);
  if (!p.texture) fail("The launcher could not draw its text.");
  return p;
}

static void put(const Picture &p, int x, int y) {
  SDL_Rect to = {x, y, p.w, p.h};
  SDL_RenderCopy(ren, p.texture, NULL, &to);
}

static SDL_Rect tile(int i) {
  SDL_Rect r = {LEFT + i * (SHOT_W + GAP) - PAD, TOP - PAD, SHOT_W + 2 * PAD, TILE_H + 2 * PAD};
  return r;
}

// The game under a point of the window, or -1.
static int tile_at(int x, int y) {
  SDL_Point at = {x, y};
  for (int i = 0; i < 3; i++) {
    SDL_Rect r = tile(i);
    if (SDL_PointInRect(&at, &r)) return i;
  }
  return -1;
}

// Game `n` has been picked. True means the launcher's work is done and it should end.
static bool picked(int n, SDL_Window *window) {
#ifdef _WIN32
  // Start the game in its own folder, step out of the way and wait for it to end.
  char folder[32], program[64];
  SDL_snprintf(folder, sizeof folder, "pakoon%d", n);
  SDL_snprintf(program, sizeof program, "pakoon%d\\Pakoon.exe", n);
  STARTUPINFOA start = {sizeof start};
  PROCESS_INFORMATION game;
  SDL_HideWindow(window);
  if (CreateProcessA(program, NULL, NULL, NULL, FALSE, 0, NULL, folder, &start, &game)) {
    WaitForSingleObject(game.hProcess, INFINITE);
    CloseHandle(game.hProcess);
    CloseHandle(game.hThread);
  } else {
    SDL_ShowSimpleMessageBox(SDL_MESSAGEBOX_ERROR, "Pakoon", "That game would not start.", NULL);
  }
  SDL_ShowWindow(window);
  SDL_RaiseWindow(window);
  SDL_FlushEvents(SDL_FIRSTEVENT, SDL_LASTEVENT);
  return false;
#else
  printf("%d\n", n);
  return true;
#endif
}

int main(int argc, char **argv) {
  bool check = argc > 1 && !strcmp(argv[1], "--check");
  int selected = argc > 1 && !check ? atoi(argv[1]) : 0;
  if (selected < 0 || selected > 2) selected = 0;

  if (SDL_Init(SDL_INIT_VIDEO) < 0) fail("The launcher could not start SDL.");
  // Everything is found from the launcher's own folder, wherever it was started from.
  char *base = SDL_GetBasePath();
  if (base && chdir(base) != 0) fail("The launcher could not open its own folder.");
  SDL_free(base);
  if (TTF_Init() < 0) fail("The launcher could not start its fonts.");
  if (!(IMG_Init(IMG_INIT_PNG) & IMG_INIT_PNG)) fail("The launcher could not load pictures.");
  SDL_Window *window = SDL_CreateWindow("Pakoon", SDL_WINDOWPOS_CENTERED, SDL_WINDOWPOS_CENTERED, W, H, check ? SDL_WINDOW_HIDDEN : 0);
  if (!window) fail("The launcher could not open its window.");
  ren = SDL_CreateRenderer(window, -1, 0);
  if (!ren) fail("The launcher could not draw in its window.");
  SDL_RenderSetLogicalSize(ren, W, H);

  const SDL_Color white = {240, 240, 240, 255}, grey = {168, 172, 182, 255};
  TTF_Font *big = font(DISPLAY_FONT, 36), *bold = font(DISPLAY_FONT, 19), *plain = font(TEXT_FONT, 13);
  Picture title = text(big, "Pakoon", white, 0);
  Picture byline = text(plain, "Three driving games by Mikko Oksalahti", grey, 0);
  Picture hint = text(plain, "Arrow keys and Enter, or click, to play.   Esc closes.", grey, 0);
  const SDL_Color blue = {120, 176, 255, 255}, bright = {190, 216, 255, 255};
  TTF_SetFontStyle(plain, TTF_STYLE_UNDERLINE);
  Picture link = text(plain, LINK_TEXT, blue, 0), link_lit = text(plain, LINK_TEXT, bright, 0);
  TTF_SetFontStyle(plain, TTF_STYLE_NORMAL);
  const SDL_Rect link_at = {(W - link.w) / 2 - 6, LINK_Y - 4, link.w + 12, link.h + 8};
  SDL_Cursor *arrow = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_ARROW), *hand = SDL_CreateSystemCursor(SDL_SYSTEM_CURSOR_HAND);
  bool on_link = false;
  Picture shot[3], name[3], line[3];
  for (int i = 0; i < 3; i++) {
    char path[64];
    SDL_snprintf(path, sizeof path, "shots/pakoon%d.png", i);
    shot[i].texture = IMG_LoadTexture(ren, path);
    if (!shot[i].texture) fail("The launcher could not find its pictures of the games.");
    shot[i].w = SHOT_W;
    shot[i].h = SHOT_H;
    name[i] = text(bold, names[i], white, 0);
    line[i] = text(plain, about[i], grey, SHOT_W);
  }
  if (check) return 0;

  for (bool redraw = true;;) {
    if (redraw) {
      SDL_SetRenderDrawColor(ren, 22, 24, 30, 255);
      SDL_RenderClear(ren);
      put(title, (W - title.w) / 2, 68 - title.h);
      put(byline, (W - byline.w) / 2, 70);
      for (int i = 0; i < 3; i++) {
        SDL_Rect r = tile(i);
        if (i == selected) {
          SDL_SetRenderDrawColor(ren, 255, 170, 40, 255);
          SDL_RenderFillRect(ren, &r);
          SDL_Rect inner = {r.x + 3, r.y + 3, r.w - 6, r.h - 6};
          SDL_SetRenderDrawColor(ren, 48, 52, 64, 255);
          SDL_RenderFillRect(ren, &inner);
        }
        put(shot[i], r.x + PAD, r.y + PAD);
        put(name[i], r.x + PAD, r.y + PAD + SHOT_H + 36 - name[i].h);
        put(line[i], r.x + PAD, r.y + PAD + SHOT_H + 40);
      }
      put(hint, (W - hint.w) / 2, HINT_Y);
      put(on_link ? link_lit : link, (W - link.w) / 2, LINK_Y);
      SDL_RenderPresent(ren);
      redraw = false;
    }

    SDL_Event e;
    if (!SDL_WaitEvent(&e)) fail("The launcher lost its window.");
    int over, was = selected, play = -1;
    bool was_on_link = on_link;
    SDL_Point at;
    switch (e.type) {
    case SDL_QUIT:
      return 1;
    case SDL_KEYDOWN:
      switch (e.key.keysym.sym) {
      case SDLK_LEFT: case SDLK_UP: selected = (selected + 2) % 3; break;
      case SDLK_RIGHT: case SDLK_DOWN: case SDLK_TAB: selected = (selected + 1) % 3; break;
      case SDLK_0: case SDLK_1: case SDLK_2: selected = e.key.keysym.sym - SDLK_0; break;
      case SDLK_RETURN: case SDLK_KP_ENTER: case SDLK_SPACE: play = selected; break;
      case SDLK_ESCAPE:
        return 1;
      }
      break;
    case SDL_MOUSEMOTION:
      over = tile_at(e.motion.x, e.motion.y);
      if (over >= 0) selected = over;
      at.x = e.motion.x;
      at.y = e.motion.y;
      on_link = SDL_PointInRect(&at, &link_at);
      break;
    case SDL_MOUSEBUTTONUP:
      if (e.button.button != SDL_BUTTON_LEFT) break;
      play = tile_at(e.button.x, e.button.y);
      at.x = e.button.x;
      at.y = e.button.y;
      if (play < 0 && SDL_PointInRect(&at, &link_at)) SDL_OpenURL(LINK_URL);
      break;
    case SDL_WINDOWEVENT:
      if (e.window.event == SDL_WINDOWEVENT_LEAVE) on_link = false;
      redraw = true;
      break;
    }
    if (play >= 0) {
      selected = play;
      if (picked(play, window)) return 0;
      redraw = true;
    }
    if (on_link != was_on_link) SDL_SetCursor(on_link ? hand : arrow);
    if (selected != was || on_link != was_on_link) redraw = true;
  }
}
