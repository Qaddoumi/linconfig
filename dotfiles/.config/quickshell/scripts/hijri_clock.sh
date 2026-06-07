#!/usr/bin/env bash


HIJRI_CACHE="/tmp/hijri_date_cache_$(date +%Y)-$(date +%m)-$(date +%d)"

# Get current Hijri date using online API
get_hijri_date() {

	local hijri_date

	local day=$(grep "^day=" $HIJRI_CACHE | cut -d= -f2)
	local month=$(grep "^month=" $HIJRI_CACHE | cut -d= -f2)
	local year=$(grep "^year=" $HIJRI_CACHE | cut -d= -f2)

	if [[ -n "$day" && -n "$month" && -n "$year" ]]; then
		hijri_date="$day-$month-$year"
		echo "$hijri_date"
		return 0
	fi

	# Try multiple APIs for reliability

	# API 1: AlAdhan API
	hijri_date=$(curl -s --connect-timeout 5 "https://api.aladhan.com/v1/gToH/$(date +%d-%m-%Y)" | jq -r '.data.hijri.date' 2>/dev/null)

	if [[ "$hijri_date" != "null" && -n "$hijri_date" ]]; then
		echo "$hijri_date"
		return 0
	fi

	# API 2: UmmahAPI
	hijri_date=$(curl -s --connect-timeout 5 "https://ummahapi.com/api/hijri-date?date=$(date +%Y-%m-%d)" | jq -r '.data.hijri.date' 2>/dev/null)

	if [[ "$hijri_date" != "null" && -n "$hijri_date" ]]; then
		echo "$hijri_date"
		return 0
	fi

	# Fallback: show error
	echo "N/A"
}

# Get Hijri date (try API, fallback to offline)
HIJRI_DATE=$(get_hijri_date)
DAY_NAME=$(date "+%A")
GREG_MONTH_NAME=$(date "+%B")

if [[ "$HIJRI_DATE" == "N/A" ]]; then
	echo "{\"tooltip\":\"$DAY_NAME \\nGregorian: $GREG_MONTH_NAME $(date '+%d-%m-%Y')\\nHijri: N/A\"}"
else
	# Hijri month names (1-based index)
	HIJRI_MONTHS=("Muharram" "Safar" "Rabi' al-awwal" "Rabi' al-thani" "Jumada al-awwal" "Jumada al-thani" "Rajab" "Sha'ban" "Ramadan" "Shawwal" "Dhu al-Qi'dah" "Dhu al-Hijjah")

	# Parse Hijri date into day, month, year
	if [[ "$HIJRI_DATE" =~ ^([0-9]{1,2})[/-]([0-9]{1,2})[/-]([0-9]{2,4})$ ]]; then
		hijri_day="${BASH_REMATCH[1]}"
		hijri_month="${BASH_REMATCH[2]}"
		hijri_year="${BASH_REMATCH[3]}"
		hijri_month_name="${HIJRI_MONTHS[$((hijri_month-1))]}"
		HIJRI_FORMATTED="$hijri_day $hijri_month_name $hijri_year"
	else
		HIJRI_FORMATTED="$HIJRI_DATE"
	fi

	# Get regular time
	REGULAR_TIME=$(date "+%I:%M %p")

	# Output for Waybar
	echo "{\"tooltip\":\"$DAY_NAME \\nGregorian: $GREG_MONTH_NAME $(date '+%d-%m-%Y')\\nHijri: $hijri_month_name $HIJRI_DATE\"}"

fi
