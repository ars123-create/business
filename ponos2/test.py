import socket
from config import BROKER
PORT = 1883

s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(3)

try:
    s.connect((BROKER, PORT))
    print(f"✅ Соединение с {BROKER}:{PORT} успешно!")
except socket.timeout:
    print(f"❌ Таймаут подключения к {BROKER}:{PORT}")
except OSError as e:
    print(f"❌ Ошибка подключения: {e}")
finally:
    s.close()