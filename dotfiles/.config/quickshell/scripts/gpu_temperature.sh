#!/usr/bin/env bash

### Nvidia GPU Temperature Script

get_gpu_temp() {
	local temp=$(nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader)

	if [ -z "$temp" ] || [[ "$temp" == *"command not found"* ]]; then
		echo "N/A"
	else
		echo "$temp°C"
	fi
}

get_full_gpu_data() {
	# Get GPU stats
    # nvidia-smi -q | grep -vE "N/A|Disabled|None|Not Active|0 MiB|Requested functionality has been deprecated" | grep -v "Pending" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
	gpu_stats=$(nvidia-smi --query-gpu=name,temperature.gpu,utilization.gpu,utilization.memory,memory.total,memory.used,memory.free,power.draw --format=csv,noheader,nounits | \
awk -F', ' '{
    print "name: "$1
    print "temperature.gpu: "$2" C"
    print "utilization.gpu: "$3" %"
    print "utilization.memory: "$4" %"
    print "memory.total: "$5" MiB"
    print "memory.used: "$6" MiB"
    print "memory.free: "$7" MiB"
    print "power.draw: "$8" W"
}')

	# Get processes using the GPU (Universal query for C and G types)
	apps_raw=$(nvidia-smi -q -d PIDS | awk -F': ' '/Name/ {name=$2} /Used GPU Memory/ {if(name) print name ": " $2; name=""}')

	if [ -n "$apps_raw" ]; then
		formatted_apps=$(echo "$apps_raw" | awk 'BEGIN { print "\nProcesses:" } { print $0 }')
		gpu_stats="${gpu_stats}${formatted_apps}"
	fi

	echo "$gpu_stats" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
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