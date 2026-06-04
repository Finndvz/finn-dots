pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

QsPopupWindow {
    id: root

    popupWidth: 360
    popupMaxHeight: 700
    anchorSide: "center"
    moduleName: "Weather"
    contentImplicitHeight: content.implicitHeight

    // Cor do ícone baseada na condição
    function conditionColor(icon: string): color {
        if (icon === "󰖐" || icon === "󰖗" || icon === "󰖑") return Config.accentColor;
        if (icon === "󰖙" || icon === "󰼶")                  return Qt.rgba(0.53, 0.81, 0.98, 1);
        if (icon === "󰖔" || icon === "󰙾")                  return Config.warningColor;
        return Qt.color(WeatherService.currentHex);
    }

    ColumnLayout {
        id: content
        anchors.fill: parent
        spacing: 12

        // =====================================================================
        // HEADER — cidade + ícone grande + temperatura atual
        // =====================================================================
        RowLayout {
            Layout.fillWidth: true
            spacing: 12

            // Ícone grande com fundo colorido
            Rectangle {
                Layout.preferredWidth:  48
                Layout.preferredHeight: 48
                radius: Config.radius
                color: Qt.alpha(Qt.color(WeatherService.currentHex), 0.18)

                Text {
                    anchors.centerIn: parent
                    text: WeatherService.currentIcon || "󰖔"
                    font.family:    Config.font
                    font.pixelSize: Config.fontSizeIconLarge
                    color: Qt.color(WeatherService.currentHex)
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                Text {
                    text: WeatherService.hasData
                        ? (WeatherService.selectedDay.day_full + " · " + WeatherService.selectedDay.date)
                        : "Loading..."
                    font.family:    Config.font
                    font.pixelSize: Config.fontSizeSmall
                    color: Config.subtextColor
                }

                Text {
                    text: WeatherService.currentTempStr
                    font.family:    Config.font
                    font.pixelSize: 28
                    font.bold:      true
                    color: Config.textColor
                }
            }

            // Botão refresh
            Rectangle {
                Layout.preferredWidth:  30
                Layout.preferredHeight: 30
                radius: Config.radius
                color: refreshHover.hovered
                    ? Qt.alpha(Config.accentColor, 0.18)
                    : Config.surface1Color

                Text {
                    anchors.centerIn: parent
                    text: WeatherService.loading ? "󰔟" : "󰑐"
                    font.family:    Config.font
                    font.pixelSize: Config.fontSizeNormal
                    color: Config.subtextColor
                }

                TapHandler { onTapped: WeatherService.forceRefresh() }
                HoverHandler { id: refreshHover; cursorShape: Qt.PointingHandCursor }

                Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
            }
        }

        // =====================================================================
        // CONDIÇÃO + DETALHES DO DIA SELECIONADO
        // =====================================================================
        Rectangle {
            Layout.fillWidth: true
            implicitHeight:   detailsGrid.implicitHeight + Config.padding * 2
            radius: Config.radius
            color: Config.surface0Color

            GridLayout {
                id: detailsGrid
                anchors {
                    left:   parent.left;   leftMargin:  Config.padding
                    right:  parent.right;  rightMargin: Config.padding
                    top:    parent.top;    topMargin:   Config.padding
                }
                columns: 2
                rowSpacing:    8
                columnSpacing: 12

                DetailItem {
                    icon:  WeatherService.selectedDay.icon || "󰖔"
                    label: "Condition"
                    value: WeatherService.selectedDay.desc || "—"
                    iconColor: Qt.color(WeatherService.selectedDay.hex || "#cdd6f4")
                }
                DetailItem {
                    icon:  "󰔄"
                    label: "Feels like"
                    value: WeatherService.selectedDay.feelsLikeStr || "—"
                    iconColor: Config.warningColor
                }
                DetailItem {
                    icon:  "󰖑"
                    label: "Humidity"
                    value: (WeatherService.selectedDay.humidity || "0") + "%"
                    iconColor: Config.accentColor
                }
                DetailItem {
                    icon:  "󰖗"
                    label: "Rain"
                    value: WeatherService.selectedDay.popStr || "0%"
                    iconColor: Config.accentColor
                }
                DetailItem {
                    icon:  "󰸎"
                    label: "Wind"
                    value: WeatherService.selectedDay.windStr || "—"
                    iconColor: Config.subtextColor
                }
                DetailItem {
                    icon:  "󰅐"
                    label: "Updated"
                    value: WeatherService.lastUpdated || "—"
                    iconColor: Config.subtextColor
                }
            }
        }

        // =====================================================================
        // PREVISÃO HORÁRIA DO DIA SELECIONADO
        // =====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 6
            visible: WeatherService.continuousHourly.length > 1

            Text {
                text: "Hourly"
                font.family:    Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold:      true
                color: Config.subtextColor
            }

            // Scroll horizontal dos slots horários
            Item {
                Layout.fillWidth: true
                implicitHeight: hourlyRow.implicitHeight

                Flickable {
                    anchors.fill: parent
                    contentWidth: hourlyRow.implicitWidth
                    clip: true
                    interactive: true

                    Row {
                        id: hourlyRow
                        spacing: 6

                        Repeater {
                            model: WeatherService.continuousHourly

                            delegate: Rectangle {
                                required property var    modelData
                                required property int    index

                                implicitWidth:  56
                                implicitHeight: 70
                                radius: Config.radius
                                color: Config.surface0Color

                                ColumnLayout {
                                    anchors.centerIn: parent
                                    spacing: 4

                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.time || "—"
                                        font.family:    Config.font
                                        font.pixelSize: 10
                                        color: Config.subtextColor
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.icon || "󰖔"
                                        font.family:    Config.font
                                        font.pixelSize: Config.fontSizeLarge
                                        color: Qt.color(modelData.hex || "#cdd6f4")
                                    }
                                    Text {
                                        Layout.alignment: Qt.AlignHCenter
                                        text: modelData.tempStr || "—"
                                        font.family:    Config.font
                                        font.pixelSize: 11
                                        font.bold:      true
                                        color: Config.textColor
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }

        // =====================================================================
        // SEPARADOR
        // =====================================================================
        Rectangle {
            Layout.fillWidth:    true
            Layout.preferredHeight: 1
            color: Config.surface1Color
        }

        // =====================================================================
        // PREVISÃO 5 DIAS
        // =====================================================================
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            Text {
                text: "5-day forecast"
                font.family:    Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold:      true
                color: Config.subtextColor
            }

            Repeater {
                model: WeatherService.forecast

                delegate: Rectangle {
                    required property var  modelData
                    required property int  index

                    readonly property bool isSelected: index === WeatherService.selectedIndex

                    Layout.fillWidth: true
                    implicitHeight: 44
                    radius: Config.radius
                    color: isSelected
                        ? Qt.alpha(Config.accentColor, 0.12)
                        : (dayHover.hovered ? Config.surface0Color : "transparent")

                    Behavior on color { ColorAnimation { duration: Config.animDurationShort } }

                    RowLayout {
                        anchors {
                            fill:        parent
                            leftMargin:  10
                            rightMargin: 10
                        }
                        spacing: 8

                        // Dia da semana
                        Text {
                            text: modelData.day || "—"
                            font.family:    Config.font
                            font.pixelSize: Config.fontSizeNormal
                            font.bold:      isSelected
                            color: isSelected ? Config.accentColor : Config.textColor
                            Layout.preferredWidth: 32

                            Behavior on color { ColorAnimation { duration: Config.animDurationShort } }
                        }

                        // Ícone
                        Text {
                            text: modelData.icon || "󰖔"
                            font.family:    Config.font
                            font.pixelSize: Config.fontSizeLarge
                            color: Qt.color(modelData.hex || "#cdd6f4")
                        }

                        // Descrição
                        Text {
                            text: modelData.desc || "—"
                            font.family:    Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.subtextColor
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                        }

                        // Chuva
                        Text {
                            text: "󰖗 " + (modelData.pop || "0") + "%"
                            font.family:    Config.font
                            font.pixelSize: Config.fontSizeSmall
                            color: Config.accentColor
                            visible: parseInt(modelData.pop || "0") > 0
                        }

                        // Min / Max
                        RowLayout {
                            spacing: 4
                            Text {
                                text: modelData.minStr || "—"
                                font.family:    Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                            Text {
                                text: "·"
                                font.family:    Config.font
                                font.pixelSize: Config.fontSizeSmall
                                color: Config.subtextColor
                            }
                            Text {
                                text: modelData.maxStr || "—"
                                font.family:    Config.font
                                font.pixelSize: Config.fontSizeSmall
                                font.bold: true
                                color: Config.textColor
                            }
                        }
                    }

                    TapHandler {
                        onTapped: WeatherService.goToDay(index)
                        cursorShape: Qt.PointingHandCursor
                    }
                    HoverHandler { id: dayHover }
                }
            }
        }

        // =====================================================================
        // FOOTER — atualizado às HH:mm
        // =====================================================================
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: WeatherService.hasError
                ? ("Error: " + WeatherService.errorMessage)
                : ("Updated at " + WeatherService.lastUpdated)
            font.family:    Config.font
            font.pixelSize: 11
            color: WeatherService.hasError ? Config.errorColor : Config.subtextColor
        }
    }

    // =========================================================================
    // ITEM DE DETALHE (ícone + label + valor)
    // =========================================================================
    component DetailItem: RowLayout {
        required property string icon
        required property string label
        required property string value
        required property color  iconColor

        spacing: 6
        Layout.fillWidth: true

        Text {
            text: parent.icon
            font.family:    Config.font
            font.pixelSize: Config.fontSizeLarge
            color: parent.iconColor
        }

        ColumnLayout {
            spacing: 0
            Text {
                text: parent.parent.label
                font.family:    Config.font
                font.pixelSize: 10
                color: Config.subtextColor
            }
            Text {
                text: parent.parent.value
                font.family:    Config.font
                font.pixelSize: Config.fontSizeSmall
                font.bold:      true
                color: Config.textColor
            }
        }
    }
}
