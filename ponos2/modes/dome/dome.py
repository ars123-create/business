import argparse
import json
import logging
import queue
import sys
import threading
import time
from pathlib import Path

import paho.mqtt.client as mqtt
from PySide6.QtCore import QObject, Property, QTimer, QUrl, Signal
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtWidgets import QApplication

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

try:
    import config as _cfg
except Exception as exc:  # pragma: no cover - config is mandatory on device
    raise RuntimeError("config.py с параметрами BROKER/PORT/ID обязателен для режима Купол") from exc

ID = getattr(_cfg, "ID")
BROKER = getattr(_cfg, "BROKER")
PORT = getattr(_cfg, "PORT")
DEFAULT_DOME_ID = getattr(_cfg, "DOME_ID", f"DOME_{ID}")
TEAM_NAME_OVERRIDES = getattr(_cfg, "DOME_TEAM_NAMES", {}) or {}
TEAM_COLORS = getattr(_cfg, "DOME_TEAM_COLORS", {}) or {}

MODE_DIR = Path(__file__).resolve().parent
QML_DISPLAY = MODE_DIR / "dome_display.qml"
DEFAULT_HP_MAX = int(getattr(_cfg, "DOME_HP_MAX", 1000))
HIT_DAMAGE = max(1, int(getattr(_cfg, "DOME_HIT_DAMAGE", 100)))
SUPER_TOPIC = "arena/supertopic"

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger("dome")


def parse_args():
    parser = argparse.ArgumentParser(description="Купол: дисплей состояния")
    parser.add_argument("--dome-id", help="идентификатор купола (для дисплея)")
    return parser.parse_args()


