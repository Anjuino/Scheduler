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
                    // Обновляем название и дату
                    //dayItem.dayName = day.day;
                    dayItem.dayDate = Utils.formatDate(day.date);

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
            Backend.log("Ошибка парсинга JSON:", e);
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
                                            if (mouse.button === Qt.LeftButton) {
                                                // Левый клик - начинаем редактирование
                                                taskDelegate.isEditing = true
                                                editTextInput.forceActiveFocus()
                                                editTextInput.selectAll()
                                                tasksListView.taskLeftClicked(modelData, index)
                                            } else if (mouse.button === Qt.RightButton) {
                                                // Правый клик - открываем модальное окно
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

                                    // Поле ввода для редактирования (отображается при редактировании)
                                    TextInput {
                                        id: editTextInput
                                        anchors.fill: parent
                                        anchors.margins: 2
                                        visible: taskDelegate.isEditing
                                        text: modelData.taskText || ""
                                        font.pixelSize: 14
                                        font.bold: true
                                        verticalAlignment: TextInput.AlignVCenter

                                        // Завершаем редактирование при нажатии Enter или потере фокуса
                                        onAccepted: {
                                            finishEditing()
                                        }

                                        onActiveFocusChanged: {
                                            if (!activeFocus && taskDelegate.isEditing) {
                                                finishEditing()
                                            }
                                        }

                                        Keys.onEscapePressed: {
                                            taskDelegate.isEditing = false
                                            editTextInput.text = modelData.taskText || ""
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
                                        console.log("Текст задачи изменен:", newText)
                                        // Здесь можно сохранить изменения в базу данных или обновить модель
                                        // Например: Backend.updateTask(dayContainer.index, index, newText)
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
                                    taskDetailPopup.currentTaskData = dayTasks[dayTasks.length - 1]
                                    taskDetailPopup.currentTaskIndex = dayTasks.length - 1
                                    taskDetailPopup.currentDayIndex = dayContainer.index
                                    taskDetailPopup.open()

                                    console.log("Добавлена новая задача в день:", dayName)
                                }
                            }
                        }

                        // Свойства для данных дня
                        property string dayName: ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"][index]
                        property string dayDate: ""
                        property var dayTasks: []
                        property int index: model.index
                    }
                }
            }
        }

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
                                Backend.read_file(Utils.getWeekNumber())
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

    // Модальное окно для детального просмотра/редактирования (добавлено в корень)
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

            Text {
                text: "Детали задачи"
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
                            taskDetailPopup.currentTaskData.taskText = popupTitleInput.text
                            taskDetailPopup.currentTaskData.taskDescription = popupDescInput.text

                            // Полностью перезагружаем модель
                            var dayItem = daysRepeater.itemAt(taskDetailPopup.currentDayIndex)
                            if (dayItem) {
                                var currentTasks = dayItem.dayTasks
                                dayItem.dayTasks = []
                                dayItem.dayTasks = currentTasks
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