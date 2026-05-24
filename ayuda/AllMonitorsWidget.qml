import QtQuick
import Quickshell
import qs.Common
import qs.Services
import qs.Widgets
import qs.Modules.Plugins

/**
 * AllMonitorsWidget.qml
 * Este widget muestra monitores del sistema (CPU, RAM, Disco, etc.) en la barra de la shell.
 * Soporta orientaciones tanto horizontales como verticales.
 */
PluginComponent {
    id: root

    layerNamespacePlugin: "all-monitors"

    property var popoutService: null

    pillClickAction: (x, y, width, section, screen) => {
        console.log("AllMonitors: pillClickAction called", x, y, width, section, screen);
        console.log("AllMonitors: popoutService is", popoutService);
        DgopService.setSortBy("cpu");
        popoutService?.toggleProcessList(x, y, width, section, screen);
    }

    // --- PROPIEDADES DE CONFIGURACIÓN ---
    // Estas propiedades están vinculadas a 'pluginData', que proviene de 'AllMonitorsSettings.qml'.
    // Puedes añadir más propiedades aquí si añades más ajustes en los settings.
    readonly property bool showCpuUsage: pluginData.showCpuUsage !== undefined ? pluginData.showCpuUsage : true
    readonly property bool showCpuTemp: pluginData.showCpuTemp !== undefined ? pluginData.showCpuTemp : true
    readonly property bool showRam: pluginData.showRam !== undefined ? pluginData.showRam : true
    readonly property bool showSwap: pluginData.showSwap !== undefined ? pluginData.showSwap : false
    readonly property bool showDisk: pluginData.showDisk !== undefined ? pluginData.showDisk : true
    readonly property string diskMountPath: pluginData.diskMountPath || "/"
    readonly property int spacing: pluginData.spacing !== undefined ? pluginData.spacing : 10

    // --- LÓGICA DE MONITOREO ---
    // Los datos se obtienen de 'DgopService', que proporciona estadísticas del sistema en tiempo real.
    
    // Cálculo de Swap: (Usado / Total) * 100
    readonly property real swapUsage: DgopService.totalSwapKB > 0 ? (DgopService.usedSwapKB / DgopService.totalSwapKB) * 100 : 0

    // Lógica para encontrar la información del punto de montaje del disco basado en la ruta configurada
    property var selectedMount: {
        if (!DgopService.diskMounts || DgopService.diskMounts.length === 0) {
            return null;
        }

        const currentMountPath = root.diskMountPath || "/";

        // Intenta encontrar la ruta de montaje exacta
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === currentMountPath) {
                return DgopService.diskMounts[i];
            }
        }

        // Si no se encuentra, vuelve a la raíz (/) como respaldo
        for (let i = 0; i < DgopService.diskMounts.length; i++) {
            if (DgopService.diskMounts[i].mount === "/") {
                return DgopService.diskMounts[i];
            }
        }

        return DgopService.diskMounts[0] || null;
    }

    // Extrae el porcentaje numérico de la cadena del punto de montaje (ej., "45%" -> 45)
    property real diskUsagePercent: {
        if (!selectedMount || !selectedMount.percent) {
            return 0;
        }
        const percentStr = selectedMount.percent.replace("%", "");
        return parseFloat(percentStr) || 0;
    }

    // --- Interfaz: PÍLDORA DE LA BARRA HORIZONTAL ---
    // Este componente se renderiza cuando la barra está arriba o abajo (TOP o BOTTOM).
    horizontalBarPill: Component {
        MouseArea {
            id: horizontalMouseArea
            implicitWidth: horizontalLayout.implicitWidth
            implicitHeight: horizontalLayout.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                console.log("AllMonitors: horizontal click");
                const globalPos = mapToItem(null, 0, 0);
                const currentScreen = root.parentScreen || Screen;
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, implicitWidth);
                root.pillClickAction(pos.x, pos.y, pos.width, root.section, currentScreen);
            }

            Row {
                id: horizontalLayout
                spacing: root.spacing
                anchors.verticalCenter: parent.verticalCenter

                // Bloque del Monitor de CPU
                Row {
                    spacing: Theme.spacingXS
                    visible: root.showCpuUsage
                    DankIcon { 
                        name: "memory"
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                        color: DgopService.cpuUsage > 80 ? Theme.tempDanger : (DgopService.cpuUsage > 60 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: (DgopService.cpuUsage > 0) ? DgopService.cpuUsage.toFixed(0) + "%" : "--%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                    }
                }

                // Bloque de Temperatura
                Row {
                    spacing: Theme.spacingXS
                    visible: root.showCpuTemp
                    DankIcon { 
                        name: "device_thermostat"
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                        color: DgopService.cpuTemperature > 85 ? Theme.tempDanger : (DgopService.cpuTemperature > 69 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: (DgopService.cpuTemperature >= 0) ? Math.round(DgopService.cpuTemperature) + "°" : "--°"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                    }
                }

                // Bloque de RAM
                Row {
                    spacing: Theme.spacingXS
                    visible: root.showRam
                    DankIcon { 
                        name: "developer_board"
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                        color: DgopService.memoryUsage > 90 ? Theme.tempDanger : (DgopService.memoryUsage > 75 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: {
                            let t = (DgopService.memoryUsage > 0) ? DgopService.memoryUsage.toFixed(0) + "%" : "--%";
                            if (root.showSwap && DgopService.totalSwapKB > 0) t += " · " + root.swapUsage.toFixed(0) + "%";
                            return t;
                        }
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                    }
                }

                // Bloque de Disco
                Row {
                    spacing: Theme.spacingXS
                    visible: root.showDisk
                    DankIcon { 
                        name: "storage"
                        size: Theme.barIconSize(root.barThickness, undefined, root.barConfig?.noBackground)
                        color: root.diskUsagePercent > 90 ? Theme.tempDanger : (root.diskUsagePercent > 75 ? Theme.tempWarning : Theme.surfaceText)
                    }
                    StyledText {
                        text: root.selectedMount ? root.selectedMount.mount : "--"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                    }
                    StyledText {
                        text: (root.diskUsagePercent > 0) ? root.diskUsagePercent.toFixed(0) + "%" : "--%"
                        font.pixelSize: Theme.barTextSize(root.barThickness, root.barConfig?.fontScale)
                        color: Theme.widgetTextColor
                    }
                }
            }
        }
    }

    // --- Interfaz: PÍLDORA DE LA BARRA VERTICAL ---
    // Este componente se renderiza cuando la barra está a la izquierda o derecha (LEFT o RIGHT).
    verticalBarPill: Component {
        MouseArea {
            id: verticalMouseArea
            implicitWidth: verticalLayout.implicitWidth
            implicitHeight: verticalLayout.implicitHeight
            cursorShape: Qt.PointingHandCursor
            onClicked: {
                console.log("AllMonitors: vertical click");
                const globalPos = mapToItem(null, 0, 0);
                const currentScreen = root.parentScreen || Screen;
                const pos = SettingsData.getPopupTriggerPosition(globalPos, currentScreen, root.barThickness, implicitWidth);
                root.pillClickAction(pos.x, pos.y, pos.width, root.section, currentScreen);
            }

            Column {
                id: verticalLayout
                spacing: root.spacing
                anchors.horizontalCenter: parent.horizontalCenter

                // CPU (Vertical)
                Column {
                    visible: root.showCpuUsage
                    anchors.horizontalCenter: parent.horizontalCenter
                    DankIcon { 
                        name: "memory"
                        size: Theme.iconSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: DgopService.cpuUsage > 80 ? Theme.tempDanger : (DgopService.cpuUsage > 60 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: (DgopService.cpuUsage > 0) ? DgopService.cpuUsage.toFixed(0) + "%" : "--%"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.widgetTextColor
                    }
                }

                // Temp (Vertical)
                Column {
                    visible: root.showCpuTemp
                    anchors.horizontalCenter: parent.horizontalCenter
                    DankIcon { 
                        name: "device_thermostat"
                        size: Theme.iconSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: DgopService.cpuTemperature > 85 ? Theme.tempDanger : (DgopService.cpuTemperature > 69 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: (DgopService.cpuTemperature >= 0) ? Math.round(DgopService.cpuTemperature) + "°" : "--°"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.widgetTextColor
                    }
                }

                // RAM (Vertical)
                Column {
                    visible: root.showRam
                    anchors.horizontalCenter: parent.horizontalCenter
                    DankIcon { 
                        name: "developer_board"
                        size: Theme.iconSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: DgopService.memoryUsage > 90 ? Theme.tempDanger : (DgopService.memoryUsage > 75 ? Theme.tempWarning : Theme.widgetIconColor)
                    }
                    StyledText {
                        text: (DgopService.memoryUsage > 0) ? DgopService.memoryUsage.toFixed(0) + "%" : "--%"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.widgetTextColor
                    }
                }

                // Disco (Vertical)
                Column {
                    visible: root.showDisk
                    anchors.horizontalCenter: parent.horizontalCenter
                    DankIcon { 
                        name: "storage"
                        size: Theme.iconSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: root.diskUsagePercent > 90 ? Theme.tempDanger : (root.diskUsagePercent > 75 ? Theme.tempWarning : Theme.surfaceText)
                    }
                    StyledText {
                        text: (root.diskUsagePercent > 0) ? root.diskUsagePercent.toFixed(0) + "%" : "--%"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.widgetTextColor
                    }
                    StyledText {
                        text: root.selectedMount ? root.selectedMount.mount : "--"
                        font.pixelSize: Theme.fontSizeSmall
                        anchors.horizontalCenter: parent.horizontalCenter
                        color: Theme.widgetTextColor
                    }
                }
            }
        }
    }
}
