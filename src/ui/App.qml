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

    Timer {
        id: assignmentTimer
        property var newTasks: null
        property var dayItem: null
        property int dayIndex: -1
        interval: 10
        onTriggered: {
            //Backend.log("выполняем присваивание")
            if (dayItem && newTasks) {
                try {
                    dayItem.dayTasks = newTasks
                    //Backend.log("МОДЕЛЬ ОБНОВЛЕНА!")

                    // Сохраняем изменения
                    //Backend.log("Сохранение данных...")
                    saveDayData(dayIndex)
                    //Backend.log("Данные сохранены!")
                } catch (e) {
                    //Backend.log("Ошибка в таймере:", e)
                }
            }
        }
    }

    // Глобальная переменная для отслеживания перетаскивания
    property var draggedTask: null

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
            interval: 3000
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
                            taskColor: task.color || "#ffffff"
                        });
                    }
                    dayItem.dayTasks = tasksModel;

                    // Инициализируем счетчик после загрузки задач
                    dayItem.lessonsCount = dayItem.countLessons();
                }
            }
        } catch (e) {
            Backend.log("Ошибка парсинга JSON:", e);
        }
    }

    // Функция для сохранения данных дня
    function saveDayData(dayIndex) {
        //Backend.log("Попытка сохранения")
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
                    "color": task.taskColor || "#ffffff"
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
        anchors.margins: root.width * 0.001

        Rectangle {
            id: firstField
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * 0.97

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
                        color: "white"
                        border.width: 1
                        border.color: "#595959"

                        property int lessonsCount: 0

                        // Функция для подсчета задач определенных цветов
                        function countLessons() {
                            var count = 0;
                            for (var i = 0; i < dayTasks.length; i++) {
                                var task = dayTasks[i];
                                if (task.taskColor === "#ffffff" || task.taskColor === "white" || task.taskColor === "#ffcccc") {
                                    count++;
                                }
                            }
                            return count;
                        }

                        // Обновляем счетчик при изменении задач
                        onDayTasksChanged: {
                            lessonsCount = countLessons();
                        }

                        property bool isToday: {
                            if (!originalDate) return false;

                            var today = new Date();
                            // Форматируем вручную в YYYY-MM-DD
                            var year = today.getFullYear();
                            var month = String(today.getMonth() + 1).padStart(2, '0');
                            var day = String(today.getDate()).padStart(2, '0');
                            var localDateString = year + '-' + month + '-' + day;

                            return originalDate === localDateString;
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 2

                            // Заголовок дня
                            Rectangle {
                                id: dayHeader
                                width: parent.width
                                height: 50  // Увеличиваем высоту для двух строк
                                color: dayContainer.isToday ? "#27ae60" : "#4a86e8"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5

                                    // Первая строка: день и дата
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20

                                        Text {
                                            text: dayName
                                            font.pixelSize: 15
                                            font.bold: true
                                            color: "white"
                                            Layout.alignment: Qt.AlignVCenter
                                        }

                                        Item { Layout.fillWidth: true } // Пустое пространство

                                        Text {
                                            text: dayDate
                                            font.pixelSize: 15
                                            color: "white"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

                                    // Вторая строка: счетчик уроков (выровнен слева)
                                    RowLayout {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 20

                                        Rectangle {
                                            Layout.alignment: Qt.AlignLeft
                                            width: 60
                                            height: 15
                                            color: "white"
                                            radius: 9

                                            Text {
                                                anchors.centerIn: parent
                                                text: "Уроков: " + dayContainer.lessonsCount
                                                font.pixelSize: 11
                                                font.bold: true
                                                color: "#333333"
                                            }
                                        }

                                        Item { Layout.fillWidth: true } // Пустое пространство справа
                                    }
                                }
                            }

                            // Область для задач
                            ListView {
                                id: tasksListView
                                width: parent.width
                                height: parent.height - dayHeader.height - addButton.height - 8
                                model: dayTasks
                                spacing: 10
                                clip: true

                                // Сигналы для внешней обработки
                                signal taskLeftClicked(var taskData, int index)
                                signal taskRightClicked(var taskData, int index)
                                signal taskEditFinished(var taskData, int index, string newText)

                                delegate: Rectangle {
                                    id: taskDelegate
                                    width: tasksListView.width - 7
                                    height: 40
                                    color: modelData.taskColor || "#ffffff"
                                    border.width: 1
                                    border.color: "#000000"
                                    radius: 8
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    property bool isEditing: false
                                    property int taskIndex: index

                                    // Свойства для перетаскивания
                                    property bool isDragging: false
                                    property int dragSourceIndex: index
                                    property int visualIndex: index

                                    // MouseArea для ЛЕВОЙ кнопки (перетаскивание)
                                    MouseArea {
                                        id: leftMouseArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton
                                        cursorShape: tasksListView.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        drag.target: tasksListView.count > 1 ? taskDelegate : null
                                        drag.axis: Drag.YAxis
                                        drag.minimumY: 0
                                        drag.maximumY: tasksListView.height - taskDelegate.height

                                        property int startIndex: index
                                        property bool isDragging: false
                                        property bool isLastElementBlocked: false

                                        onPressed: {
                                            if (tasksListView.count <= 1) {
                                                //Backend.log("перетаскивание заблокировано")
                                                return
                                            }

                                            //Backend.log("ЛЕВАЯ кнопка onPressed")
                                            taskDelegate.z = 1
                                            startIndex = index
                                            isDragging = true
                                            taskDelegate.originalY = taskDelegate.y

                                            // ВОССТАНАВЛИВАЕМ drag.target если он был отключен
                                            if (!drag.target) {
                                                drag.target = taskDelegate
                                            }
                                        }

                                        onPositionChanged: {
                                            if (tasksListView.count <= 1) return

                                            if (isDragging) {
                                                // ФИКС: Если элемент последний и его тянут ВНИЗ - постоянно возвращаем на место
                                                if (startIndex === tasksListView.count - 1) {
                                                    var originalY = startIndex * (taskDelegate.height + tasksListView.spacing) - tasksListView.contentY
                                                    if (taskDelegate.y > originalY) {
                                                        // Постоянно возвращаем на место, создавая эффект сопротивления
                                                        taskDelegate.y = originalY
                                                        return
                                                    }
                                                }

                                                var newVisualIndex = Math.round((taskDelegate.y + tasksListView.contentY) / (taskDelegate.height + tasksListView.spacing))
                                                newVisualIndex = Math.max(0, Math.min(dayTasks.length - 1, newVisualIndex))

                                                if (newVisualIndex !== taskDelegate.visualIndex) {
                                                    taskDelegate.visualIndex = newVisualIndex

                                                    for (var i = 0; i < tasksListView.count; i++) {
                                                        var otherDelegate = tasksListView.itemAt(i)
                                                        if (otherDelegate && otherDelegate !== taskDelegate) {
                                                            if (taskDelegate.visualIndex > startIndex) {
                                                                if (i > startIndex && i <= taskDelegate.visualIndex) {
                                                                    otherDelegate.y = - (taskDelegate.height + tasksListView.spacing)
                                                                } else {
                                                                    otherDelegate.y = 0
                                                                }
                                                            } else {
                                                                if (i >= taskDelegate.visualIndex && i < startIndex) {
                                                                    otherDelegate.y = taskDelegate.height + tasksListView.spacing
                                                                } else {
                                                                    otherDelegate.y = 0
                                                                }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }

                                        onReleased: {
                                            if (tasksListView.count <= 1) return

                                            //Backend.log("ЛЕВАЯ кнопка onReleased")
                                            taskDelegate.z = 0
                                            isDragging = false
                                            isLastElementBlocked = false

                                            if (taskDelegate.visualIndex !== startIndex) {
                                                //Backend.log("Позиция изменилась, обновляем модель")

                                                var dayItem = dayContainer
                                                if (dayItem && dayItem.dayTasks) {
                                                    var originalTasks = dayItem.dayTasks
                                                    var newTasks = []

                                                    for (var i = 0; i < originalTasks.length; i++) {
                                                        if (i === startIndex) continue

                                                        if (i === taskDelegate.visualIndex) {
                                                            if (taskDelegate.visualIndex < startIndex) {
                                                                newTasks.push({
                                                                    taskText: originalTasks[startIndex].taskText,
                                                                    taskDescription: originalTasks[startIndex].taskDescription,
                                                                    taskColor: originalTasks[startIndex].taskColor
                                                                })
                                                                newTasks.push({
                                                                    taskText: originalTasks[i].taskText,
                                                                    taskDescription: originalTasks[i].taskDescription,
                                                                    taskColor: originalTasks[i].taskColor
                                                                })
                                                            } else {
                                                                newTasks.push({
                                                                    taskText: originalTasks[i].taskText,
                                                                    taskDescription: originalTasks[i].taskDescription,
                                                                    taskColor: originalTasks[i].taskColor
                                                                })
                                                                newTasks.push({
                                                                    taskText: originalTasks[startIndex].taskText,
                                                                    taskDescription: originalTasks[startIndex].taskDescription,
                                                                    taskColor: originalTasks[startIndex].taskColor
                                                                })
                                                            }
                                                        } else {
                                                            newTasks.push({
                                                                taskText: originalTasks[i].taskText,
                                                                taskDescription: originalTasks[i].taskDescription,
                                                                taskColor: originalTasks[i].taskColor
                                                            })
                                                        }
                                                    }

                                                    assignmentTimer.newTasks = newTasks
                                                    assignmentTimer.dayItem = dayItem
                                                    assignmentTimer.dayIndex = dayContainer.index
                                                    assignmentTimer.start()
                                                }
                                            }

                                            resetDelegatesPosition.start()
                                        }
                                    }

                                    // MouseArea для ПРАВОЙ кнопки (меню)
                                    MouseArea {
                                        anchors.fill: parent
                                        acceptedButtons: Qt.RightButton
                                        cursorShape: Qt.PointingHandCursor

                                        onClicked: {
                                            //Backend.log("ПРАВАЯ кнопка clicked")
                                            tasksListView.taskRightClicked(modelData, index)
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
                                            height: parent.height  // если нужно вертикальное выравнивание
                                            text: modelData.taskText
                                            font.pixelSize: 14
                                            font.bold: true
                                            elide: Text.ElideRight
                                            horizontalAlignment: Text.AlignHCenter  // по горизонтали
                                            verticalAlignment: Text.AlignVCenter    // по вертикали
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
                                width: parent.width - 2
                                height: 25
                                text: "+ Добавить задачу"
                                font.pixelSize: 11
                                anchors.horizontalCenter: parent.horizontalCenter

                                onClicked: {
                                    // Создаем новую задачу
                                    var newTask = {
                                        taskText: "",
                                        taskDescription: "",
                                        taskColor: "#ffffff"
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
            height: parent.height * 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5

                Item { Layout.fillHeight: true } // Верхний спейсер

                // Навигация
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "🡰️"
                    font.pixelSize: 16
                    ToolTip.text: "Предыдущая неделя"
                    ToolTip.visible: hovered
                    onClicked: {
                        if (comboBox.count > 0) {
                            var currentIndex = comboBox.currentIndex
                            var newIndex = currentIndex > 0 ? currentIndex - 1 : comboBox.count - 1
                            comboBox.currentIndex = newIndex
                        }
                    }
                }

                Item { Layout.preferredHeight: 3 } // Отступ

                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "📍"
                    font.pixelSize: 16
                    ToolTip.text: "Перейти к текущей неделе"
                    ToolTip.visible: hovered
                    onClicked: {
                        comboBox.currentIndex = Utils.getWeekNumber()
                    }
                }

                Item { Layout.preferredHeight: 3 } // Отступ

                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "🡲️"
                    font.pixelSize: 16
                    ToolTip.text: "Следующая неделя"
                    ToolTip.visible: hovered
                    onClicked: {
                        if (comboBox.count > 0) {
                            var currentIndex = comboBox.currentIndex
                            var newIndex = currentIndex < comboBox.count - 1 ? currentIndex + 1 : 0
                            comboBox.currentIndex = newIndex
                        }
                    }
                }

                Item { Layout.preferredHeight: 3 } // Отступ

                // Кнопка копирования
                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "📋"
                    font.pixelSize: 16
                    ToolTip.text: "Перенести текущую неделю на следующую"
                    ToolTip.visible: hovered
                    onClicked: {
                        var currentWeek = comboBox.currentText || Utils.getWeekNumber()
                        if (currentWeek) {
                            Backend.copy_to_next_week(currentWeek)
                        }
                    }
                }

                Item { Layout.preferredHeight: 3 } // Отступ

                // Выбор недели
                ComboBox {
                    id: comboBox
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    model: Backend.get_list_weeks()
                    currentIndex: -1

                    ToolTip.text: "Выберите неделю для просмотра"
                    ToolTip.visible: hovered

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

                Item { Layout.preferredHeight: 3 } // Отступ

                // Кнопка настроек
                /*Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "⚙️"
                    font.pixelSize: 16
                    ToolTip.text: "Настройки"
                    ToolTip.visible: hovered
                    onClicked: console.log("Settings button clicked")
                }*/

                Item { Layout.fillHeight: true } // Нижний спейсер
            }
        }
    }

    // Модальное окно для детального просмотра/редактирования
    Popup {
        property string selectedColor: "#ffffff"

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

        Keys.onReturnPressed: {
            if (event.modifiers & Qt.ControlModifier) {
                // Ctrl+Enter работает из TextArea
                return
            }
            saveButton.clicked()
        }

        Keys.onEnterPressed: {
            if (event.modifiers & Qt.ControlModifier) {
                // Ctrl+Enter работает из TextArea
                return
            }
            saveButton.clicked()
        }

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

                background: Rectangle {
                    border.color: "#cccccc"
                    border.width: 2
                    color: "transparent"
                }

                // Обработка клавиши Enter
                Keys.onReturnPressed: {
                    saveButton.clicked()
                }
                Keys.onEnterPressed: {
                    saveButton.clicked()
                }
            }

            TextArea {
                id: popupDescInput
                width: parent.width
                height: 120
                placeholderText: "Описание задачи"
                wrapMode: TextArea.Wrap
                font.pixelSize: 12

                background: Rectangle {
                    border.color: "#cccccc"
                    border.width: 2
                    color: "transparent"
                    radius: 4
                }

                // Обработка клавиши Enter с Ctrl
                Keys.onReturnPressed: {
                    if (event.modifiers & Qt.ControlModifier) {
                        saveButton.clicked()
                    }
                }
                Keys.onEnterPressed: {
                    if (event.modifiers & Qt.ControlModifier) {
                        saveButton.clicked()
                    }
                }
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
                            { name: "Белый", color: "#ffffff" },    // Уроки
                            { name: "Красный", color: "#ffcccc" },  // Перенесенный урок
                            { name: "Серый", color: "#a8a8a8" },    // Отмена
                            { name: "Зеленый", color: "#ccffcc" },  // Дела
                            { name: "Синий", color: "#cce5ff" },
                            { name: "Желтый", color: "#ffffcc" },
                            { name: "Оранжевый", color: "#ffe6cc" },
                            { name: "Фиолетовый", color: "#e6ccff" },
                            { name: "Розовый", color: "#ffccf2" },
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
                    id: saveButton  // Добавляем id
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
                                    actualTask.taskColor = taskDetailPopup.currentTaskData.taskColor || "#ffffff"

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
                selectedColor = currentTaskData.taskColor || "#ffffff"
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