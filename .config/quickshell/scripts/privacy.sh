#!/usr/bin/env bash
# Privacy widget script for Quickshell
# Detects active microphone, camera, and screenshare usage via PipeWire AND direct V4L2 access
# Optimized for speed by piping directly to jq

# Check if required tools are available
if ! command -v pw-dump &>/dev/null || ! command -v jq &>/dev/null; then
    echo '{"visible":false,"text":"","tooltip":"","items":[]}'
    exit 0
fi

# Check for direct camera access via V4L2 (Chrome and other apps bypass PipeWire)
camera_apps=()
if command -v lsof &>/dev/null; then
    # Get processes using /dev/video* devices
    while IFS= read -r line; do
        # Extract process name, skip header and empty lines
        if [[ "$line" =~ ^[^C] ]] && [[ -n "$line" ]]; then
            app=$(echo "$line" | awk '{print $1}')
            [[ -n "$app" ]] && camera_apps+=("$app")
        fi
    done < <(lsof /dev/video* 2>/dev/null)
fi

# Remove duplicates from camera_apps and create JSON array
if [[ ${#camera_apps[@]} -gt 0 ]]; then
    camera_apps_unique=($(printf '%s\n' "${camera_apps[@]}" | sort -u))
    v4l2_json=$(printf '%s\n' "${camera_apps_unique[@]}" | jq -R . | jq -s .)
else
    v4l2_json="[]"
fi

# Run pw-dump and parse with jq in a single pipeline for speed
result=$(pw-dump 2>/dev/null | jq -c --argjson v4l2_apps "$v4l2_json" '
    # Filter to running nodes with relevant media classes
    [.[] | select(.type == "PipeWire:Interface:Node") |
     select(.info.state == "running" or .info.state == "suspended") |  # Optional: include suspended for open streams
     {
        app_name: (.info.props["application.name"] // .info.props["node.name"] // "Unknown"),
        media_class: .info.props["media.class"],
        media_name: .info.props["media.name"] // ""
     } |
     select(.media_class == "Stream/Input/Audio" or 
            .media_class == "Audio/Source" or .media_class == "Audio/Source/Virtual" or  # Add source/virtual for better mic detection
            .media_class == "Stream/Input/Video")
    ] |
    
    # Group by type
    {
        audio_in: [.[] | select(.media_class | contains("Audio")) | .app_name] | unique,  # Broader for mic
        video_in: [.[] | select(.media_class == "Stream/Input/Video") | {app_name: .app_name, media_name: .media_name}],
    } |
    
    # Split video_in into camera and screenshare based on media_name patterns
    .screenshare = [.video_in[] | select(.media_name | test("xdph-streaming|gsr-default|game capture"; "i")) | .app_name] | unique |
    .video_out = [.video_in[] | select(.media_name | test("xdph-streaming|gsr-default|game capture"; "i") | not) | .app_name] | unique |
    del(.video_in) |
    
    # Add V4L2 camera apps to video_out
    .video_out = ((.video_out // []) + ($v4l2_apps // [])) | unique |
    
    # Build output (same as original)
    {
        visible: ((.audio_in | length) > 0 or (.video_out | length) > 0 or (.screenshare | length) > 0),
        text: (
            (if (.audio_in | length) > 0 then "󰍬 " else "" end) +
            (if (.video_out | length) > 0 then "󰄀 " else "" end) +
            (if (.screenshare | length) > 0 then "󰹑 " else "" end)
        ) | rtrimstr(" "),
        tooltip: (
            (if (.audio_in | length) > 0 then "Microphone:\\n" + (.audio_in | map("  • " + .) | join("\\n")) + "\\n" else "" end) +
            (if (.video_out | length) > 0 then "Camera:\\n" + (.video_out | map("  • " + .) | join("\\n")) + "\\n" else "" end) +
            (if (.screenshare | length) > 0 then "Screenshare:\\n" + (.screenshare | map("  • " + .) | join("\\n")) + "\\n" else "" end)
        ) | rtrimstr("\\n"),
        items: (
            [.audio_in[] | {type: "audio-in", name: ., icon: "󰍬"}] +
            [.video_out[] | {type: "video-out", name: ., icon: "󰄀"}] +
            [.screenshare[] | {type: "screenshare", name: ., icon: "󰹑"}]
        )
    }
' 2>/dev/null)

# If jq failed or no result, output default
if [[ -z "$result" ]]; then
    echo '{"visible":false,"text":"","tooltip":"","items":[]}'
else
    echo "$result"
fi