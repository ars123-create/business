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
    color: "#03131a"
    flags: Qt.FramelessWindowHint

    property real baseWidth: 1920
    property real baseHeight: 1080
    property real s: width / baseWidth
    function dp(x) { return Math.max(1, x * s); }

    property color accentColor: "#31d6ff"
    property color neonPink: "#ff46ba"
    property color neonAmber: "#ffb347"
    property color hudText: "#d8f5ff"
    property color hudMuted: "#6ea0b7"
    property color panelColor: "#050c16"
    property color tntAccent: "#ff3f67"
    property color cAlarm: neonPink

    property real glowBlur: 18.0
    property real glowAlpha: 0.6
    property real scanPhase: 0.0
    property real gridShift: 0.0
    property real timerSweep: 0.0
    property real planePhase: 0.0
    property real timerSweepPrev: 0.0
    property int timerSweepPhase: 0
    property string backgroundPath: ""

    onPlanePhaseChanged: {
        if (planeCanvas) planeCanvas.requestPaint()
    }

    function hudSeconds(value) {
        var v = Math.max(0, Math.floor(value || 0))
        var str = (v < 10 ? "0" + v : v.toString())
        return str + " С"
    }

    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#03040b" }
            GradientStop { position: 0.4; color: "#050f1d" }
            GradientStop { position: 1; color: "#080214" }
        }
    }

    Image {
        anchors.fill: parent
        source: backgroundPath
        fillMode: Image.PreserveAspectCrop
        opacity: source ? 0.35 : 0
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.24
        onPaint: {
            var ctx = getContext("2d")
            ctx.clearRect(0, 0, width, height)
            var spacing = 80 * s
            var offset = gridShift * spacing
            ctx.strokeStyle = "rgba(255,255,255,0.05)"
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
                y: (parent.height / 14) * index + (gridShift * 60)
                color: Qt.rgba(1, 1, 1, 0.01 + (index % 3) * 0.01)
            }
        }
    }

    Item {
        id: tntLayer
        anchors.centerIn: holoConsole
        width: holoConsole.width + 220 * s
        height: holoConsole.height * 0.65
        z: -0.05
        opacity: 0.85
        property int totalCylinders: 6

        Row {
            id: tntRow
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.verticalCenter: parent.verticalCenter
            spacing: 12 * s
            Repeater {
                model: tntLayer.totalCylinders
                delegate: Item {
                    width: (tntLayer.width * 0.75) / tntLayer.totalCylinders
                    height: tntLayer.height * 0.9
                    Rectangle {
                        anchors.fill: parent
                        radius: width / 2
                        color: "transparent"
                        border.color: Qt.rgba(tntAccent.r, tntAccent.g, tntAccent.b, 0.55)
                        border.width: 4 * s
                    }
                    Canvas {
                        anchors.fill: parent
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0,0,width,height)
                            ctx.strokeStyle = Qt.rgba(tntAccent.r, tntAccent.g, tntAccent.b, 0.9)
                            ctx.lineWidth = 2.2 * s
                            ctx.beginPath()
                            ctx.ellipse(width/2, 0, width*0.45, width*0.25)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.ellipse(width/2, height, width*0.45, width*0.25)
                            ctx.stroke()
                            ctx.beginPath()
                            ctx.moveTo(width*0.3, 0)
                            ctx.lineTo(width*0.3, height)
                            ctx.moveTo(width*0.7, 0)
                            ctx.lineTo(width*0.7, height)
                            ctx.stroke()
                        }
                    }
                    Canvas {
                        anchors.top: parent.top
                        anchors.horizontalCenter: parent.horizontalCenter
                        width: parent.width
                        height: parent.height * 0.5
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.clearRect(0,0,width,height)
                            ctx.strokeStyle = Qt.rgba(tntAccent.r, tntAccent.g, tntAccent.b, 0.85)
                            ctx.lineWidth = 2 * s
                            ctx.beginPath()
                            ctx.moveTo(width/2, 0)
                            ctx.bezierCurveTo(width/2 + 25 * s, -height * 0.4,
                                              width/2 - 10 * s, -height * 0.6,
                                              width/2 + 30 * s, -height * 0.85)
                            ctx.stroke()
                        }
                    }
                }
            }
        }
    }

    Rectangle {
        id: leftNeonBar
        width: Math.max(10, 14 * s)
        anchors.left: parent.left
        anchors.leftMargin: 36 * s
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.78
        radius: 14 * s
        color: "#050b14"
        border.width: Math.max(1, 2 * s)
        border.color: accentColor
        opacity: 0.35
        layer.enabled: true
        layer.smooth: true

        Column {
            anchors.centerIn: parent
            spacing: 12 * s
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.6
                    height: Math.max(4, 6 * s)
                    radius: 6 * s
                    anchors.horizontalCenter: parent.parent.horizontalCenter
                    color: Qt.tint(accentColor, Qt.rgba(0, 0, 0, 0.75))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
        Behavior on border.color { ColorAnimation { duration: 420 } }
    }

    Rectangle {
        id: rightNeonBar
        width: leftNeonBar.width
        anchors.right: parent.right
        anchors.rightMargin: 36 * s
        anchors.verticalCenter: parent.verticalCenter
        height: leftNeonBar.height
        radius: leftNeonBar.radius
        color: leftNeonBar.color
        border.width: leftNeonBar.border.width
        border.color: neonPink
        opacity: leftNeonBar.opacity

        Column {
            anchors.centerIn: parent
            spacing: 12 * s
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.6
                    height: Math.max(4, 6 * s)
                    radius: 6 * s
                    anchors.horizontalCenter: parent.parent.horizontalCenter
                    color: Qt.tint(neonPink, Qt.rgba(0, 0, 0, 0.75))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
        Behavior on border.color { ColorAnimation { duration: 420 } }
    }

    PropertyAnimation {
        target: root
        property: "gridShift"
        from: 0
        to: 1
        duration: 8000
        loops: Animation.Infinite
        running: true
        onRunningChanged: gridCanvas.requestPaint()
    }

    PropertyAnimation {
        target: root
        property: "scanPhase"
        from: 0
        to: 1
        duration: 3600
        loops: Animation.Infinite
        running: true
    }

    PropertyAnimation {
        target: root
        property: "timerSweep"
        from: 0
        to: 1
        duration: 5200
        loops: Animation.Infinite
        running: true
    }

    PropertyAnimation {
        target: root
        property: "planePhase"
        from: 0
        to: 1
        duration: 7200
        loops: Animation.Infinite
        running: true
    }

    onTimerSweepChanged: {
        if (timerSweep < timerSweepPrev) {
            timerSweepPhase += 1
        }
        timerSweepPrev = timerSweep
        if (orbitCanvas) orbitCanvas.requestPaint()
    }

    Rectangle {
        id: topPanel
        anchors.top: parent.top
        anchors.topMargin: 28 * s
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.72
        height: Math.max(76, 88 * s)
        radius: 20 * s
        color: panelColor
        border.color: accentColor
        border.width: Math.max(2, 3 * s)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.02, 0.15, 0.26, 0.9) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.05, 0.11, 0.8) }
        }
        opacity: 0.9
        layer.enabled: true
        layer.smooth: true

        Row {
            anchors.fill: parent
            anchors.margins: 22 * s
            spacing: 34 * s

            Column {
                spacing: 4 * s
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2 * s
                Text {
                    text: "РЕЖИМ БОМБЫ"
                    font.pixelSize: Math.max(16, 22 * s)
                    font.bold: true
                    color: hudText
                }
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.rgba(1, 1, 1, 0.12)
            }

            Column {
                spacing: 2 * s
                Text {
                    text: "ВРЕМЯ"
                    font.pixelSize: Math.max(12, 16 * s)
                    color: neonAmber
                    font.bold: true
                }
                Text {
                    text: backend ? hudSeconds(backend.timerRemaining) : hudSeconds(0)
                    font.pixelSize: Math.max(18, 26 * s)
                    color: hudText
                }
            }

            Column {
                spacing: 4 * s
                Text {
                    text: "ВВЕДИТЕ КОД ДЛЯ ОБЕЗВРЕЖИВАНИЯ"
                    font.pixelSize: Math.max(14, 18 * s)
                    font.bold: true
                    color: accentColor
                }
            }
        }

        Behavior on border.color { ColorAnimation { duration: 420 } }
    }

    Rectangle {
        id: holoConsole
        width: Math.min(parent.width * 0.86, parent.height * 0.8)
        height: width * 0.64
        anchors.centerIn: parent
        radius: 28 * s
        color: Qt.rgba(6 / 255, 14 / 255, 26 / 255, 0.92)
        border.color: accentColor
        border.width: Math.max(2, 2.5 * s)
        layer.enabled: true
        layer.smooth: true

        Canvas {
            anchors.fill: parent
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.07)
                ctx.lineWidth = 1
                ctx.setLineDash([18 * s, 8 * s])
                ctx.strokeRect(10 * s, 10 * s, width - 20 * s, height - 20 * s)
                ctx.setLineDash([])
            }
        }

        Row {
            id: consoleRow
            anchors.fill: parent
            anchors.margins: 32 * s
            spacing: 36 * s

            Rectangle {
                id: telemetryPod
                width: Math.min(340 * s, consoleRow.width * 0.28)
                height: consoleRow.height
                radius: 24 * s
                color: Qt.rgba(5 / 255, 12 / 255, 22 / 255, 0.85)
                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                border.width: 1.4
                layer.enabled: true
                layer.smooth: true

                Column {
                    anchors.fill: parent
                    anchors.margins: 24 * s
                    spacing: 16 * s
                    width: parent.width

                    Canvas {
                        id: timerCanvas
                        width: Math.min(parent.width * 0.9, 260 * s)
                        height: width
                        anchors.horizontalCenter: parent.horizontalCenter
                        property real stroke: Math.max(8 * s, 8)
                        property real innerScale: 0.82

                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            ctx.clearRect(0, 0, width, height)

                            var cx = width / 2
                            var cy = height / 2
                            var radius = (Math.min(width, height) / 2 - stroke) * innerScale
                            ctx.save()
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius + stroke * 0.85, 0, Math.PI * 2)
                            ctx.lineWidth = stroke * 0.55
                            ctx.strokeStyle = "rgba(49,214,255,0.18)"
                            ctx.stroke()
                            ctx.restore()
                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, 0, Math.PI * 2, false)
                            ctx.lineWidth = stroke
                            ctx.strokeStyle = "rgba(49,214,255,0.12)"
                            ctx.stroke()

                            var total = backend ? backend.timerTotal : 0
                            var rem = backend ? backend.timerRemaining : 0
                            var pct = 0
                            if (total > 0) pct = Math.max(0, Math.min(1, rem / total))
                            var start = -Math.PI / 2
                            var end = start + pct * 2 * Math.PI

                            ctx.beginPath()
                            ctx.arc(cx, cy, radius, start, end, false)
                            ctx.lineWidth = stroke
                            ctx.lineCap = "round"
                            var grad = ctx.createLinearGradient(0, 0, width, height)
                            grad.addColorStop(0, accentColor)
                            grad.addColorStop(1, neonPink)
                            ctx.strokeStyle = grad
                            ctx.stroke()

                            ctx.fillStyle = hudText
                            var fontSize = Math.max(16, 24 * s)
                            ctx.font = Math.round(fontSize) + "px 'Fira Mono', sans-serif"
                            var secs = isNaN(rem) ? 0 : Math.max(0, Math.ceil(rem))
                            var label = secs.toString()
                            var textW = ctx.measureText(label).width
                            ctx.fillText(label, cx - textW / 2, cy + (fontSize / 3))
                        }

                        Component.onCompleted: timerCanvas.requestPaint()
                    }

                    Column {
                        id: orbitStack
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 16 * s

                        Canvas {
                            id: orbitCanvas
                            width: Math.min(timerCanvas.width * 1.2, telemetryPod.width * 0.82)
                            height: Math.min(width * 0.55, telemetryPod.height * 0.32)
                            onPaint: {
                                var ctx = getContext("2d")
                                ctx.clearRect(0, 0, width, height)
                                ctx.save()
                                ctx.translate(width / 2, height / 2)

                                var phase = (timerSweep + timerSweepPhase) * Math.PI * 2
                                ctx.globalAlpha = 0.95
                                var layers = 3
                                var maxRadius = Math.min(width, height) / 2 - 8 * s
                                for (var i = 0; i < layers; ++i) {
                                    ctx.save()
                                    var offset = i * 0.4
                                    var radius = Math.max(6 * s, maxRadius - i * 10 * s)
                                    ctx.beginPath()
                                    ctx.lineWidth = 4 + i
                                    var grad = ctx.createLinearGradient(-radius, 0, radius, 0)
                                    grad.addColorStop(0, "rgba(49,214,255," + (0.48 - i * 0.08) + ")")
                                    grad.addColorStop(1, "rgba(255,70,186," + (0.48 - i * 0.08) + ")")
                                    ctx.strokeStyle = grad
                                    ctx.setLineDash([])
                                    ctx.rotate(0.01 + i * 0.003)
                                    var speed = 1.0 + i * 0.15
                                    var start = phase * speed + offset
                                    var span = Math.PI * (0.42 - i * 0.06)
                                    var end = start + Math.max(0.12 * Math.PI, span)
                                    ctx.arc(0, 0, radius, start, end, false)
                                    ctx.stroke()
                                    ctx.restore()
                                }
                                ctx.restore()
                            }
                            Component.onCompleted: requestPaint()
                            onWidthChanged: requestPaint()
                            onHeightChanged: requestPaint()
                        }

                        Rectangle {
                            id: telemetryStrip
                            width: orbitCanvas.width
                            height: orbitCanvas.height * 0.62
                            radius: 12 * s
                            color: Qt.rgba(6 / 255, 16 / 255, 28 / 255, 0.92)
                            border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.55)
                            border.width: 1.4
                            layer.enabled: true
                            layer.smooth: true

                            Item {
                                anchors.fill: parent
                                anchors.margins: 16 * s

                                Canvas {
                                    id: telemetryCanvas
                                    anchors.fill: parent
                                    onPaint: {
                                        var ctx = getContext("2d")
                                        ctx.clearRect(0, 0, width, height)
                                        ctx.save()
                                        ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.22)
                                        ctx.lineWidth = 1
                                        var step = Math.max(18 * s, 28)
                                        for (var x = -step; x < width + step; x += step) {
                                            ctx.beginPath()
                                            ctx.moveTo(x, 0)
                                            ctx.lineTo(x + step * 0.4, height)
                                            ctx.stroke()
                                        }
                                        ctx.restore()
                                    }
                                }

                                Column {
                                    anchors.fill: parent
                                    spacing: 12 * s

                                    Repeater {
                                        model: 4
                                        Rectangle {
                                            width: parent.width
                                            height: 8 * s
                                            radius: height / 2
                                            color: Qt.rgba(0, 0, 0, 0.35)
                                            border.color: Qt.rgba(1, 1, 1, 0.08)
                                            Rectangle {
                                                anchors.left: parent.left
                                                anchors.verticalCenter: parent.verticalCenter
                                                width: parent.width * (0.35 + index * 0.1)
                                                height: parent.height
                                                radius: parent.radius
                                                gradient: Gradient {
                                                    GradientStop { position: 0; color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.75) }
                                                    GradientStop { position: 1; color: Qt.rgba(neonPink.r, neonPink.g, neonPink.b, 0.35) }
                                                }
                                            }
                                        }
                                    }

                                    Rectangle {
                                        width: parent.width
                                        height: 1
                                        color: Qt.rgba(1, 1, 1, 0.05)
                                    }

                                    Row {
                                        spacing: 12 * s
                                        anchors.horizontalCenter: parent.horizontalCenter
                                        Repeater {
                                            model: 6
                                            Rectangle {
                                                width: parent.width / 6 - 6 * s
                                                height: parent ? parent.height * 0.12 : 12 * s
                                                radius: 8 * s
                                                gradient: Gradient {
                                                    GradientStop { position: 0; color: Qt.rgba(5 / 255, 24 / 255, 52 / 255, 0.85) }
                                                    GradientStop { position: 1; color: Qt.rgba(neonPink.r, neonPink.g, neonPink.b, 0.3) }
                                                }
                                                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.3)
                                                Rectangle {
                                                    anchors.centerIn: parent
                                                    width: parent.width * 0.32
                                                    height: parent.height * 0.32
                                                    radius: width / 2
                                                    color: Qt.rgba(1, 1, 1, 0.1)
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        }

                        Item {
                            width: telemetryStrip.width
                            height: Math.max(40 * s, telemetryStrip.height * 0.3)
                            Canvas {
                                id: planeCanvas
                                anchors.fill: parent
                                onPaint: {
                                    var ctx = getContext("2d")
                                    ctx.clearRect(0, 0, width, height)
                                    ctx.save()
                                    ctx.translate(width / 2, height / 2)
                                    var rx = width * 0.38
                                    var ry = height * 0.84

                                    ctx.beginPath()
                                    for (var angle = -Math.PI; angle <= Math.PI + 0.01; angle += Math.PI / 80) {
                                        var denom = 1 + Math.pow(Math.cos(angle), 2)
                                        var px = rx * Math.sin(angle) / denom
                                        var py = ry * Math.sin(angle) * Math.cos(angle) / denom
                                        if (angle === -Math.PI) ctx.moveTo(px, py)
                                        else ctx.lineTo(px, py)
                                    }
                                    ctx.strokeStyle = "rgba(255,255,255,0.08)"
                                    ctx.lineWidth = 2
                                    ctx.stroke()

                                    var theta = (planePhase * 2 - 1) * Math.PI
                                    var denomShip = 1 + Math.pow(Math.cos(theta), 2)
                                    var shipX = rx * Math.sin(theta) / denomShip
                                    var shipY = ry * Math.sin(theta) * Math.cos(theta) / denomShip
                                    var delta = 0.01
                                    var thetaNext = theta + delta
                                    var denomNext = 1 + Math.pow(Math.cos(thetaNext), 2)
                                    var nx = rx * Math.sin(thetaNext) / denomNext
                                    var ny = ry * Math.sin(thetaNext) * Math.cos(thetaNext) / denomNext
                                    var dx = nx - shipX
                                    var dy = ny - shipY
                                    var rot = Math.atan2(dy, dx)

                                    ctx.save()
                                    ctx.translate(shipX, shipY)
                                    ctx.rotate(rot)

                                    var bodyLen = Math.max(24 * s, width * 0.06)
                                    var wing = Math.max(10 * s, width * 0.025)

                                    ctx.beginPath()
                                    ctx.moveTo(-bodyLen * 0.4, 0)
                                    ctx.lineTo(bodyLen * 0.5, 0)
                                    ctx.lineWidth = 3
                                    ctx.strokeStyle = Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.8)
                                    ctx.stroke()

                                    ctx.beginPath()
                                    ctx.moveTo(0, 0)
                                    ctx.lineTo(-bodyLen * 0.2, wing)
                                    ctx.lineTo(-bodyLen * 0.05, 0)
                                    ctx.lineTo(-bodyLen * 0.2, -wing)
                                    ctx.closePath()
                                    ctx.fillStyle = Qt.rgba(neonPink.r, neonPink.g, neonPink.b, 0.75)
                                    ctx.fill()

                                    ctx.beginPath()
                                    ctx.moveTo(bodyLen * 0.45, 0)
                                    ctx.lineTo(bodyLen * 0.2, wing * 0.6)
                                    ctx.lineTo(bodyLen * 0.2, -wing * 0.6)
                                    ctx.closePath()
                                    ctx.fillStyle = Qt.rgba(255 / 255, 180 / 255, 120 / 255, 0.9)
                                    ctx.fill()

                                    ctx.restore()
                                    ctx.restore()
                                }
                                Component.onCompleted: requestPaint()
                                onWidthChanged: requestPaint()
                                onHeightChanged: requestPaint()
                            }
                        }
                    }
                }
            }

            Item {
                id: consoleArea
                width: consoleRow.width - telemetryPod.width - consoleRow.spacing
                height: consoleRow.height

                Column {
                    id: consoleColumn
                    anchors.fill: parent
                    spacing: 18 * s

                    Column {
                        anchors.horizontalCenter: parent.horizontalCenter
                        spacing: 4 * s
                        Text {
                            text: "БОМБА"
                            color: accentColor
                            font.pixelSize: Math.max(28, 40 * s)
                            font.bold: true
                            horizontalAlignment: Text.AlignHCenter
                        }
                    }

                    Rectangle {
                        id: screen
                        width: parent.width
                        height: parent.height * 0.22
                        radius: 18 * s
                        gradient: Gradient {
                            GradientStop { position: 0; color: Qt.rgba(4 / 255, 20 / 255, 34 / 255, 0.92) }
                            GradientStop { position: 1; color: Qt.rgba(2 / 255, 8 / 255, 18 / 255, 0.88) }
                        }
                        border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.45)
                        border.width: 1.6
                        anchors.horizontalCenter: parent.horizontalCenter

                        Text {
                            text: "CODE LOCK"
                            anchors.left: parent.left
                            anchors.top: parent.top
                            anchors.leftMargin: 16 * s
                            anchors.topMargin: 10 * s
                            font.pixelSize: Math.max(12, 18 * s)
                            color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.8)
                            font.family: "Roboto Mono"
                        }

                    Text {
                        id: screenText
                        anchors.fill: parent
                        anchors.margins: 32 * s
                        text: backend ? backend.screenText : ""
                        wrapMode: Text.NoWrap
                        horizontalAlignment: Text.AlignLeft
                        color: backend && backend.screenText && backend.screenText.indexOf("НЕВЕРНЫЙ") >= 0 ? neonPink : hudText
                        font.pixelSize: Math.max(30, 46 * s)
                        font.family: "Fira Mono"
                    }

                    Rectangle {
                        id: errorOverlay
                        anchors.fill: parent
                        color: Qt.rgba(1, 0, 0, 0.0)
                        radius: parent.radius
                    }

                    SequentialAnimation {
                        id: flashAnim
                        loops: 1
                        PropertyAnimation { target: errorOverlay; property: "color"; from: Qt.rgba(1, 0, 0, 0.0); to: Qt.rgba(1, 0, 0, 0.55); duration: 150; easing.type: Easing.InOutQuad }
                        PauseAnimation { duration: 700 }
                        PropertyAnimation { target: errorOverlay; property: "color"; from: Qt.rgba(1, 0, 0, 0.55); to: Qt.rgba(1, 0, 0, 0.0); duration: 150; easing.type: Easing.InOutQuad }
                    }
                }

                    Grid {
                        id: keypad
                        columns: 3
                        columnSpacing: 12 * s
                        rowSpacing: 24 * s
                        anchors.horizontalCenter: parent.horizontalCenter
                        property real availableWidth: parent.width
                        width: keyWidth * columns + columnSpacing * (columns - 1)
                        height: parent.height * 0.56
                        property int rows: 4
                        property real baseKeyWidth: (availableWidth - (columns - 1) * columnSpacing) / columns
                        property real keyWidth: Math.min(availableWidth / columns * 1.2, baseKeyWidth * 1.4) / 2
                        property real baseKeyHeight: (height - (rows - 1) * rowSpacing) / rows
                        property real keyHeight: Math.min(height / rows, baseKeyHeight * 1.08)

                        Repeater {
                            model: [
                                {text:"1", action:"1"},
                                {text:"2", action:"2"},
                                {text:"3", action:"3"},
                                {text:"4", action:"4"},
                                {text:"5", action:"5"},
                                {text:"6", action:"6"},
                                {text:"7", action:"7"},
                                {text:"8", action:"8"},
                                {text:"9", action:"9"},
                                {text:"✕", action:"del"},
                                {text:"0", action:"0"},
                                {text:"⏎", action:"enter"}
                            ]
                            delegate: Rectangle {
                                width: keypad.keyWidth
                                height: keypad.keyHeight
                                radius: 20 * s
                                gradient: Gradient {
                                    GradientStop { position: 0; color: Qt.rgba(5 / 255, 18 / 255, 34 / 255, 0.95) }
                                    GradientStop { position: 1; color: Qt.rgba(8 / 255, 30 / 255, 46 / 255, 0.9) }
                                }
                                border.color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.35)
                                border.width: 1.2
                                layer.enabled: true
                                layer.smooth: true

                                Rectangle {
                                    anchors.fill: parent
                                    anchors.margins: 6 * s
                                    radius: parent.radius * 0.7
                                    color: Qt.rgba(neonPink.r, neonPink.g, neonPink.b, 0.08)
                                    border.width: 1
                                    border.color: Qt.rgba(neonPink.r, neonPink.g, neonPink.b, 0.25)
                                }

                                Column {
                                    anchors.centerIn: parent
                                    spacing: 4 * s
                                    Text {
                                        text: modelData.text
                                        font.pixelSize: Math.max(40, 56 * s)
                                        color: accentColor
                                        font.bold: true
                                        horizontalAlignment: Text.AlignHCenter
                                    }
                                    Rectangle {
                                        width: parent.width * 0.6
                                        height: 3 * s
                                        radius: height / 2
                                        color: Qt.rgba(accentColor.r, accentColor.g, accentColor.b, 0.25)
                                        anchors.horizontalCenter: parent.horizontalCenter
                                    }
                                }

                                MouseArea {
                                    anchors.fill: parent
                                    enabled: backend && backend.winnerText === ""
                                    onPressed: parent.scale = 0.93
                                    onReleased: {
                                        parent.scale = 1.0
                                        if (!backend) return
                                        if (modelData.action === "del") {
                                            backend.buttonDel()
                                        } else if (modelData.action === "enter") {
                                            var success = backend.buttonEnter()
                                            if (!success) flashAnim.start()
                                            backend.clearScreen()
                                        } else {
                                            var fnName = "button" + modelData.action
                                            if (backend[fnName]) backend[fnName]()
                                        }
                                    }
                                }

                                Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.InOutQuad } }
                            }
                        }
                    }
                }
            }
        }
    }

    Connections { target: backend; onTimerChanged: timerCanvas.requestPaint() }

    Item {
        anchors.fill: parent
        visible: backend && backend.winnerText !== ""
        z: 999
        Rectangle {
            anchors.fill: parent
            color: Qt.rgba(0, 0, 0, 0.75)
        }
        Text {
            anchors.centerIn: parent
            text: backend ? backend.winnerText : ""
            color: "#FFDDDD"
            font.pixelSize: Math.max(40, 80 * root.s)
            font.bold: true
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
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

    Component.onCompleted: {
        gridCanvas.requestPaint()
        timerCanvas.requestPaint()
    }
}
