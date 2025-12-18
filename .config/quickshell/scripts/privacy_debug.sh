#!/usr/bin/env bash
# Debug script for Quickshell Privacy widget

echo "Checking for required tools..."
command -v pw-dump >/dev/null && echo "pw-dump found" || echo "pw-dump NOT found"
command -v jq >/dev/null && echo "jq found" || echo "jq NOT found"

echo "----------------------------------------"
echo "Camera Hardware (Video/Source nodes):"
pw-dump 2>/dev/null | jq -r '
    .[] | 
    select(.type == "PipeWire:Interface:Node") |
    select(.info.props["media.class"] == "Video/Source") |
    "ID: \(.id)\nName: \(.info.props["node.name"])\nMedia Class: \(.info.props["media.class"])\nState: \(.info.state)\n----------------------------------------"
' || echo "None found"

echo ""
echo "----------------------------------------"
echo "Active Camera STREAMS (Stream/Output/Video - what we actually want!):"
streams=$(pw-dump 2>/dev/null | jq -r '
    .[] | 
    select(.type == "PipeWire:Interface:Node") |
    select(.info.props["media.class"] == "Stream/Output/Video") |
    "ID: \(.id)\nApp: \(.info.props["application.name"] // "Unknown")\nNode Name: \(.info.props["node.name"])\nMedia Class: \(.info.props["media.class"])\nState: \(.info.state)\n----------------------------------------"
')

if [[ -z "$streams" ]]; then
    echo "No active camera streams found."
else
    echo "$streams"
fi

echo ""
echo "----------------------------------------"
echo "ALL Stream nodes (running only):"
pw-dump 2>/dev/null | jq -r '
    .[] | 
    select(.type == "PipeWire:Interface:Node") |
    select(.info.state == "running") |
    select(.info.props["media.class"] | strings | test("Stream")) |
    "ID: \(.id)\nApp: \(.info.props["application.name"] // "Unknown")\nMedia Class: \(.info.props["media.class"])\nState: \(.info.state)\n----------------------------------------"
' || echo "None found"