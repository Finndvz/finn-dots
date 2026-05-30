pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.config

Item {
    id: root

    // --- Sizing Properties ---
    readonly property int itemWidth: 15
    readonly property int itemHeight: 15
    readonly property int activeWidth: 30
    readonly property int activeHeight: 18
    readonly property int itemSpacing: 4

    // --- Monitor Logic ---
    readonly property var parentWindow: QsWindow.window
    readonly property var parentScreen: parentWindow?.screen ?? null

    property var currentMonitor: {
        if (!Hyprland)
            return null;
        return (parentScreen ? Hyprland.monitorFor(parentScreen) : null) ?? Hyprland.focusedMonitor ?? null;
    }

    readonly property string monitorName: currentMonitor?.name ?? ""
    property var activeWorkspace: currentMonitor?.activeWorkspace ?? null

    // --- Special Workspace Detection ---
    property string manualSpecialName: ""
    readonly property bool isSpecialWorkspace: manualSpecialName !== ""

    readonly property string specialWorkspaceName: {
        if (!isSpecialWorkspace)
            return "";
        return manualSpecialName.startsWith("special:") ? manualSpecialName.substring(8) : manualSpecialName;
    }

    property int activeId: (activeWorkspace && activeWorkspace.id > 0) ? activeWorkspace.id : 1

    // --- Occupied Workspaces ---
    // Tracks which workspace IDs have at least one window
    property var occupiedWorkspaces: ({})

    // =========================================================================
    // DYNAMIC VISIBLE WORKSPACE LIST
    // Only shows workspaces that are occupied OR currently active.
    // Always includes the active workspace even if it's empty (e.g. freshly
    // switched to). Sorted numerically so the order matches Hyprland's.
    // =========================================================================
    property var visibleWorkspaceIds: []

    function updateOccupiedWorkspaces() {
        if (!Hyprland || !Hyprland.workspaces)
            return;

        let newObj = {};
        for (let ws of Hyprland.workspaces.values) {
            if (ws && ws.id > 0)
                newObj[ws.id] = true;
        }
        occupiedWorkspaces = newObj;

        // Build the visible list: occupied IDs + active ID, deduplicated and sorted
        let ids = new Set(Object.keys(newObj).map(Number));
        if (activeId > 0)
            ids.add(activeId);
        visibleWorkspaceIds = Array.from(ids).sort((a, b) => a - b);
    }

    // Re-evaluate when the active workspace changes so it's always visible
    onActiveIdChanged: updateOccupiedWorkspaces()

    Component.onCompleted: updateOccupiedWorkspaces()

    // Debounce rapid events (window open/close/move) — 50ms is enough
    Timer {
        id: occupiedUpdateTimer
        interval: 50
        onTriggered: root.updateOccupiedWorkspaces()
    }

    // Dynamic size: grows/shrinks as workspaces are added/removed
    implicitWidth: isSpecialWorkspace ? specialIndicator.width : workspacesRow.implicitWidth
    implicitHeight: activeHeight + 4

    // --- Special Workspaces Config ---
    readonly property var specialWorkspaces: ({
            "whatsapp": {
                icon: "󰖣",
                color: Config.successColor,
                name: "WhatsApp"
            },
            "spotify": {
                icon: "󰓇",
                color: Config.accentColor,
                name: "Music"
            },
            "magic": {
                icon: "󰀘",
                color: Config.warningColor,
                name: "Magic"
            }
        })

    property string cachedIcon: "󰀘"
    property string cachedName: ""
    property color cachedColor: Config.accentColor

    readonly property var currentSpecialConfig: {
        if (!isSpecialWorkspace)
            return null;
        return specialWorkspaces[specialWorkspaceName] ?? {
            icon: "󰀘",
            color: Config.accentColor,
            name: specialWorkspaceName.charAt(0).toUpperCase() + specialWorkspaceName.slice(1)
        };
    }

    onCurrentSpecialConfigChanged: {
        if (currentSpecialConfig) {
            cachedIcon = currentSpecialConfig.icon;
            cachedName = currentSpecialConfig.name;
            cachedColor = currentSpecialConfig.color;
        }
    }

    // --- Event Handling ---
    Connections {
        target: Hyprland
        function onRawEvent(event) {
            if (!event)
                return;
            if (event.name === "activespecial") {
                let parts = event.data.split(',');
                let wsName = parts[0] || "";
                let targetMonitor = parts[1] || "";
                if (targetMonitor === "" || targetMonitor === root.monitorName)
                    root.manualSpecialName = wsName;
            }
            if (event.name === "workspace") {
                root.manualSpecialName = "";
                occupiedUpdateTimer.restart();
            }
            const refreshEvents = ["createworkspace", "destroyworkspace", "movewindow", "openwindow", "closewindow"];
            if (refreshEvents.includes(event.name))
                occupiedUpdateTimer.restart();
        }
    }

    // =========================================================================
    // SPECIAL WORKSPACE INDICATOR (unchanged)
    // =========================================================================
    Rectangle {
        id: specialIndicator
        visible: opacity > 0
        anchors.centerIn: parent
        opacity: root.isSpecialWorkspace ? (specialHover.hovered ? 0.8 : 1.0) : 0
        scale: root.isSpecialWorkspace ? 1.0 : 0.9
        property int yOffset: root.isSpecialWorkspace ? 0 : 5
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: yOffset
        width: specialContent.width + Config.padding * 3
        height: root.activeHeight
        radius: Config.radius
        color: root.cachedColor
        border.width: 1

        Behavior on opacity {
            NumberAnimation { duration: Config.animDurationShort }
        }
        Behavior on scale {
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on anchors.verticalCenterOffset {
            NumberAnimation { duration: Config.animDuration; easing.type: Easing.OutCubic }
        }
        Behavior on color {
            ColorAnimation { duration: Config.animDuration }
        }

        Row {
            id: specialContent
            anchors.centerIn: parent
            spacing: Config.padding * 0.8

            Text {
                text: root.cachedIcon
                font { family: Config.font; pixelSize: Config.fontSizeLarge }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }
            Text {
                text: root.cachedName
                font { family: Config.font; bold: true; pixelSize: Config.fontSizeNormal }
                color: Config.textReverseColor
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        TapHandler {
            onTapped: {
                if (root.specialWorkspaceName)
                    Hyprland.dispatch("togglespecialworkspace " + root.specialWorkspaceName);
            }
        }
        HoverHandler {
            id: specialHover
            cursorShape: Qt.PointingHandCursor
        }
    }

    // =========================================================================
    // NORMAL WORKSPACES — dynamic list, only occupied + active
    // =========================================================================
    Row {
        id: workspacesRow
        visible: !root.isSpecialWorkspace
        opacity: visible ? 1 : 0
        anchors.verticalCenter: parent.verticalCenter
        spacing: root.itemSpacing

        Behavior on opacity {
            NumberAnimation { duration: Config.animDuration }
        }

        Repeater {
            // Model is now the dynamic array — typically 1–5 items instead of 99
            model: root.visibleWorkspaceIds

            delegate: Rectangle {
                id: workspaceItem
                required property int modelData  // the workspace ID
                required property int index

                readonly property bool isActive: modelData === root.activeId
                // isEmpty = active but no windows (just switched to it)
                readonly property bool isEmpty: root.occupiedWorkspaces[modelData] !== true

                anchors.verticalCenter: parent.verticalCenter
                width: isActive ? root.activeWidth : root.itemWidth
                height: isActive ? root.activeHeight : root.itemHeight
                radius: Config.radius
                color: isActive
                       ? Config.accentColor
                       : (!isEmpty ? Config.surface3Color : Qt.alpha(Config.surface2Color, 0.65))
                opacity: !isActive ? (workspaceHover.hovered ? 0.8 : 1.0) : 1

                Behavior on width  { NumberAnimation { duration: Config.animDurationShort } }
                Behavior on height { NumberAnimation { duration: Config.animDurationShort } }
                Behavior on color  { ColorAnimation  { duration: Config.animDuration     } }
                Behavior on opacity { NumberAnimation { duration: Config.animDurationShort } }

                TapHandler {
                    onTapped: {
                        if (!workspaceItem.isActive)
                            Hyprland.dispatch("workspace " + workspaceItem.modelData);
                    }
                }
                HoverHandler {
                    id: workspaceHover
                    cursorShape: workspaceItem.isActive ? Qt.ArrowCursor : Qt.PointingHandCursor
                }
            }
        }
    }
}
