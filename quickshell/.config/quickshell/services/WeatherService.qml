pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

Singleton {
    id: root

    readonly property string scriptPath: StateService.get(
        "weather.scriptPath",
        "/home/finn/.lyne-dots/scripts/weather/weather.sh"
    )
    readonly property int    pollMs: 60000
    readonly property string units:  StateService.get("weather.units", "metric")

    readonly property real   currentTemp:    internal.currentTemp
    readonly property string currentTempStr: internal.currentTempStr
    readonly property string currentIcon:    internal.currentIcon
    readonly property color  currentHex:     internal.currentHex
    readonly property var    forecast:       internal.forecast

    // Flat continuous timeline of upcoming hourly slots across all days.
    // Always starts from the current/next slot regardless of day boundaries.
    readonly property var    continuousHourly: internal.continuousHourly

    property int selectedIndex: 0

    readonly property var selectedDay: {
        if (internal.forecast.length === 0) return _emptyDay;
        var idx = Math.max(0, Math.min(root.selectedIndex, internal.forecast.length - 1));
        return internal.forecast[idx] || _emptyDay;
    }

    readonly property bool canGoNext: selectedIndex < internal.forecast.length - 1
    readonly property bool canGoPrev: selectedIndex > 0

    function nextDay() { if (canGoNext) selectedIndex++; }
    function prevDay() { if (canGoPrev) selectedIndex--; }

    readonly property bool   loading:      internal.loading
    readonly property bool   hasError:     internal.hasError
    readonly property string errorMessage: internal.errorMessage
    readonly property string lastUpdated:  internal.lastUpdated
    readonly property bool   hasData:      internal.forecast.length > 0

    function forceRefresh() { forceUpdate.running = true; }

    readonly property var _emptyDay: ({
        "id": "0", "day": "—", "day_full": "—", "date": "—",
        "max": "—", "min": "—", "feels_like": "—",
        "wind": "0", "humidity": "0", "pop": "0",
        "icon": "", "hex": "#cdd6f4", "desc": "—",
        "maxStr": "—", "minStr": "—", "feelsLikeStr": "—",
        "windStr": "—", "popStr": "—", "hourly": []
    })

    QtObject {
        id: internal
        property real   currentTemp:    0
        property string currentTempStr: "—"
        property string currentIcon:    ""
        property color  currentHex:     "#cdd6f4"
        property var    forecast:         []
        property var    continuousHourly: []
        property bool   loading:        false
        property bool   hasError:       false
        property string errorMessage:   ""
        property string lastUpdated:    ""
    }

    Component.onCompleted: fetchWeather.running = true

    Timer {
        interval: root.pollMs
        running:  true
        repeat:   true
        onTriggered: fetchWeather.running = true
    }

    Process {
        id: fetchWeather
        command: ["bash", root.scriptPath, "--json"]
        property string _buf: ""
        onRunningChanged: if (running) internal.loading = true
        stdout: SplitParser { onRead: data => fetchWeather._buf += data }
        onExited: (code, _) => {
            internal.loading = false;
            var raw = fetchWeather._buf.trim();
            fetchWeather._buf = "";
            if (code !== 0 || raw === "") {
                internal.hasError = true;
                internal.errorMessage = "Script error (code " + code + ")";
                return;
            }
            root._parse(raw);
        }
    }

    Process {
        id: forceUpdate
        command: ["bash", root.scriptPath, "--getdata"]
        onExited: (code, _) => { if (code === 0) fetchWeather.running = true; }
    }

    function _unitSym() {
        if (units === "imperial") return "°F";
        if (units === "standard") return " K";
        return "°C";
    }

    function _parse(raw) {
        var json;
        try { json = JSON.parse(raw); }
        catch (e) {
            internal.hasError = true;
            internal.errorMessage = "JSON invalido";
            return;
        }

        var sym = _unitSym();
        var cTemp = parseFloat(json.current_temp || "0");
        internal.currentTemp    = isNaN(cTemp) ? 0 : cTemp;
        internal.currentTempStr = (isNaN(cTemp) ? "—" : Math.round(cTemp)) + sym;
        internal.currentIcon    = json.current_icon || "";
        internal.currentHex     = json.current_hex  || "#cdd6f4";

        var raw_fc = json.forecast || [];
        if (raw_fc.length === 0) {
            internal.hasError = true;
            internal.errorMessage = "Previsao vazia";
            internal.forecast = [];
            return;
        }

        var now = Math.floor(Date.now() / 1000); // unix seconds

        var days = [];
        for (var i = 0; i < raw_fc.length; i++) {
            var day = raw_fc[i];
            var hourly = [];
            var src_h = day.hourly || [];
            for (var j = 0; j < src_h.length; j++) {
                var h = src_h[j];
                // For today (i===0): skip slots older than 1.5h ago so the
                // current/next slot is always the first one shown — same
                // behaviour as openweathermap.org
                if (i === 0 && h.dt && parseInt(h.dt) < now - 5400) continue;
                hourly.push({
                    "dt":      h.dt      || 0,
                    "time":    h.time    || "—",
                    "temp":    h.temp    || "—",
                    "tempStr": (h.temp ? Math.round(parseFloat(h.temp)) : "—") + sym,
                    "icon":    h.icon    || "",
                    "hex":     h.hex     || "#cdd6f4"
                });
            }
            days.push({
                "id":          day.id       || String(i),
                "day":         day.day      || "—",
                "day_full":    day.day_full || "—",
                "date":        day.date     || "—",
                "max":         day.max      || "—",
                "min":         day.min      || "—",
                "feels_like":  day.feels_like || "—",
                "wind":        day.wind     || "0",
                "humidity":    day.humidity || "0",
                "pop":         day.pop      || "0",
                "icon":        day.icon     || "",
                "hex":         day.hex      || "#cdd6f4",
                "desc":        day.desc     || "—",
                "maxStr":      (day.max        ? Math.round(parseFloat(day.max))        : "—") + sym,
                "minStr":      (day.min        ? Math.round(parseFloat(day.min))        : "—") + sym,
                "feelsLikeStr":(day.feels_like ? Math.round(parseFloat(day.feels_like)) : "—") + sym,
                "windStr":     (day.wind ? Math.round(parseFloat(day.wind) * 3.6) : "0") + " km/h",
                "popStr":      (day.pop     || "0") + "%",
                "hourly":      hourly
            });
        }

        internal.forecast = days;
        if (root.selectedIndex >= internal.forecast.length)
            root.selectedIndex = 0;

        // Collect raw 3h slots for the next ~12h (extra margin for interpolation)
        var raw3h = [];
        var cutoff = now - 5400;
        var margin = now + 12 * 3600;
        for (var di = 0; di < days.length; di++) {
            var slots = days[di].hourly || [];
            for (var si = 0; si < slots.length; si++) {
                var slot = slots[si];
                var dt = parseInt(slot.dt || 0);
                if (dt >= cutoff && dt <= margin)
                    raw3h.push(slot);
            }
        }
        raw3h.sort(function(a, b) { return parseInt(a.dt) - parseInt(b.dt); });

        // Interpolate between each pair of 3h slots → 1h resolution.
        // Temperature is linearly interpolated; icon/hex taken from the
        // source slot (same as what OWM shows on their site).
        var flat = [];
        var limitDt = now + 9 * 3600;

        for (var k = 0; k < raw3h.length - 1; k++) {
            var slotA = raw3h[k];
            var slotB = raw3h[k + 1];
            var dtA   = parseInt(slotA.dt);
            var dtB   = parseInt(slotB.dt);
            var tA    = parseFloat(slotA.temp);
            var tB    = parseFloat(slotB.temp);
            var span  = dtB - dtA; // usually 10800s (3h)

            for (var offset = 0; offset < span; offset += 3600) {
                var t = dtA + offset;
                if (t < cutoff || t > limitDt) continue;
                var frac = offset / span;
                var temp = tA + (tB - tA) * frac;
                var d    = new Date(t * 1000);
                var hh   = String(d.getHours()).padStart(2, "0");
                var mm   = String(d.getMinutes()).padStart(2, "0");
                flat.push({
                    "dt":      t,
                    "time":    hh + ":" + mm,
                    "temp":    temp.toFixed(1),
                    "tempStr": Math.round(temp) + sym,
                    "icon":    slotA.icon || "",
                    "hex":     slotA.hex  || "#cdd6f4"
                });
            }
        }
        // Include the boundary slot if within window
        if (raw3h.length > 0) {
            var last = raw3h[raw3h.length - 1];
            var lastDt = parseInt(last.dt);
            if (lastDt >= cutoff && lastDt <= limitDt)
                flat.push(last);
        }
        flat.sort(function(a, b) { return a.dt - b.dt; });
        internal.continuousHourly = flat;

        internal.hasError     = false;
        internal.errorMessage = "";
        internal.lastUpdated  = Qt.formatTime(new Date(), "HH:mm");
        console.log("[WeatherService] OK", internal.currentTempStr, internal.currentIcon);
    }
}
