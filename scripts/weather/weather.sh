#!/usr/bin/env bash
# =============================================================================
# weather.sh — OpenWeatherMap weather fetcher for Quickshell
#
# Dependencies: curl, jq, bc
#
# Usage:
#   weather.sh --getdata       Force a fresh API fetch and write cache
#   weather.sh --json          Return JSON (from cache, refresh if stale)
#   weather.sh --current-temp  Print current temperature
#   weather.sh --current-icon  Print current Nerd Font icon
# =============================================================================

# Load cache helper and set up cache directory
source "$(dirname "${BASH_SOURCE[0]}")/../../caching.sh"
qs_ensure_cache "weather"

# Force C locale for consistent number formatting
export LC_ALL=C

# Paths
cache_dir="$QS_CACHE_WEATHER"
json_file="${cache_dir}/weather.json"
daily_cache_file="${cache_dir}/daily_weather_cache.json"
next_day_cache_file="${cache_dir}/next_day_precache.json"
ENV_FILE="$(dirname "${BASH_SOURCE[0]}")/.env"

# Load credentials from .env
if [ -f "$ENV_FILE" ]; then
    set -a
    source "$ENV_FILE"
    set +a
fi

KEY="${OPENWEATHER_KEY:-}"
ID="${OPENWEATHER_CITY_ID:-}"
UNIT="${OPENWEATHER_UNIT:-metric}"

case "$UNIT" in
    "imperial") UNIT_SYM="°F" ;;
    "standard") UNIT_SYM="K"  ;;
    *)          UNIT_SYM="°C" ;;
esac

# =============================================================================
# ICON MAPPING
# =============================================================================
get_icon() {
    local code="$1"
    local icon quote
    case "$code" in
        "01d") icon="󰖙"; quote="Sunny"   ;;
        "01n") icon="󰖔"; quote="Clear"   ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") icon="󰖐"; quote="Cloudy"  ;;
        "09d"|"09n"|"10d"|"10n")             icon="󰖗"; quote="Rainy"   ;;
        "11d"|"11n")                         icon="󰙾"; quote="Storm"   ;;
        "13d"|"13n")                         icon="󰼶"; quote="Snow"    ;;
        "50d"|"50n")                         icon="󰖑"; quote="Mist"    ;;
        *)                                   icon="󰖔"; quote="Unknown" ;;
    esac
    echo "${icon}|${quote}"
}

# =============================================================================
# COLOR MAPPING
# =============================================================================
get_hex() {
    case "$1" in
        "01d")                               echo "#f9e2af" ;;
        "01n")                               echo "#cba6f7" ;;
        "02d"|"02n"|"03d"|"03n"|"04d"|"04n") echo "#bac2de" ;;
        "09d"|"09n"|"10d"|"10n")             echo "#74c7ec" ;;
        "11d"|"11n")                         echo "#f9e2af" ;;
        "13d"|"13n")                         echo "#cdd6f4" ;;
        "50d"|"50n")                         echo "#84afdb" ;;
        *)                                   echo "#cdd6f4" ;;
    esac
}

# =============================================================================
# DUMMY DATA
# =============================================================================
write_dummy_data() {
    local final_json="["
    for i in {0..4}; do
        local f_day f_full_day f_date_num
        f_day=$(date -d "+${i} days" "+%a")
        f_full_day=$(date -d "+${i} days" "+%A")
        f_date_num=$(date -d "+${i} days" "+%d %b")

        final_json="${final_json} {
            \"id\": \"${i}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"0.0\",
            \"min\": \"0.0\",
            \"feels_like\": \"0.0\",
            \"wind\": \"0\",
            \"humidity\": \"0\",
            \"pop\": \"0\",
            \"icon\": \"󰖔\",
            \"hex\": \"#cdd6f4\",
            \"desc\": \"No API Key\",
            \"hourly\": [{\"time\": \"00:00\", \"temp\": \"0.0\", \"icon\": \"󰖔\", \"hex\": \"#cdd6f4\"}]
        },"
    done
    final_json="${final_json%,}]"
    echo "{ \"current_temp\": \"0.0\", \"current_icon\": \"󰖔\", \"current_hex\": \"#cdd6f4\", \"forecast\": ${final_json} }" > "${json_file}"
}

