# app.py
import paho.mqtt.client as mqtt
import queue
import sys
import time
import os
import subprocess
import signal
import platform
import config as _cfg
from config import ID, BROKER, PORT
from mode_registry import ModeRegistry, ModeConfig

#BROKER = "192.168.1.75"
#PORT = 1883
#ID = "01"


TOPIC_MODE = f"arena/point/{ID}/mode"
SUPER_TOPIC = "arena/supertopic"
TOPICS = [
    TOPIC_MODE,
    f"arena/point/{ID}/action",
    f"arena/point/{ID}/status",
    f"arena/point/{ID}/event",
    f"arena/point/{ID}/heartbeat",
    f"arena/point/{ID}/hit",
    f"arena/point/{ID}/time",
    SUPER_TOPIC,
]

# подписки для режима «Купол», если в config.py указаны идентификаторы
_extra_topics = []
_dome_id = getattr(_cfg, "DOME_ID", None)
_terminal_id = getattr(_cfg, "DOME_TERMINAL_ID", None)
if _dome_id:
    _extra_topics.append(f"arena/dome/{_dome_id}/state")
if _terminal_id:
    _extra_topics.append(f"arena/dome/bonus/{_terminal_id}/activate")
    _extra_topics.append(f"arena/dome/bonus/{_terminal_id}/choice")

TOPICS.extend(_extra_topics)

# очередь команд из MQTT — чтение из неё будет в главном потоке
cmd_queue = queue.Queue()

# Словарь запущенных дочерних процессов: name -> Popen
processes = {}
registry = ModeRegistry()

def on_connect(client, userdata, flags, rc):
    print("✅ Подключено к брокеру, код:", rc)
    if rc != 0:
        print("⚠️ Код подключения не нулевой, возможно ошибка.")
    for t in TOPICS:
        client.subscribe(t)
        print("📡 Подписка на", t)

def on_message(client, userdata, msg):
    topic = msg.topic
    payload = msg.payload.decode(errors="ignore")
    print("📩 Получено сообщение:", topic, "→", payload)

    if topic == TOPIC_MODE:
        cmd_queue.put(payload)

def _is_alive(proc: subprocess.Popen) -> bool:
    return proc and (proc.poll() is None)

def _graceful_terminate(proc: subprocess.Popen, name: str, timeout1=2, timeout2=2):
    """Пытаемся корректно завершить proc:
       1) send SIGINT (posix) или try terminate (windows),
       2) wait timeout1,
       3) proc.terminate(), wait timeout2,
       4) proc.kill() если всё ещё жив.
    """
    if proc is None:
        return

    if proc.poll() is not None:
        print(f"ℹ️ Процесс {name} уже завершился с кодом {proc.returncode}.")
        return

    print(f"⏳ Попытка корректно завершить процесс {name} (pid={proc.pid})...")

    try:
        if platform.system() != "Windows":
            # сначала посылаем SIGINT (как если бы нажали Ctrl+C)
            try:
                proc.send_signal(signal.SIGINT)
                print(f"🟡 Отправлен SIGINT процессу {name}.")
            except Exception as e:
                print("⚠️ Не удалось отправить SIGINT:", e)
        else:
            # на Windows SIGINT может не сработать для дочернего процесса — будем пробовать terminate ниже
            print("ℹ️ Windows: пропускаем SIGINT (будет использован terminate).")
    except Exception as e:
        print("⚠️ Ошибка при попытке послать сигнал:", e)

    # ждём коротко
    try:
        proc.wait(timeout=timeout1)
        print(f"✅ Процесс {name} завершился после SIGINT с кодом {proc.returncode}.")
        return
    except subprocess.TimeoutExpired:
        print(f"⌛ Процесс {name} не завершился после SIGINT, пробуем terminate()...")

    # затем terminate()
    try:
        proc.terminate()
        print(f"🟠 Отправлен terminate() процессу {name}.")
    except Exception as e:
        print("⚠️ Ошибка при terminate():", e)

    try:
        proc.wait(timeout=timeout2)
        print(f"✅ Процесс {name} корректно завершился после terminate() с кодом {proc.returncode}.")
        return
    except subprocess.TimeoutExpired:
        print(f"❗ Процесс {name} не завершился после terminate(), выполняю kill().")

    # финальный шаг: kill
    try:
        proc.kill()
        proc.wait(timeout=1)
        print(f"🔥 Процесс {name} принудительно убит (kill).")
    except Exception as e:
        print("⚠️ Не удалось убить процесс:", e)

