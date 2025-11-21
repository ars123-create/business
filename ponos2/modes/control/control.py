# control_fast_switch.py
import sys
import time
import logging
import multiprocessing as mp
from pathlib import Path
from collections import deque
import threading
from queue import Empty

import paho.mqtt.client as mqtt

from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QTimer, QObject, Signal

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

# --- Логи ---
logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
log = logging.getLogger("control_fast")

# --- Конфиг: ожидается config.py с ID, BROKER, PORT и опционально Game_time/GAME_TIME ---
try:
    import config as _cfg
    ID = getattr(_cfg, "ID")
    BROKER = getattr(_cfg, "BROKER")
    PORT = getattr(_cfg, "PORT")
    # поддерживаем разные имена
    if hasattr(_cfg, "Game_time"):
        GAME_TIME = int(getattr(_cfg, "Game_time"))
    elif hasattr(_cfg, "GAME_TIME"):
        GAME_TIME = int(getattr(_cfg, "GAME_TIME"))
    else:
        GAME_TIME = 10
except Exception as e:
    raise RuntimeError("Не найден config.py с переменными ID, BROKER, PORT (опционально Game_time/GAME_TIME)") from e

CURRENT_GAME_TIME = GAME_TIME

# QML paths
ASSET_BG = str(PROJECT_ROOT / "assets" / "medkit.jpg")
QML_FILE = Path(__file__).resolve().parent / "control.qml"
HIT_TOPIC = f"arena/point/{ID}/hit"
TIME_TOPIC = f"arena/point/{ID}/time"
ACTION_TOPIC = f"arena/point/{ID}/action"
SUPER_TOPIC = "arena/supertopic"


class QueueNotifier(QObject):
    messageReady = Signal()

# --- MQTT worker (в отдельном процессе) ---
def mqtt_worker(broker, port, hit_topic, time_topic, out_queue, stop_event):
    logging.basicConfig(level=logging.WARNING, format="%(asctime)s | %(levelname)s | %(message)s")
    lw = logging.getLogger("mqtt_worker")
    client = mqtt.Client()

    def on_connect(client, userdata, flags, rc):
        lw.warning("MQTT connected rc=%s", rc)
        try:
            subs = []
            if hit_topic:
                subs.append((hit_topic, 0))
            if time_topic and time_topic != hit_topic:
                subs.append((time_topic, 0))
            if subs:
                client.subscribe(subs)
                lw.warning("Subscribed to %s", ", ".join(t for t, _ in subs))
        except Exception:
            lw.exception("Subscribe failed")

    def on_message(client, userdata, msg):
        topic = getattr(msg, "topic", "")
        try:
            payload = msg.payload.decode(errors="ignore").strip().lower()
        except Exception:
            payload = ""
        if hit_topic and topic == hit_topic:
            if payload in ("red", "blue"):
                try:
                    out_queue.put_nowait({"kind": "hit", "value": payload})
                except Exception:
                    pass
        elif time_topic and topic == time_topic:
            try:
                seconds = int(payload)
            except ValueError:
                lw.warning("Invalid time payload '%s'", payload)
                return
            if seconds <= 0:
                lw.warning("Non-positive time payload '%s'", payload)
                return
            try:
                out_queue.put_nowait({"kind": "time", "value": seconds})
            except Exception:
                pass

    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(broker, port, keepalive=60)
        client.loop_start()
    except Exception:
        connected = False
    else:
        connected = True

    try:
        while not stop_event.is_set():
            if not connected:
                try:
                    client.reconnect()
                    client.loop_start()
                    connected = True
                except Exception:
                    time.sleep(1.0)
                    continue
            time.sleep(0.05)
    finally:
        try:
            client.loop_stop()
            client.disconnect()
        except Exception:
            pass