# =============================================================================
# MAIN FETCH
# =============================================================================
get_data() {
    if [[ -z "$KEY" || -z "$ID" || "$KEY" == "OPENWEATHER_KEY" ]]; then
        echo "[weather.sh] No credentials — writing dummy data" >&2
        write_dummy_data
        return
    fi

    local base="http://api.openweathermap.org/data/2.5"
    local raw_weather raw_api api_cod

    raw_weather=$(curl -sf --max-time 15 "${base}/weather?APPID=${KEY}&id=${ID}&units=${UNIT}")
    raw_api=$(curl -sf --max-time 15 "${base}/forecast?APPID=${KEY}&id=${ID}&units=${UNIT}")
    api_cod=$(echo "$raw_api" | jq -r '.cod' 2>/dev/null)

    if [[ "$api_cod" == "200" ]]; then
        raw_api=$(echo "$raw_api" | jq '.city.timezone as $tz | .list |= map(.local_date = ((.dt + $tz) | todateiso8601)[0:10])')
    fi

    if [[ -z "$raw_api" || -z "$raw_weather" || "$api_cod" != "200" ]]; then
        echo "[weather.sh] API error (cod=${api_cod}) — keeping existing cache" >&2
        [[ ! -f "$json_file" ]] && write_dummy_data
        return
    fi

    # Current conditions
    local c_temp c_code c_icon c_hex
    c_temp=$(echo "$raw_weather" | jq -r '.main.temp')
    c_temp=$(printf "%.1f" "$c_temp")
    c_code=$(echo "$raw_weather" | jq -r '.weather[0].icon')
    c_icon=$(get_icon "$c_code" | cut -d'|' -f1)
    c_hex=$(get_hex "$c_code")

    local c_feels c_hum c_wind c_desc
    c_feels=$(printf "%.1f" "$(echo "$raw_weather" | jq -r '.main.feels_like')")
    c_hum=$(echo "$raw_weather" | jq -r '.main.humidity')
    c_wind=$(echo "$raw_weather" | jq -r '.wind.speed' | awk '{print int($1+0.5)}')
    c_desc=$(echo "$raw_weather" | jq -r '.weather[0].description' | sed -e "s/\b\(.\)/\u\1/g")

    local current_date tomorrow_date
    current_date=$(date +%Y-%m-%d)
    tomorrow_date=$(date -d "tomorrow" +%Y-%m-%d)

    # Cache rollover
    if [ -f "$next_day_cache_file" ]; then
        local precache_date
        precache_date=$(jq -r '.[0].local_date // (.[0].dt_txt | split(" ")[0])' "$next_day_cache_file" 2>/dev/null)
        [[ "$precache_date" == "$current_date" ]] && mv "$next_day_cache_file" "$daily_cache_file"
    fi

    # Merge today slots
    local api_today_items merged_today
    api_today_items=$(echo "$raw_api" | jq -c "[.list[] | select(.local_date == \"$current_date\")]")

    if [ -f "$daily_cache_file" ]; then
        local cached_date
        cached_date=$(jq -r '.[0].local_date // (.[0].dt_txt | split(" ")[0])' "$daily_cache_file" 2>/dev/null)
        if [[ "$cached_date" == "$current_date" ]]; then
            merged_today=$(echo "$api_today_items" | \
                jq --slurpfile cache "$daily_cache_file" \
                '($cache[0] + .) | unique_by(.dt) | sort_by(.dt)')
        else
            merged_today="$api_today_items"
        fi
    else
        merged_today="$api_today_items"
    fi

    echo "$merged_today" > "$daily_cache_file"
    echo "$raw_api" | jq -c "[.list[] | select(.local_date == \"$tomorrow_date\")]" > "$next_day_cache_file"

    # Build 5-day forecast
    local processed_forecast
    processed_forecast=$(echo "$raw_api" | \
        jq --argjson today "$merged_today" --arg date "$current_date" \
        '.list = ($today + [.list[] | select(.local_date != $date)])')

    local dates
    dates=$(echo "$processed_forecast" | jq -r '.list[].local_date' | sort -u | head -n 5)

    local final_json="["
    local counter=0

    for d in $dates; do
        local day_data
        day_data=$(echo "$processed_forecast" | jq "[.list[] | select(.local_date == \"$d\")]")

        local f_max f_min f_feels f_pop f_pop_pct f_wind f_hum f_code f_desc f_icon f_hex
        f_max=$(printf "%.1f"   "$(echo "$day_data" | jq '[.[].main.temp_max] | max')")
        f_min=$(printf "%.1f"   "$(echo "$day_data" | jq '[.[].main.temp_min] | min')")
        f_feels=$(printf "%.1f" "$(echo "$day_data" | jq '[.[].main.feels_like] | max')")
        f_pop=$(echo "$day_data" | jq '[.[].pop] | max')
        f_pop_pct=$(echo "$f_pop * 100" | bc | cut -d. -f1)
        f_wind=$(echo "$day_data" | jq '[.[].wind.speed] | max | round')
        f_hum=$(echo "$day_data" | jq '[.[].main.humidity] | add / length | round')
        f_code=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].icon')
        f_desc=$(echo "$day_data" | jq -r '.[length/2 | floor].weather[0].description' | sed -e "s/\b\(.\)/\u\1/g")
        f_icon=$(get_icon "$f_code" | cut -d'|' -f1)
        f_hex=$(get_hex "$f_code")

        local f_day f_full_day f_date_num
        f_day=$(date -d "$d" "+%a")
        f_full_day=$(date -d "$d" "+%A")
        f_date_num=$(date -d "$d" "+%d %b")

        if [[ $counter -eq 0 ]]; then
            f_feels="$c_feels"
            f_hum="$c_hum"
            f_wind="$c_wind"
            f_desc="$c_desc"
            f_icon="$c_icon"
            f_hex="$c_hex"
        fi

        # Hourly slots
        local hourly_json="["
        local count_slots
        count_slots=$(echo "$day_data" | jq '. | length')
        count_slots=$((count_slots - 1))

        for i in $(seq 0 "$count_slots"); do
            local slot s_temp s_dt s_time s_code s_icon s_hex
            slot=$(echo "$day_data" | jq ".[$i]")
            s_temp=$(printf "%.1f" "$(echo "$slot" | jq '.main.temp')")
            s_dt=$(echo "$slot" | jq '.dt')
            s_time=$(date -d "@${s_dt}" "+%H:%M")
            s_code=$(echo "$slot" | jq -r '.weather[0].icon')
            s_icon=$(get_icon "$s_code" | cut -d'|' -f1)
            s_hex=$(get_hex "$s_code")
            hourly_json="${hourly_json}{\"dt\":${s_dt},\"time\":\"${s_time}\",\"temp\":\"${s_temp}\",\"icon\":\"${s_icon}\",\"hex\":\"${s_hex}\"},"
        done
        hourly_json="${hourly_json%,}]"

        final_json="${final_json}{
            \"id\": \"${counter}\",
            \"day\": \"${f_day}\",
            \"day_full\": \"${f_full_day}\",
            \"date\": \"${f_date_num}\",
            \"max\": \"${f_max}\",
            \"min\": \"${f_min}\",
            \"feels_like\": \"${f_feels}\",
            \"wind\": \"${f_wind}\",
            \"humidity\": \"${f_hum}\",
            \"pop\": \"${f_pop_pct}\",
            \"icon\": \"${f_icon}\",
            \"hex\": \"${f_hex}\",
            \"desc\": \"${f_desc}\",
            \"hourly\": ${hourly_json}
        },"
        ((counter++))
    done

    final_json="${final_json%,}]"
    echo "{\"current_temp\":\"${c_temp}\",\"current_icon\":\"${c_icon}\",\"current_hex\":\"${c_hex}\",\"forecast\":${final_json}}" > "${json_file}"
    echo "[weather.sh] Done — ${counter} days, ${c_temp}${UNIT_SYM}" >&2
}

