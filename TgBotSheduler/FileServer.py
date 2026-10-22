from flask import Flask, request, jsonify, render_template
import Logger
import threading
import os
import json
import hmac
from functools import wraps
import Scheduler
from Config import PORT, SCHEDULES_ROOT, ALLOWED_USER_IDS, TASK_COLORS, USER_PASSWORDS

app = Flask(__name__)
ALLOWED_IDS = ALLOWED_USER_IDS


def _check_password(user_id, password):
    expected = USER_PASSWORDS.get(user_id)
    return bool(expected) and hmac.compare_digest(password or '', expected)


def require_auth(f):
    """
    Без серверных сессий: браузер шлет user_id/пароль с каждым запросом
    (заголовки X-User-Id/X-Password), сам их не глядя пересылает из localStorage.
    Так пароль не "протухает" - только если пользователь сам очистит хранилище.
    """
    @wraps(f)
    def wrapper(*args, **kwargs):
        try:
            user_id = int(request.headers.get('X-User-Id', ''))
        except (ValueError, TypeError):
            return jsonify({"error": "Требуется вход"}), 401

        password = request.headers.get('X-Password', '')

        if user_id not in ALLOWED_IDS or not _check_password(user_id, password):
            return jsonify({"error": "Требуется вход"}), 401

        request.auth_user_id = user_id
        return f(*args, **kwargs)
    return wrapper


@app.route('/scheduler/login', methods=['POST'])
def login():
    payload = request.get_json(force=True, silent=True) or {}
    try:
        user_id = int(payload.get('user_id', ''))
    except (ValueError, TypeError):
        return jsonify({"success": False, "error": "Неверный ID"}), 400

    password = payload.get('password', '')

    if user_id in ALLOWED_IDS and _check_password(user_id, password):
        return jsonify({"success": True}), 200

    return jsonify({"success": False, "error": "Неверный ID или пароль"}), 401


@app.route('/scheduler/upload_schedule', methods=['POST'])
def upload_schedule():
    try:
        try:
            user_id = int(request.headers.get('User-ID'))
            current_year = int(request.headers.get('Year'))
        except (ValueError, TypeError): return jsonify({"error": "Неверный формат id или года"}), 400
        
        if not user_id:                 return jsonify({"error": "id нет в запросе"}), 400
        if user_id not in ALLOWED_IDS:  return jsonify({"error": "id нет в списке"}), 403
        if 'file' not in request.files: return jsonify({"error": "нет файла"}),    400
        
        file = request.files['file']
        if file.filename == '': return jsonify({"error": "нет имени файла"}), 400

        filename = os.path.basename(file.filename)

        file_path = os.path.join(SCHEDULES_ROOT, str(user_id), str(current_year), filename)

        # Папки user_id/year может еще не быть (первая загрузка) - создаем на лету
        os.makedirs(os.path.dirname(file_path), exist_ok=True)
        file.save(file_path)
        
        #Logger.logger.info(f"Файл сохранен: {file_path} для пользователя {user_id}")
        
        return jsonify({
            "status": "success", 
        }), 200

    except Exception as e:
        Logger.logger.error(f"Ошибка загрузки: {e}")
        return jsonify({"ошибка": str(e)}), 500

@app.route('/scheduler')
def home():
    try:
        return render_template('index.html')
    except Exception as e:
        Logger.logger.error(f"Ошибка загрузки страницы: {e}")
        return jsonify({"ошибка": str(e)}), 500

