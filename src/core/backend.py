from PySide6 import QtCore
from PySide6.QtCore import QObject, Slot, Signal
from datetime import datetime
import os
import json


class Backend(QObject):
    def __init__(self, qml_engine):
        super().__init__()
        self.qml_engine = qml_engine

    def call_qml_function(self, function_name, *args):
        if not self.qml_engine.rootObjects():
            # QML еще не загружен, ждем
            QtCore.QTimer.singleShot(100, lambda: self.call_qml_function(function_name, *args))
            return

        root_object = self.qml_engine.rootObjects()[0]
        if hasattr(root_object, function_name):
            getattr(root_object, function_name)(*args)

    def log_app(self, data):
        self.call_qml_function("log_app", data)

    @Slot(result=list)
    def get_list_weeks(self):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", str(datetime.now().year))

            files = [f for f in os.listdir(year_dir)
                     if os.path.isfile(os.path.join(year_dir, f))]

            return sorted(files)

        except Exception as e:
            print(f"Ошибка: {e}")
            return []

    @Slot(str)
    def read_file(self, file):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", str(datetime.now().year))
            filename = os.path.join(year_dir, file)

            print(f"Чтение файла: {filename}")

            with open(filename, 'r', encoding='utf-8') as f:
                content = f.read()

            # Валидируем JSON
            json.loads(content)

            # Передаем данные в QML для отображения
            self.call_qml_function("update_week_data", content)

        except Exception as e:
            print(f"Ошибка чтения файла {file}: {e}")
            self.call_qml_function("print_data", f"Ошибка: {e}")

    @Slot(str)
    def log(self, message):
        print(f"Front: {message}")