class DomeDisplayBackend(QObject):
    stateChanged = Signal()
    hpChanged = Signal()
    teamChanged = Signal()
    updateChanged = Signal()

    def __init__(self, dome_id: str, initial_hp: int):
        super().__init__()
        self._dome_id = dome_id
        self._hp_current = max(0, int(initial_hp))
        self._hp_max = max(1, int(initial_hp))
        self._hp_percent = 1.0 if self._hp_max else 0.0
        self._phase = 1
        self._state = "inactive"
        self._status = "Ожидание запуска"
        self._team_destroyer = ""
        self._team_label = ""
        self._team_color = TEAM_COLORS.get("default", "#5defff")
        self._last_update = "--"
        self._destroyed_animation_tag = 0
        self._team_damage = {}

    @Property(str, notify=stateChanged)
    def domeId(self):
        return self._dome_id

    @Property(int, notify=hpChanged)
    def hpCurrent(self):
        return int(self._hp_current)

    @Property(int, notify=hpChanged)
    def hpMax(self):
        return int(self._hp_max)

    @Property(float, notify=hpChanged)
    def hpPercent(self):
        return float(self._hp_percent)

    @Property(int, notify=stateChanged)
    def phaseIndex(self):
        return int(self._phase)

    @Property(str, notify=stateChanged)
    def viewState(self):
        return self._state

    @Property(str, notify=stateChanged)
    def statusText(self):
        return self._status

    @Property(str, notify=teamChanged)
    def destroyerName(self):
        return self._team_label

    @Property(str, notify=teamChanged)
    def destroyerCode(self):
        return self._team_destroyer

    @Property(str, notify=teamChanged)
    def destroyerColor(self):
        return self._team_color

    @Property(str, notify=updateChanged)
    def lastUpdateText(self):
        return self._last_update

    @Property(int, notify=stateChanged)
    def destroyedAnimationToken(self):
        return self._destroyed_animation_tag

    def reset_hp(self, hp_max: int | None = None):
        hp_value = max(1, int(hp_max if hp_max is not None else self._hp_max))
        self._team_damage.clear()
        self.apply_state({"hp_max": hp_value, "hp_current": hp_value, "state": "ACTIVE"})

    def apply_hit(self, team_code: str, damage: int):
        """Уменьшаем HP локально при получении MQTT-hit. Возвращает True, если купол разрушен именно этим попаданием."""
        if not damage or damage <= 0:
            return False, ""
        destroyed_before = (self._state == "destroyed")
        new_hp = max(0, int(self._hp_current) - int(damage))
        payload = {
            "hp_current": new_hp,
            "hp_max": self._hp_max,
        }
        team_code = (team_code or "").strip().lower()
        if team_code:
            self._team_damage[team_code] = self._team_damage.get(team_code, 0) + int(damage)

        winner_team = team_code
        if self._team_damage:
            winner_team = max(self._team_damage.items(), key=lambda kv: kv[1])[0]

        if new_hp <= 0:
            payload["state"] = "DESTROYED"
            payload["team_destroyer"] = winner_team
            team_label = TEAM_NAME_OVERRIDES.get(winner_team, winner_team.upper() if winner_team else "")
            if team_label:
                payload["team_name"] = team_label
        self.apply_state(payload)
        destroyed_now = new_hp <= 0 and not destroyed_before
        return destroyed_now, winner_team if destroyed_now else ""

    def _phase_from_ratio(self, ratio: float) -> int:
        if ratio >= 0.6:
            return 1
        if ratio >= 0.3:
            return 2
        if ratio > 0.0:
            return 3
        return 3

    def apply_state(self, payload: dict):
        try:
            hp_max = int(max(1, int(payload.get("hp_max", self._hp_max))))
        except Exception:
            hp_max = max(1, self._hp_max)
        try:
            hp_current = int(max(0, int(payload.get("hp_current", self._hp_current))))
        except Exception:
            hp_current = max(0, min(hp_max, self._hp_current))

        ratio = max(0.0, min(1.0, hp_current / float(hp_max)))
        phase = payload.get("phase")
        try:
            phase = int(phase)
        except Exception:
            phase = self._phase_from_ratio(ratio)

        state_raw = str(payload.get("state", "ACTIVE")) or "ACTIVE"
        state = state_raw.strip().lower()
        mapped_state = {
            "inactive": "inactive",
            "active": f"phase{phase}",
            "active_phase_1": "phase1",
            "active_phase_2": "phase2",
            "active_phase_3": "phase3",
            "destroyed": "destroyed",
        }.get(state, f"phase{phase}")

        status_text = payload.get("status_text")
        if not status_text:
            if mapped_state == "inactive":
                status_text = "Купол ждёт активации"
            elif mapped_state == "destroyed":
                status_text = "Купол разрушен. Аптечки отключены."
            else:
                status_text = {
                    "phase1": "Щит стабилен",
                    "phase2": "Щит трещит",
                    "phase3": "Щит критически нестабилен",
                }.get(mapped_state, "Купол активен")

        destroyer = str(payload.get("team_destroyer") or "").strip()
        destroyer_label = str(payload.get("team_name") or payload.get("team_destroyer_name") or "").strip()
        if not destroyer_label and destroyer:
            destroyer_label = str(TEAM_NAME_OVERRIDES.get(destroyer.lower(), destroyer.upper()))
        team_color = TEAM_COLORS.get(destroyer.lower(), TEAM_COLORS.get("default", "#f45b69"))

        changed_hp = hp_current != self._hp_current or hp_max != self._hp_max or abs(ratio - self._hp_percent) > 0.0005
        changed_state = mapped_state != self._state or phase != self._phase or status_text != self._status
        changed_team = destroyer != self._team_destroyer or destroyer_label != self._team_label or team_color != self._team_color

        self._hp_current = hp_current
        self._hp_max = hp_max
        self._hp_percent = ratio
        self._phase = phase
        self._state = mapped_state
        self._status = status_text
        self._team_destroyer = destroyer
        self._team_label = destroyer_label
        self._team_color = team_color
        self._last_update = time.strftime("%H:%M:%S")

        if mapped_state == "destroyed":
            self._destroyed_animation_tag += 1

        if changed_hp:
            self.hpChanged.emit()
        if changed_state:
            self.stateChanged.emit()
        if changed_team:
            self.teamChanged.emit()
        self.updateChanged.emit()


