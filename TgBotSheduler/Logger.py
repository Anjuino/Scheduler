import logging
import os
from Config import LOG_DIR

# Папки может не быть при первом запуске (особенно в локальном тесте) - создаем сами
os.makedirs(LOG_DIR, exist_ok=True)

# Настройка логирования
logging.basicConfig(
   format='%(asctime)s - %(levelname)s - %(message)s',
   level=logging.INFO,
   filename=os.path.join(LOG_DIR, 'new_bot.log'),
   filemode='a'
)
logger = logging.getLogger(__name__)