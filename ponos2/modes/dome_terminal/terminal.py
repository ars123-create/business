import argparse
import json
import logging
import queue
import sys
import threading
import time
from pathlib import Path

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal, Slot
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

import config as _cfg

ID = getattr(_cfg, "ID")
BROKER = getattr(_cfg, "BROKER")
PORT = getattr(_cfg, "PORT")
DEFAULT_TERMINAL_ID = getattr(_cfg, "DOME_TERMINAL_ID", ID)
DEFAULT_CHOICE = getattr(_cfg, "DOME_DEFAULT_CHOICE", "keep_ammo")
DEFAULT_TIMEOUT = getattr(_cfg, "DOME_TIMEOUT_SEC", 45)
TEAM_NAME_OVERRIDES = getattr(_cfg, "DOME_TEAM_NAMES", {}) or {}
TEAM_COLORS = getattr(_cfg, "DOME_TEAM_COLORS", {}) or {}
SUPER_TOPIC = getattr(_cfg, "SUPER_TOPIC", "arena/supertopic") or "arena/supertopic"

MODE_DIR = Path(__file__).resolve().parent
QML_TERMINAL = MODE_DIR / "dome_terminal.qml"

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger("dome_terminal")


def parse_args():
    parser = argparse.ArgumentParser(description="Терминал купола: выбор награды")
    parser.add_argument("--terminal-id", help="идентификатор терминала выбора")
    parser.add_argument("--default-choice", choices=["keep_ammo", "super_shots"], help="вариант по умолчанию")
    return parser.parse_args()


class BonusTerminalBackend(QObject):
    stateChanged = Signal()
    countdownChanged = Signal()
    choiceChanged = Signal()

    def __init__(self, terminal_id: str, publish_cb, default_choice: str):
        super().__init__()
        self._terminal_id = terminal_id
        self._publish_cb = publish_cb
        self._state = "idle"
        self._team = ""
        self._team_label = ""
        self._team_color = TEAM_COLORS.get("default", "#50d2ff")
        self._dome_id = ""
        self._countdown = 0
        self._timeout_total = DEFAULT_TIMEOUT
        self._timer = QTimer()
        self._timer.setInterval(1000)
        self._timer.timeout.connect(self._tick)
        self._selected_choice = ""
        self._default_choice = default_choice
        self._auto_selected = False
        self._info_text = "Ожидание команды"

    @Property(str, notify=stateChanged)
    def screenState(self):
        return self._state

    @Property(str, notify=stateChanged)
    def teamLabel(self):
        return self._team_label

    @Property(str, notify=stateChanged)
    def teamCode(self):
        return self._team

    @Property(str, notify=stateChanged)
    def teamColor(self):
        return self._team_color

    @Property(str, notify=stateChanged)
    def domeId(self):
        return self._dome_id

    @Property(int, notify=countdownChanged)
    def countdownSeconds(self):
        return int(self._countdown)

    @Property(bool, notify=stateChanged)
    def selectionEnabled(self):
        return self._state == "selection"

    @Property(str, notify=choiceChanged)
    def selectedChoice(self):
        return self._selected_choice

    @Property(bool, notify=choiceChanged)
    def autoSelected(self):
        return self._auto_selected

    @Property(str, notify=choiceChanged)
    def infoText(self):
        return self._info_text

    def activate(self, payload: dict):
        self._team = str(payload.get("team") or "").strip().lower()
        team_name = str(payload.get("team_name") or payload.get("teamLabel") or "").strip()
        if not team_name and self._team:
            team_name = TEAM_NAME_OVERRIDES.get(self._team, self._team.upper())
        if not team_name:
            team_name = "Неизвестная команда"
        self._team_label = team_name
        self._team_color = TEAM_COLORS.get(self._team, TEAM_COLORS.get("default", "#5defff"))
        self._dome_id = str(payload.get("dome_id") or payload.get("domeId") or "")
        timeout = payload.get("timeout_sec")
        try:
            timeout = int(timeout)
        except Exception:
            timeout = DEFAULT_TIMEOUT
        if timeout <= 2:
            timeout = DEFAULT_TIMEOUT
        self._timeout_total = timeout
        default_choice = payload.get("default_choice")
        if default_choice in ("keep_ammo", "super_shots"):
            self._default_choice = default_choice
        self._selected_choice = ""
        self._auto_selected = False
        self._countdown = self._timeout_total
        self._info_text = "Выберите награду для команды"
        self._state = "selection"
        self.stateChanged.emit()
        self.choiceChanged.emit()
        self.countdownChanged.emit()
        if not self._timer.isActive():
            self._timer.start()
        log.info("Терминал активирован: team=%s dome=%s timeout=%s", self._team, self._dome_id, timeout)

    def reset_idle(self):
        self._timer.stop()
        self._state = "idle"
        self._team = ""
        self._team_label = ""
        self._selected_choice = ""
        self._info_text = "Ожидание команды"
        self._countdown = 0
        self.stateChanged.emit()
        self.choiceChanged.emit()
        self.countdownChanged.emit()

    def _tick(self):
        if self._state != "selection":
            self._timer.stop()
            return
        self._countdown -= 1
        if self._countdown < 0:
            self._countdown = 0
        self.countdownChanged.emit()
        if self._countdown == 0:
            self._timer.stop()
            self._auto_selected = True
            self.choiceChanged.emit()
            self._select_choice(self._default_choice, auto=True)

    def _publish_choice(self, choice_key: str, auto: bool) -> bool:
        payload = {
            "type": "bonus_choice",
            "terminal_id": self._terminal_id,
            "point_id": ID,
            "dome_id": self._dome_id,
            "team": self._team,
            "choice": choice_key,
            "auto": bool(auto),
            "timestamp": int(time.time()),
        }
        try:
            ok = self._publish_cb(payload)
        except Exception:
            ok = False
        return bool(ok)

    def _select_choice(self, choice_key: str, auto: bool = False):
        if not choice_key:
            return
        if self._state not in ("selection",) and not auto:
            return
        self._timer.stop()
        sent = self._publish_choice(choice_key, auto)
        self._selected_choice = choice_key
        self._state = "locked"
        self._info_text = "Выбор отправлен" if sent else "Ошибка отправки, сообщите инструктору"
        if auto:
            self._info_text = "Выбор по умолчанию отправлен"
        self.choiceChanged.emit()
        self.stateChanged.emit()
        log.info("Выбор сделан: %s (auto=%s, sent=%s)", choice_key, auto, sent)

    @Slot()
    def chooseKeep(self):
        if self._state != "selection":
            return
        self._auto_selected = False
        self._select_choice("keep_ammo", auto=False)

    @Slot()
    def chooseRevenge(self):
        if self._state != "selection":
            return
        self._auto_selected = False
        self._select_choice("super_shots", auto=False)


