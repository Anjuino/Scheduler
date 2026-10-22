import Logger
import telebot
import time
from telebot import types
from requests.exceptions import ConnectionError, ReadTimeout
from functools import wraps
import FileServer
import Scheduler
import datetime
from telebot import apihelper
import signal
from Config import ALLOWED_USER_IDS                                       # Список пользователей тг бота

bot = telebot.TeleBot("7703428815:AAFCJFu9o3JTuYgFb6KgegfiTi9HMlns1Yw")
apihelper.proxy = {
   'http': 'socks5://89.125.81.76:1080',
   'https': 'socks5://89.125.81.76:1080'
}


# Декоратор для проверки пользователя
def allowed_users_only(func):
   @wraps(func)
   def wrapper(message, *args, **kwargs):
      if message.from_user.id not in ALLOWED_USER_IDS:
        bot.send_message(message.chat.id, "Доступ запрещен!")
        Logger.logger.info(f"Пользователь {message.from_user.first_name}/{message.from_user.id} ломится")
        return
      return func(message, *args, **kwargs)
   return wrapper

# Дополнительные обработчики с проверкой
@bot.message_handler(commands=['start'])
@allowed_users_only
def handle_start(message: types.Message):
   Logger.logger.info(f"Пользователь {message.from_user.first_name}/{message.from_user.id} авторизован")
   bot.send_message(message.chat.id, f"Привет, {message.from_user.first_name}", reply_markup=create_main_menu())

# Обработчик текстовых сообщений (кнопки меню)
@bot.message_handler(content_types=['text'], func=lambda message: not message.text.startswith('/'))
@allowed_users_only
def handle_menu_buttons(message: types.Message):
   if message.text == '📝 Сегодня':
      schedule = Scheduler.find_schedule(message.chat.id, 0)  # сегодня
      bot.send_message(message.chat.id, schedule)

   elif message.text == '📝 Завтра':
      schedule = Scheduler.find_schedule(message.chat.id, 1)  # завтра
      bot.send_message(message.chat.id, schedule)


   elif message.text == '📝 Текущая неделя':
      today = datetime.datetime.now().weekday()  # 0-пн, 6-вс
      # Находим понедельник текущей недели (отнимаем текущий день недели)
      monday_offset = -today
      
      # Выводим 7 дней текущей недели (пн-вс)
      for i in range(7):
         days_offset = monday_offset + i
         schedule = Scheduler.find_schedule(message.chat.id, days_offset)
         bot.send_message(message.chat.id, schedule)

   elif message.text == '📝 Следующая неделя':
      # Находим следующий понедельник
      today = datetime.datetime.now().weekday()  # 0-пн, 6-вс
      days_until_monday = (7 - today) % 7 or 7  # дней до следующего понедельника
      
      # Выводим 7 дней начиная со следующего понедельника
      for i in range(7):
         days_offset = days_until_monday + i
         schedule = Scheduler.find_schedule(message.chat.id, days_offset)
         bot.send_message(message.chat.id, schedule)


   else: bot.send_message(message.chat.id, "Не понимаю команду")

def create_main_menu():
   markup = types.ReplyKeyboardMarkup(resize_keyboard=True, row_width=2)
   btn1 = types.KeyboardButton('📝 Сегодня')
   btn2 = types.KeyboardButton('📝 Завтра')
   btn3 = types.KeyboardButton('📝 Текущая неделя')
   btn4 = types.KeyboardButton('📝 Следующая неделя')
   markup.row(btn1, btn2)                    

   markup.add(btn3)
   markup.add(btn4)

   return markup


def start_bot():
   Logger.logger.info("Бот запущен")
   while True:
      try:
         bot.polling(none_stop=True, interval=2, timeout=60, long_polling_timeout=60)
      except ConnectionError:
         Logger.logger.warning("Ошибка соединения")
         time.sleep(10)
      except ReadTimeout:
         Logger.logger.warning("Таймаут соединения")
         time.sleep(10)
      except Exception as e:
         Logger.logger.error(f"Unexpected error: {e}")
         Logger.logger.info("Перезапуск")
         time.sleep(10)

if __name__ == '__main__':
   FileServer.server_start()
   signal.pause()  # Только на Linux, ждет сигнал