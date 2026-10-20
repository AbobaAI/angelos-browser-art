import QtQuick
import Quickshell
import Quickshell.Io
import qs.config
import qs.services

// Fills Lyrics.artUrl (the cover every AngelOS media widget shows) when the player sends no
// mpris:artUrl but has a web page url (Firefox on YouTube etc.).
Item {
    id: root
    property var plugin

    readonly property var player: Lyrics.player
    readonly property string pageUrl: player && player.metadata ? String(player.metadata["xesam:url"] || "") : ""
    // a web page / stream url, or a local file
    readonly property string key: Lyrics.trackArt === "" && player && (/^(https?|file):\/\//i.test(pageUrl) || pageUrl.startsWith("/") || Lyrics.artist !== "") ? pageUrl + "\u0001" + Lyrics.artist + "\u0001" + Lyrics.album + "\u0001" + Lyrics.title : ""
    property string ours: ""            // the cover we set (cleared when the track has none)

    // qs -c angelos ipc call browserart status
    IpcHandler {
        target: "browserart"
        function status(): string {
            return JSON.stringify({ "page": root.pageUrl, "artist": Lyrics.artist, "album": Lyrics.album, "title": Lyrics.title, "mprisArt": Lyrics.trackArt, "cover": Lyrics.artUrl, "sets": root.sets });
        }
        function refresh(): void {
            root.done = ({});
            root.apply();
        }
    }

    // key -> the cover we settled on ("file://…", real or generated): a key seen again (the
    // player list or metadata blinking for a moment) gets its cover back at once, no refetch
    property var done: ({})
    property int sets: 0                // how many times we wrote Lyrics.artUrl (status)

    function put(u) {
        if (Lyrics.artUrl !== u) {
            Lyrics.artUrl = u;
            sets++;
        }
        ours = u;
    }

    onKeyChanged: settle.restart()
    // metadata arrives in pieces (title, then artist, url…) and the key can go "" for a moment:
    // act only when it has been still for a bit, never blank the cover in between
    Timer {
        id: settle
        interval: 600
        onTriggered: root.apply()
    }
    Connections {
        target: Lyrics
        // AngelOS blanks artUrl when the player's own art changes: put ours back without a gap
        function onArtUrlChanged() {
            if (Lyrics.artUrl === "" && Lyrics.trackArt === "" && root.key !== "" && root.done[root.key])
                root.put(root.done[root.key]);
            else if (Lyrics.artUrl === "" && root.key !== "")
                settle.restart();
        }
    }
    Component.onCompleted: settle.restart()

    function apply() {
        if (key === "" || Lyrics.trackArt !== "") {
            // the player has its own cover now, or nothing plays: take ours down
            if (ours !== "" && Lyrics.artUrl === ours && Lyrics.trackArt === "")
                put("");
            ours = "";
            return;
        }
        if (done[key]) {
            put(done[key]);
            return;
        }
        let h = 0;
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) | 0;
        const file = Config.cacheDir + "/browser-art/" + (h >>> 0).toString(16) + "-" + key.length;
        if (fetcher.running || gen.running)
            return;             // their exit asks again
        fetcher.forUrl = key;
        fetcher.file = file;
        const k = key.split("\u0001");
        fetcher.command = ["sh", Config.pluginsDir + "/browser-art/fetch.sh", k[0], k[1], k[2], k[3], file];
        fetcher.running = true;
    }
    function remember(k, u) {
        const d = Object.assign({}, done);
        const ks = Object.keys(d);
        if (ks.length > 50)
            delete d[ks[0]];
        d[k] = u;
        done = d;
    }
    Process {
        id: fetcher
        property string forUrl: ""
        property string file: ""
        onExited: code => {
            if (code === 0) {
                root.remember(forUrl, "file://" + file);
            } else if (root.plugin ? root.plugin.get("fallback", true) : true) {
                const k = forUrl.split("\u0001");
                gen.forKey = forUrl;
                gen.command = ["python3", Config.pluginsDir + "/browser-art/fallback.py", k[1] || "", k[3] || k[0], Config.cacheDir + "/browser-art"];
                gen.running = true;
                return;
            } else {
                root.remember(forUrl, "");
            }
            Qt.callLater(root.apply);
        }
    }
    // a generated pixel cassette in the current palette when nothing real was found
    Process {
        id: gen
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                root.remember(gen.forKey, f !== "" ? "file://" + f : "");
            }
        }
        onExited: Qt.callLater(root.apply)
    }
}
