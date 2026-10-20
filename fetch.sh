#!/bin/sh
# fetch.sh <url> <artist> <album> <title> <cache-file>: write a cover for the track to <cache-file>.
# Order: local file (embedded art / cover.* in its folder) → YouTube thumbnail → iTunes search by
# artist+album/title (music players: cliamp radio etc.) → the page's og:image (browsers, no artist).
url="$1"; artist="$2"; album="$3"; title="$4"; out="$5"; d="${out%/*}"; mkdir -p "$d"
find "$d" -type f -mmin +1440 -delete 2>/dev/null
[ -s "$out" ] && { touch "$out"; exit 0; }
ok() { [ -s "$out.part" ] && [ "$(stat -c%s "$out.part")" -gt "${1:-0}" ] && mv "$out.part" "$out" && exit 0; rm -f "$out.part"; }
get() { curl -sfL -m 12 -o "$out.part" "$1"; ok "$2"; }

case "$url" in
file://*|/*)
  f=$(python3 -c 'import sys,urllib.parse as u;p=sys.argv[1];print(u.unquote(u.urlparse(p).path) if p.startswith("file://") else p)' "$url")
  if [ -f "$f" ]; then
    ffmpeg -v error -y -i "$f" -an -frames:v 1 -c:v mjpeg -f image2 "$out.part" 2>/dev/null; ok
    for c in "${f%/*}"/cover.* "${f%/*}"/folder.* "${f%/*}"/front.* "${f%/*}"/Cover.* "${f%/*}"/Folder.* "${f%/*}"/Front.* "${f%/*}"/*.jpg "${f%/*}"/*.png; do
      case "$c" in *.jpg|*.jpeg|*.png|*.webp|*.JPG|*.PNG) [ -f "$c" ] && { cp "$c" "$out.part"; ok; } ;; esac
    done
  fi ;;
esac

id=$(printf '%s' "$url" | sed -nE 's#.*(youtube\.com/(watch\?(.*&)?v=|shorts/|live/|embed/)|youtu\.be/)([A-Za-z0-9_-]{11}).*#\4#p')
if [ -n "$id" ]; then
  get "https://i.ytimg.com/vi/$id/maxresdefault.jpg" 2000
  get "https://i.ytimg.com/vi/$id/hqdefault.jpg" 2000
  exit 1
fi

if [ -n "$artist" ]; then
  art=$(python3 - "$artist" "$album" "$title" <<'PY'
import json,sys,urllib.parse,urllib.request
artist,album,title=sys.argv[1:4]
def norm(s): return "".join(c for c in s.lower() if c.isalnum())
for term,ent,key in ((artist+" "+album,"album","collectionName"),(artist+" "+title,"song","trackName")):
    if not term.strip() or (ent=="album" and not album) or (ent=="song" and not title): continue
    try:
        q=urllib.parse.urlencode({"term":term,"entity":ent,"limit":10})
        rs=json.load(urllib.request.urlopen("https://itunes.apple.com/search?"+q,timeout=10))["results"]
    except Exception: continue
    want=norm(album if ent=="album" else title)
    for r in rs:
        if norm(r.get("artistName",""))==norm(artist) and norm(r.get(key,""))==want and r.get("artworkUrl100"):
            print(r["artworkUrl100"].replace("100x100bb","600x600bb")); sys.exit()
PY
)
  [ -n "$art" ] && get "$art"
  exit 1
fi

case "$url" in http://*|https://*) ;; *) exit 1;; esac
ct=$(curl -sIL -m 8 "$url" | tr -d '\r' | grep -i '^content-type:' | tail -1)
case "$ct" in *text/html*) ;; *) exit 1;; esac
img=$(curl -sfL -m 10 -A "Mozilla/5.0" "$url" | head -c 400000 | tr '\n' ' ' | grep -oiE '<meta[^>]+(property|name)="(og:image|twitter:image)"[^>]*>' | head -1 | grep -oiE 'content="[^"]+"' | sed 's/^content="//;s/"$//;s/&amp;/\&/g')
[ -n "$img" ] || exit 1
case "$img" in //*) img="https:$img";; /*) img="$(printf '%s' "$url" | grep -oE '^https?://[^/]+')$img";; esac
get "$img"
exit 1
