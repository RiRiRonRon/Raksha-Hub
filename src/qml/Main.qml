import QtQuick
import QtQuick.Layouts
import QtQuick.Controls.Basic
import QtQuick.Dialogs
import QtQuick.Window
import Raksha_Hub

ApplicationWindow {
    id: appWindow
    width: 1100
    height: 720
    visible: true
    title: "Raksha Hub"
    color: "#121212"

    property string currentSection:    "Library"
    property int    openedShowId:      -1
    property string openedShowTitle:   ""
    property real   openedShowRating:  0.0
    property string openedPosterUrl:   ""
    property bool   showPageOpen:      false

    property bool musicEverOpened: false
    onCurrentSectionChanged: {
        if (currentSection === "Music") musicEverOpened = true
    }


    function requestAddMovie() {
        movieFileDialog.open()
    }

    function requestAddShow() {
        showFolderDialog.open()
    }

    // Player state
    property bool   playerOpen:        false
    property string playerFilePath:    ""
    property real   playerStartMs:     0
    property int    playerEntryId:     -1
    property int    playerSeason:      0
    property int    playerEpisode:     0
    property string playerShowTitle:   ""
    property string playerEpisodeTitle: ""

    function openPlayer(filePath, startMs, entryId, season, episode,
                        showTitleStr, epTitleStr) {
        if (season > 0 && entryId >= 0)
            LibraryManager.saveSetting("last_ep_" + entryId,
                                       season + "," + episode)
        playerFilePath            = filePath
        playerStartMs             = startMs
        playerEntryId             = entryId
        playerSeason              = season
        playerEpisode             = episode
        playerWindow.showTitle    = showTitleStr || ""
        playerWindow.episodeTitle = epTitleStr   || ""
        playerOpen                = true
    }

    function saveProgress(entryId, season, episode, positionMs, durationMs) {
        if (entryId < 0) return
        if (season === 0 && episode === 0)
            LibraryManager.updateMovieProgress(entryId, positionMs, durationMs)
        else
            LibraryManager.updateEpisodeProgress(entryId, season, episode,
                                                  positionMs, durationMs)
    }

    //─────────────────────── titre section ───────────────────────────────────────
    header: ToolBar {
        height: 64
        visible: !playerOpen
        background: Rectangle {
            color: "#181818"
            Rectangle {
                anchors.bottom: parent.bottom
                width: parent.width; height: 1; color: "#2a2a2a"
            }
        }
        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 20; anchors.rightMargin: 20
            spacing: 14

            MenuButton {
                Layout.alignment: Qt.AlignVCenter
                onClicked: {
                    if (showPageOpen) showPageOpen = false
                    else drawer.open()
                }
            }

            Rectangle { width: 4; height: 22; radius: 2; color: "#4fc3f7" }

            Text {
                text: showPageOpen
                      ? openedShowTitle
                      : (currentSection === "Library" ? "My Library" : currentSection)
                color: "white"
                font.family: "Consolas"; font.bold: true; font.italic: true
                font.pixelSize: 22; font.letterSpacing: 0.3
                Layout.fillWidth: true
            }

            AddButton {
                visible: !showPageOpen && currentSection === "Library"
                Layout.alignment: Qt.AlignVCenter
                onClicked: addMenu.open = !addMenu.open
            }
        }
    }

    //─────────────────────── EL CONTENUH ──────────────────────────────────────
    Item {
        anchors.fill: parent
        visible: !playerOpen

        // ── Library grid ──────────────────────────────────────────────────
        GridView {
            id: libraryGrid
            anchors.fill:    parent
            anchors.margins: showPageOpen ? 0 : 24
            Behavior on anchors.margins {
                NumberAnimation { duration: 150; easing.type: Easing.OutQuad }
            }
            visible:    !showPageOpen && currentSection === "Library"
            cellHeight: 310; cellWidth: 205
            clip:       true
            model:      LibraryManager

            property int draggedIndex: -1
            property int hoverIndex:   -1

            populate: Transition {
                NumberAnimation { properties: "x,y"; duration: 600; easing.type: Easing.OutCubic }
            }
            add: Transition {
                NumberAnimation { properties: "x,y"; duration: 600; easing.type: Easing.OutCubic }
            }

            delegate: ShowCard {
                showTitle:     model.title
                showRating:    model.rating
                showKind:      model.kind
                showProgress:  model.progress
                showPosterUrl: model.posterUrl
                showDuration:  model.duration
                entryId:       model.entryId

                onDeleteRequested: LibraryManager.removeAt(index)
                onMoveRequested: function(from, to) { LibraryManager.moveEntry(from, to) }

                onShowClicked: {
                    if (model.kind === "Show") {
                        openedShowId     = model.entryId
                        openedShowTitle  = model.title
                        openedShowRating = model.rating
                        openedPosterUrl  = model.posterUrl
                        showPageOpen     = true
                    } else {
                        appWindow.openPlayer(
                            model.folderPath, model.positionMs,
                            model.entryId, 0, 0, model.title, "")
                    }
                }
            }
        }

        // ── Show page ──────────────────────────────────────────────────
        Loader {
            anchors.fill: parent
            active: showPageOpen && currentSection === "Library"
            sourceComponent: Component {
                ShowPage {
                    entryId:    openedShowId
                    showTitle:  openedShowTitle
                    showRating: openedShowRating
                    posterUrl:  openedPosterUrl
                    onBackRequested: showPageOpen = false
                    onPlayRequested: function(filePath, startMs, entryId,
                                              season, episode, epTitle) {
                        appWindow.openPlayer(filePath, startMs, entryId,
                                             season, episode, openedShowTitle, epTitle)
                    }
                }
            }
        }

        // ── Books ─────────────────────────────────────────────────────────
        Item {
            anchors.fill: parent
            visible: currentSection === "Books"

            Text {
                anchors.centerIn: parent
                text: "Cumming Soon Nerd ☝️🤓📚"
                color: "#e0e0e0"; font.family: "Consolas"
                font.bold: true; font.italic: true; font.pixelSize: 28
            }
        }

        // ── Music ───────────────────────────────────────

        Loader {
            anchors.fill: parent
            active: currentSection === "Music"
            sourceComponent: Component {
                Item {
                    id: musicSection
                    anchors.fill: parent

                    // Resolve mood.mp4 path next to the executable
                    readonly property string moodPath: {
                        var a   = Qt.application.arguments[0]
                        var idx = Math.max(a.lastIndexOf("/"), a.lastIndexOf("\\"))
                        return a.substring(0, idx + 1).replace(/\\/g, "/") + "mood.mp4"
                    }

                    // ── button L puase/unpuase  L for Lasmer ─────────────────

                    focus: true
                    Keys.priority: Keys.BeforeItem
                    Keys.onPressed: function(event) {
                        if (event.key === 76) {
                            musicMpv.togglePause()
                            event.accepted = true
                        }
                    }

                    Component.onCompleted: {
                        forceActiveFocus()

                        startDelay.restart()
                    }
                    Component.onDestruction: {
                        musicMpv.stop()
                    }

                    Timer {
                        id: startDelay
                        interval: 100
                        onTriggered: {
                            musicMpv.setLooping(true)
                            musicMpv.play(musicSection.moodPath, 0)
                            musicMpv.setVolume(600)
                        }
                    }

                    // ── Dark background ────────────────────────────────
                    Rectangle { anchors.fill: parent; color: "#0d0d0d" }

                    Column {
                        anchors.centerIn: parent
                        spacing: 22

                        // ── Description ─────────────────────────────────────
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 6

                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "🎵  The one and only music video ever needed  🎵"
                                color: "#f0f0f0"; font.family: "Consolas"
                                font.bold: true; font.pixelSize: 20
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "The best song of all time"
                                color: "#aaaaaa"; font.family: "Consolas"
                                font.italic: true; font.pixelSize: 15
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: "⚠️ Warning BANGER incoming ⚠️"
                                color: "#666"; font.family: "Consolas"
                                font.italic: true; font.pixelSize: 13
                            }
                        }

                        // ── Video player ───────────────────────────────────────────
                        Rectangle {
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: 520; height: 292
                            radius: 12; color: "#000"
                            border.color: "#2a2a2a"; border.width: 1
                            clip: true

                            MpvPlayer {
                                id: musicMpv
                                width:  parent.width
                                height: parent.height

                                onRenderReady: {
                                    musicMpv.setLooping(true)
                                    musicMpv.play(musicSection.moodPath, 0)
                                    musicMpv.setVolume(600)
                                }
                            }

                            // 7ata chay meymchi fil music section no pause on click ,etc.....
                            MouseArea {
                                anchors.fill: parent
                                onClicked: {}
                                onDoubleClicked: {}
                            }
                        }

                        // ── Fake Controls ─────
                        Column {
                            anchors.horizontalCenter: parent.horizontalCenter
                            spacing: 14


                            Item {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: 520; height: 18

                                Rectangle {
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: parent.width; height: 3; radius: 2
                                    color: "#2a2a2a"

                                    Rectangle {
                                        width: musicMpv.duration > 0
                                               ? parent.width * (musicMpv.position / musicMpv.duration)
                                               : 0
                                        height: parent.height; radius: 2; color: "#4fc3f7"
                                    }


                                    Rectangle {
                                        x: musicMpv.duration > 0
                                           ? parent.width * (musicMpv.position / musicMpv.duration) - width / 2
                                           : -width
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: fakeSeekMa.containsMouse ? 14 : 0
                                        height: width; radius: width / 2; color: "white"
                                        Behavior on width { NumberAnimation { duration: 100 } }
                                    }
                                }

                                MouseArea {
                                    id: fakeSeekMa
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {}
                                }
                            }


                            Row {
                                anchors.horizontalCenter: parent.horizontalCenter
                                spacing: 12


                                Rectangle {
                                    width: 38; height: 38; radius: 19
                                    color: fakePauseMa.containsMouse ? "#33ffffff" : "transparent"
                                    border.color: "#333"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u23F8"
                                        color: "white"; font.pixelSize: 16
                                    }
                                    MouseArea {
                                        id: fakePauseMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {}
                                    }
                                }

                                // Fake skip back
                                Rectangle {
                                    width: 34; height: 34; radius: 17
                                    color: fakeSkipBMa.containsMouse ? "#33ffffff" : "transparent"
                                    border.color: "#2a2a2a"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u21BA"; color: "white"; font.pixelSize: 15
                                    }
                                    MouseArea {
                                        id: fakeSkipBMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {}
                                    }
                                }

                                // Fake skip forward
                                Rectangle {
                                    width: 34; height: 34; radius: 17
                                    color: fakeSkipFMa.containsMouse ? "#33ffffff" : "transparent"
                                    border.color: "#2a2a2a"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                    Text {
                                        anchors.centerIn: parent
                                        text: "\u21BB"; color: "white"; font.pixelSize: 15
                                    }
                                    MouseArea {
                                        id: fakeSkipFMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {}
                                    }
                                }


                                Row {
                                    spacing: 8
                                    anchors.verticalCenter: parent.verticalCenter

                                    Text {
                                        text: "🔊"; color: "white"; font.pixelSize: 15
                                        anchors.verticalCenter: parent.verticalCenter
                                    }

                                    Item {
                                        width: 80; height: 18
                                        anchors.verticalCenter: parent.verticalCenter

                                        Rectangle {
                                            anchors.verticalCenter: parent.verticalCenter
                                            width: parent.width; height: 3; radius: 2
                                            color: "#2a2a2a"

                                            Rectangle {
                                                width: parent.width * 0.8
                                                height: parent.height; radius: 2; color: "white"
                                            }
                                        }
                                        MouseArea {
                                            anchors.fill: parent
                                            cursorShape: Qt.PointingHandCursor
                                            onClicked: {}
                                        }
                                    }
                                }


                                Item { width: 24; height: 1 }


                                Rectangle {
                                    height: 34
                                    width: addPLLabel.implicitWidth + 24
                                    radius: 17
                                    color: addPLMa.containsMouse ? "#1e2a3a" : "#161e2a"
                                    border.color: "#4fc3f7"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        id: addPLLabel
                                        anchors.centerIn: parent
                                        text: "+ Add Playlist"
                                        color: "#4fc3f7"; font.family: "Consolas"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: addPLMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {}   // convincing but fake
                                    }
                                }


                                Rectangle {
                                    height: 34
                                    width: addClipsLabel.implicitWidth + 24
                                    radius: 17
                                    color: addClipsMa.containsMouse ? "#1e2a3a" : "#161e2a"
                                    border.color: "#4fc3f7"; border.width: 1
                                    Behavior on color { ColorAnimation { duration: 120 } }

                                    Text {
                                        id: addClipsLabel
                                        anchors.centerIn: parent
                                        text: "+ Add Clips"
                                        color: "#4fc3f7"; font.family: "Consolas"
                                        font.pixelSize: 12
                                    }
                                    MouseArea {
                                        id: addClipsMa
                                        anchors.fill: parent; hoverEnabled: true
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {}
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    //─────────────────────── PLAYER OVERLAY ───────────────────────────────
    PlayerWindow {
        id: playerWindow
        anchors.fill: parent
        z: 999
        visible: playerOpen

        filePath:     appWindow.playerFilePath
        startMs:      appWindow.playerStartMs
        entryId:      appWindow.playerEntryId
        season:       appWindow.playerSeason
        episode:      appWindow.playerEpisode
        showTitle:    appWindow.playerShowTitle
        episodeTitle: appWindow.playerEpisodeTitle

        onPlaybackStopped: function(entryId, season, episode, positionMs, durationMs) {
            appWindow.saveProgress(entryId, season, episode, positionMs, durationMs)
        }
    }

    //──────────────── SIDE MENU ON THE LEFT───────────────

    Drawer {
        id: drawer
        edge: Qt.LeftEdge; width: 260; height: appWindow.height
        background: Rectangle { color: "#1c1c1c" }

        ColumnLayout {
            anchors.fill: parent
            anchors.topMargin: 32
            spacing: 4

            // ── Title ─────────────────────────────────────────────────
            Text {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 20
                text: "Menu"
                color: "#4fc3f7"
                font.family: "Consolas"
                font.bold: true
                font.italic: true
                font.pixelSize: 22
                font.letterSpacing: 1.2
            }


            Repeater {
                model: ["Library", "Books", "Music"]
                delegate: SideMenuItem {
                    label: modelData
                    active: currentSection === modelData
                    onClicked: {
                        currentSection = modelData
                        showPageOpen   = false
                        drawer.close()
                    }
                }
            }


            Item { Layout.fillHeight: true }

            // ── Dedicace for RiRiRonRon hh ──────────────────────
            Row {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: 20
                spacing: 4

                Text {
                    text: "made with"
                    color: "#444"
                    font.family: "Consolas"
                    font.italic: true
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "🌿"
                    font.pixelSize: 11
                    opacity: 0.35
                    anchors.verticalCenter: parent.verticalCenter
                }

                Text {
                    text: "by RiRiRonRon"
                    color: "#444"
                    font.family: "Consolas"
                    font.italic: true
                    font.pixelSize: 11
                    anchors.verticalCenter: parent.verticalCenter
                }
            }
        }
    }

    //─────────────────────── ADD MENU ─────────────────────────────────────
    MouseArea {
        anchors.fill: parent
        visible: addMenu.open; enabled: addMenu.open
        onClicked: addMenu.open = false
    }

    AddMenu {
        id: addMenu
        anchors.top: parent.top; anchors.right: parent.right
        anchors.topMargin: 8; anchors.rightMargin: 20
        onMovieSelected: { open = false; appWindow.requestAddMovie() }
        onShowSelected:  { open = false; appWindow.requestAddShow() }
    }



    FileDialog {
        id: movieFileDialog
        title: "Select a movie file"
        nameFilters: ["Video files (*.mp4 *.mkv *.avi *.mov)"]
        parentWindow: appWindow
        onAccepted: LibraryManager.addMovie(selectedFile)
    }

    FolderDialog {
        id: showFolderDialog
        title: "Select the show's root folder"
        parentWindow: appWindow
        onAccepted: LibraryManager.addShow(selectedFolder)
    }


    Connections {
        target: LibraryManager
        function onMovieAdded(title)     { toast.show("Added " + title) }
        function onShowAdded(title)      { toast.show("Added " + title) }
        function onItemRemoved(title)    { toast.show(title + " deleted") }
        function onDuplicateMovie(title) { toast.show(title + " already exists") }
        function onDuplicateShow(title)  { toast.show(title + " already exists") }
    }

    Toast {
        id: toast
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: 24
    }
}
