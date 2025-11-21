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

    signal circleClicked()
    signal pointCaptured(string team)
    signal gameFinished(string winner)

    // scaling
    property real baseWidth: 1920
    property real baseHeight: 1080
    property real s: width / baseWidth
    function dp(x) { return Math.max(1, x * s); }

    // colors
    property color stateBlue: "#31d6ff"
    property color stateRed: "#ff3f9d"
    property color stateWhite: "#f5f7ff"
    property color neonCyan: "#00f7ff"
    property color neonPink: "#ff46ba"
    property color hudText: "#d8f5ff"
    property color hudMuted: "#6ea0b7"
    property color cAlarm: stateRed

    // current
    property color primaryColor: stateWhite
    onPrimaryColorChanged: {
        circleCanvas.requestPaint();
        gridCanvas.requestPaint();
        // if switched to white - hide overlay
        if (primaryColor === stateWhite) {
            flashOverlay.opacity = 0;
            flashOverlay.color = "transparent";
        }
    }

    property color fillColor: primaryColor
    property color strokeColor: primaryColor

    property string backgroundPath: ""
    property real glowBlur: 18.0
    property real glowAlpha: 0.6
    property real scanPhase: 0.0
    onScanPhaseChanged: circleCanvas.requestPaint()
    property real gridShift: 0.0
    onGridShiftChanged: gridCanvas.requestPaint()
    property real particleShift: 0.0
    // timers data
    property int defaultRoundTime: 10
    property int blueTotal: defaultRoundTime
    property int redTotal: defaultRoundTime
    property int blueRemaining: defaultRoundTime
    property int redRemaining: defaultRoundTime
    property real blueProgress: 1.0
    property real redProgress: 1.0

    property bool paused: false

    function hudSecondsDisplay(value) {
        var v = Math.max(0, Math.floor(value || 0));
        var str = (v < 10 ? "0" + v : v.toString());
        return str + " С";
    }

    Rectangle {
        id: holoBg
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0; color: "#03040b" }
            GradientStop { position: 0.35; color: "#050e1b" }
            GradientStop { position: 1; color: "#080214" }
        }
    }

    Image {
        anchors.fill: parent
        source: backgroundPath
        fillMode: Image.PreserveAspectCrop
        opacity: source ? 0.42 : 0
    }

    Item {
        id: scanNoise
        anchors.fill: parent
        Repeater {
            model: 14
            Rectangle {
                width: parent.width
                height: 2 * s
                y: (parent.height / 14) * index + (gridShift * 80)
                anchors.horizontalCenter: parent.horizontalCenter
                color: "#ffffff"
                opacity: 0.01 + (index % 3) * 0.01
            }
        }
    }

    // directional particles
    Item {
        id: particleLayer
        anchors.fill: parent
        z: 0.5

        Repeater {
            id: leftParticles
            model: 16
            delegate: Rectangle {
                width: Math.max(12 * s, 20)
                height: Math.max(2 * s, 3)
                radius: height / 2
                y: parent.height * (0.08 + (index / leftParticles.model) * 0.84)
                opacity: 0.18 + (index % 4) * 0.05
                color: Qt.rgba(primaryColor.r, primaryColor.g, primaryColor.b, 0.65)
                x: -width + (parent.width + width) * ((particleShift + index * 0.07) % 1.0)
                layer.enabled: true
                layer.smooth: true
            }
        }

    }

    Rectangle {
        id: leftNeonBar
        width: Math.max(10, 14 * s)
        anchors.left: parent.left
        anchors.leftMargin: 30 * s
        anchors.verticalCenter: parent.verticalCenter
        height: parent.height * 0.72
        radius: 14 * s
        color: "#050b14"
        border.width: Math.max(1, 2 * s)
        border.color: primaryColor
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
                    color: Qt.tint(primaryColor, Qt.rgba(0, 0, 0, 0.75))
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
        anchors.rightMargin: 30 * s
        anchors.verticalCenter: parent.verticalCenter
        height: leftNeonBar.height
        radius: leftNeonBar.radius
        color: leftNeonBar.color
        border.width: leftNeonBar.border.width
        border.color: primaryColor
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
                    color: Qt.tint(primaryColor, Qt.rgba(0, 0, 0, 0.75))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
        Behavior on border.color { ColorAnimation { duration: 420 } }
    }

    // Decorations
    Rectangle {
        id: topPanel
        anchors.top: parent.top
        anchors.topMargin: 28 * s
        anchors.horizontalCenter: parent.horizontalCenter
        width: parent.width * 0.62
        height: Math.max(76, 90 * s)
        radius: 20 * s
        color: "#050c16"
        border.color: primaryColor
        border.width: Math.max(2, 3 * s)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.rgba(0.01, 0.15, 0.25, 0.9) }
            GradientStop { position: 1; color: Qt.rgba(0.02, 0.05, 0.11, 0.8) }
        }
        opacity: 0.88
        layer.enabled: true
        layer.smooth: true

        Row {
            anchors.fill: parent
            anchors.margins: 22 * s
            spacing: 36 * s

            Column {
                spacing: 4 * s
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: -2 * s
                Text {
                    text: "КОНТРОЛЬНАЯ ТОЧКА"
                    font.pixelSize: Math.max(16, 22 * s)
                    font.bold: true
                    color: hudText
                    opacity: 0.9
                }
            }

            Rectangle {
                width: 1
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                color: Qt.rgba(1,1,1,0.1)
            }

            Column {
                spacing: 2 * s
                Text {
                    text: "BLUE"
                    font.pixelSize: Math.max(12, 16 * s)
                    color: stateBlue
                    font.bold: true
                }
                Text {
                    text: hudSecondsDisplay(Math.max(0, blueRemaining))
                    font.pixelSize: Math.max(18, 26 * s)
                    color: primaryColor === stateBlue ? stateBlue : hudText
                }
            }

            Column {
                spacing: 2 * s
                Text {
                    text: "RED"
                    font.pixelSize: Math.max(12, 16 * s)
                    color: stateRed
                    font.bold: true
                }
                Text {
                    text: hudSecondsDisplay(Math.max(0, redRemaining))
                    font.pixelSize: Math.max(18, 26 * s)
                    color: primaryColor === stateRed ? stateRed : hudText
                }
            }

            Item { width: Math.max(20, 80 * s); height: 1 }

            Text {
                anchors.verticalCenter: parent.verticalCenter
                text: "ИНИЦИИРУЙТЕ УДЕРЖАНИЕ"
                font.pixelSize: Math.max(14, 18 * s)
                font.bold: true
                color: primaryColor
            }
        }

        Behavior on border.color { ColorAnimation { duration: 420 } }
        Behavior on opacity { NumberAnimation { duration: 420 } }
    }

    Component {
        id: cornerComp
        Rectangle {
            width: 160 * s
            height: 120 * s
            radius: 14 * s
            color: "#041218"
            border.color: primaryColor
            border.width: Math.max(1, 2 * s)
            opacity: 0.08
            Behavior on border.color { ColorAnimation { duration: 420 } }
        }
    }
    Item {
        anchors.fill: parent
        Rectangle { x: 16 * s; y: 16 * s; width: cornerComp.width; height: cornerComp.height; color: cornerComp.color; border.color: primaryColor; border.width: cornerComp.border.width; radius: cornerComp.radius; opacity: 0.08 }
        Rectangle { x: parent.width - cornerComp.width - 16 * s; y: 16 * s; width: cornerComp.width; height: cornerComp.height; color: cornerComp.color; border.color: primaryColor; border.width: cornerComp.border.width; radius: cornerComp.radius; opacity: 0.08 }
        Rectangle { x: 16 * s; y: parent.height - cornerComp.height - 16 * s; width: cornerComp.width; height: cornerComp.height; color: cornerComp.color; border.color: primaryColor; border.width: cornerComp.border.width; radius: cornerComp.radius; opacity: 0.08 }
        Rectangle { x: parent.width - cornerComp.width - 16 * s; y: parent.height - cornerComp.height - 16 * s; width: cornerComp.width; height: cornerComp.height; color: cornerComp.color; border.color: primaryColor; border.width: cornerComp.border.width; radius: cornerComp.radius; opacity: 0.08 }
    }

    PropertyAnimation {
        target: root
        property: "gridShift"
        from: 0
        to: 1
        duration: 8000
        loops: Animation.Infinite
        running: true
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
        property: "particleShift"
        from: 0
        to: 1
        duration: 4200
        loops: Animation.Infinite
        running: true
    }

    // hidden grid canvas (so requestPaint won't fail)
    Canvas {
        id: gridCanvas
        anchors.fill: parent
        z: 0
        visible: true
        opacity: 0.28
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0,0,width,height);
            var spacing = 80 * s;
            var offset = gridShift * spacing;
            ctx.strokeStyle = "rgba(255,255,255,0.04)";
            ctx.lineWidth = 1;

            for (var x = -spacing; x < width + spacing; x += spacing) {
                ctx.beginPath();
                ctx.moveTo(x + offset, 0);
                ctx.lineTo(x + offset, height);
                ctx.stroke();
            }

            for (var y = -spacing; y < height + spacing; y += spacing) {
                ctx.beginPath();
                ctx.moveTo(0, y + offset);
                ctx.lineTo(width, y + offset);
                ctx.stroke();
            }
        }
    }

    // main circle canvas
    Canvas {
        id: circleCanvas
        anchors.centerIn: parent
        width: Math.min(parent.width, parent.height) * 0.36
        height: width
        z: 2
        scale: 1.0

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);

            var cx = width / 2;
            var cy = height / 2;
            var size = Math.min(width, height);
            var ringR = size / 2 * 0.85;
            var haloR = size / 2 * 0.95;
            var innerR = size / 2 * 0.62;
            var coreR = size / 2 * 0.38;
            var ringWidth = Math.max(12, 20 * s);
            var accent = neonCyan;
            if (primaryColor === stateRed) {
                accent = neonPink;
            } else if (primaryColor === stateBlue) {
                accent = stateBlue;
            }
            var haloAlpha = (primaryColor === stateWhite) ? 0.15 : 0.8;
            var haloColor = (primaryColor === stateWhite) ? Qt.rgba(1, 1, 1, 0.45) : accent;

            // glow halo
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, haloR, 0, Math.PI * 2);
            ctx.strokeStyle = haloColor;
            ctx.lineWidth = ringWidth * 0.6;
            ctx.shadowColor = primaryColor;
            ctx.shadowBlur = glowBlur * 1.3 * s;
            ctx.globalAlpha = haloAlpha;
            ctx.stroke();
            ctx.restore();

            // crosshair
            ctx.beginPath();
            ctx.strokeStyle = "rgba(255,255,255,0.08)";
            ctx.lineWidth = 1;
            ctx.moveTo(cx - haloR, cy);
            ctx.lineTo(cx + haloR, cy);
            ctx.stroke();
            ctx.beginPath();
            ctx.moveTo(cx, cy - haloR);
            ctx.lineTo(cx, cy + haloR);
            ctx.stroke();

            // outer reference ring
            ctx.beginPath();
            ctx.lineWidth = ringWidth * 0.4;
            ctx.strokeStyle = "rgba(255,255,255,0.07)";
            ctx.arc(cx, cy, ringR, 0, Math.PI * 2);
            ctx.stroke();

            // radial ticks
            ctx.save();
            ctx.translate(cx, cy);
            var tickCount = 64;
            for (var i = 0; i < tickCount; ++i) {
                var angle = (Math.PI * 2) * (i / tickCount);
                var outer = ringR * 1.02;
                var innerTick = ringR * (i % 4 === 0 ? 0.9 : 0.95);
                ctx.beginPath();
                ctx.strokeStyle = "rgba(255,255,255," + (i % 8 === 0 ? 0.45 : 0.15) + ")";
                ctx.lineWidth = (i % 8 === 0) ? 3 : 1;
                ctx.moveTo(Math.cos(angle) * innerTick, Math.sin(angle) * innerTick);
                ctx.lineTo(Math.cos(angle) * outer, Math.sin(angle) * outer);
                ctx.stroke();
            }
            ctx.restore();

            // progress ring
            var showProgress = false;
            var activeProgress = 0;
            if (primaryColor === stateBlue) { activeProgress = blueProgress; showProgress = true; }
            else if (primaryColor === stateRed) { activeProgress = redProgress; showProgress = true; }

            ctx.beginPath();
            ctx.lineWidth = ringWidth * 0.9;
            ctx.strokeStyle = "rgba(255,255,255,0.08)";
            ctx.arc(cx, cy, ringR * 0.75, 0, Math.PI * 2);
            ctx.stroke();

            if (showProgress) {
                var start = -Math.PI / 2;
                var end = start + (Math.PI * 2) * activeProgress;
                var grad = ctx.createLinearGradient(0, 0, width, height);
                grad.addColorStop(0, primaryColor);
                grad.addColorStop(1, accent);
                ctx.beginPath();
                ctx.lineCap = "round";
                ctx.lineWidth = ringWidth * 1.1;
                ctx.strokeStyle = grad;
                ctx.arc(cx, cy, ringR * 0.75, start, end, false);
                ctx.stroke();
            }

            if (primaryColor !== stateWhite) {
                var sweepStart = -Math.PI / 2 + scanPhase * Math.PI * 2;
                var sweepEnd = sweepStart + Math.PI / 5;
                ctx.beginPath();
                ctx.lineWidth = ringWidth * 0.4;
                ctx.strokeStyle = accent;
                ctx.globalAlpha = 0.35;
                ctx.arc(cx, cy, ringR * 0.9, sweepStart, sweepEnd, false);
                ctx.stroke();
                ctx.globalAlpha = 1.0;
            }

            // inner glow disk
            ctx.save();
            ctx.beginPath();
            ctx.arc(cx, cy, innerR, 0, Math.PI * 2);
            ctx.fillStyle = "rgba(4, 14, 25, 0.95)";
            ctx.fill();
            ctx.globalAlpha = 0.35;
            ctx.beginPath();
            ctx.fillStyle = primaryColor;
            ctx.arc(cx, cy, innerR * 0.98, 0, Math.PI * 2);
            ctx.fill();
            ctx.restore();

            // central core
            ctx.beginPath();
            var coreGrad = ctx.createRadialGradient(cx, cy, coreR * 0.2, cx, cy, coreR);
            coreGrad.addColorStop(0, "rgba(2, 8, 12, 0.2)");
            coreGrad.addColorStop(1, "rgba(3, 13, 18, 0.85)");
            ctx.fillStyle = coreGrad;
            ctx.arc(cx, cy, coreR, 0, Math.PI * 2);
            ctx.fill();

            ctx.beginPath();
            ctx.lineWidth = 2;
            ctx.strokeStyle = "rgba(255,255,255,0.12)";
            ctx.arc(cx, cy, coreR * 1.05, 0, Math.PI * 2);
            ctx.stroke();

            // center data text
            var display = "";
            if (primaryColor === stateBlue) display = Math.max(0, blueRemaining).toString();
            else if (primaryColor === stateRed) display = Math.max(0, redRemaining).toString();

            ctx.fillStyle = hudText;
            ctx.font = Math.round(58 * s) + "px 'Orbitron', 'Eurostile', sans-serif";
            ctx.textAlign = "center";
            ctx.textBaseline = "middle";
            ctx.fillText(display, cx, cy);

            ctx.fillStyle = hudMuted;
            ctx.font = Math.round(16 * s) + "px 'Fira Mono', monospace";
            var label = "";
            if (label.length > 0) ctx.fillText(label, cx, cy - coreR * 0.7);

            ctx.font = Math.round(18 * s) + "px 'Fira Mono', monospace";
            var footerText = "";
            if (footerText.length > 0) ctx.fillText(footerText, cx, cy + coreR * 0.75);
        }
    }

    Behavior on primaryColor { ColorAnimation { duration: 420; easing.type: Easing.InOutQuad } }

    SequentialAnimation {
        id: neonPulse
        running: false
        loops: 2
        NumberAnimation { target: root; property: "glowBlur"; from: 6.0; to: 40.0; duration: 260; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "glowBlur"; from: 40.0; to: 12.0; duration: 260; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "glowAlpha"; from: 0.45; to: 0.95; duration: 260; easing.type: Easing.InOutQuad }
        NumberAnimation { target: root; property: "glowAlpha"; from: 0.95; to: 0.55; duration: 260; easing.type: Easing.InOutQuad }
        onRunningChanged: { circleCanvas.requestPaint(); gridCanvas.requestPaint(); }
    }

    // overlay for flash
    Rectangle {
        id: flashOverlay
        anchors.fill: parent
        color: "transparent"
        z: 100
        opacity: 0
        visible: true
    }

    // flash animation: 10 loops, and after stopping keep overlay visible (unless user switched to white)
    SequentialAnimation {
        id: flashAnim
        running: false
        loops: 10

        NumberAnimation { target: flashOverlay; property: "opacity"; from: 0; to: 0.32; duration: 220; easing.type: Easing.InOutQuad }
        NumberAnimation { target: flashOverlay; property: "opacity"; from: 0.32; to: 0; duration: 320; easing.type: Easing.InOutQuad }

        onStopped: {
            // keep overlay visible in finished color, except if user switched to white
            if (primaryColor !== stateWhite) {
                flashOverlay.opacity = 0.32;
            } else {
                flashOverlay.opacity = 0;
                flashOverlay.color = "transparent";
            }
        }
    }

    // countdown timer that decrements only the active color's remaining
    Timer {
        id: countdownTimer
        interval: 1000
        repeat: true
        running: false
        onTriggered: {
            if (paused) return;

            var finishedThisTick = false;

            if (primaryColor === stateBlue) {
                if (blueRemaining > 0) {
                    blueRemaining -= 1;
                    blueProgress = (blueTotal > 0) ? (blueRemaining / blueTotal) : 0;
                    circleCanvas.requestPaint();
                }
                if (blueRemaining === 0) finishedThisTick = true;
            } else if (primaryColor === stateRed) {
                if (redRemaining > 0) {
                    redRemaining -= 1;
                    redProgress = (redTotal > 0) ? (redRemaining / redTotal) : 0;
                    circleCanvas.requestPaint();
                }
                if (redRemaining === 0) finishedThisTick = true;
            }

            if (finishedThisTick) {
                var finishedTeam = "";
                if (primaryColor === stateBlue) {
                    finishedTeam = "blue";
                } else if (primaryColor === stateRed) {
                    finishedTeam = "red";
                }
                if (finishedTeam !== "") {
                    pointCaptured(finishedTeam);
                    gameFinished(finishedTeam);
                }
                // Only trigger visual effect when the other timer is NOT > 0.
                // That is: if both timers are > 0 do nothing.
                if (!(blueRemaining > 0 && redRemaining > 0)) {
                    // set overlay to the finished color (based on who finished)
                    var finishedColor = (primaryColor === stateBlue) ? stateBlue : stateRed;
                    flashOverlay.color = finishedColor;
                    // start the flashing animation (10 loops)
                    flashAnim.start();
                }
                // If both timers are 0, stop countdown; otherwise keep it stopped until resumed.
                if (blueRemaining === 0 && redRemaining === 0) {
                    countdownTimer.stop();
                } else {
                    // we stopped due to finish of active; leave timer stopped until user resumes/changes as desired
                    countdownTimer.stop();
                }
            }
        }
    }

    NumberAnimation {
        id: pulse
        target: circleCanvas
        property: "scale"
        from: 1.0
        to: 1.04
        duration: 280
        easing.type: Easing.OutBack
        onStopped: { circleCanvas.scale = 1.0; }
    }

    // start a timer for active color (do not overwrite other color)
    function startTimerForActive(seconds) {
        var sInt = Math.max(1, Math.floor(seconds));
        if (primaryColor === stateBlue) {
            var canResetBlue = (blueRemaining === blueTotal) || (blueRemaining === 0);
            if (canResetBlue) {
                blueTotal = sInt;
                blueRemaining = blueTotal;
                blueProgress = 1.0;
            }
        } else if (primaryColor === stateRed) {
            var canResetRed = (redRemaining === redTotal) || (redRemaining === 0);
            if (canResetRed) {
                redTotal = sInt;
                redRemaining = redTotal;
                redProgress = 1.0;
            }
        }
        paused = false;
        circleCanvas.requestPaint();
        if (!countdownTimer.running) countdownTimer.start();
    }

    // change color manually - must NOT start flash animation
    function changeCircleState(state) {
        if (state === "red") primaryColor = stateRed;
        else if (state === "white") primaryColor = stateWhite;
        else primaryColor = stateBlue;

        neonPulse.start();

        // manual change cancels any running flash and hides overlay
        if (flashAnim.running) flashAnim.stop();
        flashOverlay.opacity = 0;
        flashOverlay.color = "transparent";

        // start/resume timers only for non-white
        if (primaryColor === stateWhite) {
            // do not start timer when switching to white
        } else {
            var activeRemaining = primaryColor === stateBlue ? blueRemaining : redRemaining;
            if (activeRemaining > 0) {
                paused = false;
                if (!countdownTimer.running) countdownTimer.start();
            } else {
                paused = true;
                countdownTimer.stop();
            }
        }

        circleCanvas.requestPaint();
    }

    // Mouse controls


    // UI captions
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: circleCanvas.bottom
        anchors.topMargin: 32 * s
        spacing: 12 * s

        Rectangle {
            width: circleCanvas.width * 0.8
            height: Math.max(32, 42 * s)
            radius: 12 * s
            color: "#050f19"
            border.color: primaryColor
            border.width: Math.max(1, 2 * s)
            opacity: 0.8

            Text {
                anchors.centerIn: parent
                text: (primaryColor === stateWhite) ? "ТОЧКА НЕ ЗАХВАЧЕНА" : (primaryColor === stateBlue ? "СИНЯЯ ФАЗА" : "КРАСНАЯ ФАЗА")
                font.pixelSize: Math.max(14, 20 * s)
                font.bold: true
                color: hudText
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

    Component.onCompleted: {
        circleCanvas.requestPaint();
        gridCanvas.requestPaint();
    }
}
