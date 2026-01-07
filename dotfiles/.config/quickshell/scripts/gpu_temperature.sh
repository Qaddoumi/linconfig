#!/usr/bin/env bash

### Nvidia GPU Temperature Script

get_gpu_temp() {
	local temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

	if [ -z "$temp" ]; then
		echo "N/A"
	else
		echo "$temp"
	fi
}

get_full_gpu_data() {
	# Get full sensors output and format for tooltip
	nvidia-smi -q | grep -vE "N/A|Disabled|None|Not Active|0 MiB|Requested functionality has been deprecated" | grep -v "Pending" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}


case $1 in
	--temp)
		get_gpu_temp
		;;
	--tooltip)
		get_full_gpu_data
		;;
	*)
		# Default output for waybar (JSON format)
		temp=$(get_gpu_temp)
		tooltip=$(get_full_gpu_data)

		# Extract numeric value for CSS classes
		temp_num=$(echo "$temp" | grep -oE '[0-9]+' | head -1)

		# Determine CSS class based on temperature
		if [ -n "$temp_num" ]; then
			if [ "$temp_num" -lt 50 ]; then
				class="cool"
			elif [ "$temp_num" -lt 70 ]; then
				class="warm"
			elif [ "$temp_num" -lt 85 ]; then
				class="hot"
			else
				class="critical"
			fi
		else
			class="unknown"
		fi

		# Output JSON for Waybar
		echo "{\"text\":\"$temp\",\"tooltip\":\"$tooltip\",\"class\":\"$class\"}"
		;;
esac