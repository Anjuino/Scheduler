// Получить номер текущей недели
function getWeekNumber(date) {
    if (!date) date = new Date();

    var target = new Date(date.valueOf());
    var dayNr = (date.getDay() + 6) % 7;
    target.setDate(target.getDate() - dayNr + 3);
    var firstThursday = target.valueOf();
    target.setMonth(0, 1);

    if (target.getDay() !== 4) {
        target.setMonth(0, 1 + ((4 - target.getDay()) + 7) % 7);
    }

    return Math.ceil((firstThursday - target) / 604800000);
}

// Функция для форматирования даты
function formatDate(dateString) {
    var parts = dateString.split("-");
    if (parts.length === 3) return parts[2] + "." + parts[1];
    return dateString;
}

// Функция для обновления данных дней
function updateDaysData(jsonData, daysRepeater) {
    try {
        var daysData = JSON.parse(jsonData);
        var days = daysData.days;

        for (var i = 0; i < Math.min(days.length, 7); i++) {
            var day = days[i];
            var dayItem = daysRepeater.itemAt(i);

            if (dayItem) {
                // Обновляем название и дату
                dayItem.dayName = day.day;
                dayItem.dayDate = formatDate(day.date);

                // Преобразуем задачи
                var tasksModel = [];
                for (var j = 0; j < day.tasks.length; j++) {
                    var task = day.tasks[j];
                    tasksModel.push({
                        taskText: task.task,
                        //taskDescription: task.description,
                        taskColor: task.color || "white"
                    });
                }
                dayItem.dayTasks = tasksModel;
            }
        }
    } catch (e) {
        //Backend.log("Ошибка парсинга JSON:", e);
    }
}