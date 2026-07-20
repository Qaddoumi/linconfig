#!/usr/bin/env bash

no_json=false
for arg in "$@"; do
	if [[ "$arg" == "nojson" ]]; then
		no_json=true
		break
	fi
done

HIJRI_CACHE="/tmp/hijri_date_cache_$(date +%Y)-$(date +%m)-$(date +%d)"
SETTINGS_FILE="$HOME/.config/quickshell/settings.json"
settings=$(cat "$SETTINGS_FILE" | jq -r '.prayerTimes // empty')
latitude=$(echo "$settings" | jq -r '.latitude // empty')
longitude=$(echo "$settings" | jq -r '.longitude // empty')
city=$(echo "$settings" | jq -r '.city // empty')
country=$(echo "$settings" | jq -r '.country // empty')
timezone=$(echo "$settings" | jq -r '.timezone // empty')
elevation=$(echo "$settings" | jq -r '.elevation // empty')
bashIslamMethod=$(echo "$settings" | jq -r '.bashIslamMethod // empty')
bashIslamMadhab=$(echo "$settings" | jq -r '.bashIslamMadhab // empty')
bashIslamSummerTime=$(echo "$settings" | jq -r '.bashIslamSummerTime // empty')
apiMethod=$(echo "$settings" | jq -r '.apiMethod // empty')

# Get prayer times using local bashIslam script
get_prayer_times_local() {
	local prayer_data
	
	prayer_data=$(bashIslam --lat "$latitude" --lon "$longitude" --timezone "$timezone" --method "$bashIslamMethod" --madhab "$bashIslamMadhab" --summer-time "$bashIslamSummerTime" --elevation "$elevation" 2>/dev/null | jq -c 2>/dev/null)
	
	if [[ -n "$prayer_data" ]]; then
		local fajr=$(echo "$prayer_data" | jq -r '.prayers.fajr // empty')
		local dhuhr=$(echo "$prayer_data" | jq -r '.prayers.dhuhr // empty')
		local asr=$(echo "$prayer_data" | jq -r '.prayers.asr // empty')
		local maghrib=$(echo "$prayer_data" | jq -r '.prayers.maghreb // empty')
		local isha=$(echo "$prayer_data" | jq -r '.prayers.ishaa // empty')

		local hijri_day=$(echo "$prayer_data" | jq -r '.hijri.day // empty')
		local hijri_month=$(echo "$prayer_data" | jq -r '.hijri.month // empty')
		local hijri_year=$(echo "$prayer_data" | jq -r '.hijri.year // empty')

		if [[ -n "$hijri_day" && -n "$hijri_month" && -n "$hijri_year" ]]; then
			# Write/overwrite Hijri data in cache file
			cat > "$HIJRI_CACHE" << EOF
day=$hijri_day
month=$hijri_month
year=$hijri_year
EOF
		fi

		if [[ -n "$fajr" && "$fajr" != "null" ]]; then
			# Cut seconds for HH:MM format
			fajr=$(echo "$fajr" | cut -d: -f1,2)
			dhuhr=$(echo "$dhuhr" | cut -d: -f1,2)
			asr=$(echo "$asr" | cut -d: -f1,2)
			maghrib=$(echo "$maghrib" | cut -d: -f1,2)
			isha=$(echo "$isha" | cut -d: -f1,2)
			
			echo "$fajr $dhuhr $asr $maghrib $isha"
			return 0
		fi
	fi
	
	return 1
}






# Prayer names in order
PRAYER_NAMES=("Fajr" "Dhuhr" "Asr" "Maghrib" "Isha")

# Get current time in seconds since epoch
current_timestamp=$(date +%s)
current_time=$(date +%H:%M)

