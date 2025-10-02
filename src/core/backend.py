from PySide6.QtCore import QObject, Slot, Signal
from datetime import datetime
import os

#Поток интерфейса
class Backend(QObject):

    def __init__(self, qml_engine):
        super().__init__()
        self.qml_engine = qml_engine  # Ссылка на QML engine

    # Вызов функции из qml
    def call_qml_function(self, function_name, *args):
        if not self.qml_engine.rootObjects(): return

        root_object = self.qml_engine.rootObjects()[0]

        if hasattr(root_object, function_name): getattr(root_object, function_name)(*args)


    def log_app(self, data):
        #print(data)
        self.call_qml_function("log_app", data)


    @Slot(result=list)
    def get_list_weaks(self):
        try:
            # Определяем путь к папке с текущим годом
            year_dir = os.path.join("Sheduler", str(datetime.now().year))
            print("Текущая рабочая директория:", year_dir)
            # Проверяем существование папки
            if not os.path.exists(year_dir): return []
            
            # Получаем только файлы (исключаем папки)
            files = [f for f in os.listdir(year_dir) 
                    if os.path.isfile(os.path.join(year_dir, f))]
            
            return sorted(files)  # Возвращаем отсортированный список
            
        except Exception as e:
            print(f"Ошибка: {e}")
            return []

    @Slot(str)
    def read_file(self, file):
        year_dir = os.path.join("Sheduler", str(datetime.now().year))
        filename = os.path.join(year_dir, file)

        with open(filename, 'r', encoding='utf-8') as f:
            content = f.read()
        
        self.call_qml_function("print_data", content)

    # Логирование с qml
    @Slot(str)
    def log(self, message):
        print(f"Front: {message}")

