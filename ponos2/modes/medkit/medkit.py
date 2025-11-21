import sys
import time
import multiprocessing
from pathlib import Path

import paho.mqtt.client as mqtt
from PySide6.QtCore import QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import ID, BROKER, PORT, USER

ASSET_BG = str(PROJECT_ROOT / "assets" / "medkit.jpg")
MODE_DIR = Path(__file__).resolve().parent

# --- Функция отправки MQTT-сообщения в отдельном процессе ---
def send_message_proc(s: str = "heal"):
    TOPIC = f"arena/point/{ID}/action"
    client = mqtt.Client()
    try:
        client.connect(BROKER, PORT, 60)
        client.loop_start()
        client.publish(TOPIC, s)
        time.sleep(0.05)  # минимальная пауза
    finally:
        try:
            client.loop_stop()
            client.disconnect()
        except Exception:
            pass

def send_message_async(s="heal"):
    p = multiprocessing.Process(target=send_message_proc, args=(s,))
    p.start()
    p.join(0.01)  # не блокируем интерфейс

if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()
    engine.rootContext().setContextProperty("backgroundPath", ASSET_BG)
    engine.rootContext().setContextProperty("USER", USER)

    qml_file = MODE_DIR / "medkit.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Ошибка загрузки QML")
        sys.exit(-1)

    root = engine.rootObjects()[0]

    # --- Подключение сигнала ---
    def on_medkit_click():
        # Анимация через QML
        if hasattr(root, "animateMedkit"):
            root.animateMedkit()
        send_message_async()  # отправка в отдельном процессе

    try:
        root.medkitActivated.connect(on_medkit_click)
    except Exception as e:
        print("Не удалось подключиться к сигналу medkitActivated:", e)

    sys.exit(app.exec())
