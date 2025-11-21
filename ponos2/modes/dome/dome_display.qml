import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15

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
    property color neonViolet: "#bd46ff"
    property color neonAmber: "#ffb347"
    property color neonRed: "#ff4f6b"
    property color hudText: "#e2f7ff"
    property real gridShift: 0
    property real pulsePhase: 0

    Timer {
        interval: 60; running: true; repeat: true
        onTriggered: {
            gridShift = (gridShift + 0.004) % 1
            pulsePhase = (pulsePhase + 0.01)
        }
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#020711" }
            GradientStop { position: 0.5; color: "#050d19" }
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
        id: sideBarLeft
        width: dp(18)
        height: parent.height * 0.78
        anchors.left: parent.left
        anchors.leftMargin: dp(36)
        anchors.verticalCenter: parent.verticalCenter
        radius: dp(14)
        color: Qt.rgba(3/255,7/255,17/255,0.95)
        border.color: neonCyan
        border.width: dp(2)
        opacity: 0.35
        Column {
            anchors.centerIn: parent
            spacing: dp(14)
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.56
                    height: dp(6)
                    radius: dp(4)
                    color: Qt.tint(neonCyan, Qt.rgba(0,0,0,0.8))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
    }

    Rectangle {
        width: sideBarLeft.width
        height: sideBarLeft.height
        anchors.right: parent.right
        anchors.rightMargin: sideBarLeft.anchors.leftMargin
        anchors.verticalCenter: parent.verticalCenter
        radius: sideBarLeft.radius
        color: sideBarLeft.color
        border.color: neonViolet
        border.width: sideBarLeft.border.width
        opacity: sideBarLeft.opacity
        Column {
            anchors.centerIn: parent
            spacing: dp(14)
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.56
                    height: dp(6)
                    radius: dp(4)
                    color: Qt.tint(neonViolet, Qt.rgba(0,0,0,0.8))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
    }

    Rectangle {
        id: hpPanel
        width: parent.width * 0.7
        height: dp(110)
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: parent.top
        anchors.topMargin: dp(26)
        radius: dp(18)
        color: Qt.rgba(4/255, 13/255, 26/255, 0.94)
        border.color: neonCyan
        border.width: dp(1.5)
        opacity: 0.95
        Row {
            anchors.fill: parent
            anchors.margins: dp(20)
            spacing: dp(32)

            Column {
                spacing: dp(4)
                Text { text: "КУПОЛ"; color: hudText; font.pixelSize: dp(24); font.bold: true }
            }

            Rectangle { width: dp(2); anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.08) }

            Column {
                spacing: dp(6)
                Text { text: "ЭНЕРГИЯ"; color: "#6fa7ff"; font.pixelSize: dp(14); font.letterSpacing: dp(1) }
                Row {
                    spacing: dp(10)
                    Rectangle {
                        width: dp(180)
                        height: dp(12)
                        radius: height/2
                        color: Qt.rgba(8/255, 20/255, 34/255, 0.8)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: dp(2)
                            radius: parent.radius
                            width: (parent.width - dp(4)) * (domeBackend ? domeBackend.hpPercent : 0)
                            gradient: Gradient {
                                GradientStop { position: 0; color: neonCyan }
                                GradientStop { position: 1; color: domeBackend && domeBackend.viewState === "phase3" ? neonRed : neonViolet }
                            }
                        }
                    }
                    Text {
                        text: domeBackend ? Math.round(domeBackend.hpPercent * 100) + "%" : "--"
                        color: hudText
                        font.pixelSize: dp(18)
                        font.family: "Inconsolata"
                    }
                }
            }

            Rectangle { width: dp(2); anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.08) }

            Column {
                spacing: dp(4)
                Text { text: "КОМАНДА-РАЗРУШИТЕЛЬ"; color: "#6fa7ff"; font.pixelSize: dp(14); font.letterSpacing: dp(1) }
                Text {
                    text: domeBackend && domeBackend.destroyerName ? domeBackend.destroyerName : "--"
                    color: domeBackend && domeBackend.destroyerName ? domeBackend.destroyerColor : hudText
                    font.pixelSize: dp(24)
                    font.bold: true
                    elide: Text.ElideRight
                    width: dp(250)
                }
            }
        }
    }

    Item {
        id: orbLayer
        width: Math.min(parent.width * 0.6, parent.height * 0.65)
        height: width * 0.88
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: hpPanel.bottom
        anchors.topMargin: dp(140)

        property var phaseColors: {
            if (!domeBackend) return ["#1a2f4a", "#071320"]
            var percent = domeBackend.hpPercent
            if (domeBackend.viewState === "destroyed" || percent <= 0.01)
                return ["#4b050f", "#160103"]
            if (percent < 0.3)
                return ["#ff6a7f", "#2a0711"]
            if (percent < 0.6)
                return ["#28b8ff", "#0a2338"]
            return ["#60e5ff", "#06243b"]
        }

        Rectangle {
            id: outerGlow
            anchors.centerIn: parent
            width: parent.width * 1.04
            height: width
            radius: width / 2
            color: Qt.rgba(0,0,0,0)
            border.width: dp(3)
            border.color: domeBackend && domeBackend.viewState === "phase3" ? neonRed : neonCyan
            opacity: 0.25 + 0.08 * Math.sin(pulsePhase * 8)
        }

        Item {
            id: domeHex
            anchors.centerIn: parent
            width: parent.width * 0.88
            height: width
            property color fillColor: Qt.rgba(74/255, 163/255, 255/255, 0.22)
            property color borderColor: Qt.tint(
                                            domeBackend && (domeBackend.viewState === "phase3" || domeBackend.viewState === "destroyed")
                                                ? neonRed
                                                : neonCyan,
                                            Qt.rgba(0,0,0,0.3))
            property real hpPercentValue: 0
            property string viewStateValue: ""
            property real hpVisual: 1
            property var cells: []
            property string cellSeedKey: ""

            Behavior on hpVisual { NumberAnimation { duration: 680; easing.type: Easing.InOutQuad } }

            Timer {
                id: cellEnergyTimer
                interval: 40
                running: true
                repeat: true
                onTriggered: domeHex.stepCellEnergy()
            }

            Canvas {
                id: hexCanvas
                anchors.fill: parent
                opacity: 0.95
                antialiasing: true
                onPaint: {
                    var ctx = getContext("2d")
                    ctx.clearRect(0,0,width,height)
                    var borderWidth = root.dp(4)
                    var cx = width / 2
                    var cy = height / 2
                    var radius = Math.min(width, height) / 2 - borderWidth
                    var sides = 8
                    var startAngle = Math.PI / 8

                    function tracePoly(r) {
                        ctx.beginPath()
                        for (var i = 0; i < sides; i++) {
                            var angle = startAngle + i * Math.PI * 2 / sides
                            var px = cx + r * Math.cos(angle)
                            var py = cy + r * Math.sin(angle)
                            if (i === 0) ctx.moveTo(px, py)
                            else ctx.lineTo(px, py)
                        }
                        ctx.closePath()
                    }

                    ctx.save()
                    tracePoly(radius)
                    ctx.fillStyle = domeHex.fillColor
                    ctx.fill()
                    ctx.restore()

                    ctx.save()
                    tracePoly(radius)
                    ctx.lineWidth = borderWidth
                    ctx.strokeStyle = domeHex.borderColor
                    ctx.stroke()
                    ctx.restore()

                    ctx.save()
                    tracePoly(radius - borderWidth * 0.6)
                    ctx.clip()

                    var cells = domeHex.cells
                    if (cells && cells.length) {
                        function mixColor(a, b, t) {
                            return Qt.rgba(
                                        a.r + (b.r - a.r) * t,
                                        a.g + (b.g - a.g) * t,
                                        a.b + (b.b - a.b) * t,
                                        a.a + (b.a - a.a) * t)
                        }
                        var severity = 1 - domeHex.hpVisual
                        if (domeHex.viewStateValue === "phase3")
                            severity = Math.max(severity, 0.6)
                        if (domeHex.viewStateValue === "destroyed")
                            severity = 1
                        var warmColor = domeHex.viewStateValue === "destroyed"
                                ? root.neonRed
                                : (domeHex.viewStateValue === "phase3" ? root.neonAmber : root.neonViolet)
                        var blend = Math.pow(Math.max(0, Math.min(1, severity)), 0.75)
                        var accentColor = mixColor(root.neonCyan, warmColor, blend)
                        accentColor = mixColor(accentColor, root.neonCyan, 0.25 * (1 - blend))
                        var baseDark = Qt.rgba(8/255, 18/255, 34/255, 0.22 + 0.1 * severity)

                        function drawCell(cell) {
                            var energy = Math.max(0, Math.min(1, cell.energy))
                            if (energy <= 0.01)
                                return
                            var flicker = 0.82 + 0.18 * Math.sin(root.pulsePhase * 6 + cell.flicker)
                            var fillColor = mixColor(baseDark, accentColor, energy * flicker)
                            ctx.beginPath()
                            for (var i = 0; i < 6; i++) {
                                var angle = Math.PI / 2 + i * Math.PI / 3
                                var px = cell.x + cell.radius * Math.cos(angle)
                                var py = cell.y + cell.radius * Math.sin(angle)
                                if (i === 0) ctx.moveTo(px, py)
                                else ctx.lineTo(px, py)
                            }
                            ctx.closePath()
                            ctx.fillStyle = Qt.rgba(fillColor.r, fillColor.g, fillColor.b, Math.min(1, 0.25 + energy * 0.85))
                            ctx.fill()
                            ctx.lineWidth = root.dp(0.8 + energy * 1.2)
                            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.05 + energy * 0.25)
                            ctx.stroke()
                        }

                        for (var i = 0; i < cells.length; i++)
                            drawCell(cells[i])
                    }

                    ctx.restore()
                }
            }

            onCellsChanged: hexCanvas.requestPaint()
            onHpVisualChanged: updateCellTargets()
            onWidthChanged: rebuildCells(true)
            onHeightChanged: rebuildCells(true)

            Connections {
                target: root
                function onPulsePhaseChanged() { hexCanvas.requestPaint() }
            }

            Connections {
                target: domeBackend
                ignoreUnknownSignals: true
                enabled: domeBackend
                function onViewStateChanged() { domeHex.syncState(true) }
                function onHpPercentChanged() { domeHex.syncState(false) }
            }

            Connections {
                target: root
                ignoreUnknownSignals: true
                function onDomeBackendChanged() { domeHex.syncState(true) }
            }

            Component.onCompleted: domeHex.syncState(true)
            onVisibleChanged: if (visible) domeHex.syncState(true)

            function syncState(forcePattern) {
                var backend = domeBackend
                var newHp = backend ? Math.max(0, Math.min(1, backend.hpPercent || 0)) : 0
                var newState = backend && backend.viewState ? backend.viewState : ""
                var stateChanged = newState !== viewStateValue
                hpPercentValue = newHp
                viewStateValue = newState
                hpVisual = newState === "destroyed" ? 0 : newHp
                rebuildCells(forcePattern || stateChanged)
                updateCellTargets()
            }

            function rebuildCells(force) {
                var key = viewStateValue + "_" + width.toFixed(0) + "x" + height.toFixed(0)
                if (!force && key === cellSeedKey && cells.length)
                    return
                cellSeedKey = key
                var rad = Math.max(root.dp(22), width * 0.035)
                var hexH = rad * 2
                var hexW = Math.sqrt(3) * rad
                var vertSpacing = hexH * 0.75
                var rows = Math.ceil(height / vertSpacing) + 4
                var cols = Math.ceil(width / hexW) + 4
                var startY = -vertSpacing * 2

                var hash = 0
                for (var i = 0; i < key.length; i++)
                    hash = (hash * 31 + key.charCodeAt(i)) & 0x7fffffff
                var seed = hash || 1
                function rng() {
                    seed = (seed * 16807) % 2147483647
                    return (seed - 1) / 2147483646
                }

                var list = []
                for (var row = 0; row < rows; row++) {
                    var y = startY + row * vertSpacing
                    var offsetX = (row % 2 === 0 ? 0 : hexW / 2) - hexW
                    for (var col = 0; col < cols; col++) {
                        var x = offsetX + col * hexW
                        var dx = x - width / 2
                        var dy = y - height / 2
                        var dist = Math.sqrt(dx * dx + dy * dy)
                        var norm = dist / (Math.min(width, height) / 2)
                        var jitter = (rng() - 0.5) * 0.18
                        var wave = Math.max(0, Math.min(1, norm + jitter))
                        list.push({
                                      x: x,
                                      y: y,
                                      radius: rad * (0.86 + rng() * 0.18),
                                      wave: wave,
                                      waveRank: 0,
                                      energy: 1,
                                      targetEnergy: 1,
                                      randomLoss: rng(),
                                      flicker: rng() * Math.PI * 2
                                  })
                    }
                }

                list.sort(function(a, b) { return a.wave - b.wave })
                for (var idx = 0; idx < list.length; idx++) {
                    list[idx].waveRank = list.length > 1 ? idx / (list.length - 1) : 0
                }
                cells = list
                updateCellTargets()
                hexCanvas.requestPaint()
            }

            function updateCellTargets() {
                if (!cells || !cells.length)
                    return
                var activeFraction = viewStateValue === "destroyed" ? 0 : hpVisual
                var severity = 1 - activeFraction
                if (viewStateValue === "phase3")
                    severity = Math.max(severity, 0.65)
                var falloff = 0.2 + severity * 0.2
                var lossBias = severity * 0.45
                for (var i = 0; i < cells.length; i++) {
                    var cell = cells[i]
                    var diff = activeFraction - cell.waveRank
                    var target = 0.5 + diff / falloff
                    target -= cell.randomLoss * lossBias
                    if (cell.wave < 0.35 && severity > 0.25)
                        target -= (0.35 - cell.wave) * severity * 0.35
                    if (viewStateValue === "destroyed")
                        target *= 0.25
                    cell.targetEnergy = Math.max(0, Math.min(1, target))
                }
            }

            function stepCellEnergy() {
                if (!cells || !cells.length)
                    return
                var changed = false
                for (var i = 0; i < cells.length; i++) {
                    var cell = cells[i]
                    var diff = cell.targetEnergy - cell.energy
                    if (Math.abs(diff) > 0.005) {
                        cell.energy += diff * 0.2
                        changed = true
                    }
                }
                if (changed)
                    hexCanvas.requestPaint()
            }
        }

    }

    Column {
        id: bottomLog
        width: parent.width
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: dp(24)
        spacing: dp(8)

        Rectangle {
            id: timeline
            width: parent.width * 0.75
            height: dp(2)
            radius: height / 2
            color: Qt.rgba(0.16, 0.23, 0.32, 0.85)
            anchors.horizontalCenter: parent.horizontalCenter

            Repeater {
                model: 24
                Rectangle {
                    width: dp(2)
                    height: dp(10)
                    color: index % 6 === 0 ? neonCyan : Qt.rgba(0.8, 0.9, 1, 0.25)
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
                width: dp(6)
                height: dp(6)
                radius: width / 2
                color: neonRed
                y: -dp(2)
                SequentialAnimation on x {
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: timeline.width - recDot.width; duration: 2600; easing: Easing.InOutSine }
                    NumberAnimation { from: timeline.width - recDot.width; to: 0; duration: 2600; easing: Easing.InOutSine }
                }
            }
        }

        Row {
            width: timeline.width
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: dp(18)
            Text {
                text: domeBackend ? ("Купол " + domeBackend.domeId) : "Купол"
                color: Qt.rgba(hudText.r, hudText.g, hudText.b, 0.65)
                font.pixelSize: dp(12)
                font.family: "Roboto Mono"
            }
            Text {
                text: domeBackend ? (domeBackend.statusText || "Мониторинг") : "Мониторинг"
                color: hudText
                font.pixelSize: dp(12)
                font.family: "Roboto Mono"
                font.bold: true
                elide: Text.ElideRight
            }
        }
    }
}
