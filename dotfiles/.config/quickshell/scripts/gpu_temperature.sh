#!/usr/bin/env bash


get_gpu_temp() {
	nvidia-smi --query-gpu=temperature.gpu --format=csv,noheader
}

get_full_sensors() {
	# Get full sensors output and format for tooltip
	nvidia-smi -q | grep -vE "N/A|Disabled|None|Not Active|0 MiB|Requested functionality has been deprecated" | grep -v "Pending" | sed 's/\\/\\\\/g; s/"/\\"/g; s/$/\\n/' | tr -d '\n' | sed 's/\\n$//'
}

