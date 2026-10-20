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
    property string wanted: ""

    // qs -c angelos ipc call browserart status
    IpcHandler {
        target: "browserart"
        function status(): string {
            return JSON.stringify({ "page": root.pageUrl, "artist": Lyrics.artist, "album": Lyrics.album, "title": Lyrics.title, "mprisArt": Lyrics.trackArt, "cover": Lyrics.artUrl });
        }
        function refresh(): void {
            root.apply();
        }
    }

    onKeyChanged: Qt.callLater(apply)
    Connections {
        target: Lyrics
        function onArtUrlChanged() {
            if (Lyrics.artUrl === "" && root.key !== "")
                Qt.callLater(root.apply);
        }
    }
    Component.onCompleted: Qt.callLater(apply)

    function apply() {
        if (key === "" || Lyrics.trackArt !== "") {
            if (ours !== "" && Lyrics.artUrl === ours && Lyrics.trackArt === "")
                Lyrics.artUrl = "";
            ours = "";
            return;
        }
        // YouTube: one cover per video id; other sites: per page url
        let h = 0;
        for (let i = 0; i < key.length; i++)
            h = (h * 31 + key.charCodeAt(i)) | 0;
        const file = Config.cacheDir + "/browser-art/" + (h >>> 0).toString(16) + "-" + key.length;
        wanted = key;
        if (fetcher.running)
            return;
        fetcher.forUrl = key;
        fetcher.file = file;
        const k = key.split("\u0001");
        fetcher.command = ["sh", Config.pluginsDir + "/browser-art/fetch.sh", k[0], k[1], k[2], k[3], file];
        fetcher.running = true;
    }
    Process {
        id: fetcher
        property string forUrl: ""
        property string file: ""
        onExited: code => {
            if (forUrl !== root.key) {
                Qt.callLater(root.apply);
                return;
            }
            if (Lyrics.trackArt !== "")
                return;
            if (code === 0) {
                root.ours = "file://" + file;
                Lyrics.artUrl = root.ours;
            } else {
                // the previous track's cover must not stay on this one
                if (root.ours !== "" && Lyrics.artUrl === root.ours)
                    Lyrics.artUrl = "";
                root.ours = "";
                if (root.plugin ? root.plugin.get("fallback", true) : true) {
                    gen.forKey = forUrl;
                    gen.command = ["python3", Config.pluginsDir + "/browser-art/fallback.py", Lyrics.artist || "", Lyrics.title || forUrl, Config.cacheDir + "/browser-art"];
                    gen.running = true;
                }
            }
        }
    }
    // a generated pixel cassette in the current palette when nothing real was found
    Process {
        id: gen
        property string forKey: ""
        stdout: StdioCollector {
            onStreamFinished: {
                const f = text.trim();
                if (f !== "" && gen.forKey === root.key && Lyrics.trackArt === "" && Lyrics.artUrl === "") {
                    root.ours = "file://" + f;
                    Lyrics.artUrl = root.ours;
                }
            }
        }
    }
}
