import os
import requests
import time
import logging
from urllib.parse import unquote

# Настройка логирования
logging.basicConfig(
   format='%(asctime)s - %(levelname)s - %(message)s',
   level=logging.INFO,
   filename=os.path.join('/root/Flash/TgLog/', 'bot.log'), 
   filemode='a'
)
logger = logging.getLogger(__name__)

PUBLIC_VIEW_URL = "https://disk.yandex.ru/i/IidrnBI9DclSsA"

def download_file():
   try:
      api_url = f"https://cloud-api.yandex.net/v1/disk/public/resources/download?public_key={PUBLIC_VIEW_URL}"
      
      #logger.info("Получаю свежую ссылку для скачивания...")
      api_response = requests.get(api_url, timeout=30)
      api_response.raise_for_status()
      
      download_data = api_response.json()

      current_download_url = download_data['href']
      
      #logger.info(f"Свежая ссылка получена: {current_download_url}")

      file_response = requests.get(current_download_url, stream=True, timeout=30)
      file_response.raise_for_status()
      
      filename = "Расписание.xlsx"
      full_path = os.path.join("/root/Flash", filename)
      
      with open(full_path, 'wb') as f:
         for chunk in file_response.iter_content(chunk_size=8192):
            if chunk:
               f.write(chunk)
      
      logger.info(f"Файл успешно скачан: {full_path}")
      logger.info(f"Размер файла: {os.path.getsize(full_path)} байт")
      
      return True
      
   except requests.exceptions.RequestException as e:
      logger.error(f"Ошибка при загрузке с Яндекс Диска: {e}")
      return False
   except Exception as e:
      logger.error(f"Неожиданная ошибка при загрузке: {e}")
      return False