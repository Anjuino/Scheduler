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

    // Функция для отображения результата копирования
    function show_copy_result(message) {
        notificationText.text = message
        if (message.includes("Ошибка")) {
            notification.color = "#ffcccc"
            notification.border.color = "#ff6666"
        } else {
            notification.color = "#ccffcc"
            notification.border.color = "#66cc66"
        }

        showAnimation.start()
        notificationTimer.start()
    }

    // Простое уведомление как Rectangle
    Rectangle {
        id: notification
        width: 400
        height: 60
        x: (parent.width - width) / 2
        y: 30  // Чуть выше для лучшей видимости
        color: "#ccffcc"
        radius: 8
        border.color: "#66cc66"
        border.width: 2
        visible: false
        z: 9999

        // Начальные значения для анимации
        opacity: 0
        scale: 0.8
        transformOrigin: Item.Center

        Text {
            id: notificationText
            anchors.centerIn: parent
            text: ""
            color: "#333333"
            font.pixelSize: 14
            font.bold: true
        }

        Timer {
            id: notificationTimer
            interval: 2000
            onTriggered: hideAnimation.start()
        }

        // Анимация появления
        SequentialAnimation {
            id: showAnimation
            onStarted: notification.visible = true
            ParallelAnimation {
                NumberAnimation {
                    target: notification
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: 300
                    easing.type: Easing.OutCubic
                }
                NumberAnimation {
                    target: notification
                    property: "scale"
                    from: 0.8
                    to: 1
                    duration: 400
                    easing.type: Easing.OutBack
                }
            }
        }

        // Анимация исчезновения
        SequentialAnimation {
            id: hideAnimation
            ParallelAnimation {
                NumberAnimation {
                    target: notification
                    property: "opacity"
                    from: 1
                    to: 0
                    duration: 300
                    easing.type: Easing.InCubic
                }
                NumberAnimation {
                    target: notification
                    property: "scale"
                    from: 1
                    to: 0.8
                    duration: 300
                    easing.type: Easing.InCubic
                }
            }
            onFinished: notification.visible = false
        }
    }

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

                        property bool isToday: {
                            if (!originalDate) return false;
                            var today = new Date();
                            var todayString = today.toISOString().split('T')[0];
                            return originalDate === todayString;
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 2

                            // Заголовок дня
                            Rectangle {
                                id: dayHeader
                                width: parent.width
                                height: 30
                                color: dayContainer.isToday ? "#27ae60" : "#4a86e8"  // Зеленый если сегодня, синий если нет

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

                                    //Backend.log("Добавлена новая задача в день:", dayName)

                                    saveDayData(dayContainer.index)
                                }
                            }
                        }

                        // Свойства для данных дня
                        property string dayName: ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"][index]
                        property string dayDate: ""
                        property string originalDate: ""
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
                                onClicked: {
                                    var currentWeek = comboBox.currentText || Utils.getWeekNumber()
                                    if (currentWeek) {
                                        Backend.copy_to_next_week(currentWeek)
                                    }
                                }
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
        property string selectedColor: "white"

        id: taskDetailPopup
        width: 450
        height: 350
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
            anchors.margins: 15
            spacing: 15

            Text {
                text: "Редактирование задачи"
                font.bold: true
                font.pixelSize: 16
                color: "#333333"
            }

            TextField {
                id: popupTitleInput
                width: parent.width
                placeholderText: "Название задачи"
                font.pixelSize: 14
            }

            TextArea {
                id: popupDescInput
                width: parent.width
                height: 120
                placeholderText: "Описание задачи"
                wrapMode: TextArea.Wrap
                font.pixelSize: 12
            }

            // Выбор цвета
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "Цвет задачи:"
                    font.pixelSize: 14
                    color: "#333333"
                }

                Flow {
                    width: parent.width
                    spacing: 5

                    Repeater {
                        model: [
                            { name: "Белый", color: "white" },
                            { name: "Красный", color: "#ffcccc" },
                            { name: "Зеленый", color: "#ccffcc" },
                            { name: "Синий", color: "#cce5ff" },
                            { name: "Желтый", color: "#ffffcc" },
                            { name: "Оранжевый", color: "#ffe6cc" },
                            { name: "Фиолетовый", color: "#e6ccff" },
                            { name: "Розовый", color: "#ffccf2" }
                        ]

                        Rectangle {
                            width: 30
                            height: 30
                            radius: 15
                            color: modelData.color
                            border.width: taskDetailPopup.selectedColor === modelData.color ? 3 : 1
                            border.color: taskDetailPopup.selectedColor === modelData.color ? "#4a86e8" : "#cccccc"

                            MouseArea {
                                anchors.fill: parent
                                onClicked: {
                                    if (taskDetailPopup.currentTaskData) {
                                        taskDetailPopup.currentTaskData.taskColor = modelData.color
                                        taskDetailPopup.selectedColor = modelData.color
                                    }
                                }
                            }

                            ToolTip.visible: containsMouse
                            ToolTip.text: modelData.name
                        }
                    }
                }
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
                                    actualTask.taskColor = taskDetailPopup.currentTaskData.taskColor

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
                selectedColor = currentTaskData.taskColor || "white"
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