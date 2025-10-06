import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

import "Utils/Utils.js" as Utils

ApplicationWindow {
    id: root
    visible: true
    width: 1366
    height: 768
    title: "Scheduler"

    Component.onCompleted: {
        ApplicationWindow.style = "Fusion"
    }

    // Новая функция для обновления данных недели
    function update_week_data(jsonContent) {
        updateDaysData(jsonContent)
    }

    // Функция для обновления данных дней
    function updateDaysData(jsonData) {
        try {
            var daysData = JSON.parse(jsonData);
            var days = daysData.days;

            for (var i = 0; i < 7; i++) {
                var day = days[i];
                var dayItem = daysRepeater.itemAt(i);

                if (dayItem) {
                    // Сохраняем оригинальную дату из JSON для последующего сохранения
                    dayItem.originalDate = day.date;
                    dayItem.dayDate = Utils.formatDate(day.date);

                    // Преобразуем задачи
                    var tasksModel = [];
                    for (var j = 0; j < day.tasks.length; j++) {
                        var task = day.tasks[j];
                        tasksModel.push({
                            taskText: task.task,
                            taskDescription: task.description || "",
                            taskColor: task.color || "white"
                        });
                    }
                    dayItem.dayTasks = tasksModel;
                }
            }
        } catch (e) {
            Backend.log("Ошибка парсинга JSON:", e);
        }
    }

    // Функция для сохранения данных дня
    function saveDayData(dayIndex) {
        try {
            var dayItem = daysRepeater.itemAt(dayIndex);
            if (!dayItem) return;

            var currentWeek = comboBox.currentText || Utils.getWeekNumber();
            if (!currentWeek) return;

            // Собираем данные только для этого дня
            var dayData = {
                "date": dayItem.originalDate,
                "day": dayItem.dayName,
                "tasks": []
            };

            // Преобразуем задачи в нужный формат
            for (var j = 0; j < dayItem.dayTasks.length; j++) {
                var task = dayItem.dayTasks[j];
                dayData.tasks.push({
                    "task": task.taskText || "",
                    "description": task.taskDescription || "",
                    "color": task.taskColor || "white"
                });
            }

            // Отправляем в бэкенд для сохранения
            Backend.save_day_data(currentWeek, dayIndex, JSON.stringify(dayData));

        } catch (e) {
            Backend.log("Ошибка сохранения дня:", e);
        }
    }

    Rectangle {
        anchors.fill: parent
        anchors.margins: root.width * 0.01

        Rectangle {
            id: firstField
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * 0.9
            color: "#e6f3ff"
            border.width: 1

            Row {
                id: daysRow
                anchors.fill: parent
                spacing: 1

                Repeater {
                    id: daysRepeater
                    model: 7

                    Rectangle {
                        id: dayContainer
                        width: (firstField.width - 6) / 7
                        height: parent.height
                        color: "#ffffff"
                        border.width: 1
                        border.color: "#cccccc"

                        Column {
                            anchors.fill: parent
                            spacing: 2

                            // Заголовок дня
                            Rectangle {
                                id: dayHeader
                                width: parent.width
                                height: 30
                                color: "#4a86e8"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5

                                    Text {
                                        text: dayName
                                        font.pixelSize: 14
                                        font.bold: true
                                        color: "white"
                                        Layout.alignment: Qt.AlignVCenter
                                    }

                                    Item { Layout.fillWidth: true } // Пустое пространство между элементами

                                    Text {
                                        text: dayDate
                                        font.pixelSize: 14
                                        color: "white"
                                        Layout.alignment: Qt.AlignVCenter
                                    }
                                }
                            }

                            // Область для задач
                            ListView {
                                id: tasksListView
                                width: parent.width
                                height: parent.height - dayHeader.height - addButton.height - 8
                                model: dayTasks
                                spacing: 2
                                clip: true

                                // Сигналы для внешней обработки
                                signal taskLeftClicked(var taskData, int index)
                                signal taskRightClicked(var taskData, int index)
                                signal taskEditFinished(var taskData, int index, string newText)

                                delegate: Rectangle {
                                    id: taskDelegate
                                    width: tasksListView.width - 4
                                    height: 40
                                    color: modelData.taskColor || "white"
                                    border.width: 1
                                    border.color: "#dddddd"
                                    radius: 3

                                    property bool isEditing: false
                                    property int taskIndex: index

                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: function(mouse) {
                                            if (mouse.button === Qt.RightButton) {
                                                tasksListView.taskRightClicked(modelData, index)
                                            }
                                        }
                                    }

                                    // Статический текст (отображается когда не редактируем)
                                    Column {
                                        id: staticTextColumn
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        visible: !taskDelegate.isEditing

                                        Text {
                                            width: parent.width
                                            text: modelData.taskText || "Без названия"
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                        }
                                    }

                                    function finishEditing() {
                                        if (taskDelegate.isEditing) {
                                            taskDelegate.isEditing = false
                                            var newText = editTextInput.text.trim()
                                            if (newText !== "" && newText !== modelData.taskText) {
                                                // Обновляем модель
                                                modelData.taskText = newText

                                                // Принудительно обновляем весь массив
                                                var dayItem = dayContainer
                                                if (dayItem) {
                                                    dayItem.dayTasks = dayItem.dayTasks.slice()
                                                }

                                                tasksListView.taskEditFinished(modelData, index, newText)
                                            }
                                        }
                                    }
                                }

                                // Подключение обработчиков сигналов
                                Component.onCompleted: {
                                    taskRightClicked.connect(function(taskData, index) {
                                        taskDetailPopup.currentTaskData = taskData
                                        taskDetailPopup.currentTaskIndex = index
                                        taskDetailPopup.currentDayIndex = dayContainer.index
                                        taskDetailPopup.open()
                                    })

                                    taskEditFinished.connect(function(taskData, index, newText) {
                                        Backend.log("Текст задачи изменен:", newText)
                                        // Автосохранение при изменении задачи
                                        saveDayData(dayContainer.index)
                                    })
                                }
                            }

                            // Кнопка добавления новой задачи
                            Button {
                                id: addButton
                                width: parent.width
                                height: 30
                                text: "+ Добавить задачу"
                                font.pixelSize: 12

                                background: Rectangle {
                                    color: parent.down ? "#e0e0e0" : "#f5f5f5"
                                    border.color: "#cccccc"
                                    border.width: 1
                                    radius: 3
                                }

                                onClicked: {
                                    // Создаем новую задачу
                                    var newTask = {
                                        taskText: "Новая задача",
                                        taskDescription: "",
                                        taskColor: "white"
                                    }

                                    // Добавляем в модель
                                    dayTasks.push(newTask)
                                    dayTasks = dayTasks.slice() // Создаем новый массив для принудительного обновления

                                    // Сразу открываем модальное окно для редактирования
                                    // Берем задачу из ОБНОВЛЕННОГО массива
                                    taskDetailPopup.currentTaskData = dayTasks[dayTasks.length - 1]
                                    taskDetailPopup.currentTaskIndex = dayTasks.length - 1
                                    taskDetailPopup.currentDayIndex = dayContainer.index
                                    taskDetailPopup.open()

                                    Backend.log("Добавлена новая задача в день:", dayName)

                                    // Автосохранение при добавлении задачи
                                    saveDayData(dayContainer.index)
                                }
                            }
                        }

                        // Свойства для данных дня
                        property string dayName: ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"][index]
                        property string dayDate: ""
                        property string originalDate: "" // Оригинальная дата из JSON для сохранения
                        property var dayTasks: []
                        property int index: model.index
                    }
                }
            }
        }

        // Область с кнопками
        Rectangle {
            id: secondField
            anchors {
                left: firstField.right
                top: parent.top
                right: parent.right
                leftMargin: 1
            }
            height: parent.height * 0.2
            color: "#fff0e6"
            border.width: 1

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                Rectangle {
                    id: buttonPanel
                    Layout.fillWidth: true
                    Layout.preferredHeight: 90
                    color: "#f5f5f5"
                    border.width: 1
                    border.color: "#dddddd"

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        spacing: 5

                        // Верхняя строка с кнопками настроек
                        RowLayout {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 40

                            Button {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                text: "⚙️"
                                font.pixelSize: 20
                                onClicked: console.log("Settings button clicked")
                            }

                            Button {
                                Layout.preferredWidth: 40
                                Layout.preferredHeight: 40
                                text: "➕"
                                font.pixelSize: 20
                                onClicked: console.log("Add button clicked")
                            }

                            Item {
                                Layout.fillWidth: true
                            }
                        }

                        // Нижняя строка с большой кнопкой
                        Button {
                            Layout.fillWidth: true
                            Layout.preferredHeight: 20
                            text: "К текущей неделе"
                            font.pixelSize: 13
                            onClicked: {
                                comboBox.currentIndex = Utils.getWeekNumber()
                            }
                        }
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#cccccc"
                }


                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 10

                        ComboBox {
                            id: comboBox
                            Layout.fillWidth: true
                            model: Backend.get_list_weeks()
                            currentIndex: -1

                            Component.onCompleted: {
                                enabled = count > 0
                                if (count > 0) {
                                    currentIndex = Utils.getWeekNumber()
                                }
                            }

                            onCurrentTextChanged: {
                                if (currentText) {
                                    Backend.read_file(currentText)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Модальное окно для детального просмотра/редактирования
    Popup {
        id: taskDetailPopup
        width: 400
        height: 300
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        property var currentTaskData: null
        property int currentTaskIndex: -1
        property int currentDayIndex: -1

        background: Rectangle {
            color: "white"
            border.color: "#cccccc"
            border.width: 1
            radius: 5
        }

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 10

            TextField {
                id: popupTitleInput
                width: parent.width
                placeholderText: "Название задачи"
                font.pixelSize: 14
            }

            TextArea {
                id: popupDescInput
                width: parent.width
                height: 150
                placeholderText: "Описание задачи"
                wrapMode: TextArea.Wrap
                font.pixelSize: 12
            }

            Row {
                spacing: 10

                Button {
                    text: "Сохранить"
                    onClicked: {
                        if (taskDetailPopup.currentTaskData) {
                            // Получаем актуальную ссылку на день и задачу
                            var dayItem = daysRepeater.itemAt(taskDetailPopup.currentDayIndex)
                            if (dayItem && dayItem.dayTasks) {
                                // Находим актуальную задачу в массиве
                                var actualTask = dayItem.dayTasks[taskDetailPopup.currentTaskIndex]
                                if (actualTask) {
                                    // Обновляем актуальную задачу
                                    actualTask.taskText = popupTitleInput.text
                                    actualTask.taskDescription = popupDescInput.text

                                    // Принудительно обновляем модель
                                    dayItem.dayTasks = dayItem.dayTasks.slice()

                                    // Автосохранение при сохранении изменений
                                    saveDayData(taskDetailPopup.currentDayIndex)
                                }
                            }
                            taskDetailPopup.close()
                        }
                    }
                }

                Button {
                    text: "Удалить"
                    onClicked: {
                        if (taskDetailPopup.currentDayIndex !== -1 && taskDetailPopup.currentTaskIndex !== -1) {
                            var dayItem = daysRepeater.itemAt(taskDetailPopup.currentDayIndex)
                            if (dayItem && dayItem.dayTasks) {
                                dayItem.dayTasks.splice(taskDetailPopup.currentTaskIndex, 1)
                                dayItem.dayTasks = dayItem.dayTasks.slice() // Принудительно обновляем модель

                                // Автосохранение при удалении задачи
                                saveDayData(taskDetailPopup.currentDayIndex)
                            }
                            taskDetailPopup.close()
                        }
                    }
                }
            }
        }

        onOpened: {
            if (currentTaskData) {
                popupTitleInput.text = currentTaskData.taskText || ""
                popupDescInput.text = currentTaskData.taskDescription || ""
                popupTitleInput.forceActiveFocus()
            }
        }

        onClosed: {
            currentTaskData = null
            currentTaskIndex = -1
            currentDayIndex = -1
        }
    }
}