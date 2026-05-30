pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import qs.config
import qs.services
import "../../components/"

BarButton {
    id: root

    active: weatherWindow.visible
    contentItem: buttonContent
    onClicked: weatherWindow.visible = !weatherWindow.visible

    RowLayout {
        id: buttonContent
        anchors.centerIn: parent
        spacing: Config.spacing

        // Icon — muda cor quando o popup está aberto
        Text {
            text: {
                if (WeatherService.loading)  return "󰔟";
                if (WeatherService.hasError) return "󰖑";
                return WeatherService.currentIcon || "󰖔";
            }
            font.family:    Config.font
            font.pixelSize: Config.fontSizeLarge
            color: root.active
                ? Config.accentColor
                : (WeatherService.hasData
                    ? Qt.color(WeatherService.currentHex)
                    : Config.textColor)

            Behavior on color { ColorAnimation { duration: Config.animDuration } }
        }

        // Temperatura atual
        Text {
            text: WeatherService.hasError ? "—" : WeatherService.currentTempStr
            font.family:    Config.font
            font.pixelSize: Config.fontSizeNormal
            color: root.active ? Config.accentColor : Config.textColor
            visible: !WeatherService.loading

            Behavior on color { ColorAnimation { duration: Config.animDuration } }
        }
    }

    WeatherWindow {
        id: weatherWindow
        visible: false
    }
}