class TopicPublisher:
    """Minimal helper that keeps a lightweight MQTT connection for publishing arena events."""

    def __init__(self, broker, port, topic):
        self._broker = broker
        self._port = port
        self._topic = topic
        self._client = None
        self._loop_started = False
        self._connect_client()

    def _connect_client(self):
        self.close()
        client = mqtt.Client()
        try:
            result = client.connect(self._broker, self._port, keepalive=30)
            if result != 0:
                log.error("Код подключения к %s: %s", self._topic, result)
                return
            client.loop_start()
        except Exception:
            log.exception("Не удалось подключиться к брокеру для публикации в %s", self._topic)
            return
        self._client = client
        self._loop_started = True
        log.info("Публикация в %s готова", self._topic)

    def publish(self, payload: str):
        if not payload:
            return
        if self._client is None:
            self._connect_client()
            if self._client is None:
                return
        try:
            self._client.publish(self._topic, payload, qos=1, retain=False)
            log.info("Отправлено '%s' в %s", payload, self._topic)
        except Exception:
            log.exception("Не удалось отправить '%s' в %s", payload, self._topic)
            self._connect_client()

    def close(self):
        if self._client is None:
            return
        try:
            if self._loop_started:
                self._client.loop_stop()
            self._client.disconnect()
        except Exception:
            pass
        finally:
            self._client = None
            self._loop_started = False

def read_int_prop_safe(qobj, name):
    try:
        v = qobj.property(name)
        if v is None:
            return 0
        return int(v)
    except Exception:
        return 0

def read_str_prop_safe(qobj, name):
    try:
        v = qobj.property(name)
        if v is None:
            return ""
        return str(v)
    except Exception:
        return ""

def is_game_finished(root):
    blue = read_int_prop_safe(root, "blueRemaining")
    red = read_int_prop_safe(root, "redRemaining")
    return (blue == 0 and red == 0)

def _apply_round_time_to_root(root, seconds):
    if root is None:
        return
    try:
        value = int(max(1, seconds))
    except Exception:
        return
    try:
        root.setProperty("defaultRoundTime", value)
        log.info("QML defaultRoundTime set to %s", value)
    except Exception:
        log.exception("Не удалось установить defaultRoundTime в QML")


def process_message_batch(root, messages):
    global CURRENT_GAME_TIME
    last_hit = None
    updated_time = None
    for msg in messages:
        if isinstance(msg, dict):
            kind = msg.get("kind")
            if kind == "hit":
                value = (msg.get("value") or "").strip().lower()
                if value in ("red", "blue"):
                    last_hit = value
            elif kind == "time":
                try:
                    seconds = int(msg.get("value"))
                except (TypeError, ValueError):
                    continue
                if seconds > 0:
                    CURRENT_GAME_TIME = seconds
                    updated_time = seconds
        else:
            # backward compatibility: plain string hit
            value = (str(msg or "")).strip().lower()
            if value in ("red", "blue"):
                last_hit = value

    if updated_time is not None:
        log.info("Обновлено время раунда с MQTT: %s c", updated_time)
        _apply_round_time_to_root(root, updated_time)
    if last_hit is None:
        return

    if root is None:
        return

    if is_game_finished(root):
        log.info("Game finished — ignoring incoming '%s'", last_hit)
        return
    # если хотя бы один таймер обнулён — не реагируем
    blue_remaining = read_int_prop_safe(root, "blueRemaining")
    red_remaining = read_int_prop_safe(root, "redRemaining")
    if blue_remaining == 0 or red_remaining == 0:
        log.info("⏹ Один из таймеров = 0, игнорируем '%s'", last_hit)
        return

    try:
        primary = read_str_prop_safe(root, "primaryColor")
        state_blue = read_str_prop_safe(root, "stateBlue")
        state_red = read_str_prop_safe(root, "stateRed")
        blue_remaining = read_int_prop_safe(root, "blueRemaining")
        red_remaining = read_int_prop_safe(root, "redRemaining")
    except Exception:
        primary = state_blue = state_red = ""
        blue_remaining = red_remaining = 0

    same_active = False
    if last_hit == "blue" and primary == state_blue and blue_remaining > 0:
        same_active = True
    if last_hit == "red" and primary == state_red and red_remaining > 0:
        same_active = True

    if same_active:
        log.debug("Message %s ignored because same color already active with remaining > 0", last_hit)
        return

    try:
        if hasattr(root, "changeCircleState"):
            root.changeCircleState(last_hit)
    except Exception:
        log.exception("changeCircleState failed")

    try:
        delay_ms = 10
        def start_timer():
            try:
                if hasattr(root, "startTimerForActive"):
                    root.startTimerForActive(int(CURRENT_GAME_TIME))
            except Exception:
                log.exception("startTimerForActive failed")
        QTimer.singleShot(delay_ms, start_timer)
    except Exception:
        try:
            root.startTimerForActive(int(CURRENT_GAME_TIME))
        except Exception:
            log.exception("startTimerForActive direct failed")

