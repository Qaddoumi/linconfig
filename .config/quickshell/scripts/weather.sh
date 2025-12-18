#!/usr/bin/env bash

# Weather script for Quickshell using Open-Meteo API (free, no API key)
# Caches data in /tmp to avoid excessive API calls (refreshes once per day)

CACHE_FILE="/tmp/weather_cache.json"
LOCATION_CACHE="/tmp/weather_location.json"

# Weather code to emoji mapping
get_weather_emoji() {
    local code=$1
    case $code in
        0) echo "☀️" ;;           # Clear sky
        1|2|3) echo "🌤" ;;       # Mainly clear, partly cloudy
        45|48) echo "🌫" ;;       # Fog
        51|53|55) echo "🌧" ;;    # Drizzle
        56|57) echo "🌧" ;;       # Freezing drizzle
        61|63|65) echo "🌧" ;;    # Rain
        66|67) echo "🌧" ;;       # Freezing rain
        71|73|75) echo "🌨" ;;    # Snow
        77) echo "🌨" ;;          # Snow grains
        80|81|82) echo "🌧" ;;    # Rain showers
        85|86) echo "🌨" ;;       # Snow showers
        95) echo "⛈" ;;           # Thunderstorm
        96|99) echo "⛈" ;;        # Thunderstorm with hail
        *) echo "🌡" ;;           # Default
    esac
}

# Weather code to description
get_weather_desc() {
    local code=$1
    case $code in
        0) echo "Clear" ;;
        1) echo "Mostly Clear" ;;
        2) echo "Partly Cloudy" ;;
        3) echo "Overcast" ;;
        45|48) echo "Foggy" ;;
        51|53|55) echo "Drizzle" ;;
        56|57) echo "Freezing Drizzle" ;;
        61) echo "Light Rain" ;;
        63) echo "Rain" ;;
        65) echo "Heavy Rain" ;;
        66|67) echo "Freezing Rain" ;;
        71) echo "Light Snow" ;;
        73) echo "Snow" ;;
        75) echo "Heavy Snow" ;;
        77) echo "Snow Grains" ;;
        80|81|82) echo "Showers" ;;
        85|86) echo "Snow Showers" ;;
        95) echo "Thunderstorm" ;;
        96|99) echo "Thunderstorm+Hail" ;;
        *) echo "Unknown" ;;
    esac
}

# Get location from IP (cached)
get_location() {
    if [[ -f "$LOCATION_CACHE" ]]; then
        cat "$LOCATION_CACHE"
        return
    fi
    
    # Use ip-api.com for geolocation (free, no key needed)
    local location
    location=$(curl -s "http://ip-api.com/" 2>/dev/null)
    
    if [[ -n "$location" ]] && echo "$location" | jq -e '.lat' >/dev/null 2>&1; then
        echo "$location" > "$LOCATION_CACHE"
        echo "$location"
    else
        # Fallback to a default (Amman, Jordan)
        echo '{"lat":31.9555,"lon":35.9435,"city":"Amman", "country":"Jordan"}'
    fi
}

# Check if cache is valid (same day)
is_cache_valid() {
    if [[ ! -f "$CACHE_FILE" ]]; then
        return 1
    fi
    
    local cache_date
    cache_date=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || stat -f %m "$CACHE_FILE" 2>/dev/null)
    local cache_day=$(date -d "@$cache_date" +%Y-%m-%d 2>/dev/null || date -r "$cache_date" +%Y-%m-%d 2>/dev/null)
    local today=$(date +%Y-%m-%d)
    
    [[ "$cache_day" == "$today" ]]
}

# Fetch weather data from API
fetch_weather() {
    local location
    location=$(get_location)
    local lat=$(echo "$location" | jq -r '.lat')
    local lon=$(echo "$location" | jq -r '.lon')
    
    local url="https://api.open-meteo.com/v1/forecast?latitude=${lat}&longitude=${lon}&current=temperature_2m,weather_code&hourly=temperature_2m,weather_code&daily=temperature_2m_max,temperature_2m_min,weather_code&timezone=auto&forecast_days=14"
    
    curl -s "$url" 2>/dev/null
}

