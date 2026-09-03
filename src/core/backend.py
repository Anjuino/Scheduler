from PySide6 import QtCore
from PySide6.QtCore import QObject, Slot
from .FileUpload import FileUploadThread
from datetime import datetime
import os
import json


class Backend(QObject):
    def __init__(self, qml_engine, user_id, isglobal, currentYear):
        super().__init__()
        self.user_id = user_id
        self.upload_thread = None
        self.qml_engine = qml_engine
        self.isglobal = isglobal
        self.currentYear = str(currentYear)
        # Стек отмены последних действий: список записей
        # {"description": str, "files": [(abs_path, content_or_None), ...]}
        self._undo_stack = []
        self._max_undo = 30
        self._upload_threads = []

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

    def _year_dir(self):
        current_file_dir = os.path.dirname(os.path.abspath(__file__))
        project_root = os.path.dirname(os.path.dirname(current_file_dir))
        return os.path.join(project_root, "Scheduler", self.currentYear)

    def _push_undo(self, description, files):
        """Сохраняет текущее состояние файлов перед изменением для возможности отмены."""
        snapshot = []
        for path in files:
            try:
                with open(path, 'r', encoding='utf-8') as f:
                    snapshot.append((path, f.read()))
            except FileNotFoundError:
                snapshot.append((path, None))
            except Exception as e:
                print(f"Не удалось сохранить состояние для отмены {path}: {e}")
                snapshot.append((path, None))

        self._undo_stack.append({"description": description, "files": snapshot})
        if len(self._undo_stack) > self._max_undo:
            self._undo_stack.pop(0)

    def _upload_file(self, path):
        if not self.isglobal:
            return
        thread = FileUploadThread(self.user_id, path, self.currentYear)
        thread.finished.connect(lambda msg: print(f"Upload: {msg}"))
        thread.error.connect(lambda msg: print(f"Upload error: {msg}"))
        self._upload_threads.append(thread)
        thread.finished.connect(lambda *_: self._upload_threads.remove(thread) if thread in self._upload_threads else None)
        thread.start()

    @Slot(result=bool)
    def can_undo(self):
        return len(self._undo_stack) > 0

    @Slot()
    def undo_last_action(self):
        if not self._undo_stack:
            self.call_qml_function("show_notification", "Нет действий для отмены")
            return

        entry = self._undo_stack.pop()
        try:
            for path, content in entry["files"]:
                if content is None:
                    if os.path.exists(path):
                        os.remove(path)
                else:
                    with open(path, 'w', encoding='utf-8') as f:
                        f.write(content)
                self._upload_file(path)

            self.call_qml_function("show_notification",
                                   f"Отменено: {entry['description']}")
            self.call_qml_function("refresh_current_week")

        except Exception as e:
            error_msg = f"Ошибка отмены: {str(e)}"
            print(error_msg)
            self.call_qml_function("show_notification", error_msg)

    @Slot(str)
    def copy_to_next_week(self, current_week):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", self.currentYear)

            # Вычисляем следующую неделю
            next_week = f"{(int(current_week) + 1):02d}"
            if int(next_week) > 53:
                next_week = "01"

            source_file = os.path.join(year_dir, current_week)
            target_file = os.path.join(year_dir, next_week)

            print(f"Копирование задач из недели {current_week} → {next_week}")

            # Читаем текущую неделю (откуда берем задачи)
            with open(source_file, 'r', encoding='utf-8') as f:
                source_data = json.load(f)

            # Читаем следующую неделю (куда копируем задачи)
            with open(target_file, 'r', encoding='utf-8') as f:
                target_data = json.load(f)

            # Сохраняем состояние следующей недели для возможности отмены
            self._push_undo(f"перенос недели {current_week} → {next_week}", [target_file])

            # Копируем задачи из каждого дня текущей недели в следующую неделю
            for i in range(7):
                target_data["days"][i]["tasks"] = source_data["days"][i]["tasks"].copy()

            # Сохраняем следующую неделю с новыми задачами
            with open(target_file, 'w', encoding='utf-8') as f:
                json.dump(target_data, f, ensure_ascii=False, indent=2)

            if self.isglobal:
                # ОТПРАВКА НА СЕРВЕР В ОТДЕЛЬНОМ ПОТОКЕ
                self.upload_thread = FileUploadThread(self.user_id, target_file, self.currentYear)
                self.upload_thread.finished.connect(lambda msg: print(f"Upload: {msg}"))
                self.upload_thread.error.connect(lambda msg: print(f"Upload error: {msg}"))
                self.upload_thread.start()

            # Отправляем успех в QML
            self.call_qml_function("show_notification", f"Задачи успешно перенесены на следующую неделю")

        except Exception as e:
            error_msg = f"Ошибка копирования: {str(e)}"
            print(error_msg)
            # Отправляем ошибку в QML
            self.call_qml_function("show_notification", error_msg)

    @Slot(result=list)
    def get_list_weeks(self):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", self.currentYear)

            files = [f for f in os.listdir(year_dir)
                     if os.path.isfile(os.path.join(year_dir, f))]

            return sorted(files)

        except Exception as e:
            print(f"Ошибка: {e}")
            return []

    @Slot(str)
    def change_year(self, year):
        print(f"Выбран год: {year}")
        self.currentYear = year

    @Slot(str)
    def read_file(self, file):
        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", self.currentYear)
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
            year_dir = os.path.join(project_root, "Scheduler", self.currentYear)

            filename = os.path.join(year_dir, week_number)

            print(f"Обновление дня {day_index + 1} в файле: {filename}")

            # Сохраняем состояние недели для возможности отмены
            self._push_undo(f"изменение дня {day_index + 1} (неделя {week_number})", [filename])

            # Читаем текущий файл
            with open(filename, 'r', encoding='utf-8') as f:
                week_data = json.load(f)

            # Обновляем только нужный день
            new_day_data = json.loads(day_json)
            week_data["days"][day_index] = new_day_data

            # Сохраняем обратно
            with open(filename, 'w', encoding='utf-8') as f:
                json.dump(week_data, f, ensure_ascii=False, indent=2)

            print(f"День {day_index + 1} успешно обновлен")

            if self.isglobal:
                # ОТПРАВКА НА СЕРВЕР В ОТДЕЛЬНОМ ПОТОКЕ
                self.upload_thread = FileUploadThread(self.user_id, filename, self.currentYear)
                self.upload_thread.finished.connect(lambda msg: print(f"Upload: {msg}"))
                self.upload_thread.error.connect(lambda msg: print(f"Upload error: {msg}"))
                self.upload_thread.start()

        except Exception as e:
            print(f"Ошибка сохранения дня {day_index}: {e}")

    @Slot(str)
    def log(self, message):
        print(f"Front: {message}")

    @Slot(int, str, result=str)
    def get_statistics(self, month, name):
        print(f"Поиск статистики для {name} за месяц {month}")

        try:
            current_file_dir = os.path.dirname(os.path.abspath(__file__))
            project_root = os.path.dirname(os.path.dirname(current_file_dir))
            year_dir = os.path.join(project_root, "Scheduler", self.currentYear)

            weeks_dir = year_dir
            if not os.path.exists(weeks_dir):
                return "Ошибка: папка с неделями не найдена"

            current_year = datetime.now().year
            target_week_numbers = self.find_week_numbers_for_month(weeks_dir, month,
                                                                   current_year)  # ← ДОБАВИЛ current_year
            if not target_week_numbers:
                return f"Не найдено недель для месяца {month}"

            stats = self.analyze_student_statistics(weeks_dir, target_week_numbers, name, month, current_year)

            result = f"Отмен: {stats['cancelled']}\nПереносов: {stats['moved']}\nВосстановленных: {stats['restored']}"

            if stats['cancelled'] > stats['moved']:
                burned = stats['cancelled'] - stats['moved']
                result += f"\nСгорело уроков: {burned}"
            else:
                result += f"\n\nСгорело уроков: 0"

            return result

        except Exception as e:
            return f"Ошибка: {str(e)}"

    def find_week_numbers_for_month(self, weeks_dir, target_month, target_year):
        """Находит номера недель, которые попадают в указанный месяц и год"""
        target_weeks = []

        try:
            week_files = [f for f in os.listdir(weeks_dir) if f.isdigit() or (f.startswith('0') and f[1:].isdigit())]

            for week_file in week_files:
                week_number = int(week_file)
                file_path = os.path.join(weeks_dir, week_file)

                try:
                    with open(file_path, 'r', encoding='utf-8') as f:
                        data = json.load(f)

                    if self.is_week_in_month_and_year(data, target_month, target_year):
                        target_weeks.append(week_number)

                except Exception as e:
                    continue

        except Exception as e:
            pass

        return sorted(target_weeks)

    def is_week_in_month_and_year(self, week_data, target_month, target_year):
        """Проверяет, содержит ли неделя дни указанного месяца и года"""
        try:
            for day in week_data.get('days', []):
                date_str = day.get('date', '')
                if date_str:
                    date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                    if date_obj.month == target_month and date_obj.year == target_year:
                        return True
            return False
        except:
            return False

    def analyze_student_statistics(self, weeks_dir, week_numbers, student_name, target_month, target_year):
        """Анализирует статистику ученика ТОЛЬКО за указанный месяц и год"""
        stats = {
            'cancelled': 0,
            'moved': 0,
            'restored': 0
        }

        found_first_cancellation = False

        for week_number in week_numbers:
            week_file = str(week_number).zfill(2)
            file_path = os.path.join(weeks_dir, week_file)

            try:
                with open(file_path, 'r', encoding='utf-8') as f:
                    data = json.load(f)

                for day in data.get('days', []):
                    date_str = day.get('date', '')
                    if date_str:
                        date_obj = datetime.strptime(date_str, '%Y-%m-%d')
                        if date_obj.month == target_month and date_obj.year == target_year:

                            for task in day.get('tasks', []):
                                task_text = task.get('task', '')
                                task_color = task.get('color', '#ffffff').lower()

                                if student_name.lower() in task_text.lower():
                                    if task_color == '#a8a8a8':
                                        stats['cancelled'] += 1
                                        found_first_cancellation = True
                                    elif task_color in ['#ffcccc', '#ffccf2']:
                                        if not found_first_cancellation:
                                            stats['restored'] += 1
                                        else:
                                            stats['moved'] += 1

            except:
                continue

        return stats