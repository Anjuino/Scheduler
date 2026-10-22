import os
import json
from datetime import datetime, timedelta
from Config import SCHEDULES_ROOT

days_translation = {
    'Monday': 'Понедельник',
    'Tuesday': 'Вторник', 
    'Wednesday': 'Среда',
    'Thursday': 'Четверг',
    'Friday': 'Пятница',
    'Saturday': 'Суббота',
    'Sunday': 'Воскресенье'
}

def find_schedule(user_id, days_offset=0):
    """
    Получает расписание для указанного дня
    days_offset: 0 - сегодня, 1 - завтра, -1 - вчера и т.д.
    """
    # Вычисляем нужную дату
    target_date = datetime.now() + timedelta(days=days_offset)
    
    # Получаем путь к файлу (учитываем смену недели)
    week_number = target_date.isocalendar()[1]
    week_number_str = f"{week_number:02d}" 
    year = target_date.year
    file_path = os.path.join(SCHEDULES_ROOT, str(user_id), str(year), week_number_str)
    print(file_path)

    try:
        # Открываем и читаем файл
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
        
        # Форматируем целевую дату для поиска
        target_date_str = target_date.strftime("%Y-%m-%d")
        
        # Ищем нужный день в данных
        for day in data['days']:
            if day['date'] == target_date_str:
                date_obj = datetime.strptime(target_date_str, "%Y-%m-%d")
                eng_day = date_obj.strftime("%A")
                rus_day = days_translation.get(eng_day, eng_day)
                formatted_date = f"{rus_day} {date_obj.strftime('%d.%m')}"
                
                countLessons = 0

                # Собираем задачи в нужном формате
                tasks_text = ""
                for task in day['tasks']:
                    task_name = task['task']
                    if task_name:
                        if task['color'] == '#ffffff' or task['color'] == '#ffcccc': 
                            countLessons += 1
                            tasks_text += f"✏️ {task_name}\n------------------------------------\n"

                        elif task['color'] == '#a8a8a8': 
                            tasks_text += f"❌ {task_name}\n------------------------------------\n"

                        else: tasks_text += f"✏️ {task_name}\n------------------------------------\n"

                # Формируем итоговый текст
                Lessons = f"Количество уроков: {countLessons}"
                result = f"{formatted_date}\n{Lessons}\n\n{tasks_text}"
                return result.rstrip()
        
        return "❌ Расписание не найдено"
    
    except FileNotFoundError:
        return "❌ Файл расписания не найден"
    except json.JSONDecodeError:
        return "❌ Ошибка чтения файла расписания"
    except Exception as e:
        return f"❌ Произошла ошибка: {str(e)}"

def find_today_schedule(user_id):
    return find_schedule(user_id, 0)

def find_schedule_json(user_id, days_offset=0):
    """
    Возвращает расписание в виде JSON для API
    """
    target_date = datetime.now() + timedelta(days=days_offset)
    week_number = target_date.isocalendar()[1]
    week_number_str = f"{week_number:02d}" 
    year = target_date.year
    file_path = os.path.join(SCHEDULES_ROOT, str(user_id), str(year), week_number_str)

    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
        
        target_date_str = target_date.strftime("%Y-%m-%d")
        
        for day in data['days']:
            if day['date'] == target_date_str:
                date_obj = datetime.strptime(target_date_str, "%Y-%m-%d")
                eng_day = date_obj.strftime("%A")
                rus_day = days_translation.get(eng_day, eng_day)
                
                tasks = []
                count_lessons = 0

                for task_index, task in enumerate(day['tasks']):
                    task_name = task['task']
                    if task_name:
                        task_color = task.get('color', '#ffffff')

                        # Определяем тип урока
                        if task_color == '#a8a8a8':
                            task_type = "cancelled"
                            icon = "❌"
                        else:
                            task_type = "active"
                            icon = "✏️"
                            if task_color == '#ffffff' or task_color == '#ffcccc':
                                count_lessons += 1

                        tasks.append({
                            "index": task_index,
                            "name": task_name,
                            "description": task.get('description', ''),
                            "type": task_type,
                            "icon": icon,
                            "color": task_color
                        })
                
                return {
                    "success": True,
                    "data": {
                        "date": target_date_str,
                        "day_name": rus_day,
                        "formatted_date": f"{rus_day} {date_obj.strftime('%d.%m')}",
                        "lessons_count": count_lessons,
                        "tasks": tasks
                    }
                }
        
        return {
            "success": False,
            "error": "Расписание не найдено",
            "date": target_date_str
        }
    
    except FileNotFoundError:
        return {
            "success": False,
            "error": "Файл расписания не найден"
        }
    except json.JSONDecodeError:
        return {
            "success": False,
            "error": "Ошибка чтения файла расписания"
        }
    except Exception as e:
        return {
            "success": False,
            "error": str(e)
        }

