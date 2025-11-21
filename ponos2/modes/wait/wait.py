import sys
from pathlib import Path

from PySide6.QtCore import QObject, Signal, Property, QUrl
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine

PROJECT_ROOT = Path(__file__).resolve().parents[2]
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from config import ID, BROKER, PORT  # noqa: F401 - параметры могут пригодиться в QML


# если хочешь, положи сюда своё изображение и используй в QML, сейчас не нужно
ASSET_BG = str(PROJECT_ROOT / "assets" / "medkit.jpg")
MODE_DIR = Path(__file__).resolve().parent

class Backend(QObject):
    IDChanged = Signal()

    def __init__(self, parent=None):
        super().__init__(parent)
        self._id = ID     # начальное значение

    def getID(self) -> str:
        return self._id

    def setID(self, value: str) -> None:
        if value != self._id:
            self._id = value
            self.IDChanged.emit()

    ID = Property(str, getID, setID, notify=IDChanged)

if __name__ == "__main__":
    app = QApplication(sys.argv)
    engine = QQmlApplicationEngine()

    backend = Backend()
    # пример: можно изменить ID перед запуском:
    # backend.setID("student42")

    engine.rootContext().setContextProperty("backend", backend)
    # если позже захочешь, можно пробросить backgroundPath или другие свойства:
    # engine.rootContext().setContextProperty("backgroundPath", ASSET_BG)

    qml_file = MODE_DIR / "wait.qml"
    engine.load(QUrl.fromLocalFile(str(qml_file)))

    if not engine.rootObjects():
        print("Ошибка загрузки QML")
        sys.exit(-1)

    sys.exit(app.exec())
