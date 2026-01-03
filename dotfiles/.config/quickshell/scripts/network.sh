#!/usr/bin/env bash
# Network status script for Quickshell

# Storage for bandwidth calculation (uses temp files for persistence between calls)
BANDWIDTH_FILE="/tmp/quickshell_network_bandwidth"

# Find the default interface (the one with a default route)
get_default_interface() {
	ip route show default 2>/dev/null | awk '/default/ {print $5; exit}'
}

# Get interface IP address
get_ip_address() {
	local iface="$1"
	ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}' | cut -d/ -f1
}

get_ip6_address() {
	local iface="$1"
	ip -6 addr show "$iface" scope global 2>/dev/null | awk '/inet6/ {print $2; exit}' | cut -d/ -f1
}

# Get gateway address
get_gateway() {
	ip route show default 2>/dev/null | awk '/default/ {print $3; exit}'
}

# Get netmask/CIDR
get_cidr() {
	local iface="$1"
	ip -4 addr show "$iface" 2>/dev/null | awk '/inet / {print $2; exit}' | cut -d/ -f2
}

# Check if interface is wireless
is_wireless() {
	local iface="$1"
	[ -d "/sys/class/net/$iface/wireless" ]
}

# Get WiFi info using iw (preferred) or iwconfig (fallback)
get_wifi_info() {
	local iface="$1"
	local essid="" bssid="" signal_dbm=0 signal_percent=0 frequency=""

	if command -v iw &>/dev/null; then
		# Use iw for WiFi info
		local info
		info=$(iw dev "$iface" link 2>/dev/null)
		
		essid=$(echo "$info" | awk -F: '/SSID:/ {gsub(/^[ \t]+/, "", $2); print $2}')
		bssid=$(echo "$info" | awk '/Connected to/ {print $3}')
		signal_dbm=$(echo "$info" | awk '/signal:/ {print $2}')
		frequency=$(echo "$info" | awk '/freq:/ {printf "%.1f", $2/1000}')
		
		# Convert dBm to percentage (rough approximation)
		# -30 dBm = 100%, -90 dBm = 0%
		if [ -n "$signal_dbm" ] && [ "$signal_dbm" -lt 0 ] 2>/dev/null; then
			signal_percent=$(( (signal_dbm + 90) * 100 / 60 ))
			[ "$signal_percent" -gt 100 ] && signal_percent=100
			[ "$signal_percent" -lt 0 ] && signal_percent=0
		fi
	elif command -v iwconfig &>/dev/null; then
		# Fallback to iwconfig
		local info
		info=$(iwconfig "$iface" 2>/dev/null)
		
		essid=$(echo "$info" | awk -F'"' '/ESSID/ {print $2}')
		bssid=$(echo "$info" | awk '/Access Point:/ {print $NF}')
		signal_percent=$(echo "$info" | awk -F'[= ]' '/Link Quality/ {split($3, a, "/"); if(a[2]>0) printf "%d", a[1]*100/a[2]}')
		frequency=$(echo "$info" | awk '/Frequency:/ {print $2}' | tr -d 'GHz')
	fi

	echo "${essid:-}|${bssid:-}|${signal_dbm:-0}|${signal_percent:-0}|${frequency:-0}"
}

# Read bandwidth from /proc/net/dev
get_bandwidth() {
	local iface="$1"
	local rx_bytes=0 tx_bytes=0
	
	while IFS= read -r line; do
		if [[ "$line" =~ ^[[:space:]]*${iface}: ]]; then
			read -r _ rx_bytes _ _ _ _ _ _ _ tx_bytes _ <<< "$line"
			break
		fi
	done < /proc/net/dev
	
	echo "$rx_bytes $tx_bytes"
}

# Calculate bandwidth speed
calculate_bandwidth_speed() {
	local iface="$1"
	local current_time rx_bytes tx_bytes
	local prev_time prev_rx prev_tx
	local rx_speed=0 tx_speed=0
	
	current_time=$(date +%s.%N)
	read -r rx_bytes tx_bytes <<< "$(get_bandwidth "$iface")"
	
	if [ -f "$BANDWIDTH_FILE" ]; then
		read -r prev_time prev_rx prev_tx < "$BANDWIDTH_FILE"
		
		local time_diff
		time_diff=$(echo "$current_time - $prev_time" | bc 2>/dev/null || echo "1")
		
		if [ "$(echo "$time_diff > 0" | bc 2>/dev/null)" = "1" ]; then
			rx_speed=$(echo "scale=0; ($rx_bytes - $prev_rx) / $time_diff" | bc 2>/dev/null || echo "0")
			tx_speed=$(echo "scale=0; ($tx_bytes - $prev_tx) / $time_diff" | bc 2>/dev/null || echo "0")
			
			# Ensure non-negative
			[ "$rx_speed" -lt 0 ] 2>/dev/null && rx_speed=0
			[ "$tx_speed" -lt 0 ] 2>/dev/null && tx_speed=0
		fi
	fi
	
	# Save current values for next calculation
	echo "$current_time $rx_bytes $tx_bytes" > "$BANDWIDTH_FILE"
	
	echo "$rx_speed $tx_speed"
}