# Format the output
format_output() {
    local data="$1"
    
    # Current weather
    local current_temp=$(echo "$data" | jq -r '.current.temperature_2m // "N/A"')
    local current_code=$(echo "$data" | jq -r '.current.weather_code // 0')
    local emoji=$(get_weather_emoji "$current_code")
    
    # Today's high/low
    local today_max=$(echo "$data" | jq -r '.daily.temperature_2m_max[0] // "N/A"')
    local today_min=$(echo "$data" | jq -r '.daily.temperature_2m_min[0] // "N/A"')
    local today_code=$(echo "$data" | jq -r '.daily.weather_code[0] // 0')
    
    # Build tooltip
    local tooltip=""
    
    # City name
    local city=$(get_location | jq -r '.city // "N/A"')
    local country=$(get_location | jq -r '.country // "N/A"')
    tooltip+="==>  $city/$country  <==\\n"

    # Header: Today's summary
    local today_emoji=$(get_weather_emoji "$today_code")
    tooltip+="$today_emoji Today: ${today_max}° / ${today_min}°C\\n"
    tooltip+="━━━━━━━━━━━━━━━━━━━━━━\\n"
    
    # Hourly forecast (next 12 hours starting from current hour)
    local current_hour=$(date +%H)
    tooltip+="\\n⏰ Next 12 Hours:\\n"
    
    local hourly_times=$(echo "$data" | jq -r '.hourly.time | @json')
    local hourly_temps=$(echo "$data" | jq -r '.hourly.temperature_2m | @json')
    local hourly_codes=$(echo "$data" | jq -r '.hourly.weather_code | @json')
    
    # Find starting index for current hour
    local start_idx=0
    for i in $(seq 0 23); do
        local hour_time=$(echo "$data" | jq -r ".hourly.time[$i]")
        local hour=$(echo "$hour_time" | cut -d'T' -f2 | cut -d':' -f1)
        if [[ "$hour" == "$current_hour" ]]; then
            start_idx=$i
            break
        fi
    done
    
    for i in $(seq $start_idx $((start_idx + 11))); do
        local hour_time=$(echo "$data" | jq -r ".hourly.time[$i]")
        local hour_temp=$(echo "$data" | jq -r ".hourly.temperature_2m[$i]")
        local hour_code=$(echo "$data" | jq -r ".hourly.weather_code[$i]")
        local hour_emoji=$(get_weather_emoji "$hour_code")
        local hour_str=$(echo "$hour_time" | cut -d'T' -f2 | cut -d':' -f1)
        tooltip+="  ${hour_str}:00  $hour_emoji ${hour_temp}°C\\n"
    done
    
    tooltip+="\\n━━━━━━━━━━━━━━━━━━━━━━\\n"
    tooltip+="\\n📅 14-Day Forecast:\\n"
    
    # Daily forecast (14 days)
    for i in $(seq 0 13); do
        local day_date=$(echo "$data" | jq -r ".daily.time[$i]")
        local day_max=$(echo "$data" | jq -r ".daily.temperature_2m_max[$i]")
        local day_min=$(echo "$data" | jq -r ".daily.temperature_2m_min[$i]")
        local day_code=$(echo "$data" | jq -r ".daily.weather_code[$i]")
        local day_emoji=$(get_weather_emoji "$day_code")
        
        # Get day name
        local day_name
        if [[ $i -eq 0 ]]; then
            day_name="Today    "
        elif [[ $i -eq 1 ]]; then
            day_name="Tomorrow "
        else
            day_name=$(date -d "$day_date" +%a 2>/dev/null || date -j -f "%Y-%m-%d" "$day_date" +%a 2>/dev/null)
            day_name=$(printf "%-9s" "$day_name")
        fi
        
        tooltip+="  $day_name $day_emoji ${day_max}° / ${day_min}°C\\n"
    done
    
    # Output JSON
    local text="${emoji} ${current_temp}°C"
    
    jq -cn \
        --arg text "$text" \
        --arg tooltip "$tooltip" \
        '{text: $text, tooltip: $tooltip}'
}

# Main logic
main() {
    local weather_data
    
    if is_cache_valid; then
        weather_data=$(cat "$CACHE_FILE")
    else
        weather_data=$(fetch_weather)
        if [[ -n "$weather_data" ]] && echo "$weather_data" | jq -e '.current' >/dev/null 2>&1; then
            echo "$weather_data" > "$CACHE_FILE"
        else
            # If fetch failed and we have old cache, use it
            if [[ -f "$CACHE_FILE" ]]; then
                weather_data=$(cat "$CACHE_FILE")
            else
                echo '{"text": "Weather N/A", "tooltip": "Failed to fetch weather data"}'
                exit 1
            fi
        fi
    fi
    
    format_output "$weather_data"
}

main