def _load_day_for_date(user_id, date_str):
    """
    Открывает файл недели по дате и находит в нем нужный день.
    Возвращает (file_path, week_data, day_dict, None) либо (None, None, None, error_dict).
    """
    try:
        date_obj = datetime.strptime(date_str, "%Y-%m-%d")
    except ValueError:
        return None, None, None, {"success": False, "error": "Неверный формат даты"}

    week_number = date_obj.isocalendar()[1]
    week_number_str = f"{week_number:02d}"
    year = date_obj.year
    file_path = os.path.join(SCHEDULES_ROOT, str(user_id), str(year), week_number_str)

    try:
        with open(file_path, 'r', encoding='utf-8') as file:
            data = json.load(file)
    except FileNotFoundError:
        return None, None, None, {"success": False, "error": "Расписание на эту дату не найдено"}
    except json.JSONDecodeError:
        return None, None, None, {"success": False, "error": "Ошибка чтения файла расписания"}

    for day in data.get('days', []):
        if day.get('date') == date_str:
            return file_path, data, day, None

    return None, None, None, {"success": False, "error": "Расписание на эту дату не найдено"}


def _save_week_file(file_path, data):
    data['updated_at'] = datetime.utcnow().isoformat() + "Z"
    with open(file_path, 'w', encoding='utf-8') as file:
        json.dump(data, file, ensure_ascii=False, indent=2)


def update_task_in_schedule(user_id, date_str, task_index, task_text, task_description="", task_color=None):
    """Обновляет текст, описание и (если передан) цвет задачи по дате и индексу задачи в дне."""
    file_path, data, day, error = _load_day_for_date(user_id, date_str)
    if error:
        return error

    tasks = day.get('tasks', [])
    if task_index < 0 or task_index >= len(tasks):
        return {"success": False, "error": "Задача не найдена"}

    tasks[task_index]['task'] = task_text
    tasks[task_index]['description'] = task_description
    if task_color:
        tasks[task_index]['color'] = task_color

    _save_week_file(file_path, data)
    return {"success": True}


def add_task_to_schedule(user_id, date_str, task_text, task_description="", task_color="#ffffff"):
    """Добавляет новую задачу в конец списка задач указанного дня."""
    file_path, data, day, error = _load_day_for_date(user_id, date_str)
    if error:
        return error

    tasks = day.setdefault('tasks', [])
    tasks.append({"task": task_text, "description": task_description, "color": task_color})

    _save_week_file(file_path, data)
    return {"success": True, "index": len(tasks) - 1}


def delete_task_from_schedule(user_id, date_str, task_index):
    """Удаляет задачу по индексу из указанного дня."""
    file_path, data, day, error = _load_day_for_date(user_id, date_str)
    if error:
        return error

    tasks = day.get('tasks', [])
    if task_index < 0 or task_index >= len(tasks):
        return {"success": False, "error": "Задача не найдена"}

    tasks.pop(task_index)

    _save_week_file(file_path, data)
    return {"success": True}


def reorder_tasks_in_schedule(user_id, date_str, from_index, to_index):
    """Перемещает задачу с одной позиции на другую внутри дня (drag-n-drop на вебе)."""
    file_path, data, day, error = _load_day_for_date(user_id, date_str)
    if error:
        return error

    tasks = day.get('tasks', [])
    if from_index < 0 or from_index >= len(tasks) or to_index < 0 or to_index >= len(tasks):
        return {"success": False, "error": "Неверный индекс задачи"}

    task = tasks.pop(from_index)
    tasks.insert(to_index, task)

    _save_week_file(file_path, data)
    return {"success": True}