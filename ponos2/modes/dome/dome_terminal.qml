import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    color: "#020611"
    flags: Qt.FramelessWindowHint

    property real baseWidth: 1920
    property real baseHeight: 1080
    property real s: width / baseWidth
    function dp(value) { return Math.max(1, value * s) }

    property color neonCyan: "#4df0ff"
    property color neonPink: "#ff4db5"
    property color neonAmber: "#ffb347"
    property color hudText: "#e2f7ff"
    property real gridShift: 0
    property real pulsePhase: 0

    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            gridShift = (gridShift + 0.004) % 1
            pulsePhase = (pulsePhase + 0.01) % 1
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#020711" }
            GradientStop { position: 0.4; color: "#050d19" }
            GradientStop { position: 1; color: "#01030a" }
        }
    }

    Canvas {
        id: grid
        anchors.fill: parent
        opacity: 0.35
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0,0,width,height)
            var spacing = 110 * s
            var offset = gridShift * spacing
            ctx.strokeStyle = "rgba(255,255,255,0.05)"
            ctx.lineWidth = 1
            for (var x=-spacing; x<width+spacing; x+=spacing) {
                ctx.beginPath()
                ctx.moveTo(x+offset,0)
                ctx.lineTo(x+offset,height)
                ctx.stroke()
            }
            for (var y=-spacing; y<height+spacing; y+=spacing) {
                ctx.beginPath()
                ctx.moveTo(0,y+offset)
                ctx.lineTo(width,y+offset)
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
                height: dp(2)
                y: (parent.height/14) * index + (gridShift * 60)
                color: Qt.rgba(1,1,1,0.01 + (index % 3) * 0.01)
            }
        }
    }

    Rectangle {
        id: topPanel
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: dp(40)
        width: parent.width * 0.74
        height: dp(120)
        radius: dp(28)
        color: Qt.rgba(4/255, 15/255, 29/255, 0.96)
        border.color: neonCyan
        border.width: dp(2)
        RowLayout {
            anchors.fill: parent
            anchors.margins: dp(24)
            spacing: dp(20)
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: terminalBackend && terminalBackend.teamLabel ? "Команда " + terminalBackend.teamLabel + " разрушила купол" : "Ожидаем команду"
                    color: hudText
                    font.pixelSize: dp(32)
                    font.bold: true
                }
                Text {
                    text: terminalBackend && terminalBackend.domeId ? "Купол " + terminalBackend.domeId : ""
                    color: "#7fbfff"
                    font.pixelSize: dp(22)
                }
            }
            Rectangle { width: dp(2); Layout.fillHeight: true; color: Qt.rgba(1,1,1,0.08) }
            Column {
                spacing: dp(4)
                Text { text: "ТАЙМЕР"; color: neonAmber; font.pixelSize: dp(18); font.letterSpacing: dp(1.5) }
                Text {
                    text: terminalBackend ? (terminalBackend.countdownSeconds < 10 ? "0" + terminalBackend.countdownSeconds : terminalBackend.countdownSeconds) : "--"
                    color: terminalBackend && terminalBackend.selectionEnabled ? neonAmber : "#6f8ea8"
                    font.pixelSize: dp(54)
                    font.family: "Inconsolata"
                }
            }
        }
    }

    Text {
        id: infoText
        anchors.top: topPanel.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: dp(30)
        text: terminalBackend ? terminalBackend.infoText : ""
        color: hudText
        font.pixelSize: dp(28)
    }

    Row {
        id: buttonRow
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: infoText.bottom
        anchors.topMargin: dp(40)
        spacing: dp(50)
        Repeater {
            model: [
                { key: "keep_ammo", title: "СОХРАНИТЬ БОЕЗАПАС", subtitle: "Игроки остаются в обычном режиме", accent: neonCyan },
                { key: "super_shots", title: "5 ВЫСТРЕЛОВ ВОЗМЕЗДИЯ", subtitle: "Команда получает 5 мощных выстрелов", accent: neonPink }
            ]
            delegate: Rectangle {
                width: root.width * 0.33
                height: root.height * 0.45
                radius: dp(28)
                color: Qt.rgba(5/255, 15/255, 28/255, 0.95)
                border.width: dp(3)
                border.color: modelData.accent
                opacity: terminalBackend && terminalBackend.selectionEnabled ? 1 : 0.5
                scale: terminalBackend && terminalBackend.selectedChoice === modelData.key ? 1.02 : 1
                Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutQuad } }

                Column {
                    anchors.fill: parent
                    anchors.margins: dp(26)
                    spacing: dp(18)
                    Text {
                        text: modelData.title
                        wrapMode: Text.WordWrap
                        color: hudText
                        font.pixelSize: dp(38)
                        font.bold: true
                    }
                    Text {
                        text: modelData.subtitle
                        wrapMode: Text.Wrap
                        color: "#7fbfff"
                        font.pixelSize: dp(22)
                    }
                    Rectangle {
                        width: parent.width
                        height: dp(2)
                        color: Qt.rgba(1,1,1,0.08)
                    }
                    Text {
                        text: terminalBackend && terminalBackend.selectedChoice === modelData.key
                              ? (terminalBackend.autoSelected ? "ВЫБОР ПО УМОЛЧАНИЮ" : "ВЫБРАНО")
                              : (terminalBackend && terminalBackend.selectionEnabled ? "НАЖМИТЕ" : "")
                        color: terminalBackend && terminalBackend.selectedChoice === modelData.key ? modelData.accent : hudText
                        font.pixelSize: dp(24)
                        font.bold: true
                    }
                }

                MouseArea {
                    anchors.fill: parent
                    enabled: terminalBackend && terminalBackend.selectionEnabled
                    onClicked: {
                        if (!terminalBackend) return
                        if (modelData.key === "keep_ammo") terminalBackend.chooseKeep()
                        else terminalBackend.chooseRevenge()
                    }
                }
            }
        }
    }

    Rectangle {
        id: statusStrip
        anchors.bottom: parent.bottom
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottomMargin: dp(30)
        width: parent.width * 0.65
        height: dp(80)
        radius: dp(18)
        color: Qt.rgba(5/255, 15/255, 28/255, 0.96)
        border.color: neonCyan
        border.width: dp(2)
        Row {
            anchors.fill: parent
            anchors.margins: dp(20)
            spacing: dp(20)
            Column {
                spacing: dp(4)
                Text { text: "ТЕРМИНАЛ"; color: "#6fa7ff"; font.pixelSize: dp(16); font.letterSpacing: dp(2) }
                Text { text: terminalBackend ? terminalBackend.screenState.toUpperCase() : "--"; color: hudText; font.pixelSize: dp(24); font.bold: true }
            }
            Rectangle { width: dp(2); color: Qt.rgba(1,1,1,0.05); anchors.top: parent.top; anchors.bottom: parent.bottom }
            Column {
                spacing: dp(4)
                Text { text: "КОМАНДА"; color: "#6fa7ff"; font.pixelSize: dp(16); font.letterSpacing: dp(2) }
                Text { text: terminalBackend ? terminalBackend.teamLabel : "--"; color: terminalBackend ? terminalBackend.teamColor : hudText; font.pixelSize: dp(24); font.bold: true }
            }
        }
    }
}
