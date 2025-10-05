import json
import os
from datetime import datetime, date, timedelta

def generate_files(year: int, folder_path: str):

    # Создаем папку если ее нет
    if not os.path.exists(folder_path):
        os.makedirs(folder_path)
    
    weekdays_ru = ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"]
    
    current_date = date(year, 1, 1)
    week_number = 1
    
    while current_date.year == year:
        if current_date.weekday() != 0:
            current_date = current_date - timedelta(days=current_date.weekday())
        
        start_date = current_date
        end_date = current_date + timedelta(days=6)
        
        # Создаем дни недели как объекты
        days_array = []
        for i in range(7):
            day_date = current_date + timedelta(days=i)
            day_str = day_date.strftime("%Y-%m-%d")
            
            day_obj = {
                "date": day_str,
                "day": weekdays_ru[day_date.weekday()],
                "tasks": [
                    {
                        "task": "Работа",
                        "description": "",
                        "color": "white"
                    }
                ]
            }
            
            days_array.append(day_obj)
        
        # Создаем данные для недели
        week_data = {
            #"week_number": week_number,
            #"start": start_date.strftime("%Y-%m-%d"),
            #"end": end_date.strftime("%Y-%m-%d"),
            "days": days_array
        }
        
        # Сохраняем в отдельный файл
        filename = f"{week_number:02d}"
        file_path = os.path.join(folder_path, filename)
        
        with open(file_path, 'w', encoding='utf-8') as f:
            json.dump(week_data, f, ensure_ascii=False, indent=2)
        
        print(f"Создан файл: {filename}")
        
        # Переходим к следующей неделе
        current_date = end_date + timedelta(days=1)
        week_number += 1
    
    print(f"\nСоздано {week_number-1} файлов в папке '{folder_path}'")

generate_files(2025, "Scheduler/2025")
generate_files(2026, "Scheduler/2026")