@app.route('/scheduler/get_schedule', methods=['GET'])
@require_auth
def get_schedule():
    try:
        user_id = request.auth_user_id
        days_offset = request.args.get('days_offset', 0)

        try:
            days_offset = int(days_offset)
        except ValueError:
            return jsonify({"error": "Неверный формат"}), 400

        # Получаем JSON от новой функции
        result = Scheduler.find_schedule_json(user_id, days_offset)
        
        if result["success"]:
            return jsonify(result), 200
        else:
            return jsonify(result), 404
        
    except Exception as e:
        Logger.logger.error(f"Ошибка: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/scheduler/download_schedule', methods=['GET'])
def download_schedule():
    try:
        user_id = request.args.get('user_id')
        year = request.args.get('year')
        week = request.args.get('week')

        if not user_id or not year or not week:
            return jsonify({"error": "Не указаны обязательные параметры"}), 400

        try:
            user_id = int(user_id)
        except ValueError:
            return jsonify({"error": "Неверный формат user_id"}), 400

        if user_id not in ALLOWED_IDS:
            return jsonify({"error": "Доступ запрещен"}), 403

        # basename защищает от выхода за пределы папки пользователя через ../
        year = os.path.basename(str(year))
        week = os.path.basename(str(week))
        file_path = os.path.join(SCHEDULES_ROOT, str(user_id), year, week)

        if not os.path.isfile(file_path):
            return jsonify({"error": "Файл не найден"}), 404

        with open(file_path, 'r', encoding='utf-8') as f:
            data = json.load(f)

        return jsonify(data), 200

    except Exception as e:
        Logger.logger.error(f"Ошибка скачивания: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/scheduler/update_task', methods=['POST'])
@require_auth
def update_task():
    try:
        payload = request.get_json(force=True, silent=True) or {}

        user_id = request.auth_user_id
        date_str = payload.get('date')
        task_index = payload.get('task_index')
        task_text = payload.get('task')
        task_description = payload.get('description', '')
        task_color = payload.get('color')

        if date_str is None or task_index is None or task_text is None:
            return jsonify({"error": "Не указаны обязательные параметры"}), 400

        if task_color is not None and task_color not in TASK_COLORS:
            return jsonify({"error": "Неверный цвет"}), 400

        try:
            task_index = int(task_index)
        except (ValueError, TypeError):
            return jsonify({"error": "Неверный формат параметров"}), 400

        result = Scheduler.update_task_in_schedule(user_id, date_str, task_index, task_text, task_description, task_color)

        if result.get("success"):
            return jsonify(result), 200
        return jsonify(result), 404

    except Exception as e:
        Logger.logger.error(f"Ошибка обновления задачи: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/scheduler/add_task', methods=['POST'])
@require_auth
def add_task():
    try:
        payload = request.get_json(force=True, silent=True) or {}

        user_id = request.auth_user_id
        date_str = payload.get('date')
        task_text = payload.get('task')
        task_description = payload.get('description', '')
        task_color = payload.get('color', '#ffffff')

        if date_str is None or not task_text:
            return jsonify({"error": "Не указаны обязательные параметры"}), 400

        if task_color not in TASK_COLORS:
            return jsonify({"error": "Неверный цвет"}), 400

        result = Scheduler.add_task_to_schedule(user_id, date_str, task_text, task_description, task_color)

        if result.get("success"):
            return jsonify(result), 200
        return jsonify(result), 404

    except Exception as e:
        Logger.logger.error(f"Ошибка добавления задачи: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/scheduler/delete_task', methods=['POST'])
@require_auth
def delete_task():
    try:
        payload = request.get_json(force=True, silent=True) or {}

        user_id = request.auth_user_id
        date_str = payload.get('date')
        task_index = payload.get('task_index')

        if date_str is None or task_index is None:
            return jsonify({"error": "Не указаны обязательные параметры"}), 400

        try:
            task_index = int(task_index)
        except (ValueError, TypeError):
            return jsonify({"error": "Неверный формат параметров"}), 400

        result = Scheduler.delete_task_from_schedule(user_id, date_str, task_index)

        if result.get("success"):
            return jsonify(result), 200
        return jsonify(result), 404

    except Exception as e:
        Logger.logger.error(f"Ошибка удаления задачи: {e}")
        return jsonify({"error": str(e)}), 500


@app.route('/scheduler/reorder_tasks', methods=['POST'])
@require_auth
def reorder_tasks():
    try:
        payload = request.get_json(force=True, silent=True) or {}

        user_id = request.auth_user_id
        date_str = payload.get('date')
        from_index = payload.get('from_index')
        to_index = payload.get('to_index')

        if date_str is None or from_index is None or to_index is None:
            return jsonify({"error": "Не указаны обязательные параметры"}), 400

        try:
            from_index = int(from_index)
            to_index = int(to_index)
        except (ValueError, TypeError):
            return jsonify({"error": "Неверный формат параметров"}), 400

        result = Scheduler.reorder_tasks_in_schedule(user_id, date_str, from_index, to_index)

        if result.get("success"):
            return jsonify(result), 200
        return jsonify(result), 404

    except Exception as e:
        Logger.logger.error(f"Ошибка перестановки задачи: {e}")
        return jsonify({"error": str(e)}), 500


def run_server():
    try:
        Logger.logger.info(f"Сервер запущен http://0.0.0.0:{PORT}")
        app.run(host='0.0.0.0', port=PORT, debug=False, use_reloader=False)
    except Exception as e:
        Logger.logger.error(f"КРИТИЧЕСКАЯ ОШИБКА СЕРВЕРА: {e}")
        print(f"КРИТИЧЕСКАЯ ОШИБКА СЕРВЕРА: {e}")  # Чтобы точно увидеть

# Обертка для запуска в отдельном потоке
def server_start():
    server_thread = threading.Thread(target=run_server, daemon=True)
    server_thread.start()
    Logger.logger.info("Поток сервера запущен")

# Отдельный запуск для локального теста: `python FileServer.py`.
# В отличие от NewTgBot.py не использует signal.pause() (недоступен на Windows).
if __name__ == "__main__":
    run_server()