# Function to convert time to seconds since midnight
time_to_seconds() {
	local time_str="$1"
	local hour=$(echo "$time_str" | cut -d: -f1)
	local minute=$(echo "$time_str" | cut -d: -f2)
	echo $(( 10#$hour * 3600 + 10#$minute * 60 ))
}

# Function to format seconds to HH:MM
seconds_to_time() {
	local total_seconds="$1"
	local hours=$(( total_seconds / 3600 ))
	local minutes=$(( (total_seconds % 3600) / 60 ))
	printf "%02d:%02d" "$hours" "$minutes"
}

# Function to calculate time difference
time_diff() {
	local prayer_time="$1"
	local current_seconds=$(time_to_seconds "$current_time")
	local prayer_seconds=$(time_to_seconds "$prayer_time")
	
	# If prayer time is tomorrow (e.g., Fajr after midnight)
	if [ $prayer_seconds -lt $current_seconds ]; then
		prayer_seconds=$(( prayer_seconds + 86400 ))
	fi
	
	local diff=$(( prayer_seconds - current_seconds ))
	echo "$diff"
}

# Get prayer times using online API
get_prayer_times_api() {
	local prayer_data
	local today=$(date +%d-%m-%Y)
	
	# API 1: AlAdhan API

	# Configuration for the api only - Update these with your location

### Possible values:
# 0 - Jafari / Shia Ithna-Ashari
# 1 - University of Islamic Sciences, Karachi
# 2 - Islamic Society of North America
# 3 - Muslim World League
# 4 - Umm Al-Qura University, Makkah
# 5 - Egyptian General Authority of Survey
# 7 - Institute of Geophysics, University of Tehran
# 8 - Gulf Region
# 9 - Kuwait
# 10 - Qatar
# 11 - Majlis Ugama Islam Singapura, Singapore
# 12 - Union Organization islamic de France
# 13 - Diyanet İşleri Başkanlığı, Turkey
# 14 - Spiritual Administration of Muslims of Russia
# 15 - Moonsighting Committee Worldwide (also requires shafaq parameter)
# 16 - Dubai (experimental)
# 17 - Jabatan Kemajuan Islam Malaysia (JAKIM)
# 18 - Tunisia
# 19 - Algeria
# 20 - KEMENAG - Kementerian Agama Republik Indonesia
# 21 - Morocco
# 22 - Comunidade Islamica de Lisboa
# 23 - Ministry of Awqaf, Islamic Affairs and Holy Places, Jordan
# 99 - Custom. See https://aladhan.com/calculation-methods
	prayer_data=$(curl -s --connect-timeout 5 "http://api.aladhan.com/v1/timings/$today?latitude=$latitude&longitude=$longitude&method=$apiMethod" 2>/dev/null)
	
	if [[ -n "$prayer_data" && "$prayer_data" != *"error"* ]]; then
		local fajr=$(echo "$prayer_data" | jq -r '.data.timings.Fajr' | cut -d' ' -f1)
		local dhuhr=$(echo "$prayer_data" | jq -r '.data.timings.Dhuhr' | cut -d' ' -f1)
		local asr=$(echo "$prayer_data" | jq -r '.data.timings.Asr' | cut -d' ' -f1)
		local maghrib=$(echo "$prayer_data" | jq -r '.data.timings.Maghrib' | cut -d' ' -f1)
		local isha=$(echo "$prayer_data" | jq -r '.data.timings.Isha' | cut -d' ' -f1)
		
		if [[ "$fajr" != "null" && -n "$fajr" ]]; then
			echo "$fajr $dhuhr $asr $maghrib $isha"
			return 0
		fi
	fi
	
	# API 2: Prayer Times API
	prayer_data=$(curl -s --connect-timeout 5 "https://api.pray.zone/v2/times/today.json?city=$city&country=$country" 2>/dev/null)
	
	if [[ -n "$prayer_data" && "$prayer_data" != *"error"* ]]; then
		local fajr=$(echo "$prayer_data" | jq -r '.results.datetime[0].times.Fajr')
		local dhuhr=$(echo "$prayer_data" | jq -r '.results.datetime[0].times.Dhuhr')
		local asr=$(echo "$prayer_data" | jq -r '.results.datetime[0].times.Asr')
		local maghrib=$(echo "$prayer_data" | jq -r '.results.datetime[0].times.Maghrib')
		local isha=$(echo "$prayer_data" | jq -r '.results.datetime[0].times.Isha')
		
		if [[ "$fajr" != "null" && -n "$fajr" ]]; then
			echo "$fajr $dhuhr $asr $maghrib $isha"
			return 0
		fi
	fi
	
	return 1
}

# Get prayer times
prayer_times=$(get_prayer_times_local)
if [[ $? -ne 0 || -z "$prayer_times" ]]; then
	prayer_times=$(get_prayer_times_api)
	if [[ $? -ne 0 || -z "$prayer_times" ]]; then
		offline_mode="(offline)"
		exit 1
	fi
fi

# Parse prayer times
read -r fajr dhuhr asr maghrib isha <<< "$prayer_times"
prayer_array=("$fajr" "$dhuhr" "$asr" "$maghrib" "$isha")

# Find next prayer
next_prayer=""
next_prayer_name=""
min_diff=999999
current_prayer=""

for i in "${!prayer_array[@]}"; do
	prayer_time="${prayer_array[$i]}"
	prayer_name="${PRAYER_NAMES[$i]}"
	diff=$(time_diff "$prayer_time")
	
	# Check if this is the current prayer (within 30 minutes after start)
	if [[ $diff -lt 0 && $diff -gt -1800 ]]; then
		current_prayer="$prayer_name"
	fi
	
	# Find next upcoming prayer
	if [[ $diff -gt 0 && $diff -lt $min_diff ]]; then
		min_diff=$diff
		next_prayer="$prayer_time"
		next_prayer_name="$prayer_name"
	fi
done

# If no prayer found for today, next is tomorrow's Fajr
if [[ -z "$next_prayer" ]]; then
	next_prayer="$fajr"
	next_prayer_name="Fajr"
	min_diff=$(( $(time_to_seconds "$fajr") + 86400 - $(time_to_seconds "$current_time") ))
fi

# Format time remaining
hours_left=$(( min_diff / 3600 ))
minutes_left=$(( (min_diff % 3600) / 60 ))

if [[ $hours_left -gt 0 ]]; then
	time_remaining="${hours_left}h ${minutes_left}m"
else
	time_remaining="${minutes_left}m"
fi

# Create tooltip with all prayer times
tooltip="Prayer Times in $city/$country\\n"
tooltip+="\\n"
tooltip+="Fajr:    $fajr\\n"
tooltip+="Dhuhr:   $dhuhr\\n"
tooltip+="Asr:     $asr\\n"
tooltip+="Maghrib: $maghrib\\n"
tooltip+="Isha:    $isha\\n\\n"
tooltip+="Next:    $next_prayer_name in $time_remaining"

# Current prayer indicator
if [[ -n "$current_prayer" ]]; then
	display_text="$current_prayer"
	class="current-prayer"
else
	display_text="$next_prayer_name $time_remaining"
	class="next-prayer"
fi

# Output for Waybar
if $no_json; then
	echo "$tooltip"
else
	echo "{\"text\":\"󱠧 $display_text\", \"tooltip\":\"$tooltip\", \"class\":\"$class\"}"
fi