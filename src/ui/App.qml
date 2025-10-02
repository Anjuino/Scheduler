import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Window

ApplicationWindow {
    id: root
    visible: true
    width: 1366
    height: 768
    title: "Scheduler"
    //color: "#c8c8c8"

    Component.onCompleted: {
        ApplicationWindow.style = "Fusion" // или "Material", "Basic"
    }

    function print_data(message) {
        if (message) {
            textElement.text = message
        }
    }


    Rectangle {
        anchors.fill: parent
        anchors.margins: root.width * 0.01
        //color: "#fdfdfd"
        
        Rectangle {
            id: firstField
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            width: parent.width * 0.85
            color: "#e6f3ff"
            border.width: 1
            
            Text {
                id: textElement  // Добавляем id для Text элемента
                anchors.centerIn: parent
                text: "Первое поле (85% ширины, 100% высоты)"
                font.pixelSize: 16
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
                    Layout.preferredHeight: 60  
                    color: "#f5f5f5"
                    border.width: 1
                    border.color: "#dddddd"
                    
                    RowLayout {
                        anchors.fill: parent
                        anchors.margins: 5
                        
                        Button {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            text: "⚙️"
                            font.pixelSize: 20
                            
                            onClicked: {
                                console.log("Settings button clicked")
                            }
                        }
                        
                        // Можно добавить другие кнопки
                        Button {
                            Layout.preferredWidth: 40
                            Layout.preferredHeight: 40
                            text: "➕"
                            font.pixelSize: 20
                            
                            onClicked: {
                                console.log("Add button clicked")
                            }
                        }
                        
                        // Распорка чтобы прижать кнопки к правому краю
                        Item {
                            Layout.fillWidth: true
                        }
                    }
                }
                
                // Горизонтальная разделительная линия
                Rectangle {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 1
                    color: "#cccccc"
                }
                
                // Основное содержимое второго поля
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: "transparent"
                    
                    ComboBox {
                        id: comboBox
                        Layout.fillWidth: true
                        model: Backend.get_list_weaks()
                        currentIndex: -1
                        Component.onCompleted: {
                            enabled = count > 0
                        }

                        onCurrentTextChanged: {
                            Backend.read_file(currentText)
                        }
                    }

                    Text {
                        anchors.centerIn: parent
                        text: ""
                        font.pixelSize: 16
                    }
                }
            }
        }
    }
}