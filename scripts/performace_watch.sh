
watch -n 1 "cat /proc/cpuinfo | grep MHz"

watch -n 1 "cpupower frequency-info | grep 'current CPU frequency'"


# Look for ACPI devices that might control LEDs
ls /sys/class/leds/
# Check for platform devices
ls /sys/bus/platform/devices/ | grep -i lenovo

#Monitor temps and fan speeds under load:
watch -n 1 sensors
watch -n 1 "sensors 2>/dev/null | grep -v '^ERROR:' | sed 's/&/\&amp;/g; s/</\&lt;/g; s/>/\&gt;/g'"