class TerminalMqttClient:
    def __init__(self, broker, port, event_queue, super_topic: str):
        self._broker = broker
        self._port = port
        self._queue = event_queue
        self._super_topic = super_topic
        self._client = mqtt.Client()
        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message

    def start(self):
        try:
            self._client.connect(self._broker, self._port, 60)
            self._client.loop_start()
        except Exception:
            log.exception("MQTT подключение не удалось")

    def stop(self):
        try:
            self._client.loop_stop()
        except Exception:
            pass
        try:
            self._client.disconnect()
        except Exception:
            pass

    def _on_connect(self, client, userdata, flags, rc):
        log.info("MQTT connected rc=%s", rc)
        try:
            client.subscribe(self._super_topic)
            log.info("Subscribed to %s", self._super_topic)
        except Exception:
            log.exception("Subscribe failed")

    def _parse_payload(self, msg):
        try:
            text = msg.payload.decode("utf-8", errors="ignore")
        except Exception:
            return ""
        try:
            return json.loads(text)
        except Exception:
            return (text or "").strip()

    def _on_message(self, client, userdata, msg):
        payload = self._parse_payload(msg)
        event = {"payload": payload, "topic": msg.topic}
        try:
            self._queue.put_nowait(event)
        except queue.Full:
            log.warning("Очередь переполнена, отбрасываем событие из %s", msg.topic)

    def publish_super(self, payload: dict) -> bool:
        if not payload:
            return False
        try:
            body = json.dumps(payload, ensure_ascii=False)
        except Exception:
            log.exception("Не удалось сериализовать payload")
            return False
        try:
            info = self._client.publish(self._super_topic, body, qos=1, retain=False)
            info.wait_for_publish(timeout=2.0)
            log.info("Опубликовано событие '%s' в %s", body, self._super_topic)
            return True
        except Exception:
            log.exception("Ошибка публикации в %s", self._super_topic)
            return False


def run(terminal_id: str, default_choice: str):
    app = QApplication(sys.argv)
    event_queue = queue.Queue()

    mqtt_client = TerminalMqttClient(BROKER, PORT, event_queue, SUPER_TOPIC)
    mqtt_client.start()

    engine = QQmlApplicationEngine()
    context = engine.rootContext()
    backend = BonusTerminalBackend(terminal_id, mqtt_client.publish_super, default_choice)
    context.setContextProperty("terminalBackend", backend)
    engine.load(QUrl.fromLocalFile(str(QML_TERMINAL)))
    if not engine.rootObjects():
        log.error("Не удалось загрузить QML %s", QML_TERMINAL)
        mqtt_client.stop()
        sys.exit(-1)

    def drain_events():
        while True:
            try:
                event = event_queue.get_nowait()
            except queue.Empty:
                break
            payload = event.get("payload") or {}
            if isinstance(payload, dict) and str(payload.get("type") or "").lower() == "bonus_activate":
                tid = str(payload.get("terminal_id") or payload.get("terminalId") or "").strip()
                if not tid or tid == terminal_id:
                    backend.activate(payload)

    timer = QTimer()
    timer.setInterval(50)
    timer.timeout.connect(drain_events)
    timer.start()

    exit_code = 0
    try:
        exit_code = app.exec()
    finally:
        timer.stop()
        mqtt_client.stop()
    sys.exit(exit_code)


if __name__ == "__main__":
    args = parse_args()
    terminal_id = (args.terminal_id or str(DEFAULT_TERMINAL_ID)).strip() or DEFAULT_TERMINAL_ID
    default_choice = (args.default_choice or str(DEFAULT_CHOICE)).strip() or DEFAULT_CHOICE
    run(terminal_id, default_choice)