# =============================================================================
# MODE HANDLING
# =============================================================================
case "$1" in
    --getdata)
        get_data
        ;;
    --json)
        CACHE_LIMIT=900
        PENDING_RETRY=3600
        if [ -f "$json_file" ]; then
            local_age=$(( $(date +%s) - $(stat -c %Y "$json_file") ))
            if grep -q '"desc": "No API Key"' "$json_file" 2>/dev/null; then
                [[ $local_age -gt $PENDING_RETRY ]] && { touch "$json_file"; get_data & }
            else
                [[ $local_age -gt $CACHE_LIMIT ]] && { touch "$json_file"; get_data & }
            fi
            cat "$json_file"
        else
            get_data
            cat "$json_file"
        fi
        ;;
    --current-temp)
        t=$(jq -r '.current_temp' "$json_file" 2>/dev/null)
        echo "${t}${UNIT_SYM}"
        ;;
    --current-icon)
        jq -r '.current_icon' "$json_file" 2>/dev/null
        ;;
    --current-hex)
        jq -r '.current_hex' "$json_file" 2>/dev/null
        ;;
    --icon)
        jq -r '.forecast[0].icon' "$json_file" 2>/dev/null
        ;;
    --temp)
        t=$(jq -r '.forecast[0].max' "$json_file" 2>/dev/null)
        echo "${t}${UNIT_SYM}"
        ;;
    *)
        echo "Uso: $0 {--getdata|--json|--current-temp|--current-icon|--icon|--temp}" >&2
        exit 1
        ;;
esac
