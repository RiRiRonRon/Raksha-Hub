import QtQuick
import QtQuick.Layouts
import Raksha_Hub

Item {
    id: root
    property int episodeRefresh: 0

    function onEpisodesUpdated(updatedId) {
        if (updatedId === root.entryId) {
            allEpisodes = LibraryManager.episodesForShow(root.entryId)
            episodeRefresh++
        }
    }

    property int    entryId:    -1
    property string showTitle:  ""
    property real   showRating: 0.0
    property string posterUrl:  ""
    property string showKind:   "Show"

    signal backRequested()
    signal playRequested(string filePath, real startMs, int entryId,
                         int season, int episode, string episodeTitle)

    property var allEpisodes: []
    property int activeSeason: 1

    property var seasonNumbers: {
        var seen = {}
        var arr  = []
        for (var i = 0; i < allEpisodes.length; i++) {
            var s = allEpisodes[i].season
            if (!seen[s]) { seen[s] = true; arr.push(s) }
        }
        arr.sort(function(a, b) { return a - b })
        return arr
    }

    property var continueEpisode: {

        var lastKey = LibraryManager.getSetting("last_ep_" + root.entryId, "")
        if (lastKey.length > 0) {
            var parts = lastKey.split(",")
            var lastS = parseInt(parts[0])
            var lastE = parseInt(parts[1])
            for (var i = 0; i < allEpisodes.length; i++) {
                if (allEpisodes[i].season === lastS &&
                    allEpisodes[i].episode === lastE)
                    return allEpisodes[i]
            }
        }

        for (var j = 0; j < allEpisodes.length; j++) {
            var ep  = allEpisodes[j]
            var pct = ep.durationMs > 0 ? ep.positionMs / ep.durationMs : 0
            if (pct > 0 && pct < 0.97) return ep
        }
        return allEpisodes.length > 0 ? allEpisodes[0] : null
    }
    property var visibleEpisodes: {
        var arr = []
        for (var i = 0; i < allEpisodes.length; i++) {
            if (allEpisodes[i].season === activeSeason)
                arr.push(allEpisodes[i])
        }
        return arr
    }

    onEntryIdChanged: {
        if (entryId >= 0) {
            allEpisodes = LibraryManager.episodesForShow(entryId)
            episodeRefresh++

            if (continueEpisode)
                activeSeason = continueEpisode.season
            else if (seasonNumbers.length > 0)
                activeSeason = seasonNumbers[0]
            LibraryManager.rescanShow(entryId)
        }
    }

    Connections {
        target: LibraryManager
        function onEpisodesUpdated(updatedId) {
            if (updatedId === root.entryId)
                allEpisodes = LibraryManager.episodesForShow(root.entryId)
        }
    }

    Rectangle { anchors.fill: parent; color: "#111111" }

    // ── Scrollable content ────────────────────────────────────────────────
    Flickable {
        id: flickable
        anchors.fill: parent
        contentHeight: contentCol.implicitHeight + 60
        clip: true
        flickDeceleration: 100
        maximumFlickVelocity: 60000
        boundsBehavior: Flickable.StopAtBounds

        ColumnLayout {
            id: contentCol
            width: parent.width
            spacing: 0

            // ── Back button ───────────────────────────────────────────────
            Item {
                Layout.fillWidth: true
                height: 62

                Row {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.left: parent.left
                    anchors.leftMargin: 32
                    spacing: 10

                    Rectangle {
                        width: 38; height: 38; radius: 19
                        color: backMa.containsMouse ? "#2a2a2a" : "#1e1e1e"
                        border.color: "#2e2e2e"; border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Text {
                            anchors.centerIn: parent
                            text: "\u2190"; color: "#aaa"; font.pixelSize: 18
                        }
                        MouseArea {
                            id: backMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.backRequested()
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: "My Library"; color: "#555"
                        font.family: "Consolas"; font.pixelSize: 15
                    }
                }
            }

            // ──poster + info ───────────────────────────────────────
            Item {
                Layout.fillWidth: true
                implicitHeight: heroRow.implicitHeight + 44
                Layout.leftMargin: 32
                Layout.rightMargin: 32

                Row {
                    id: heroRow
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 8
                    spacing: 30

                    // Poster
                    Rectangle {
                        width: 175; height: 260
                        radius: 10; color: "#1e1e1e"
                        border.color: "#2a2a2a"; border.width: 1
                        clip: true

                        Text {
                            visible: root.posterUrl.length === 0
                            anchors.centerIn: parent
                            text: root.showTitle.length > 0 ? root.showTitle[0] : "?"
                            color: "#444"; font.pixelSize: 66
                        }

                        Image {
                            anchors.fill: parent
                            visible: root.posterUrl.length > 0
                            source: root.posterUrl
                            fillMode: Image.PreserveAspectCrop
                            asynchronous: true
                        }
                    }

                    // Info
                    ColumnLayout {
                        width: parent.width - 205
                        spacing: 0

                        Text {
                            text: root.showTitle; color: "#f0f0f0"
                            font.family: "Consolas"; font.bold: true
                            font.pixelSize: 34; elide: Text.ElideRight
                            Layout.fillWidth: true; Layout.topMargin: 6
                        }


                        Row {
                            spacing: 8
                            Layout.topMargin: 16

                            Repeater {
                                model: {
                                    var pills = []
                                    if (root.seasonNumbers.length > 0)
                                        pills.push(root.seasonNumbers.length + " season" +
                                                   (root.seasonNumbers.length > 1 ? "s" : ""))
                                    if (root.allEpisodes.length > 0)
                                        pills.push(root.allEpisodes.length + " episodes")
                                    return pills
                                }
                                delegate: Rectangle {
                                    height: 28; radius: 14
                                    color: "#1a1a1a"
                                    border.color: "#2e2e2e"; border.width: 1
                                    width: pillText.implicitWidth + 24
                                    Text {
                                        id: pillText
                                        anchors.centerIn: parent
                                        text: modelData; color: "#888"
                                        font.family: "Consolas"; font.pixelSize: 13
                                    }
                                }
                            }

                            Rectangle {
                                visible: root.showRating > 0
                                height: 28; radius: 14
                                color: "#1a1a1a"
                                border.color: "#2e2e2e"; border.width: 1
                                width: ratingRow.implicitWidth + 24
                                Row {
                                    id: ratingRow
                                    anchors.centerIn: parent
                                    spacing: 5
                                    Text {
                                        text: "\u2605"; color: "#e8c05a"
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: root.showRating.toFixed(1)
                                        color: "#e8c05a"; font.family: "Consolas"
                                        font.bold: true; font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                }
                            }
                        }

                        // ── Continue / Start Watching button ──────────────
                        Rectangle {
                            Layout.topMargin: 24
                            width: 225
                            height: root.continueEpisode &&
                                    root.continueEpisode.positionMs > 0 ? 58 : 48
                            radius: 9; clip: true

                            Behavior on height { NumberAnimation { duration: 150 } }

                            // Dark
                            Rectangle {
                                anchors.fill: parent; radius: parent.radius
                                color: continueMa.containsMouse ? "#1e2a3a" : "#161e2a"
                                Behavior on color { ColorAnimation { duration: 120 } }
                            }

                            // Blue progress fill
                            Rectangle {
                                anchors.left: parent.left
                                anchors.top: parent.top
                                anchors.bottom: parent.bottom
                                radius: parent.radius
                                width: {
                                    if (!root.continueEpisode ||
                                        root.continueEpisode.positionMs <= 0)
                                        return parent.width * 0.08
                                    var pct = root.continueEpisode.durationMs > 0
                                              ? root.continueEpisode.positionMs /
                                                root.continueEpisode.durationMs
                                              : 0
                                    return parent.width * Math.max(0.08, Math.min(pct, 0.96))
                                }
                                color: "#4a7fc1"
                                Behavior on width {
                                    NumberAnimation { duration: 300; easing.type: Easing.OutQuad }
                                }
                            }

                            Row {
                                anchors.centerIn: parent
                                spacing: 10

                                Text {
                                    anchors.verticalCenter: parent.verticalCenter
                                    text: "\u25B6"; color: "white"; font.pixelSize: 14
                                }

                                Column {
                                    anchors.verticalCenter: parent.verticalCenter
                                    spacing: 2

                                    Text {
                                        text: {
                                            if (!root.continueEpisode) return "Play"
                                            if (root.continueEpisode.season === 1 &&
                                                root.continueEpisode.episode === 1 &&
                                                root.continueEpisode.positionMs <= 0)
                                                return "Start Watching"
                                            if (root.continueEpisode.positionMs <= 0)
                                                return "Start Watching"
                                            return "Continue Watching"
                                        }
                                        color: "white"; font.family: "Consolas"
                                        font.bold: true; font.pixelSize: 15
                                    }

                                    Text {
                                        visible: root.continueEpisode !== null &&
                                                 root.continueEpisode.positionMs > 0
                                        text: root.continueEpisode
                                              ? "S" + root.continueEpisode.season +
                                                " · E" + root.continueEpisode.episode
                                              : ""
                                        color: "#a0c4e8"; font.family: "Consolas"
                                        font.pixelSize: 12
                                    }
                                }
                            }

                            MouseArea {
                                id: continueMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (!root.continueEpisode) return
                                    var ep = root.continueEpisode
                                    root.playRequested(ep.filePath, ep.positionMs,
                                                       root.entryId, ep.season,
                                                       ep.episode, ep.title || "")
                                }
                            }
                        }
                    }
                }
            }

            // ── Divider between show infos and show episodes (une ligne) ─────
            Rectangle {
                Layout.fillWidth: true
                Layout.leftMargin: 32; Layout.rightMargin: 32
                Layout.topMargin: 18; Layout.bottomMargin: 26
                height: 1; color: "#1e1e1e"
            }

            // ── Season tabs
            Item {
                Layout.fillWidth: true
                Layout.leftMargin: 32
                implicitHeight: seasonRow.implicitHeight

                Row {
                    id: seasonRow
                    spacing: 8

                    Repeater {
                        model: root.seasonNumbers
                        delegate: Rectangle {
                            width: tabLabel.implicitWidth + 36
                            height: 38; radius: 19
                            color: root.activeSeason === modelData
                                   ? "#e8e8e8"
                                   : (tabMa.containsMouse ? "#1e1e1e" : "#161616")
                            border.color: root.activeSeason === modelData
                                          ? "transparent" : "#2a2a2a"
                            border.width: 1
                            Behavior on color { ColorAnimation { duration: 120 } }

                            Text {
                                id: tabLabel
                                anchors.centerIn: parent
                                text: "Season " + modelData
                                color: root.activeSeason === modelData ? "#111" : "#666"
                                font.family: "Consolas"
                                font.bold: root.activeSeason === modelData
                                font.pixelSize: 14
                            }
                            MouseArea {
                                id: tabMa
                                anchors.fill: parent
                                hoverEnabled: true
                                cursorShape: Qt.PointingHandCursor
                                onClicked: root.activeSeason = modelData
                            }
                        }
                    }
                }
            }

            // ── Episode cards ─────────────────────────────────────────────
            ColumnLayout {
                Layout.fillWidth: true
                Layout.leftMargin: 32; Layout.rightMargin: 32
                Layout.topMargin: 18
                spacing: 10

                Repeater {
                    model: root.visibleEpisodes

                    delegate: Rectangle {
                        Layout.fillWidth: true
                        height: 122; radius: 10
                        color: epMa.containsMouse ? "#1c1c1c" : "#161616"
                        border.color: {
                            var pct = modelData.durationMs > 0
                                      ? modelData.positionMs / modelData.durationMs : 0
                            return (pct > 0 && pct < 0.97) ? "#3a5a8a" : "#222222"
                        }
                        border.width: 1
                        Behavior on color { ColorAnimation { duration: 120 } }

                        Row {
                            anchors.fill: parent
                            anchors.margins: 13
                            spacing: 14

                            // Thumbnail
                            Rectangle {
                                width: 152; height: 86
                                anchors.verticalCenter: parent.verticalCenter
                                radius: 6; color: "#1e1e1e"
                                border.color: "#2a2a2a"; border.width: 1
                                clip: true

                                Image {
                                    anchors.fill: parent
                                    visible: (modelData.thumbnailPath || "").length > 0
                                    source: (modelData.thumbnailPath || "").length > 0
                                            ? "file:///" + modelData.thumbnailPath
                                                           .replace(/\\/g, "/")
                                            : ""
                                    fillMode: Image.PreserveAspectCrop
                                    asynchronous: true
                                }

                                // Play icon
                                Text {
                                    anchors.centerIn: parent
                                    text: "\u25B6"
                                    color: (modelData.thumbnailPath || "").length > 0
                                           ? "#ffffffaa"
                                           : (epMa.containsMouse ? "#777" : "#2e2e2e")
                                    font.pixelSize: 26
                                    Behavior on color { ColorAnimation { duration: 120 } }
                                }
                            }

                            // Episode info
                            ColumnLayout {
                                width: parent.width - 152 - 14 - 86 - 14
                                anchors.verticalCenter: parent.verticalCenter
                                spacing: 5

                                Row {
                                    spacing: 9
                                    Text {
                                        text: "E" + String(modelData.episode).padStart(2, "0")
                                        color: "#555"; font.family: "Consolas"
                                        font.pixelSize: 13
                                        anchors.verticalCenter: parent.verticalCenter
                                    }
                                    Text {
                                        text: modelData.title || ("Episode " + modelData.episode)
                                        color: "#d8d8d8"; font.family: "Consolas"
                                        font.bold: true; font.pixelSize: 17
                                        elide: Text.ElideRight
                                        width: parent.parent.width - 48
                                    }
                                }

                                Row {
                                    spacing: 6
                                    Text {
                                        text: modelData.duration || ""; color: "#555"
                                        font.family: "Consolas"; font.pixelSize: 14
                                        visible: (modelData.duration || "").length > 0
                                    }
                                    Text {
                                        text: "\u00B7"; color: "#444"; font.pixelSize: 14
                                        visible: (modelData.duration || "").length > 0 &&
                                                 (modelData.rating || "").length > 0 &&
                                                 modelData.rating !== "N/A"
                                    }
                                    Text {
                                        text: "\u2605 " + (modelData.rating || "")
                                        color: "#e8c05a"; font.family: "Consolas"
                                        font.pixelSize: 14
                                        visible: (modelData.rating || "").length > 0 &&
                                                 modelData.rating !== "N/A"
                                    }
                                }

                                // Progress bar
                                Rectangle {
                                    width: parent.width
                                    height: 2; radius: 1; color: "#222"
                                    Layout.topMargin: 2

                                    Rectangle {
                                        width: modelData.durationMs > 0
                                               ? parent.width * Math.min(1.0,
                                                 modelData.positionMs / modelData.durationMs)
                                               : 0
                                        height: 2; radius: 1; color: "#4a7fc1"
                                    }
                                }
                            }

                            // Time
                            Text {
                                width: 86
                                anchors.verticalCenter: parent.verticalCenter
                                horizontalAlignment: Text.AlignRight
                                text: {
                                    if (modelData.durationMs <= 0)
                                        return modelData.duration || ""
                                    var pct = modelData.positionMs / modelData.durationMs
                                    if (pct <= 0) return modelData.duration || ""
                                    var leftMs  = modelData.durationMs - modelData.positionMs
                                    var leftMin = Math.round(leftMs / 60000)
                                    var doneMin = Math.round(modelData.positionMs / 60000)
                                    if (leftMin <= 3) return modelData.duration || ""
                                    return pct > 0.5
                                           ? leftMin + " min left"
                                           : doneMin + " min in"
                                }
                                color: "#555"; font.family: "Consolas"; font.pixelSize: 14
                            }
                        }

                        MouseArea {
                            id: epMa
                            anchors.fill: parent
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                root.playRequested(
                                    modelData.filePath,
                                    modelData.positionMs,
                                    root.entryId,
                                    modelData.season,
                                    modelData.episode,
                                    modelData.title || "")
                            }
                        }
                    }
                }


                Item {
                    Layout.fillWidth: true
                    height: 80
                    visible: root.visibleEpisodes.length === 0
                    Text {
                        anchors.centerIn: parent
                        text: "No episodes found for this season"
                        color: "#444"; font.family: "Consolas"
                        font.italic: true; font.pixelSize: 15
                    }
                }
            }
        }
    }

    // ── Scrollbar ─────────────────────────────────────────────────────────
    Item {
        id: scrollBar
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        anchors.rightMargin: 4
        width: 14
        visible: flickable.contentHeight > flickable.height

        readonly property real trackTop:    12
        readonly property real trackH:      height - 24
        readonly property real thumbH:      Math.max(32,
            (flickable.height / flickable.contentHeight) * trackH)
        readonly property real maxContentY: flickable.contentHeight - flickable.height


        Rectangle {
            anchors.centerIn: parent
            width: 3; height: scrollBar.trackH; radius: 2; color: "#1e1e1e"

            MouseArea {
                anchors.fill: parent
                onPressed: function(mouse) {
                    var ratio = (mouse.y - scrollBar.thumbH / 2) /
                                (scrollBar.trackH - scrollBar.thumbH)
                    flickable.contentY = Math.max(0,
                        Math.min(ratio * scrollBar.maxContentY, scrollBar.maxContentY))
                }
            }
        }


        Rectangle {
            id: thumb
            anchors.horizontalCenter: parent.horizontalCenter
            width:  trackMa.containsMouse || trackMa.pressed ||
                    thumbMa.containsMouse  || thumbMa.pressed ? 6 : 3
            height: scrollBar.thumbH
            radius: width / 2
            color:  thumbMa.pressed       ? "#cccccc"
                  : thumbMa.containsMouse ? "#888888" : "#444444"

            Behavior on width { NumberAnimation { duration: 120 } }
            Behavior on color { ColorAnimation  { duration: 120 } }

            y: scrollBar.trackTop +
               (flickable.contentY / Math.max(1, scrollBar.maxContentY)) *
               (scrollBar.trackH - scrollBar.thumbH)

            MouseArea {
                id: thumbMa
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                preventStealing: true

                property real grabOffsetY: 0

                onPressed: function(m) { grabOffsetY = thumb.y + m.y }
                onPositionChanged: function(m) {
                    if (!pressed) return
                    var cur   = thumb.y + m.y
                    var delta = cur - grabOffsetY
                    grabOffsetY = cur
                    var ratio = delta / (scrollBar.trackH - scrollBar.thumbH)
                    var newY  = flickable.contentY + ratio * scrollBar.maxContentY
                    flickable.contentY = Math.max(0, Math.min(newY, scrollBar.maxContentY))
                }
            }
        }

        MouseArea {
            id: trackMa
            anchors.fill: parent
            hoverEnabled: true
            onPressed: function(mouse) { mouse.accepted = false }
        }
    }
}
