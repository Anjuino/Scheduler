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

    @Slot(str)
    def copy_to_next_week(self, current_week):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", str(datetime.now().year))

            # Вычисляем следующую неделю
            next_week = str(int(current_week) + 1)
            if int(next_week) > 53:
                next_week = "1"

            source_file = os.path.join(year_dir, current_week)
            target_file = os.path.join(year_dir, next_week)

            print(f"Копирование задач из недели {current_week} → {next_week}")

            # Читаем текущую неделю (откуда берем задачи)
            with open(source_file, 'r', encoding='utf-8') as f:
                source_data = json.load(f)

            # Читаем следующую неделю (куда копируем задачи)
            with open(target_file, 'r', encoding='utf-8') as f:
                target_data = json.load(f)

            # Копируем задачи из каждого дня текущей недели в следующую неделю
            for i in range(7):
                target_data["days"][i]["tasks"] = source_data["days"][i]["tasks"].copy()

            # Сохраняем следующую неделю с новыми задачами
            with open(target_file, 'w', encoding='utf-8') as f:
                json.dump(target_data, f, ensure_ascii=False, indent=2)

            # Отправляем успех в QML
            self.call_qml_function("show_copy_result", f"Задачи успешно перенесены на следующую неделю")

        except Exception as e:
            error_msg = f"Ошибка копирования: {str(e)}"
            print(error_msg)
            # Отправляем ошибку в QML
            self.call_qml_function("show_copy_result", error_msg)

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

    @Slot(str, int, str)
    def save_day_data(self, week_number, day_index, day_json):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", str(datetime.now().year))

            filename = os.path.join(year_dir, week_number)

            print(f"Обновление дня {day_index} в файле: {filename}")

            # Читаем текущий файл
            with open(filename, 'r', encoding='utf-8') as f:
                week_data = json.load(f)

            # Обновляем только нужный день
            new_day_data = json.loads(day_json)
            week_data["days"][day_index] = new_day_data

            # Сохраняем обратно
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(week_data, f, ensure_ascii=False, indent=2)

            print(f"День {day_index} успешно обновлен")

        except Exception as e:
            print(f"Ошибка сохранения дня {day_index}: {e}")

    @Slot(str)
    def log(self, message):
        print(f"Front: {message}")