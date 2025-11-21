import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Shapes 1.15
import QtQuick3D

Window {
    id: root
    visible: true
    visibility: Window.FullScreen
    color: "#030914"
    flags: Qt.FramelessWindowHint

    signal medkitActivated()

    function animateMedkit() {
        var a1 = Qt.createQmlObject(
            'import QtQuick 2.15; NumberAnimation { target: crossHub; property: "scale"; from: 1.0; to: 1.06; duration: 100; running: true }',
            crossHub
        );
        a1.stopped.connect(function() {
            Qt.createQmlObject(
                'import QtQuick 2.15; NumberAnimation { target: crossHub; property: "scale"; from: 1.06; to: 1.0; duration: 240; easing.type: Easing.OutQuad; running: true }',
                crossHub
            );
        });
    }

    // адаптивность
    property real baseWidth: 1920
    property real baseHeight: 1080
    property real s: width / baseWidth
    function dp(x) { return Math.max(1, x * s) }
    function withAlpha(col, alpha) {
        if (col && typeof col === "object" && col.r !== undefined)
            return Qt.rgba(col.r, col.g, col.b, alpha)
        return Qt.rgba(1, 1, 1, alpha)
    }

    // палитра
    readonly property color cBg:        "#030914"
    readonly property color cBg2:       "#08111f"
    readonly property color neonCyan:   Qt.rgba(90/255, 220/255, 120/255, 1)
    readonly property color neonCyanDim:Qt.rgba(60/255, 160/255, 95/255, 1)
    readonly property color neonPink:   Qt.rgba(1, 75/255, 155/255, 1)
    readonly property color neonAmber:  Qt.rgba(1, 179/255, 71/255, 1)
    readonly property color hudText:    Qt.rgba(216/255, 245/255, 1, 1)
    readonly property color hudMuted:   Qt.rgba(100/255, 133/255, 163/255, 1)
    readonly property color hudBorder:  Qt.rgba(12/255, 30/255, 51/255, 1)
    readonly property color cAlarm:     Qt.rgba(1, 60/255, 77/255, 1)

    // состояние
    property var  backgroundPath: ""   // строка из Python
    property string userName: (typeof USER !== "undefined" && USER) ? USER : ""
    property bool lowSpec: false
    property real gridShift: 0.0
    onGridShiftChanged: if (gridCanvas) gridCanvas.requestPaint()
    property real scanPhase: 0.0
    onScanPhaseChanged: if (circleHalo) circleHalo.requestPaint()

    function toUrl(p) {
        if (!p) return "";
        if (typeof p === "string") {
            if (p.indexOf("://") >= 0) return p;
            if (p.startsWith("/")) return "file://" + p;
            return p;
        }
        return p;
    }

    // фон
    Rectangle {
        id: holoBg
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "#020611" }
            GradientStop { position: 0.4; color: "#050f1c" }
            GradientStop { position: 1.0; color: "#080216" }
        }
    }

    Image {
        anchors.fill: parent
        source: toUrl(backgroundPath)
        fillMode: Image.PreserveAspectCrop
        opacity: source && source !== "" ? 0.25 : 0.0
        visible: opacity > 0
        layer.enabled: true
    }

    Canvas {
        id: gridCanvas
        anchors.fill: parent
        opacity: 0.28
        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            var spacing = 100 * s;
            var offset = gridShift * spacing;
            ctx.strokeStyle = "rgba(255,255,255,0.05)";
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

    Item {
        anchors.fill: parent
        Repeater {
            model: 18
            Rectangle {
                width: parent.width
                height: 2 * s
                y: (parent.height / 18) * index + (scanPhase * 40)
                color: Qt.rgba(1, 1, 1, 0.04 + (index % 3) * 0.01)
            }
        }
    }

    // боковые полосы как в control
    Rectangle {
        width: dp(18)
        height: parent.height * 0.76
        anchors.left: parent.left
        anchors.leftMargin: dp(36)
        anchors.verticalCenter: parent.verticalCenter
        radius: dp(14)
        color: Qt.rgba(4/255, 12/255, 22/255, 0.85)
        border.color: neonCyan
        border.width: dp(2)
        opacity: 0.4
        Column {
            anchors.centerIn: parent
            spacing: dp(16)
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.6
                    height: dp(6)
                    radius: dp(3)
                    color: Qt.tint(neonCyan, Qt.rgba(0,0,0,0.7))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
    }

    Rectangle {
        width: dp(18)
        height: parent.height * 0.76
        anchors.right: parent.right
        anchors.rightMargin: dp(36)
        anchors.verticalCenter: parent.verticalCenter
        radius: dp(14)
        color: Qt.rgba(4/255, 12/255, 22/255, 0.85)
        border.color: neonCyan
        border.width: dp(2)
        opacity: 0.4
        Column {
            anchors.centerIn: parent
            spacing: dp(16)
            Repeater {
                model: 6
                Rectangle {
                    width: parent.parent.width * 0.6
                    height: dp(6)
                    radius: dp(3)
                    color: Qt.tint(neonCyan, Qt.rgba(0,0,0,0.7))
                    opacity: 0.25 + index * 0.08
                }
            }
        }
    }

    Rectangle {
        id: topPanel
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: dp(24)
        width: parent.width * 0.7
        height: dp(90)
        radius: dp(18)
        color: Qt.rgba(4/255, 12/255, 22/255, 0.92)
        border.color: neonCyan
        border.width: 1
        opacity: 0.9
        layer.enabled: true

        Row {
            anchors.fill: parent
            anchors.margins: dp(20)
            spacing: dp(36)

            Column {
                spacing: dp(4)
                anchors.verticalCenter: parent.verticalCenter
                anchors.verticalCenterOffset: dp(-2)
                Text { text: "АПТЕЧКА"; color: hudText; font.pixelSize: dp(24); font.bold: true }
            }

            Rectangle { width: 1; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.1) }

            Column {
                spacing: dp(2)
                Text { text: "МЕДОБЕСПЕЧЕНИЕ"; color: neonCyan; font.pixelSize: dp(14); font.family: "Roboto Mono" }
                Text { text: "СИСТЕМА ГОТОВА"; color: hudText; font.pixelSize: dp(18); font.family: "Roboto Mono" }
            }

            Rectangle { width: 1; anchors.top: parent.top; anchors.bottom: parent.bottom; color: Qt.rgba(1,1,1,0.1) }

            Column {
                spacing: dp(2)
                Text { text: "ЭНЕРГИЯ"; color: hudMuted; font.pixelSize: dp(12); font.family: "Roboto Mono" }
                Row {
                    spacing: dp(6)
                    Rectangle {
                        width: dp(120); height: dp(6); radius: height/2; color: Qt.rgba(0.12,0.18,0.22,0.8)
                        Rectangle { width: parent.width * 0.78; height: parent.height; radius: parent.radius; color: neonCyan }
                    }
                    Text { text: "78%"; color: hudText; font.pixelSize: dp(14); font.family: "Roboto Mono" }
                }
            }

            Column {
                spacing: dp(2)
                Text { text: "РЕЖИМ"; color: hudMuted; font.pixelSize: dp(12); font.family: "Roboto Mono" }
                Text { text: "РУЧНОЙ"; color: neonPink; font.pixelSize: dp(20); font.family: "Roboto Mono"; font.bold: true }
            }
        }
    }

    // сетка/скан (твоя базовая)
    ShaderEffect {
        anchors.fill: parent
        z: -1
        property real t: 0
        property color lineColor: neonCyan
        property real density: lowSpec ? 28.0 : 36.0
        blending: true
        fragmentShader: "
            uniform lowp float qt_Opacity;
            uniform lowp float t;
            uniform lowp vec4 lineColor;
            uniform lowp float density;
            varying highp vec2 qt_TexCoord0;
            void main() {
                highp vec2 uv = qt_TexCoord0;
                highp vec2 g = abs(fract(uv * density) - 0.5);
                lowp float vline = smoothstep(0.485, 0.5, 0.5 - g.x);
                lowp float hline = smoothstep(0.485, 0.5, 0.5 - g.y);
                lowp float grid = max(vline, hline);
                lowp float hatch = step(0.96, fract((uv.x + uv.y) * density * 0.5));
                lowp float scan = smoothstep(0.0, 1.0, sin((uv.y * 6.2831 * density * 0.06) + t*1.4) * 0.5 + 0.5);
                lowp float a = grid * 0.050 + hatch * 0.020 + scan * 0.035;
                gl_FragColor = vec4(lineColor.rgb, a) * qt_Opacity;
            }"
        NumberAnimation on t { from: 0; to: 6.2831; loops: Animation.Infinite; duration: 6000 }
    }

    // ===================== ЦЕНТР =====================
    Item {
        id: crossHub
        width: Math.min(parent.width, parent.height) * 0.60
        height: width
        anchors.centerIn: parent

        Canvas {
            id: circleHalo
            anchors.centerIn: parent
            width: parent.width * 1.18
            height: width
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0,0,width,height);
                var cx = width/2;
                var cy = height/2;
                var size = Math.min(width,height);
                var outer = size/2 * 0.98;
                var inner = size/2 * 0.68;
                var accent = neonCyan;
                ctx.beginPath();
                ctx.arc(cx, cy, outer, 0, Math.PI * 2);
                ctx.lineWidth = 6 * s;
                ctx.strokeStyle = withAlpha(accent, 0.08);
                ctx.stroke();

                ctx.beginPath();
                var grad = ctx.createRadialGradient(cx, cy, inner * 0.4, cx, cy, outer);
                grad.addColorStop(0, "rgba(6,15,28,0.8)");
                grad.addColorStop(1, withAlpha(accent, 0.18));
                ctx.fillStyle = grad;
                ctx.arc(cx, cy, outer, 0, Math.PI * 2);
                ctx.fill();

                var sweepStart = -Math.PI/2 + scanPhase * Math.PI * 2;
                var sweepEnd = sweepStart + Math.PI / 4;
                ctx.beginPath();
                ctx.lineWidth = 10 * s;
                ctx.globalAlpha = 0.35;
                ctx.strokeStyle = accent;
                ctx.arc(cx, cy, outer * 0.85, sweepStart, sweepEnd, false);
                ctx.stroke();
                ctx.globalAlpha = 1.0;
            }
            onWidthChanged: requestPaint()
            onHeightChanged: requestPaint()
        }

        // кольца
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.12; height: width
            radius: width/2; color: "transparent"
            border.color: neonCyanDim; border.width: 1; opacity: 0.16
        }
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 1.02; height: width
            radius: width/2; color: "transparent"
            border.color: neonCyan; border.width: 1; opacity: 0.25
        }
        Shape {
            id: dashedRing
            anchors.centerIn: parent
            width: crossHub.width * 0.92; height: width
            opacity: 0.26; antialiasing: true
            property real dashAnim: 0
            ShapePath {
                strokeColor: neonCyan; strokeWidth: 1
                strokeStyle: ShapePath.DashLine
                dashPattern: [ 4, 10 ]
                dashOffset: dashedRing.dashAnim
                fillColor: "transparent"
                startX: dashedRing.width/2; startY: 0
                PathAngleArc {
                    centerX: dashedRing.width/2; centerY: dashedRing.height/2
                    radiusX: dashedRing.width/2; radiusY: dashedRing.height/2
                    startAngle: 0; sweepAngle: 360
                }
            }
            NumberAnimation on dashAnim { from: 0; to: 200; duration: 10000; loops: Animation.Infinite; easing: Easing.Linear }
        }
        Item {
            id: tickRing
            anchors.centerIn: parent
            width: crossHub.width * 1.06; height: width
            opacity: 0.22; antialiasing: true
            Repeater {
                model: 24
                delegate: Item {
                    width: tickRing.width; height: tickRing.height
                    transform: Rotation { angle: index * (360/24); origin.x: width/2; origin.y: height/2 }
                    Rectangle {
                        width: dp(2); height: dp(10); radius: dp(1)
                        color: neonCyan; opacity: index % 6 === 0 ? 0.9 : 0.45
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: dp(6)
                    }
                }
            }
            NumberAnimation on rotation { from: 0; to: 360; duration: 16000; loops: Animation.Infinite; easing: Easing.Linear }
        }

        // 3D окно
        View3D {
            anchors.centerIn: parent
            width: crossHub.width * 0.92
            height: width
            visible: !lowSpec

            environment: SceneEnvironment {
                backgroundMode: SceneEnvironment.Transparent
                antialiasingMode: SceneEnvironment.MSAA
                antialiasingQuality: SceneEnvironment.High
            }

            Node {
                // Key light — тёплый и не слишком яркий
                DirectionalLight {
                    eulerRotation.x: -35
                    eulerRotation.y: -25
                    color: Qt.rgba(1.0, 0.90, 0.80, 1.0)
                    brightness: 2
                    castsShadow: true
                    shadowBias: 0.015
                    shadowFactor: 0.70
                    shadowMapQuality: DirectionalLight.ShadowMapQualityHigh
                }
                // фронтальный fill — очень мягкий
                DirectionalLight {
                    eulerRotation.x: 0
                    eulerRotation.y: 0
                    color: Qt.rgba(1.0, 0.92, 0.85, 1.0)
                    brightness: 1
                    castsShadow: false
                }
                // rim — тёплый акцент по краю
                DirectionalLight {
                    eulerRotation.x: 25
                    eulerRotation.y: 170
                    color: Qt.rgba(1.0, 0.85, 0.70, 1.0)
                    brightness: 10
                    castsShadow: false
                }

                // камера
                PerspectiveCamera {
                    id: cam
                    fieldOfView: 30
                    clipNear: 1
                    clipFar: 5000
                    readonly property real cube: 100
                    readonly property real halfHeight: 0.5 * cube * Math.max(barV.scale.y, barH.scale.y)
                    readonly property real halfWidth:  0.5 * cube * Math.max(barV.scale.x, barH.scale.x)
                    readonly property real bob: cross3d.bob3D
                    readonly property real halfExtentNeeded: Math.max(halfHeight + bob, halfWidth)
                    property real margin: 1.08
                    readonly property real fovRad: fieldOfView * Math.PI / 180
                    z: (halfExtentNeeded / Math.tan(fovRad / 2)) * margin
                }

                PrincipledMaterial {
                    id: matPbr
                    baseColor: neonCyan
                    metalness: 0.05
                    roughness: 0.45
                }

                Node {
                    id: cross3d
                    NumberAnimation on eulerRotation.y {
                        from: 0; to: 360; duration: 7000
                        loops: Animation.Infinite
                        easing: Easing.Linear
                    }

                    property real bob3D: 12
                    property int  bobT:  3200
                    SequentialAnimation on position.y {
                        loops: Animation.Infinite
                        NumberAnimation { from: -cross3d.bob3D; to: cross3d.bob3D; duration: cross3d.bobT; easing: Easing.InOutSine }
                        NumberAnimation { from:  cross3d.bob3D; to: -cross3d.bob3D; duration: cross3d.bobT; easing: Easing.InOutSine }
                    }

                    Model { id: barV; source: "#Cube"; materials: [matPbr]; scale: Qt.vector3d(0.90, 2.70, 0.90) }
                    Model { id: barH; source: "#Cube"; materials: [matPbr]; scale: Qt.vector3d(2.70, 0.90, 0.90) }
                }
            }
        }
    }

    // ===================== ПРАВЫЙ САЙДБАР =====================
    Column {
        id: rightSidebar
        spacing: dp(12)
        anchors.right: parent.right
        anchors.rightMargin: dp(80)
        anchors.verticalCenter: parent.verticalCenter
        width: dp(240)

        Repeater {
            model: [
                { label: "ESP32", val: 22 },
                { label: "RASPBERRY", val: 65 },
                { label: "SERVER", val: 45 }
            ]
            delegate: Column {
                spacing: dp(6)
                Text {
                    text: "00:: " + modelData.label
                    color: hudMuted
                    font.family: "Roboto Mono"
                    font.pixelSize: dp(12)
                    font.letterSpacing: dp(1.0)
                }
                Rectangle {
                    width: rightSidebar.width
                    height: dp(4)
                    radius: height / 2
                    color: Qt.rgba(0.12, 0.18, 0.22, 0.8)
                    Rectangle {
                        width: parent.width * (modelData.val / 100.0)
                        height: parent.height
                        radius: parent.radius
                        color: neonCyan
                    }
                    Text {
                        anchors.right: parent.right
                        anchors.verticalCenter: parent.verticalCenter
                        text: modelData.val + "%"
                        color: hudText
                        font.family: "Roboto Mono"
                        font.pixelSize: dp(11)
                    }
                }
            }
        }

        Rectangle {
            width: rightSidebar.width
            height: dp(120)
            radius: dp(10)
            color: Qt.rgba(5/255, 12/255, 22/255, 0.9)
            border.color: neonCyanDim
            border.width: 1
            Column {
                anchors.fill: parent
                anchors.margins: dp(12)
                spacing: dp(6)
                Text { text: "ИНФО"; color: neonAmber; font.family: "Roboto Mono"; font.pixelSize: dp(12); font.bold: true }
                Text { text: "Общий статус: стабильный"; color: hudText; font.family: "Roboto Mono"; font.pixelSize: dp(12) }
                Text { text: userName ? "USER: " + userName : "USER: не задан"; color: hudMuted; font.family: "Roboto Mono"; font.pixelSize: dp(11) }
            }
        }
    }

    // ===================== НИЖНИЙ ЛОГ =====================
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

            // дополнительный маркер справа для симметрии
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

    // Левый сайдбар удалён

    // ===================== ПОДСКАЗКА =====================
    Column {
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.top: crossHub.bottom
        anchors.topMargin: dp(80)
        spacing: dp(6)
        Text {
            text: ">> НАЖМИ В ЛЮБОМ МЕСТЕ, ЧТОБЫ ИСПОЛЬЗОВАТЬ"
            color: hudText
            font.family: "Roboto Mono"
            font.pixelSize: dp(16)
            opacity: 0.72
        }
    }

    NumberAnimation {
        target: root
        property: "gridShift"
        from: 0; to: 1
        duration: 9000
        loops: Animation.Infinite
        running: true
    }

    NumberAnimation {
        target: root
        property: "scanPhase"
        from: 0; to: 1
        duration: 6000
        loops: Animation.Infinite
        running: true
    }

    // риппл
    Component {
        id: shockwaveComponent
        Item {
            id: wave
            width: dp(40); height: dp(40)
            property real life: 720
            property color col: neonCyan
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                radius: width/2; color: "transparent"; border.color: col; border.width: 1; opacity: 0.8
                NumberAnimation on scale { from: 0.2; to: 6.0; duration: wave.life; easing: Easing.OutCubic }
                NumberAnimation on opacity { from: 0.8; to: 0.0; duration: wave.life }
            }
            Rectangle {
                anchors.centerIn: parent
                width: parent.width; height: parent.height
                radius: width/2; color: "transparent"; border.color: neonCyanDim; border.width: 1; opacity: 0.35
                NumberAnimation on scale { from: 0.2; to: 5.0; duration: wave.life*0.9; easing: Easing.OutCubic }
                NumberAnimation on opacity { from: 0.35; to: 0.0; duration: wave.life*0.9 }
            }
            Timer { interval: life; running: true; repeat: false; onTriggered: wave.destroy() }
        }
    }

    // глобальный захват клика
    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        onClicked: {
            shockwaveComponent.createObject(root, { x: mouse.x - dp(20), y: mouse.y - dp(20) })
            var a1 = Qt.createQmlObject(
                'import QtQuick 2.15; NumberAnimation { target: crossHub; property: "scale"; from: 1.0; to: 1.06; duration: 100; running: true }',
                crossHub
            )
            a1.stopped.connect(function() {
                Qt.createQmlObject(
                    'import QtQuick 2.15; NumberAnimation { target: crossHub; property: "scale"; from: 1.06; to: 1.0; duration: 240; easing.type: Easing.OutQuad; running: true }',
                    crossHub
                )
            })
            root.medkitActivated()
        }
    }

    // направляющие
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; y: dp(12); height: dp(6); color: "transparent"; border.color: neonCyanDim; border.width: 1; opacity: 0.08 }
    Rectangle { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: dp(6); color: "transparent"; border.color: neonCyanDim; border.width: 1; opacity: 0.08 }
}
