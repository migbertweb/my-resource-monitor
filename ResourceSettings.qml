import QtQuick
import QtQuick.Controls
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginSettings {
    id: root
    pluginId: "allMonitorsW"

    onPluginServiceChanged: intervalInput.loadValue()

    Connections {
        target: root.pluginService
        enabled: root.pluginService !== null

        function onPluginDataChanged(changedPluginId) {
            if (changedPluginId === root.pluginId)
                intervalInput.loadValue()
        }
    }

    function normalizedInterval(value) {
        var parsed = parseInt(value, 10)
        if (isNaN(parsed) || parsed < 0)
            parsed = 0
        if (parsed > 300)
            parsed = 300
        return parsed
    }

    StyledText {
        width: parent.width
        text: "Resource Monitor Settings"
        font.pixelSize: Theme.fontSizeLarge
        font.weight: Font.Bold
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Configure auto-refresh interval for CPU, memory and swap monitoring. Set to 0 to disable auto-refresh."
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.surfaceVariantText
        wrapMode: Text.WordWrap
    }

    Column {
        width: parent.width
        spacing: Theme.spacingS

        StyledText {
            text: "Auto Refresh Interval"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeMedium
            font.weight: Font.Medium
        }

        StyledText {
            text: "Seconds between refreshes (0 = off). Updates the widget continuously so the popout opens with current data."
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.WordWrap
            width: parent.width
        }

        Row {
            spacing: Theme.spacingS

            Rectangle {
                width: 80
                height: 36
                radius: Theme.cornerRadius - 4
                color: Theme.surfaceContainerHighest
                border.color: Theme.surfaceContainerHigh
                border.width: 1

                TextField {
                    id: intervalInput
                    anchors.fill: parent
                    anchors.leftMargin: 4
                    anchors.rightMargin: 4
                    verticalAlignment: TextInput.AlignVCenter
                    color: Theme.surfaceText
                    font.pixelSize: Theme.fontSizeMedium
                    background: null
                    padding: 0
                    selectByMouse: true
                    validator: IntValidator { bottom: 0; top: 300 }

                    function loadValue() {
                        text = String(root.loadValue("refreshInterval", 5))
                    }

                    Component.onCompleted: loadValue()

                    onEditingFinished: {
                        var val = root.normalizedInterval(text)
                        text = String(val)
                        root.saveValue("refreshInterval", val)
                    }
                }
            }

            StyledText {
                text: "seconds"
                color: Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    StyledText {
        width: parent.width
        text: "Element Spacing"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    StyledText {
        width: parent.width
        text: "Spacing in pixels between each monitored element in the bar."
        color: Theme.surfaceVariantText
        font.pixelSize: Theme.fontSizeSmall
        wrapMode: Text.WordWrap
    }

    Row {
        spacing: Theme.spacingS

        Rectangle {
            width: 80
            height: 36
            radius: Theme.cornerRadius - 4
            color: Theme.surfaceContainerHighest
            border.color: Theme.surfaceContainerHigh
            border.width: 1

            TextField {
                id: spacingInput
                anchors.fill: parent
                anchors.leftMargin: 4
                anchors.rightMargin: 4
                verticalAlignment: TextInput.AlignVCenter
                color: Theme.surfaceText
                font.pixelSize: Theme.fontSizeMedium
                background: null
                padding: 0
                selectByMouse: true
                validator: IntValidator { bottom: 0; top: 30 }

                function loadValue() {
                    text = String(root.loadValue("spacing", 10))
                }

                Component.onCompleted: loadValue()

                onEditingFinished: {
                    var val = parseInt(text, 10)
                    if (isNaN(val) || val < 0) val = 0
                    if (val > 30) val = 30
                    text = String(val)
                    root.saveValue("spacing", val)
                }
            }
        }

        StyledText {
            text: "px"
            color: Theme.surfaceVariantText
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    StyledText {
        width: parent.width
        text: "Visibility"
        font.pixelSize: Theme.fontSizeMedium
        font.weight: Font.Medium
        color: Theme.surfaceText
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        Switch {
            id: swapSwitch
            checked: root.loadValue("showSwap", true)
            onCheckedChanged: root.saveValue("showSwap", checked)
        }

        StyledText {
            text: "Show Swap"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }

    Row {
        width: parent.width
        spacing: Theme.spacingS

        Switch {
            id: tempSwitch
            checked: root.loadValue("showCpuTemp", true)
            onCheckedChanged: root.saveValue("showCpuTemp", checked)
        }

        StyledText {
            text: "Show CPU Temperature"
            color: Theme.surfaceText
            font.pixelSize: Theme.fontSizeSmall
            anchors.verticalCenter: parent.verticalCenter
        }
    }
}
