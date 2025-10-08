import sys
from pathlib import Path
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon
from core.backend import Backend
import json

def main():
    app = QApplication(sys.argv)

    icon_path = Path(__file__).parent / "ui" / "images" / "icon.svg"
    app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()

    # Читаем текущий файл
    with open("User_profile", 'r', encoding='utf-8') as f:
        data = json.load(f)
        user_id = data["user_id"]
        print(user_id)

    backend = Backend(engine, user_id)
    engine.rootContext().setContextProperty("Backend", backend)

    qml_path = Path(__file__).parent / "ui" / "App.qml"
    engine.load(QUrl.fromLocalFile(str(qml_path)))

    sys.exit(app.exec())

if __name__ == "__main__":
    main()