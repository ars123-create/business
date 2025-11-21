import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    width: 1920
    height: 1080
    color: "#02060e"
    flags: Qt.FramelessWindowHint

    property real baseWidth: 1920
    property real baseHeight: 1080
    property real s: width / baseWidth
    function dp(x) { return Math.max(1, x * s); }

    property color neonCyan: "#26f0ff"
    property color neonMagenta: "#ff45c7"
    property color neonAmber: "#ffb347"
    property color hudText: "#e1f6ff"
    property color hudMuted: "#6ea0b7"
    property color cAlarm: neonAmber

    property real gridShift: 0.0
    property real scanPhase: 0.0
    property real glowBlur: 14.0

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#02040b" }
            GradientStop { position: 0.35; color: "#07152c" }
            GradientStop { position: 1; color: "#030714" }
        }
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.28
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0,0,width,height)
            var spacing = 90 * s
            var offset = gridShift * spacing
            ctx.strokeStyle = "rgba(255,255,255,0.04)"
            ctx.lineWidth = 1
            for (var x = -spacing; x < width + spacing; x += spacing) {
                ctx.beginPath()
                ctx.moveTo(x + offset, 0)
                ctx.lineTo(x + offset, height)
                ctx.stroke()
            }
            for (var y = -spacing; y < height + spacing; y += spacing) {
                ctx.beginPath()
                ctx.moveTo(0, y + offset)
                ctx.lineTo(width, y + offset)
                ctx.stroke()
            }
        }
    }

    Item {
        anchors.fill: parent
        Repeater {
            model: 14
            Rectangle {
                width: parent.width
                height: 2 * s
                y: (parent.height / 14) * index + (gridShift * 40)
                color: Qt.rgba(1,1,1,0.01 + (index % 3) * 0.01)
            }
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0,0,0,0) }
            GradientStop { position: 1; color: Qt.rgba(0,0,0,0.25) }
        }
    }

    Rectangle {
        id: leftColumn
        width: Math.max(12 * s, 14)
        anchors.left: parent.left
        anchors.leftMargin: 42 * s
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.72
        radius: 14 * s
        color: "#040b13"
        border.color: neonCyan
        border.width: Math.max(1, 2 * s)
        opacity: 0.4
        Column {
            anchors.centerIn: parent
            spacing: 18 * s
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.7
                    height: Math.max(4, 6 * s)
                    radius: 3 * s
                    color: Qt.tint(neonCyan, Qt.rgba(0,0,0,0.75))
                    opacity: 0.25 + index * 0.1
                }
            }
        }
    }

    Rectangle {
        width: leftColumn.width
        anchors.right: parent.right
        anchors.rightMargin: 42 * s
        anchors.verticalCenter: parent.verticalCenter
        height: leftColumn.height
        radius: leftColumn.radius
        color: leftColumn.color
        border.color: neonMagenta
        border.width: leftColumn.border.width
        opacity: leftColumn.opacity
        Column {
            anchors.centerIn: parent
            spacing: 18 * s
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.7
                    height: Math.max(4, 6 * s)
                    radius: 3 * s
                    color: Qt.tint(neonMagenta, Qt.rgba(0,0,0,0.75))
                    opacity: 0.25 + index * 0.1
                }
            }
        }
    }

    Rectangle {
        id: hudBar
        anchors.top: parent.top
        anchors.topMargin: 30 * s
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width * 0.68, 1320)
        height: Math.max(70, 92 * s)
        radius: 24 * s
        color: "#050d17"
        border.color: neonCyan
        border.width: Math.max(2, 3 * s)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.03, 0.18, 0.26, 0.92) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.05, 0.13, 0.82) }
        }
        Row {
            anchors.fill: parent
            anchors.margins: 24 * s
            spacing: 36 * s
            Column {
                spacing: 4 * s
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2 * s
                Text {
                    text: "РЕЖИМ ОЖИДАНИЯ"
                    color: hudText
                    font.pixelSize: Math.max(18, 26 * s)
                    font.bold: true
                }
            }
            Rectangle { width: 1; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.1) }
            Column {
                spacing: 4 * s
                Text {
                    text: backend && backend.ID ? "ID ПОЛУЧЕН" : "ОЖИДАНИЕ"
                    color: neonAmber
                    font.pixelSize: Math.max(16, 20 * s)
                    font.bold: true
                }
            }
            Rectangle { width: 1; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.1) }
            Column {
                spacing: 6 * s
                Text {
                    text: Qt.formatTime(new Date(), "hh:mm:ss")
                    color: hudText
                    font.pixelSize: Math.max(18, 24 * s)
                    Timer {
                        interval: 1000; running: true; repeat: true
                        onTriggered: parent.text = Qt.formatTime(new Date(), "hh:mm:ss")
                    }
                }
            }
        }
    }

    Rectangle {
        id: holoConsole
        width: Math.min(parent.width * 0.68, parent.height * 0.7)
        height: width * 0.6
        anchors.centerIn: parent
        radius: 28 * s
        color: Qt.rgba(6 / 255, 16 / 255, 30 / 255, 0.92)
        border.color: neonCyan
        border.width: Math.max(2, 2.4 * s)
        layer.enabled: true
        layer.smooth: true

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = "rgba(255,255,255,0.08)"
                ctx.lineWidth = 1
                ctx.setLineDash([18 * s, 10 * s])
                ctx.strokeRect(10 * s, 10 * s, width - 20 * s, height - 20 * s)
            }
        }

        Column {
            anchors.centerIn: parent
            spacing: 14 * s
            anchors.horizontalCenter: parent.horizontalCenter

            Text {
                text: "POINT ID"
                color: neonMagenta
                font.family: "Roboto Mono"
                font.pixelSize: Math.max(14, 26 * s)
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                id: idValue
                text: backend ? backend.ID : "........"
                color: hudText
                font.pixelSize: Math.max(60, 140 * s)
                font.bold: true
                font.family: "Fira Mono"
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width * 0.92
                height: Math.max(10 * s, 16)
                radius: height / 2
                color: Qt.rgba(6 / 255, 16 / 255, 30 / 255, 0.85)
                border.color: Qt.rgba(neonMagenta.r, neonMagenta.g, neonMagenta.b, 0.35)
                anchors.horizontalCenter: parent.horizontalCenter
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.rgba(neonCyan.r, neonCyan.g, neonCyan.b, 0.35) }
                    GradientStop { position: 1; color: Qt.rgba(neonMagenta.r, neonMagenta.g, neonMagenta.b, 0.35) }
                }
                Row {
                    anchors.fill: parent
                    anchors.margins: 6 * s
                    spacing: 4 * s
                    Repeater {
                        id: stripRepeater
                        model: 14
                        Rectangle {
                            height: parent.height
                            width: (parent.width - (stripRepeater.count - 1) * 4 * s) / stripRepeater.count
                            radius: height / 2
                            color: index % 3 === 0 ? neonAmber : Qt.rgba(255/255,255/255,255/255,0.15)
                            opacity: 0.65
                        }
                    }
                }
            }
        }
    }

    Column {
        id: bottomLog
        width: parent.width
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dp(22)
        anchors.horizontalCenter: parent.horizontalCenter
        spacing: dp(8)

        Rectangle {
            id: timeline
            width: parent.width * 0.86; height: dp(2); radius: height/2
            color: Qt.rgba(0.2,0.25,0.28,0.8)
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: 24
                Rectangle {
                    width: dp(2); height: dp(10)
                    color: index % 6 === 0 ? neonCyan : Qt.rgba(0.8,0.9,1,0.18)
                    anchors.bottom: parent.top
                    x: (timeline.width / 24) * index
                }
            }

            Rectangle {
                width: dp(2)
                height: dp(10)
                color: neonCyan
                anchors.bottom: parent.top
                x: timeline.width - width
            }

            Rectangle {
                id: recDot
                width: dp(6); height: dp(6); radius: width/2; color: cAlarm; y: -dp(2)
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: timeline.width - recDot.width; duration: 2600; easing: Easing.InOutSine }
                    NumberAnimation { from: timeline.width - recDot.width; to: 0; duration: 2600; easing: Easing.InOutSine }
                }
            }
        }

        Row {
            width: parent.width * 0.86
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: dp(18)
            function entry(txt, ok) { return txt + (ok ? " :: ОШИБОК НЕ ОБНАРУЖЕНО" : " :: ОШИБКА МОДУЛЯ 2"); }
            Text { text: "[00] " + entry("ЗАПУСК", true); color: hudMuted; font.family: "Roboto Mono"; font.pixelSize: dp(12) }
            Text {
                text: "TOUCH SCREEN ARENA"
                color: hudText
                font.family: "Roboto Mono"
                font.pixelSize: dp(12)
                font.bold: true
            }
        }
    }

    PropertyAnimation {
        target: root
        property: "gridShift"
        from: 0
        to: 1
        duration: 9000
        loops: Animation.Infinite
        running: true
        onRunningChanged: gridCanvas.requestPaint()
    }

    PropertyAnimation {
        target: root
        property: "scanPhase"
        from: 0
        to: 1
        duration: 5200
        loops: Animation.Infinite
        running: true
    }

    Component.onCompleted: {
        gridCanvas.requestPaint()
    }
}
