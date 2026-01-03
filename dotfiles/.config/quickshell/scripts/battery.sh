#!/usr/bin/env bash
# Battery status script for Quickshell

BAT=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^BAT' | head -1)
AC=$(ls /sys/class/power_supply/ 2>/dev/null | grep -E '^(AC|ADP|ACAD)' | head -1)

if [ -z "$BAT" ]; then
	echo '{"error": "No battery found"}'
	exit 0
fi

BAT_PATH="/sys/class/power_supply/$BAT"

capacity=$(cat "$BAT_PATH/capacity" 2>/dev/null || echo "0")
status=$(cat "$BAT_PATH/status" 2>/dev/null || echo "Unknown")

# Check if plugged in
plugged=0
if [ -n "$AC" ]; then
	plugged=$(cat "/sys/class/power_supply/$AC/online" 2>/dev/null || echo "0")
fi

# Get battery power consumption (in microwatts, convert to watts)
power_now=$(cat "$BAT_PATH/power_now" 2>/dev/null || echo "0")
power=$(echo "scale=1; $power_now / 1000000" | bc 2>/dev/null || echo "0")

# Get adapter/cable power (if available)
adapter_power="0"
if [ -n "$AC" ] && [ "$plugged" = "1" ]; then
	# Some systems report adapter power in the AC supply
	AC_PATH="/sys/class/power_supply/$AC"
	adapter_power_now=$(cat "$AC_PATH/power_now" 2>/dev/null || echo "")
	if [ -n "$adapter_power_now" ] && [ "$adapter_power_now" != "0" ]; then
		adapter_power=$(echo "scale=1; $adapter_power_now / 1000000" | bc 2>/dev/null || echo "0")
	else
		# Fallback: Try to read from uevent or calculate from voltage/current
		voltage=$(cat "$AC_PATH/voltage_now" 2>/dev/null || echo "0")
		current=$(cat "$AC_PATH/current_now" 2>/dev/null || echo "0")
		if [ "$voltage" != "0" ] && [ "$current" != "0" ]; then
			adapter_power=$(echo "scale=1; ($voltage * $current) / 1000000000000" | bc 2>/dev/null || echo "0")
		fi
	fi
fi

# Get charge cycle count
cycles=$(cat "$BAT_PATH/cycle_count" 2>/dev/null || echo "0")

# Calculate health (current full capacity vs design capacity)
energy_full=$(cat "$BAT_PATH/energy_full" 2>/dev/null || cat "$BAT_PATH/charge_full" 2>/dev/null || echo "0")
energy_full_design=$(cat "$BAT_PATH/energy_full_design" 2>/dev/null || cat "$BAT_PATH/charge_full_design" 2>/dev/null || echo "0")
if [ "$energy_full_design" -gt 0 ] 2>/dev/null; then
	health=$(echo "scale=0; $energy_full * 100 / $energy_full_design" | bc 2>/dev/null || echo "100")
else
	health=100
fi

# Calculate time remaining
time_remaining=""
time_to_empty=$(cat "$BAT_PATH/time_to_empty_now" 2>/dev/null || echo "")
time_to_full=$(cat "$BAT_PATH/time_to_full_now" 2>/dev/null || echo "")

# Fallback calculation based on power
if [ -z "$time_to_empty" ] && [ -z "$time_to_full" ] && [ "$power_now" -gt 0 ] 2>/dev/null; then
	energy_now=$(cat "$BAT_PATH/energy_now" 2>/dev/null || cat "$BAT_PATH/charge_now" 2>/dev/null || echo "0")
	if [ "$status" = "Discharging" ] && [ "$energy_now" -gt 0 ]; then
		minutes=$(echo "scale=0; $energy_now * 60 / $power_now" | bc 2>/dev/null || echo "0")
		hours=$((minutes / 60))
		mins=$((minutes % 60))
		time_remaining="${hours}h ${mins}m remaining"
	elif [ "$status" = "Charging" ] && [ "$energy_full" -gt 0 ]; then
		remaining=$((energy_full - energy_now))
		if [ "$remaining" -gt 0 ]; then
			minutes=$(echo "scale=0; $remaining * 60 / $power_now" | bc 2>/dev/null || echo "0")
			hours=$((minutes / 60))
			mins=$((minutes % 60))
			time_remaining="${hours}h ${mins}m to full"
		fi
	fi
else
	if [ -n "$time_to_empty" ] && [ "$time_to_empty" -gt 0 ] 2>/dev/null; then
		hours=$((time_to_empty / 60))
		mins=$((time_to_empty % 60))
		time_remaining="${hours}h ${mins}m remaining"
	elif [ -n "$time_to_full" ] && [ "$time_to_full" -gt 0 ] 2>/dev/null; then
		hours=$((time_to_full / 60))
		mins=$((time_to_full % 60))
		time_remaining="${hours}h ${mins}m to full"
	fi
fi

echo "{\"capacity\": $capacity, \"status\": \"$status\", \"plugged\": $plugged, \"power\": $power, \"adapterPower\": $adapter_power, \"cycles\": $cycles, \"health\": $health, \"timeRemaining\": \"$time_remaining\"}"
