import QtQuick
import qs.Common
import qs.Widgets
import qs.Modules.Plugins

PluginComponent {
    id: root
    pluginId: "resourceMonitor"

    readonly property int refreshIntervalSeconds: {
        var value = parseInt(pluginData.refreshInterval, 10)
        if (isNaN(value) || value < 0)
            return 5

        return value
    }
    readonly property int refreshIntervalMs: refreshIntervalSeconds * 1000
    readonly property string sampleRequestId: pluginId + "-" + Math.random().toString(36).slice(2)
    readonly property var sampleCommand: ["bash", "-c", "MEMS=($(awk '/MemTotal/{t=$2} /MemAvailable/{a=$2} END{print t, a, (t-a)*100/t}' /proc/meminfo)); " +
        "SWAPS=($(awk '/SwapTotal/{t=$2} /SwapFree/{f=$2} END{if(t>0) print t, f, (t-f)*100/t; else print 0, 0, 0}' /proc/meminfo)); " +
        "PREV_IDLE=$(awk '/^cpu / {print $5}' /proc/stat); " +
        "PREV_TOTAL=$(awk '/^cpu / {for(i=2;i<=NF;i++) t+=$i; print t}' /proc/stat); " +
        "sleep 1; " +
        "CUR_IDLE=$(awk '/^cpu / {print $5}' /proc/stat); " +
        "CUR_TOTAL=$(awk '/^cpu / {for(i=2;i<=NF;i++) t+=$i; print t}' /proc/stat); " +
        "CPU=$(( (100 * (CUR_TOTAL - CUR_IDLE - PREV_TOTAL + PREV_IDLE)) / (CUR_TOTAL - PREV_TOTAL) )); " +
        "echo MEM:${MEMS[0]},${MEMS[1]},${MEMS[2]}; " +
        "echo SWP:${SWAPS[0]},${SWAPS[1]},${SWAPS[2]}; " +
        "echo CPU:${CPU}"]

    property bool loadingState: false
    property bool hasData: false
    property string lastError: ""
    property double memPercent: 0
    property double swapPercent: 0
    property double cpuPercent: 0
    property double memTotalKB: 0
    property double memAvailableKB: 0
    property double swapTotalKB: 0
    property double swapFreeKB: 0

    function formatKB(kb) {
        return (kb / (1024 * 1024)).toFixed(1) + " GB"
    }

    function formatPercent(pct) {
        var rounded = Math.round(pct)
        return rounded > 99 ? "99" : String(rounded)
    }

    function usageColor(pct) {
        return pct >= 80 ? Theme.error : Theme.primary
    }

    function applySampleOutput(output) {
        var lines = (output || "").trim().split('\n')
        var parsedAny = false

        for (var i = 0; i < lines.length; i++) {
            var line = lines[i].trim()
            var parts

            if (line.startsWith("MEM:")) {
                parts = line.substring(4).split(',')
                if (parts.length >= 3) {
                    memTotalKB = parseFloat(parts[0]) || 0
                    memAvailableKB = parseFloat(parts[1]) || 0
                    memPercent = parseFloat(parts[2]) || 0
                    parsedAny = true
                }
            } else if (line.startsWith("SWP:")) {
                parts = line.substring(4).split(',')
                if (parts.length >= 3) {
                    swapTotalKB = parseFloat(parts[0]) || 0
                    swapFreeKB = parseFloat(parts[1]) || 0
                    swapPercent = parseFloat(parts[2]) || 0
                    parsedAny = true
                }
            } else if (line.startsWith("CPU:")) {
                cpuPercent = parseFloat(line.substring(4)) || 0
                parsedAny = true
            }
        }

        if (parsedAny) {
            hasData = true
            lastError = ""
        } else {
            lastError = "Refresh returned no parseable data."
        }
    }

    function scanResources() {
        if (loadingState)
            return

        loadingState = true
        lastError = ""

        Proc.runCommand(sampleRequestId, sampleCommand, (output, exitCode) => {
            root.loadingState = false

            if (exitCode !== 0) {
                root.lastError = "Refresh failed (exit code " + exitCode + ")."
                return
            }

            root.applySampleOutput(output)
        }, 0, 5000)
    }

    onRefreshIntervalMsChanged: {
        if (root.refreshIntervalMs > 0)
            refreshTimer.restart()
        else
            refreshTimer.stop()
    }

    Timer {
        id: refreshTimer
        interval: root.refreshIntervalMs > 0 ? root.refreshIntervalMs : 1000
        repeat: true
        running: root.refreshIntervalMs > 0
        triggeredOnStart: true
        onTriggered: root.scanResources()
    }

    component ResourceRingIcon: Item {
        id: ringRoot
        required property double value
        required property color ringColor
        required property string iconName
        property bool ringVisible: true
        property real iconOpacity: 0.8

        width: 28
        height: 28

        Canvas {
            anchors.fill: parent
            visible: ringRoot.ringVisible

            onVisibleChanged: requestPaint()
            Connections {
                target: ringRoot

                function onValueChanged() {
                    ringCanvas.requestPaint()
                }

                function onRingColorChanged() {
                    ringCanvas.requestPaint()
                }
            }

            id: ringCanvas

            onPaint: {
                var ctx = getContext("2d")
                var w = width
                var h = height
                var cx = w / 2
                var cy = h / 2
                var r = w / 2 - 2
                var angle = (Math.min(ringRoot.value, 100) / 100) * Math.PI * 2

                ctx.clearRect(0, 0, w, h)

                ctx.beginPath()
                ctx.arc(cx, cy, r, 0, Math.PI * 2)
                ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.15)
                ctx.lineWidth = 3
                ctx.stroke()

                ctx.beginPath()
                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + angle)
                ctx.strokeStyle = ringRoot.ringColor
                ctx.lineWidth = 3
                ctx.lineCap = "round"
                ctx.stroke()
            }
        }

        DankIcon {
            anchors.centerIn: parent
            name: ringRoot.iconName
            size: 15
            color: Theme.surfaceText
            opacity: ringRoot.iconOpacity
        }
    }

    horizontalBarPill: Component {
        Row {
            spacing: Theme.spacingM
            anchors.verticalCenter: parent.verticalCenter

            ResourceRingIcon {
                value: root.memPercent
                ringColor: root.usageColor(root.memPercent)
                iconName: "memory"
                ringVisible: root.hasData
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.hasData ? root.formatPercent(root.memPercent) : "--"
                color: root.hasData ? root.usageColor(root.memPercent) : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            ResourceRingIcon {
                value: root.swapPercent
                ringColor: root.usageColor(root.swapPercent)
                iconName: "swap_horiz"
                ringVisible: root.hasData && root.swapTotalKB > 0
                iconOpacity: root.swapTotalKB > 0 ? 0.8 : 0.3
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.hasData && root.swapTotalKB > 0 ? root.formatPercent(root.swapPercent) : "--"
                color: root.hasData && root.swapTotalKB > 0 ? root.usageColor(root.swapPercent) : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }

            ResourceRingIcon {
                value: root.cpuPercent
                ringColor: root.usageColor(root.cpuPercent)
                iconName: "speed"
                ringVisible: root.hasData
                anchors.verticalCenter: parent.verticalCenter
            }

            StyledText {
                text: root.hasData ? root.formatPercent(root.cpuPercent) : "--"
                color: root.hasData ? root.usageColor(root.cpuPercent) : Theme.surfaceVariantText
                font.pixelSize: Theme.fontSizeSmall
                font.weight: Font.Medium
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    popoutWidth: 420
    popoutHeight: 230

    popoutContent: Component {
        PopoutComponent {
            headerText: "Resource Monitor"
            showCloseButton: true

            Component.onCompleted: root.scanResources()

            Item {
                width: parent.width
                implicitHeight: mainCol.implicitHeight + Theme.spacingL * 2

                Column {
                    id: mainCol
                    x: Theme.spacingL
                    y: Theme.spacingL
                    width: parent.width - Theme.spacingL * 2
                    spacing: Theme.spacingM

                    Row {
                        width: parent.width
                        spacing: Theme.spacingL

                        Column {
                            width: (parent.width - Theme.spacingL) / 3
                            spacing: Theme.spacingS

                            StyledText { text: "RAM"; color: Theme.surfaceText; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSizeMedium }
                            StyledText { text: "Used: " + root.formatKB(root.memTotalKB - root.memAvailableKB); color: root.usageColor(root.memPercent); font.pixelSize: Theme.fontSizeSmall }
                            StyledText { text: "Free: " + root.formatKB(root.memAvailableKB); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                            StyledText { text: "Total: " + root.formatKB(root.memTotalKB); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }

                        Column {
                            width: (parent.width - Theme.spacingL) / 3
                            spacing: Theme.spacingS
                            visible: root.swapTotalKB > 0

                            StyledText { text: "Swap"; color: Theme.surfaceText; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSizeMedium }
                            StyledText { text: "Used: " + root.formatKB(root.swapTotalKB - root.swapFreeKB); color: root.usageColor(root.swapPercent); font.pixelSize: Theme.fontSizeSmall }
                            StyledText { text: "Free: " + root.formatKB(root.swapFreeKB); color: Theme.surfaceText; font.pixelSize: Theme.fontSizeSmall }
                            StyledText { text: "Total: " + root.formatKB(root.swapTotalKB); color: Theme.surfaceVariantText; font.pixelSize: Theme.fontSizeSmall }
                        }

                        Column {
                            width: (parent.width - Theme.spacingL) / 3
                            spacing: Theme.spacingS

                            StyledText { text: "CPU"; color: Theme.surfaceText; font.weight: Font.DemiBold; font.pixelSize: Theme.fontSizeMedium }
                            StyledText { text: "Load: " + Math.round(root.cpuPercent) + "%"; color: root.usageColor(root.cpuPercent); font.pixelSize: Theme.fontSizeSmall }
                        }
                    }

                    StyledText {
                        visible: !root.hasData && root.loadingState
                        text: "Collecting first sample..."
                        color: Theme.primary
                        font.pixelSize: Theme.fontSizeSmall
                        width: parent.width
                    }

                    StyledText {
                        visible: root.lastError.length > 0
                        text: root.lastError
                        color: Theme.error
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }

                    StyledText {
                        visible: root.refreshIntervalSeconds === 0
                        text: "Auto-refresh is off. This popout still takes one fresh sample when opened."
                        color: Theme.surfaceVariantText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.WordWrap
                        width: parent.width
                    }
                }
            }
        }
    }
}
