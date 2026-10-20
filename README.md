# Cover Art Fallback / Обложки для любых плееров

Fills the cover in AngelOS media widgets (desktop music widget, Halo, macOS Control Center, bar lyrics in "cover" mode) when the active MPRIS player sends no `mpris:artUrl` — e.g. Firefox on YouTube, terminal players, web radio.

Order of sources:
1. Local file (`file://`): embedded picture (ffmpeg) or `cover.*` / `folder.*` / `front.*` next to it.
2. YouTube link: the video thumbnail (`i.ytimg.com`).
3. Player sends an artist: iTunes Search API, exact artist + album/title match, 600×600.
4. Browser page without artist: the page's `og:image` / `twitter:image` (HTML pages only).
5. Nothing found: a generated pixel cassette in the current AngelOS palette, unique per track (set plugin data `fallback` to `false` to disable).

A player's own cover is never replaced. Covers are cached in `~/.cache/angelos/browser-art/` for a day.

IPC: `qs -c angelos ipc call browserart status` / `refresh`.

**Requirements:** `curl`, `python3`, `python-pillow` (fallback cassette); optional `ffmpeg` (embedded art).
**Network:** i.ytimg.com, itunes.apple.com, mzstatic.com and the playing page's site — only for tracks without a cover. No login, no data sent besides the search query.

---

Подставляет обложку, когда плеер её не отдаёт: превью YouTube, обложка локального файла, поиск в iTunes, og:image страницы, иначе — пиксельная кассета в цветах темы. Настоящие обложки не трогает.

License: MIT
