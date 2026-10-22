import os
import json
from PySide6.QtCore import QObject, Slot, QThread, Signal
import requests

class FileUploadThread(QThread):
    finished = Signal(str)
    error = Signal(str)

    def __init__(self, user_id, file_path, year, server_url):
        super().__init__()
        self.user_id = user_id
        self.file_path = file_path  # Полный путь к файлу
        self.file_name = os.path.basename(file_path)  # Берем только имя файла из пути
        self.year = year
        self.server_url = server_url.rstrip('/') + "/scheduler/upload_schedule"

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


class FileDownloadThread(QThread):
    # status: "updated" | "up_to_date" | "not_found" | "error"
    finished = Signal(str, str)

    def __init__(self, user_id, week_file, year, server_url, local_path):
        super().__init__()
        self.user_id = user_id
        self.week_file = week_file
        self.year = year
        self.server_url = server_url.rstrip('/') + "/scheduler/download_schedule"
        self.local_path = local_path

        self.finished.connect(self.deleteLater)

    def run(self):
        try:
            response = requests.get(
                self.server_url,
                params={
                    'user_id': self.user_id,
                    'year': self.year,
                    'week': self.week_file
                },
                timeout=5
            )

            if response.status_code == 404:
                self.finished.emit("not_found", "")
                return
            if response.status_code != 200:
                self.finished.emit("error", "")
                return

            remote_data = response.json()
            remote_updated = remote_data.get("updated_at")

            local_updated = None
            if os.path.exists(self.local_path):
                try:
                    with open(self.local_path, 'r', encoding='utf-8') as f:
                        local_updated = json.load(f).get("updated_at")
                except Exception:
                    local_updated = None

            if remote_updated and (not local_updated or remote_updated > local_updated):
                payload = json.dumps(remote_data, ensure_ascii=False, indent=2)
                self.finished.emit("updated", payload)
            else:
                self.finished.emit("up_to_date", "")

        except Exception as e:
            print(f"Ошибка проверки обновлений: {e}")
            self.finished.emit("error", "")
