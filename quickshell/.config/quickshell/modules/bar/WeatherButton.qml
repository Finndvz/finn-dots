pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs.services
import qs.config

// Compact weather widget for the bar.
// Shows current icon + temperature. Click to force refresh.

RowLayout {
    id: root
    spacing: Config.spacing / 2

    readonly property color _color: {
        if (WeatherService.hasError) return Config.errorColor;
        return WeatherService.hasData
            ? Qt.color(WeatherService.currentHex)
            : Config.subtextColor;
    }

    // Icon
    Text {
        text: {
            if (WeatherService.loading)  return "󰔟";
            if (WeatherService.hasError) return "󰖑";
            return WeatherService.currentIcon || "󰖔";
        }
        font.family:    Config.font
        font.pixelSize: Config.fontSizeIcon
        color: root._color

        Behavior on color { ColorAnimation { duration: Config.animDuration } }
    }

    // Temperature
    Text {
        text: {
            if (WeatherService.loading)  return "...";
            if (WeatherService.hasError) return "—";
            return WeatherService.currentTempStr;
        }
        font.family:    Config.font
        font.pixelSize: Config.fontSizeNormal
        color: Config.textColor
        visible: !WeatherService.loading || WeatherService.hasData
    }

    // Click to force refresh
    TapHandler {
        onTapped: WeatherService.forceRefresh()
        cursorShape: Qt.PointingHandCursor
    }

    // Tooltip on hover
    HoverHandler { id: hov }
    ToolTip {
        visible: hov.hovered && WeatherService.hasData
        delay: 600
        text: {
            const d = WeatherService.selectedDay;
            return [
                d.day_full + " — " + d.desc,
                "󰔄 Máx " + d.maxStr + "  Mín " + d.minStr,
                "󰖑 Umidade " + d.humidity + "%",
                "󰸎 Vento "   + d.windStr,
                "󰖗 Chuva "   + d.popStr,
            ].join("\n");
        }
    }
}