def stop_all_processes(except_name: str | None = None):
    """Завершить все дочерние процессы, кроме опционально указанного."""
    global processes
    names = list(processes.keys())
    for name in names:
        if except_name is not None and name == except_name:
            # если хотим сохранить конкретный процесс, проверим жив ли он — если нет, удалим из словаря
            proc = processes.get(name)
            if not _is_alive(proc):
                processes.pop(name, None)
            else:
                print(f"🔒 Оставляем процесс {name} (pid={proc.pid})")
            continue

        proc = processes.get(name)
        if proc is None:
            processes.pop(name, None)
            continue
        _graceful_terminate(proc, name)
        # очистим запись
        processes.pop(name, None)

def start_mode(mode_id: str):
    """Запуск режима из реестра manifest'ов."""
    mode: ModeConfig | None = registry.get(mode_id)
    if mode is None:
        print(f"❌ Режим '{mode_id}' не найден в каталоге modes/")
        return

    # Закрываем ВСЕ другие перед стартом
    stop_all_processes(except_name=None)

    cmd = [sys.executable, str(mode.entry)] + list(mode.args)
    pretty_cmd = " ".join(cmd)
    print(f"🚀 Запуск режима {mode.name} ({mode_id}): {pretty_cmd}")
    try:
        proc = subprocess.Popen(cmd, cwd=str(mode.workdir))
        processes[mode_id] = proc
        print(f"🟢 Процесс {mode_id} запущен (pid={proc.pid}).")
    except Exception as e:
        print("❌ Не удалось запустить процесс:", e)

def main():
    client = mqtt.Client()
    client.on_connect = on_connect
    client.on_message = on_message

    try:
        client.connect(BROKER, PORT, 60)
    except Exception as e:
        print("❌ Не удалось подключиться к брокеру MQTT:", e)
        return

    client.loop_start()

    print("⏳ Контроллер запущен. Ожидание команд (mode). Ctrl+C — выход.")

    try:
        while True:
            try:
                cmd = cmd_queue.get(timeout=1)  # ждём команду 1 сек
            except queue.Empty:
                # при пустой очереди можно проверять живость процессов и очищать завершённые
                # удаляем из словаря процессы, которые умерли
                for n, p in list(processes.items()):
                    if not _is_alive(p):
                        print(f"ℹ️ Процесс {n} завершился самостоятельно с кодом {p.returncode}, удаляю из списка.")
                        processes.pop(n, None)
                continue

            cmd = cmd.strip()
            if not cmd:
                continue

            print("▶ Получена команда:", cmd)

            if cmd in registry:
                start_mode(cmd)
            else:
                print("Неизвестная команда:", cmd)

    except KeyboardInterrupt:
        print("\n🛑 Остановка контроллера по Ctrl+C")
    finally:
        # корректно завершить все дочерние процессы перед выходом
        print("🏁 Завершаю все дочерние процессы...")
        stop_all_processes(except_name=None)

        # остановим MQTT loop перед disconnect
        try:
            client.loop_stop()
        except Exception as e:
            print("⚠️ Ошибка при остановке loop:", e)
        try:
            client.disconnect()
        except Exception as e:
            print("⚠️ Ошибка при отключении от брокера:", e)
        print("✅ MQTT отключён. Выход.")

if __name__ == "__main__":
    main()
