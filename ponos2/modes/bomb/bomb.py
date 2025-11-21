import sys
import threading
from pathlib import Path

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Signal, Property, QTimer, Slot, QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

MODE_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = MODE_DIR.parent.parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import ID, BROKER, PORT

TOPIC = f"arena/point/{ID}/time"
SUPER_TOPIC = "arena/supertopic"
DEFAULT_SECONDS_IF_NO_MQTT = 20


class Backend(QObject):
    screenTextChanged = Signal()
    timerChanged = Signal()
    gameEnded = Signal()
    winnerTextChanged = Signal()

    def __init__(self):
        super().__init__()
        self._screenText = ""
        self._winnerText = ""
        self._inputCode = ""
        self._correct_code = None
        self._timerRemaining = 0
        self._timerTotal = 0
        self._timerRunning = False
        self._gameEnded = False
        self._receivedTime = None
        self._super_event_sent = False

        self.timer = QTimer()
        self.timer.timeout.connect(self._tick)

        self._client = mqtt.Client()
        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message
        try:
            self._client.connect(BROKER, PORT, 60)
        except Exception as e:
            print(f"[MQTT] Connect error: {e}")

        self._mqtt_thread = threading.Thread(target=self._client.loop_forever, daemon=True)
        self._mqtt_thread.start()
    
    def _publish_super_event(self, payload: str):
        """Publish a single-shot event to the shared arena topic."""
        if self._super_event_sent:
            return
        self._super_event_sent = True
        try:
            info = self._client.publish(SUPER_TOPIC, payload, qos=1, retain=False)
            # publish() is async; wait briefly for completion
            info.wait_for_publish()
            print(f"[MQTT] published '{payload}' to {SUPER_TOPIC}")
        except Exception as exc:
            print(f"[MQTT] failed to publish '{payload}' to {SUPER_TOPIC}: {exc}")

    # --- QML свойства ---
    @Property(str, notify=screenTextChanged)
    def screenText(self):
        return self._screenText

    @Property(str, notify=winnerTextChanged)
    def winnerText(self):
        return self._winnerText

    @Property(int, notify=timerChanged)
    def timerRemaining(self):
        return int(self._timerRemaining)

    @Property(int, notify=timerChanged)
    def timerTotal(self):
        return int(self._timerTotal)

    def startTimer(self, seconds=None):
        if self._gameEnded:
            return
        if seconds is None:
            seconds = self._receivedTime if self._receivedTime is not None else DEFAULT_SECONDS_IF_NO_MQTT
        self._timerRemaining = seconds
        self._timerTotal = seconds
        self._timerRunning = True
        self.timer.start(1000)
        self.timerChanged.emit()
        print(f"[TIMER] started for {seconds} seconds")

    def _tick(self):
        if not self._timerRunning or self._gameEnded:
            return
        self._timerRemaining -= 1
        self.timerChanged.emit()
        if self._timerRemaining <= 0:
            self.timer.stop()
            self._timerRunning = False
            self._gameEnded = True
            self._winnerText = "ТЕРРОРИСТЫ ПОБЕДИЛИ!"
            self.winnerTextChanged.emit()
            print("[GAME] timer ended: terrorists won")
            self.gameEnded.emit()
            self._publish_super_event(f"bomb_esplose_terrorists_{ID}")

    def _pressNumber(self, num):
        if self._gameEnded:
            return
        if len(self._inputCode) >= 4:
            return
        self._inputCode += str(num)
        self._screenText = self._inputCode
        self.screenTextChanged.emit()

    # --- кнопки ---
    @Slot()
    def button0(self): self._pressNumber(0)
    @Slot()
    def button1(self): self._pressNumber(1)
    @Slot()
    def button2(self): self._pressNumber(2)
    @Slot()
    def button3(self): self._pressNumber(3)
    @Slot()
    def button4(self): self._pressNumber(4)
    @Slot()
    def button5(self): self._pressNumber(5)
    @Slot()
    def button6(self): self._pressNumber(6)
    @Slot()
    def button7(self): self._pressNumber(7)
    @Slot()
    def button8(self): self._pressNumber(8)
    @Slot()
    def button9(self): self._pressNumber(9)

    @Slot()
    def buttonDel(self):
        if self._gameEnded:
            return
        if self._inputCode:
            self._inputCode = self._inputCode[:-1]
            self._screenText = self._inputCode
            self.screenTextChanged.emit()

    @Slot()
    def clearScreen(self):
        if self._gameEnded:
            return
        self._inputCode = ""
        self._screenText = ""
        self.screenTextChanged.emit()

    @Slot(result=bool)
    def buttonEnter(self):
        if self._gameEnded:
            return True  # если игра закончена — можно возвращать True
        if len(self._inputCode) != 4:
            self._screenText = "ВВЕДИТЕ 4 ЦИФРЫ!"
            self.screenTextChanged.emit()
            self._inputCode = ""
            return False

        if self._correct_code is None:
            self._correct_code = self._inputCode
            self._inputCode = ""
            self.startTimer()
            return True

        if self._inputCode == self._correct_code:
            if self._timerRunning:
                self.timer.stop()
                self._timerRunning = False
            self._gameEnded = True
            self._winnerText = "СПЕЦНАЗ ПОБЕДИЛ!"
            self.winnerTextChanged.emit()
            print("[GAME] correct code entered: spetsnaz won")
            self.gameEnded.emit()
            self._publish_super_event(f"bomb_defused_spetsnaz_{ID}")
            self._inputCode = ""
            return True
        else:
            self._screenText = "НЕВЕРНЫЙ КОД!"
            self.screenTextChanged.emit()
            self._inputCode = ""
            return False

    # --- MQTT ---
    def _on_connect(self, client, userdata, flags, rc):
        print(f"[MQTT] Connected with rc = {rc}")
        client.subscribe(TOPIC)
        print(f"[MQTT] subscribed to {TOPIC}")

    def _on_message(self, client, userdata, msg):
        payload = msg.payload.decode(errors="ignore").strip()
        try:
            seconds = int(payload)
            self._receivedTime = seconds
            print(f"[MQTT] received time: {seconds}s")
        except ValueError:
            print(f"[MQTT] invalid payload: '{payload}'")


if __name__ == "__main__":
    app = QApplication(sys.argv)
    backend = Backend()
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backend", backend)
    qml_file = MODE_DIR / "bomb.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))
    if not engine.rootObjects():
        sys.exit(-1)
    sys.exit(app.exec())
