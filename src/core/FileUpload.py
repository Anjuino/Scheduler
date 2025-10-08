import os
from PySide6.QtCore import QObject, Slot, QThread, Signal
import requests

class FileUploadThread(QThread):
    finished = Signal(str)
    error = Signal(str)

    def __init__(self, user_id, file_path, year):
        super().__init__()
        self.user_id = user_id
        self.file_path = file_path  # Полный путь к файлу
        self.file_name = os.path.basename(file_path)  # Берем только имя файла из пути
        self.year = year
        self.server_url = "http://192.168.0.105:6000/upload_schedule"

        self.finished.connect(self.deleteLater)
        self.error.connect(self.deleteLater)

    def run(self):
        try:
            with open(self.file_path, 'rb') as f:
                files = {'file': (self.file_name, f, 'application/json')}  # Отправляем только имя
                headers = {
                    'User-ID': str(self.user_id),
                    'Year': str(self.year)
                }

                response = requests.post(
                    self.server_url,
                    files=files,
                    headers=headers,
                    timeout=30
                )

                if response.status_code == 200: self.finished.emit(f"Файл отправлен: {self.file_name}")
                else:                           self.error.emit(f"Ошибка: {response.json().get('error', 'Unknown error')}")

        except Exception as e: self.error.emit(f"Ошибка отправки: {str(e)}")