import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Raksha_Hub

Item {
    id: playerRoot

    property string filePath:     ""
    property real   startMs:      0
    property int    entryId:      -1
    property int    season:       0
    property int    episode:      0
    property string showTitle:    ""
    property string episodeTitle: ""
    property bool   isLoading:    false

    signal playbackStopped(int entryId, int season, int episode,
                           real posMs, real durMs)

    property bool renderContextReady: false
    property bool playPending:        false

    property int  m_switchCount:   0
    property real savedVolume:     100
    property bool stableIsPlaying: false

    Timer {
        id: playDebounce
        interval: 500
        onTriggered: {
            if (!mpv.playing && playerRoot.m_switchCount === 0)
                playerRoot.stableIsPlaying = false
        }
    }

    Component.onCompleted: {
        var v = parseFloat(LibraryManager.getSetting("volume", "100"))
        playerRoot.savedVolume = isNaN(v) ? 100 : v
    }

    // ── Next episode info ────────────────────────
    readonly property var nextEp: (season > 0 && entryId >= 0)
        ? LibraryManager.nextEpisode(entryId, season, episode)
        : ({ "exists": false })

    // ── Save progress ──────────────
    function saveProgress() {
        if (playerRoot.entryId < 0) return
        if (playerRoot.season === 0 && playerRoot.episode === 0)
            LibraryManager.updateMovieProgress(
                playerRoot.entryId, mpv.position, mpv.duration)
        else
            LibraryManager.updateEpisodeProgress(
                playerRoot.entryId, playerRoot.season, playerRoot.episode,
                mpv.position, mpv.duration)
    }

    // ── Jump to next episode ────────────────────────────────────────────
    function playNextEpisode() {
        if (!nextEp || !nextEp.exists) return

        var ep = {
            filePath:   nextEp.filePath,
            positionMs: nextEp.positionMs || 0,
            season:     nextEp.season,
            episode:    nextEp.episode,
            title:      nextEp.title || ""
        }

        if (ep.season > 0 && playerRoot.entryId >= 0)
            LibraryManager.saveSetting("last_ep_" + playerRoot.entryId,
                                       ep.season + "," + ep.episode)

        saveProgress()

        playerRoot.m_switchCount++
        playerRoot.isLoading    = true
        playerRoot.episodeTitle = ep.title

        appWindow.playerStartMs  = ep.positionMs
        appWindow.playerSeason   = ep.season
        appWindow.playerEpisode  = ep.episode
        appWindow.playerFilePath = ep.filePath

        playerRoot.stableIsPlaying = true
        mpv.play(ep.filePath, ep.positionMs)

        showControls()
    }

    // ── Player opened / closed ─────────────────
    onVisibleChanged: {
        if (visible) {
            controlsVisible = true
            hideTimer.restart()
            forceActiveFocus()

            if (filePath.length === 0) return

            playerRoot.stableIsPlaying = true
            if (renderContextReady)
                mpv.play(filePath, startMs)
            else
                playPending = true
        } else {
            mpv.stop()
            playPending = false
            isLoading   = false
        }
    }

    function saveAndClose() {
        playerRoot.playbackStopped(
            playerRoot.entryId, playerRoot.season, playerRoot.episode,
            mpv.position, mpv.duration)
        appWindow.playerOpen = false
    }

    function toggleFullscreen() {
        if (appWindow.visibility === Window.FullScreen)
            appWindow.showNormal()
        else
            appWindow.showFullScreen()
    }

    property bool controlsVisible: true

    function showControls() {
        controlsVisible = true
        hideTimer.restart()
    }

    Timer {
        id: hideTimer
        interval: 1500
        onTriggered: { if (mpv.playing) controlsVisible = false }
    }

    Timer {
        interval: 5000
        repeat: true
        running: mpv.playing
        onTriggered: playerRoot.saveProgress()
    }

    Connections {
        target: mpv
        function onVolumeChanged() {
            playerRoot.savedVolume = mpv.volume
            LibraryManager.saveSetting("volume", mpv.volume.toString())
        }
    }

    // ── Background ─────────────────────────────────────────────────────────
    Rectangle { anchors.fill: parent; color: "#000000" }

    // ── MPV video surface ──────────────────────────────────────────────────
    MpvPlayer {
        id: mpv
        width:  playerRoot.visible ? playerRoot.width  : 1
        height: playerRoot.visible ? playerRoot.height : 1

        onRenderReady: {
            playerRoot.renderContextReady = true
            mpv.setVolume(playerRoot.savedVolume)
            if (playerRoot.playPending && playerRoot.visible &&
                playerRoot.filePath.length > 0) {
                playerRoot.playPending     = false
                playerRoot.stableIsPlaying = true
                mpv.play(playerRoot.filePath, playerRoot.startMs)
            }
        }

        onEndReached: function(finalPos) {
            playerRoot.playbackStopped(
                playerRoot.entryId, playerRoot.season, playerRoot.episode,
                finalPos, mpv.duration)
            if (playerRoot.nextEp && playerRoot.nextEp.exists)
                playerRoot.playNextEpisode()
            else
                appWindow.playerOpen = false
        }

        onStopped: function(finalPos) {}

        onPlayingChanged: {
            if (mpv.playing) {
                if (playerRoot.m_switchCount > 0)
                    playerRoot.m_switchCount--
                playerRoot.stableIsPlaying = true
                playerRoot.isLoading       = false
                playDebounce.stop()
            } else {
                playDebounce.restart()
                if (playerRoot.m_switchCount === 0 && playerRoot.visible)
                    playerRoot.saveProgress()
            }
        }
    }

    // ── Mouse capture ──────────────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: controlsVisible ? Qt.ArrowCursor : Qt.BlankCursor
        onMouseXChanged: playerRoot.showControls()
        onMouseYChanged: playerRoot.showControls()
        onClicked: {
            mpv.togglePause()
            playerRoot.forceActiveFocus()
            playerRoot.showControls()
        }
        onDoubleClicked: playerRoot.toggleFullscreen()
    }

    // ── Keyboard shortcuts ─────────────────────────────────────────────────
    Keys.onPressed: function(event) {
        switch (event.key) {
        case Qt.Key_Space:
            mpv.togglePause()
            playerRoot.showControls()
            event.accepted = true; break
        case Qt.Key_F:
        case Qt.Key_F11:
            playerRoot.toggleFullscreen()
            event.accepted = true; break
        case Qt.Key_Escape:
            if (appWindow.visibility === Window.FullScreen)
                appWindow.showNormal()
            else
                playerRoot.saveAndClose()
            event.accepted = true; break
        case Qt.Key_Left:
            mpv.seek(Math.max(0, mpv.position - 5000))
            playerRoot.showControls()
            event.accepted = true; break
        case Qt.Key_Right:
            mpv.seek(Math.min(mpv.duration, mpv.position + 5000))
            playerRoot.showControls()
            event.accepted = true; break
        case Qt.Key_Up:
            mpv.setVolume(Math.min(130, mpv.volume + 5))
            playerRoot.showControls()
            event.accepted = true; break
        case Qt.Key_Down:
            mpv.setVolume(Math.max(0, mpv.volume - 5))
            playerRoot.showControls()
            event.accepted = true; break
        case Qt.Key_N:
            if (nextEp && nextEp.exists) {
                playerRoot.playNextEpisode()
                event.accepted = true
            }
            break
        }
    }

    // ── Subtitle click anywhere so it close ──────────────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: subMenu.visible
        z: 50
        onClicked: subMenu.visible = false
    }

    // ── Subtitle menu ──────────────────────────────────────────────────────

    Rectangle {
        id: subMenu
        visible: false
        z: 51

        readonly property int rowH:       38
        readonly property int rowSpacing: 2
        readonly property int maxRows:    6
        readonly property int pad:        8
        readonly property int n:          Math.min(mpv.subtitleTracks.length, maxRows)

        width: 220


        height: n > 0 ? n * rowH + Math.max(0, n - 1) * rowSpacing + pad * 2 : 0

        radius: 8; color: "#1c1c1c"
        border.color: "#444"; border.width: 1


        anchors.right:       parent.right
        anchors.rightMargin: 20


        y: playerRoot.height - height - 70

        clip: true

        Flickable {
            anchors.fill: parent
            anchors.margins: subMenu.pad
            contentHeight: subCol.implicitHeight
            clip: true
            flickDeceleration: 800
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: subCol
                width: parent.width
                spacing: subMenu.rowSpacing

                Repeater {
                    model: mpv.subtitleTracks
                    delegate: Rectangle {
                        width: parent.width
                        height: subMenu.rowH
                        radius: 5
                        color: subItemMa.containsMouse ? "#2e2e2e" : "transparent"
                        Behavior on color { ColorAnimation { duration: 80 } }

                        Text {
                            anchors.left:           parent.left
                            anchors.leftMargin:     10
                            anchors.verticalCenter: parent.verticalCenter
                            text: modelData.title || ("Track " + modelData.id)
                            color: "white"
                            font.family: "Consolas"; font.pixelSize: 13
                            elide: Text.ElideRight
                            width: parent.width - 20
                        }

                        MouseArea {
                            id: subItemMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                mpv.setSubtitleTrack(modelData.id)
                                subMenu.visible = false
                            }
                        }
                    }
                }
            }
        }
    }

    // ── Controls overlay ──────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        opacity: playerRoot.controlsVisible ? 1 : 0
        enabled: playerRoot.controlsVisible
        Behavior on opacity { NumberAnimation { duration: 250 } }


        Rectangle {
            anchors.top:   parent.top
            anchors.left:  parent.left
            anchors.right: parent.right
            height: 100
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#cc000000" }
                GradientStop { position: 1.0; color: "#00000000" }
            }

            Row {
                anchors.left:    parent.left
                anchors.top:     parent.top
                anchors.margins: 18
                spacing: 14

                Rectangle {
                    width: 36; height: 36; radius: 18
                    color: backMa.containsMouse ? "#55ffffff" : "#22ffffff"
                    Behavior on color { ColorAnimation { duration: 120 } }
                    Text {
                        anchors.centerIn: parent
                        text: "\u2190"; color: "white"; font.pixelSize: 18
                    }
                    MouseArea {
                        id: backMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: playerRoot.saveAndClose()
                    }
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 3
                    Text {
                        visible: playerRoot.showTitle.length > 0
                        text: playerRoot.showTitle
                        color: "#ffffff"
                        font.family: "Consolas"; font.bold: true; font.pixelSize: 14
                    }
                    Text {
                        visible: playerRoot.season > 0
                        text: "S" + playerRoot.season +
                              " · E" + String(playerRoot.episode).padStart(2, "0") +
                              (playerRoot.episodeTitle.length > 0
                               ? "  " + playerRoot.episodeTitle : "")
                        color: "#aaaaaa"
                        font.family: "Consolas"; font.pixelSize: 12
                    }
                }
            }
        }


        Rectangle {
            anchors.bottom: parent.bottom
            anchors.left:   parent.left
            anchors.right:  parent.right
            height: 150
            gradient: Gradient {
                orientation: Gradient.Vertical
                GradientStop { position: 0.0; color: "#00000000" }
                GradientStop { position: 1.0; color: "#dd000000" }
            }

            ColumnLayout {
                anchors.left:    parent.left
                anchors.right:   parent.right
                anchors.bottom:  parent.bottom
                anchors.margins: 20
                spacing: 10


                Item {
                    Layout.fillWidth: true
                    height: 20

                    Rectangle {
                        id: seekTrack
                        anchors.verticalCenter: parent.verticalCenter
                        anchors.left:  parent.left
                        anchors.right: parent.right
                        height: seekMa.containsMouse ? 5 : 3
                        radius: 3; color: "#33ffffff"
                        Behavior on height { NumberAnimation { duration: 100 } }

                        Rectangle {
                            width: mpv.duration > 0
                                   ? parent.width * (mpv.position / mpv.duration) : 0
                            height: parent.height; radius: parent.radius; color: "#4a7fc1"
                        }

                        Rectangle {
                            x: mpv.duration > 0
                               ? (seekTrack.width * (mpv.position / mpv.duration)) - width / 2
                               : -width / 2
                            anchors.verticalCenter: parent.verticalCenter
                            width: seekMa.containsMouse ? 14 : 0
                            height: width; radius: width / 2; color: "white"
                            Behavior on width { NumberAnimation { duration: 100 } }
                        }
                    }

                    MouseArea {
                        id: seekMa
                        anchors.fill: parent; hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        preventStealing: true
                        onPressed:         function(m) { mpv.seek((m.x / width) * mpv.duration) }
                        onPositionChanged: function(m) {
                            if (pressed)
                                mpv.seek(Math.max(0, Math.min(m.x / width, 1)) * mpv.duration)
                        }
                    }
                }

                // ── Controls row ───────────────────────────────────────────
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 14

                    // Play / Pause
                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: playMa.containsMouse ? "#33ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: (playerRoot.stableIsPlaying || playerRoot.m_switchCount > 0)
                                  ? "\u23F8" : "\u25B6"
                            color: "white"
                            font.pixelSize: (playerRoot.stableIsPlaying ||
                                             playerRoot.m_switchCount > 0) ? 18 : 16
                        }
                        MouseArea {
                            id: playMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpv.togglePause()
                        }
                    }

                    // Skip back
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: skipBMa.containsMouse ? "#33ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u21BA"; color: "white"; font.pixelSize: 16
                        }
                        MouseArea {
                            id: skipBMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpv.seek(Math.max(0, mpv.position - 5000))
                        }
                    }

                    // Skip forward
                    Rectangle {
                        width: 34; height: 34; radius: 17
                        color: skipFMa.containsMouse ? "#33ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "\u21BB"; color: "white"; font.pixelSize: 16
                        }
                        MouseArea {
                            id: skipFMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: mpv.seek(Math.min(mpv.duration, mpv.position + 5000))
                        }
                    }

                    // Time display
                    Text {
                        text: formatMs(mpv.position) + "  /  " + formatMs(mpv.duration)
                        color: "#ccffffff"
                        font.family: "Consolas"; font.pixelSize: 13

                        function formatMs(ms) {
                            var s   = Math.floor(ms / 1000)
                            var h   = Math.floor(s / 3600)
                            var m   = Math.floor((s % 3600) / 60)
                            var sec = s % 60
                            if (h > 0)
                                return h + ":" +
                                       String(m).padStart(2, "0") + ":" +
                                       String(sec).padStart(2, "0")
                            return String(m).padStart(2, "0") + ":" +
                                   String(sec).padStart(2, "0")
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // ── Next Episode / Next Season button ──────────────────
                    Rectangle {
                        visible: nextEp && nextEp.exists
                        height: 37
                        width: nextEpLabel.implicitWidth + 28
                        radius: 20

                        color: (nextEp && nextEp.isNextSeason)
                               ? (nextEpMa.containsMouse ? "#3da8c8" : "#2e8aa8")
                               : (nextEpMa.containsMouse ? "#22ffffff" : "transparent")

                        border.color: (nextEp && nextEp.isNextSeason) ? "transparent" : "#4fc3f7"
                        border.width: (nextEp && nextEp.isNextSeason) ? 0 : 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.centerIn: parent
                            spacing: 6
                            Text {
                                anchors.verticalCenter: parent.verticalCenter
                                text: "\u23ED"; color: "white"; font.pixelSize: 13
                            }
                            Text {
                                id: nextEpLabel
                                anchors.verticalCenter: parent.verticalCenter
                                text: (nextEp && nextEp.isNextSeason)
                                      ? "Next Season" : "Next Episode"
                                color: "white"
                                font.family: "Consolas"
                                font.bold: nextEp && nextEp.isNextSeason
                                font.pixelSize: 11
                            }
                        }

                        MouseArea {
                            id: nextEpMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerRoot.playNextEpisode()
                        }
                    }

                    // Volume
                    Row {
                        spacing: 8
                        Layout.alignment: Qt.AlignVCenter

                        Text {
                            text: mpv.volume === 0 ? "\uD83D\uDD07"
                                : mpv.volume < 50  ? "\uD83D\uDD08"
                                : "\uD83D\uDD0A"
                            color: "white"; font.pixelSize: 16
                        }

                        Item {
                            width: 80; height: 18
                            Rectangle {
                                anchors.verticalCenter: parent.verticalCenter
                                width: parent.width; height: 3; radius: 2
                                color: "#44ffffff"
                                Rectangle {
                                    width: parent.width * (mpv.volume / 100)
                                    height: parent.height; radius: 2; color: "white"
                                }
                            }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                onPressed: function(m) {
                                    mpv.setVolume((m.x / width) * 100)
                                }
                                onPositionChanged: function(m) {
                                    if (pressed)
                                        mpv.setVolume(
                                            Math.max(0, Math.min((m.x / width) * 100, 100)))
                                }
                            }
                        }
                    }

                    // ── subtitles button ──────────────────────────────────────────
                    Rectangle {
                        id: ccButton
                        visible: mpv.subtitleTracks.length > 1
                        width: 44; height: 30; radius: 6
                        color: subMa.containsMouse ? "#33ffffff" : "#22ffffff"
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "CC"; color: "white"
                            font.family: "Consolas"; font.bold: true; font.pixelSize: 13
                        }
                        MouseArea {
                            id: subMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: subMenu.visible = !subMenu.visible
                        }
                    }

                    // Fullscreen button
                    Rectangle {
                        width: 34; height: 34; radius: 6
                        color: fsMa.containsMouse ? "#33ffffff" : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: appWindow.visibility === Window.FullScreen
                                  ? "\u2196" : "\u26F6"
                            color: "white"; font.pixelSize: 15
                        }
                        MouseArea {
                            id: fsMa
                            anchors.fill: parent; hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: playerRoot.toggleFullscreen()
                        }
                    }
                }
            }
        }
    }
}