def main():
    try:
        mp.set_start_method("spawn")
    except RuntimeError:
        pass

    mp_queue = mp.Queue()
    stop_event = mp.Event()
    super_topic_publisher = None
    action_publisher = None

    mqtt_proc = mp.Process(target=mqtt_worker, args=(BROKER, PORT, HIT_TOPIC, TIME_TOPIC, mp_queue, stop_event), daemon=True)
    mqtt_proc.start()
    log.info("Started mqtt process pid=%s", mqtt_proc.pid)

    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backgroundPath", ASSET_BG)
    engine.load(str(QML_FILE))
    if not engine.rootObjects():
        log.error("Failed to load QML: %s", QML_FILE)
        stop_event.set()
        mqtt_proc.join(timeout=2.0)
        if mqtt_proc.is_alive():
            mqtt_proc.terminate()
        sys.exit(-1)

    root = engine.rootObjects()[0]
    log.info("QML loaded")

    try:
        if hasattr(root, "changeCircleState"):
            root.changeCircleState("white")
    except Exception:
        pass

    _apply_round_time_to_root(root, CURRENT_GAME_TIME)

    super_topic_publisher = TopicPublisher(BROKER, PORT, SUPER_TOPIC)
    action_publisher = TopicPublisher(BROKER, PORT, ACTION_TOPIC)

    def handle_point_capture(team):
        team_value = (team or "").strip().lower()
        if team_value not in ("red", "blue"):
            log.warning("Получено неизвестное имя команды '%s' для публикации победы", team)
            return
        payload = f"{team_value}_team_point_{ID}"
        super_topic_publisher.publish(payload)

    if hasattr(root, "pointCaptured"):
        try:
            root.pointCaptured.connect(handle_point_capture)
        except Exception:
            log.exception("Не удалось подключиться к сигналу pointCaptured")
    else:
        log.warning("pointCaptured сигнал не найден в QML — публикации захвата точки не будут отправляться")

    def handle_game_finished(team):
        team_value = (team or "").strip().lower()
        if team_value not in ("red", "blue"):
            team_value = "unknown"
        payload = f"game_finished_{team_value}_point_{ID}"
        action_publisher.publish(payload)

    if hasattr(root, "gameFinished"):
        try:
            root.gameFinished.connect(handle_game_finished)
        except Exception:
            log.exception("Не удалось подключиться к сигналу gameFinished")
    else:
        log.warning("gameFinished сигнал не найден в QML — публикации окончания игры не будут отправляться")

    pending_messages = deque()
    pending_lock = threading.Lock()
    queue_notifier = QueueNotifier()

    def drain_pending():
        batch = []
        with pending_lock:
            while pending_messages:
                batch.append(pending_messages.popleft())
        if batch:
            process_message_batch(root, batch)

    queue_notifier.messageReady.connect(drain_pending)

    queue_thread_stop = threading.Event()

    def forward_mp_queue():
        while not queue_thread_stop.is_set():
            try:
                msg = mp_queue.get(timeout=0.25)
            except Empty:
                continue
            except (EOFError, OSError):
                if queue_thread_stop.is_set():
                    break
                continue
            with pending_lock:
                pending_messages.append(msg)
            queue_notifier.messageReady.emit()

    queue_thread = threading.Thread(target=forward_mp_queue, name="mp-queue-forwarder", daemon=True)
    queue_thread.start()

    try:
        exit_code = app.exec()
    finally:
        queue_thread_stop.set()
        queue_thread.join(timeout=1.0)
        stop_event.set()
        mqtt_proc.join(timeout=2.0)
        if mqtt_proc.is_alive():
            mqtt_proc.terminate()
        if super_topic_publisher is not None:
            super_topic_publisher.close()
        if action_publisher is not None:
            action_publisher.close()
        log.info("Shutdown complete")
    sys.exit(exit_code)

if __name__ == "__main__":
    main()