class DomeMqttClient:
    def __init__(self, broker, port, topic_map, event_queue, super_topic=None):
        self._broker = broker
        self._port = port
        self._topic_map = {k: v for k, v in (topic_map or {}).items() if k}
        self._queue = event_queue
        self._super_topic = super_topic
        self._client = mqtt.Client()
        self._client.on_connect = self._on_connect
        self._client.on_message = self._on_message
        self._connected = threading.Event()
        self._lock = threading.Lock()

    def start(self):
        try:
            self._client.connect(self._broker, self._port, 60)
        except Exception:
            log.exception("MQTT подключение не удалось")
        try:
            self._client.loop_start()
        except Exception:
            log.exception("Не удалось запустить loop_start")

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
        if not self._topic_map:
            return
        subs = [(topic, 0) for topic in self._topic_map]
        try:
            client.subscribe(subs)
            log.info("Subscribed to %s", ", ".join(self._topic_map.keys()))
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
        kind = self._topic_map.get(msg.topic, "raw")
        payload = self._parse_payload(msg)
        event = {"kind": kind, "payload": payload, "topic": msg.topic}
        try:
            self._queue.put_nowait(event)
        except queue.Full:
            log.warning("Очередь переполнена, отбрасываем событие %s", kind)

    def publish_super(self, payload: str) -> bool:
        if not self._super_topic or not payload:
            return False
        try:
            info = self._client.publish(self._super_topic, payload, qos=1, retain=False)
            info.wait_for_publish(timeout=2.0)
            log.info("Опубликовано событие '%s' в %s", payload, self._super_topic)
            return True
        except Exception:
            log.exception("Не удалось опубликовать '%s' в %s", payload, self._super_topic)
            return False


def run(dome_id: str):
    app = QApplication(sys.argv)
    event_queue = queue.Queue()

    topic_map = {}
    hit_topic = f"arena/point/{ID}/hit"
    state_topic = f"arena/dome/{dome_id}/state"
    topic_map[state_topic] = "dome_state"
    topic_map[hit_topic] = "hit"

    mqtt_client = DomeMqttClient(BROKER, PORT, topic_map, event_queue, super_topic=SUPER_TOPIC)
    mqtt_client.start()

    engine = QQmlApplicationEngine()
    context = engine.rootContext()

    backend = DomeDisplayBackend(dome_id, DEFAULT_HP_MAX)
    backend.reset_hp(DEFAULT_HP_MAX)
    context.setContextProperty("domeBackend", backend)
    qml_file = QML_DISPLAY

    engine.load(QUrl.fromLocalFile(str(qml_file)))
    if not engine.rootObjects():
        log.error("Не удалось загрузить QML %s", qml_file)
        mqtt_client.stop()
        sys.exit(-1)

    def drain_events():
        while True:
            try:
                event = event_queue.get_nowait()
            except queue.Empty:
                break
            payload = event.get("payload") or {}
            kind = event.get("kind")
            if kind == "dome_state":
                backend.apply_state(payload)
            elif kind == "hit":
                team = ""
                if isinstance(payload, str):
                    team = payload.strip().lower()
                elif isinstance(payload, dict):
                    team = str(payload.get("team") or payload.get("value") or payload.get("raw") or "").strip().lower()
                if team:
                    destroyed_now, winner = backend.apply_hit(team, HIT_DAMAGE)
                    if destroyed_now:
                        event_team = winner or team
                        event_payload = f"dome_destroyed_{event_team}_{dome_id}"
                        mqtt_client.publish_super(event_payload)

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
    dome_id = (args.dome_id or str(DEFAULT_DOME_ID)).strip() or DEFAULT_DOME_ID
    run(dome_id)
