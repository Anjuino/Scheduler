import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: appWindow
    width: 800
    height: 600
    visible: true
    title: "LogViewer"

    property string startPage: "pages/test.qml"
    property string appPage: "pages/App.qml"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: startPage
    }

    // Функция навигации
    function navigateTo(pageUrl) {
        Backend.log("Переход на: " + pageUrl)
        stackView.push(pageUrl)
    }
}