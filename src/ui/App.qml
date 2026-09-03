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
            if (dayItem && newTasks) {
                try {
                    dayItem.dayTasks = newTasks
                    saveDayData(dayIndex)
                } catch (e) {
                    console.log("Ошибка в таймере:", e)
                }
            }
        }
    }

    Timer {
        id: resetDelegatesPosition
        interval: 10
        onTriggered: {
            for (var i = 0; i < tasksListView.count; i++) {
                var delegate = tasksListView.itemAt(i)
                if (delegate) {
                    delegate.y = 0
                }
            }
        }
    }

    property var draggedTask: null

    function show_notification(message) {
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

    function update_week_data(jsonContent) {
        updateDaysData(jsonContent)
    }

    function refresh_current_week() {
        if (comboBox.currentText) {
            Backend.read_file(comboBox.currentText)
        }
    }

    function updateDaysData(jsonData) {
        try {
            var daysData = JSON.parse(jsonData);
            var days = daysData.days;

            for (var i = 0; i < 7; i++) {
                var day = days[i];
                var dayItem = daysRepeater.itemAt(i);

                if (dayItem) {
                    dayItem.originalDate = day.date;
                    dayItem.dayDate = Utils.formatDate(day.date);

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
                    dayItem.lessonsCount = dayItem.countLessons();
                }
            }
        } catch (e) {
            console.log("Ошибка парсинга JSON:", e);
        }
    }

    function saveDayData(dayIndex) {
        try {
            var dayItem = daysRepeater.itemAt(dayIndex);
            if (!dayItem) return;

            var currentWeek = comboBox.currentText || Utils.getWeekNumber();
            if (!currentWeek) return;

            var dayData = {
                "date": dayItem.originalDate,
                "day": dayItem.dayName,
                "tasks": []
            };

            for (var j = 0; j < dayItem.dayTasks.length; j++) {
                var task = dayItem.dayTasks[j];
                dayData.tasks.push({
                    "task": task.taskText || "",
                    "description": task.taskDescription || "",
                    "color": task.taskColor || "#ffffff"
                });
            }

            Backend.save_day_data(currentWeek, dayIndex, JSON.stringify(dayData));

        } catch (e) {
            console.log("Ошибка сохранения дня:", e);
        }
    }

    Rectangle {
        id: notification
        width: 400
        height: 60
        x: (parent.width - width) / 2
        y: 30
        color: "#ccffcc"
        radius: 8
        border.color: "#66cc66"
        border.width: 2
        visible: false
        z: 9999
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

                        function countLessons() {
                            var count = 0;
                            for (var i = 0; i < dayTasks.length; i++) {
                                var task = dayTasks[i];
                                if (task.taskText) {
                                    if (task.taskColor === "#ffffff" || task.taskColor === "white" || task.taskColor === "#ffccf2" || task.taskColor === "#ffcccc") {
                                        count++;
                                    }
                                }
                            }
                            return count;
                        }

                        onDayTasksChanged: {
                            lessonsCount = countLessons();
                        }

                        property bool isToday: {
                            if (!originalDate) return false;

                            var today = new Date();
                            var year = today.getFullYear();
                            var month = String(today.getMonth() + 1).padStart(2, '0');
                            var day = String(today.getDate()).padStart(2, '0');
                            var localDateString = year + '-' + month + '-' + day;

                            return originalDate === localDateString;
                        }

                        Column {
                            anchors.fill: parent
                            spacing: 2

                            Rectangle {
                                id: dayHeader
                                width: parent.width
                                height: 50
                                color: dayContainer.isToday ? "#27ae60" : "#4a86e8"

                                ColumnLayout {
                                    anchors.fill: parent
                                    anchors.margins: 5

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

                                        Item { Layout.fillWidth: true }

                                        Text {
                                            text: dayDate
                                            font.pixelSize: 15
                                            color: "white"
                                            Layout.alignment: Qt.AlignVCenter
                                        }
                                    }

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

                                        Item { Layout.fillWidth: true }
                                    }
                                }
                            }

                            ListView {
                                id: tasksListView
                                width: parent.width
                                height: parent.height - dayHeader.height - addButton.height - 8
                                model: dayTasks
                                spacing: 10
                                clip: true

                                signal taskLeftClicked(var taskData, int index)
                                signal taskRightClicked(var taskData, int index)
                                signal taskEditFinished(var taskData, int index, string newText)

                                delegate: Rectangle {
                                    id: taskDelegate
                                    width: tasksListView.width - 7
                                    height: 60
                                    color: modelData.taskColor || "#ffffff"
                                    border.width: 1
                                    border.color: "#000000"
                                    radius: 8
                                    anchors.horizontalCenter: parent.horizontalCenter

                                    property bool isEditing: false
                                    property int taskIndex: index
                                    property bool isDragging: false
                                    property int dragSourceIndex: index
                                    property int visualIndex: index

                                    // Текст с переносом и обрезкой
                                    Text {
                                        id: textItem
                                        width: parent.width - 20
                                        anchors.centerIn: parent
                                        text: modelData.taskText
                                        font.pixelSize: 14
                                        font.bold: true
                                        wrapMode: Text.Wrap
                                        elide: Text.ElideRight
                                        maximumLineCount: 3
                                        horizontalAlignment: Text.AlignHCenter
                                        verticalAlignment: Text.AlignVCenter
                                    }

                                    // ОДИН MouseArea для ВСЕХ кнопок
                                    MouseArea {
                                        id: mouseArea
                                        anchors.fill: parent
                                        acceptedButtons: Qt.LeftButton | Qt.RightButton
                                        cursorShape: tasksListView.count > 1 ? Qt.PointingHandCursor : Qt.ArrowCursor
                                        drag.target: tasksListView.count > 1 ? taskDelegate : null
                                        drag.axis: Drag.YAxis
                                        drag.minimumY: 0
                                        drag.maximumY: tasksListView.height - taskDelegate.height
                                        hoverEnabled: true

                                        // ТУЛТИП ДЛЯ ОПИСАНИЯ
                                        ToolTip.text: modelData.taskDescription || ""
                                        ToolTip.visible: containsMouse && modelData.taskDescription

                                        property int startIndex: index
                                        property bool isDragging: false
                                        property bool isLastElementBlocked: false

                                        onPressed: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (tasksListView.count <= 1) {
                                                    return
                                                }

                                                taskDelegate.z = 1
                                                startIndex = index
                                                isDragging = true
                                                taskDelegate.originalY = taskDelegate.y

                                                if (!drag.target) {
                                                    drag.target = taskDelegate
                                                }
                                            }
                                        }

                                        onPositionChanged: (mouse) => {
                                            if (tasksListView.count <= 1) return

                                            if (isDragging) {
                                                if (startIndex === tasksListView.count - 1) {
                                                    var originalY = startIndex * (taskDelegate.height + tasksListView.spacing) - tasksListView.contentY
                                                    if (taskDelegate.y > originalY) {
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

                                        onReleased: (mouse) => {
                                            if (mouse.button === Qt.LeftButton) {
                                                if (tasksListView.count <= 1) return

                                                taskDelegate.z = 0
                                                isDragging = false
                                                isLastElementBlocked = false

                                                if (taskDelegate.visualIndex !== startIndex) {
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

                                        onClicked: (mouse) => {
                                            if (mouse.button === Qt.RightButton) {
                                                tasksListView.taskRightClicked(modelData, index)
                                            } else if (mouse.button === Qt.LeftButton && !isDragging) {
                                                tasksListView.taskLeftClicked(modelData, index)
                                            }
                                        }
                                    }

                                    function finishEditing() {
                                        if (taskDelegate.isEditing) {
                                            taskDelegate.isEditing = false
                                            var newText = editTextInput.text.trim()
                                            if (newText !== "" && newText !== modelData.taskText) {
                                                modelData.taskText = newText

                                                var dayItem = dayContainer
                                                if (dayItem) {
                                                    dayItem.dayTasks = dayItem.dayTasks.slice()
                                                }

                                                tasksListView.taskEditFinished(modelData, index, newText)
                                            }
                                        }
                                    }
                                }

                                Component.onCompleted: {
                                    taskRightClicked.connect(function(taskData, index) {
                                        taskDetailPopup.currentTaskData = taskData
                                        taskDetailPopup.currentTaskIndex = index
                                        taskDetailPopup.currentDayIndex = dayContainer.index
                                        taskDetailPopup.open()
                                    })

                                    taskEditFinished.connect(function(taskData, index, newText) {
                                        console.log("Текст задачи изменен:", newText)
                                        saveDayData(dayContainer.index)
                                    })
                                }
                            }

                            Button {
                                id: addButton
                                width: parent.width - 2
                                height: 25
                                text: "+ Добавить задачу"
                                font.pixelSize: 11
                                anchors.horizontalCenter: parent.horizontalCenter

                                onClicked: {
                                    var newTask = {
                                        taskText: "",
                                        taskDescription: "",
                                        taskColor: "#ffffff"
                                    }

                                    dayTasks.push(newTask)
                                    dayTasks = dayTasks.slice()

                                    taskDetailPopup.currentTaskData = dayTasks[dayTasks.length - 1]
                                    taskDetailPopup.currentTaskIndex = dayTasks.length - 1
                                    taskDetailPopup.currentDayIndex = dayContainer.index
                                    taskDetailPopup.open()

                                    saveDayData(dayContainer.index)
                                }
                            }
                        }

                        property string dayName: ["Понедельник", "Вторник", "Среда", "Четверг", "Пятница", "Суббота", "Воскресенье"][index]
                        property string dayDate: ""
                        property string originalDate: ""
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
            height: parent.height * 1

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 5

                Item { Layout.fillHeight: true }

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

                Item { Layout.preferredHeight: 3 }

Button {
    Layout.preferredWidth: 30
    Layout.preferredHeight: 30
    Layout.alignment: Qt.AlignHCenter
    text: "📍"
    font.pixelSize: 16
    ToolTip.text: "Перейти к текущей неделе и году"
    ToolTip.visible: hovered
    onClicked: {
        // Получаем текущую неделю
        var currentWeek = Utils.getWeekNumber();

        // Получаем текущий год
        var currentYear = new Date().getFullYear().toString();

        // Устанавливаем текущий год в yearBox
        var yearIndex = yearBox.model.indexOf(currentYear);
        if (yearIndex !== -1) {
            yearBox.currentIndex = yearIndex;
        } else {
            // Если текущего года нет в списке, выбираем первый доступный
            yearBox.currentIndex = 0;
        }

        // Устанавливаем текущую неделю в comboBox
        comboBox.currentIndex = currentWeek;
    }
}

                Item { Layout.preferredHeight: 3 }

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

                Item { Layout.preferredHeight: 3 }

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

                Item { Layout.preferredHeight: 3 }

                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "↩️"
                    font.pixelSize: 16
                    ToolTip.text: "Отменить последнее действие"
                    ToolTip.visible: hovered
                    onClicked: {
                        Backend.undo_last_action()
                    }
                }

                Item { Layout.preferredHeight: 3 }

                ComboBox {
                    id: yearBox
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    model: ["2025", "2026", "2027", "2028", "2029", "2030"]
                    // currentIndex будет установлен в Component.onCompleted
                    property bool skipFirstChange: true

                    ToolTip.text: "Выберите год для просмотра"
                    ToolTip.visible: hovered

                    Component.onCompleted: {
                        // Получаем текущий год
                        var currentYear = new Date().getFullYear().toString();

                        // Находим индекс текущего года в списке
                        var yearIndex = model.indexOf(currentYear);

                        if (yearIndex !== -1) {
                            // Устанавливаем текущий год
                            currentIndex = yearIndex;
                        } else {
                            // Если текущего года нет в списке, устанавливаем первый элемент
                            currentIndex = 0;
                        }

                        skipFirstChange = false;
                    }

                    onCurrentTextChanged: {
                        if (skipFirstChange) return

                        if(currentText) {
                            var message = "Выбран " + currentText + " год"
                            show_notification(message)
                            Backend.change_year(currentText)

                            if (comboBox.currentText) {
                                Backend.read_file(comboBox.currentText)
                            }
                        }
                    }
                }

                Item { Layout.preferredHeight: 3 }

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

                Item { Layout.preferredHeight: 3 }

                Button {
                    Layout.preferredWidth: 30
                    Layout.preferredHeight: 30
                    Layout.alignment: Qt.AlignHCenter
                    text: "📊"
                    font.pixelSize: 16
                    ToolTip.text: "Статистика"
                    ToolTip.visible: hovered
                    onClicked: {
                        statisticsPopup.open()
                    }
                }

                Item { Layout.preferredHeight: 3 }

                Item { Layout.fillHeight: true }
            }
        }
    }

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
                return
            }
            saveButton.clicked()
        }

        Keys.onEnterPressed: {
            if (event.modifiers & Qt.ControlModifier) {
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
                            { name: "Белый", color: "#ffffff" },
                            { name: "Красный", color: "#ffcccc" },
                            { name: "Серый", color: "#a8a8a8" },
                            { name: "Зеленый", color: "#ccffcc" },
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
                    id: saveButton
                    text: "Сохранить"
                    onClicked: {
                        if (taskDetailPopup.currentTaskData) {
                            var dayItem = daysRepeater.itemAt(taskDetailPopup.currentDayIndex)
                            if (dayItem && dayItem.dayTasks) {
                                var actualTask = dayItem.dayTasks[taskDetailPopup.currentTaskIndex]
                                if (actualTask) {
                                    actualTask.taskText = popupTitleInput.text
                                    actualTask.taskDescription = popupDescInput.text
                                    actualTask.taskColor = taskDetailPopup.currentTaskData.taskColor || "#ffffff"

                                    dayItem.dayTasks = dayItem.dayTasks.slice()
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
                                dayItem.dayTasks = dayItem.dayTasks.slice()
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

    Popup {
        id: statisticsPopup
        width: 600
        height: 400
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        modal: true
        focus: true
        closePolicy: Popup.CloseOnEscape | Popup.CloseOnPressOutside

        background: Rectangle {
            color: "white"
            border.color: "#cccccc"
            border.width: 2
            radius: 8
        }

        property var monthsModel: [
            { text: "Январь", value: 1 },
            { text: "Февраль", value: 2 },
            { text: "Март", value: 3 },
            { text: "Апрель", value: 4 },
            { text: "Май", value: 5 },
            { text: "Июнь", value: 6 },
            { text: "Июль", value: 7 },
            { text: "Август", value: 8 },
            { text: "Сентябрь", value: 9 },
            { text: "Октябрь", value: 10 },
            { text: "Ноябрь", value: 11 },
            { text: "Декабрь", value: 12 }
        ]

        contentItem: Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 15

            Text {
                font.bold: true
                font.pixelSize: 20
                color: "#333333"
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Rectangle {
                width: parent.width
                height: 1
                color: "#cccccc"
            }

            // Выпадающий список месяцев
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "Месяц:"
                    font.pixelSize: 14
                    color: "#333333"
                }

                ComboBox {
                    id: monthComboBox
                    width: parent.width
                    model: statisticsPopup.monthsModel
                    textRole: "text"
                    currentIndex: new Date().getMonth() // Текущий месяц по умолчанию
                }
            }

            // Поле ввода имени ученика
            Column {
                width: parent.width
                spacing: 5

                Text {
                    text: "Имя ученика:"
                    font.pixelSize: 14
                    color: "#333333"
                }

                TextField {
                    id: studentNameInput
                    width: parent.width
                    placeholderText: "Введите имя ученика"
                    font.pixelSize: 14

                    background: Rectangle {
                        border.color: "#cccccc"
                        border.width: 1
                        radius: 4
                    }
                }
            }

            // Кнопка поиска
            Button {
                text: "Найти"
                width: 100
                anchors.right: parent.right
                onClicked: {
                    var monthData = monthComboBox.currentValue
                    var monthNumber = monthData ? monthData.value : 0
                    var studentName = studentNameInput.text.trim()

                    if (studentName === "") {
                        show_notification("Введите имя ученика")
                        return
                    }

                    var result = Backend.get_statistics(monthNumber, studentName)

                    if (result === "") {
                        show_notification("Ошибка при получении статистики")
                        resultsText.text = "Данные не найдены"

                    } else resultsText.text = result

                }
            }

            Rectangle {
                id: resultsArea
                width: parent.width
                height: 100
                radius: 8
                border.color: "#dee2e6"
                border.width: 2

                Text {
                    id: resultsText
                    anchors.fill: parent
                    anchors.margins: 10
                    text: ""
                    font.pixelSize: 14
                    color: "#6c757d"
                    wrapMode: Text.Wrap
                    verticalAlignment: Text.AlignVCenter
                    horizontalAlignment: Text.AlignLeft
                }
            }
        }
    }
}