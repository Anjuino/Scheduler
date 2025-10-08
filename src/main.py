import sys
from pathlib import Path
from PySide6.QtWidgets import QApplication
from PySide6.QtQml import QQmlApplicationEngine
from PySide6.QtCore import QUrl
from PySide6.QtGui import QIcon
from core.backend import Backend
import json
import os

def main():
    print("Файлы в директории:", os.listdir('.'))
    print("Текущая директория:", os.getcwd())
    app = QApplication(sys.argv)

    icon_path = Path(__file__).parent / "ui" / "images" / "icon.svg"
    app.setWindowIcon(QIcon(str(icon_path)))

    engine = QQmlApplicationEngine()

    try:
        # Читаем текущий файл
        current_dir = os.path.dirname(os.path.abspath(__file__))
        user_profile_path = os.path.join(current_dir, 'User_profile')
        with open(user_profile_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
            user_id = data["user_id"]
            isglobal = data["isGlobal"]

        backend = Backend(engine, user_id, isglobal)
        engine.rootContext().setContextProperty("Backend", backend)

        qml_path = Path(__file__).parent / "ui" / "App.qml"
        engine.load(QUrl.fromLocalFile(str(qml_path)))

        sys.exit(app.exec())

    except FileNotFoundError:
        print("ОШИБКА: Файл User_profile не найден!")
        sys.exit(1)
    except KeyError as e:
        print(f"ОШИБКА: В файле User_profile отсутствует ключ: {e}")
        sys.exit(1)
    except json.JSONDecodeError:
        print("ОШИБКА: Файл User_profile поврежден!")
        sys.exit(1)
    except Exception as e:
        print(f"ОШИБКА: {e}")
        sys.exit(1)

if __name__ == "__main__":
    main()