# Format bytes to human readable
format_bytes() {
	local bytes="$1"
	local suffix="${2:-B/s}"
	
	if [ "$bytes" -ge 1073741824 ] 2>/dev/null; then
		echo "$(echo "scale=1; $bytes / 1073741824" | bc)G$suffix"
	elif [ "$bytes" -ge 1048576 ] 2>/dev/null; then
		echo "$(echo "scale=1; $bytes / 1048576" | bc)M$suffix"
	elif [ "$bytes" -ge 1024 ] 2>/dev/null; then
		echo "$(echo "scale=1; $bytes / 1024" | bc)K$suffix"
	else
		echo "${bytes}$suffix"
	fi
}

# Get network state
get_network_state() {
	local iface="$1"
	local ip="$2"
	local essid="$3"
	
	if [ -z "$iface" ]; then
		echo "disconnected"
	elif [ -z "$ip" ]; then
		echo "linked"
	elif [ -n "$essid" ]; then
		echo "wifi"
	else
		echo "ethernet"
	fi
}

# Check carrier status
get_carrier() {
	local iface="$1"
	cat "/sys/class/net/$iface/carrier" 2>/dev/null || echo "0"
}

# Main logic
main() {
	local iface
	iface=$(get_default_interface)
	
	if [ -z "$iface" ]; then
		echo '{"state": "disconnected", "ifname": "", "ipaddr": "", "gateway": "", "essid": "", "signalStrength": 0, "bandwidthDown": "0B/s", "bandwidthUp": "0B/s"}'
		exit 0
	fi
	
	local ipaddr ipaddr6 gateway cidr carrier
	ipaddr=$(get_ip_address "$iface")
	ipaddr6=$(get_ip6_address "$iface")
	gateway=$(get_gateway)
	cidr=$(get_cidr "$iface")
	carrier=$(get_carrier "$iface")
	
	local essid="" bssid="" signal_dbm=0 signal_percent=0 frequency=""
	if is_wireless "$iface"; then
		IFS='|' read -r essid bssid signal_dbm signal_percent frequency <<< "$(get_wifi_info "$iface")"
	fi
	
	local state
	state=$(get_network_state "$iface" "$ipaddr" "$essid")
	
	local rx_speed tx_speed
	read -r rx_speed tx_speed <<< "$(calculate_bandwidth_speed "$iface")"
	
	local bandwidth_down bandwidth_up
	bandwidth_down=$(format_bytes "$rx_speed")
	bandwidth_up=$(format_bytes "$tx_speed")
	
	# Select icon based on state and signal
	local icon=""
	case "$state" in
		"disconnected")
			icon="󰤭"  # No network
			;;
		"linked")
			icon="󰤩"  # Connected but no IP
			;;
		"ethernet")
			icon="󰈀"  # Ethernet
			;;
		"wifi")
			if [ "$signal_percent" -ge 80 ]; then
				icon="󰤨"  # Excellent signal
			elif [ "$signal_percent" -ge 60 ]; then
				icon="󰤥"  # Good signal
			elif [ "$signal_percent" -ge 40 ]; then
				icon="󰤢"  # Fair signal
			elif [ "$signal_percent" -ge 20 ]; then
				icon="󰤟"  # Weak signal
			else
				icon="󰤯"  # Very weak signal
			fi
			;;
	esac
	
	# Output JSON
	cat <<EOF
{"state": "$state", "ifname": "$iface", "ipaddr": "$ipaddr", "ipaddr6": "${ipaddr6:-}", "gateway": "$gateway", "cidr": ${cidr:-0}, "carrier": $carrier, "essid": "${essid:-}", "bssid": "${bssid:-}", "signalDbm": ${signal_dbm:-0}, "signalStrength": ${signal_percent:-0}, "frequency": "${frequency:-0}", "bandwidthDown": "$bandwidth_down", "bandwidthUp": "$bandwidth_up", "bandwidthDownBytes": ${rx_speed:-0}, "bandwidthUpBytes": ${tx_speed:-0}, "icon": "$icon"}
EOF
}

main
