#!/usr/bin/env bash
# Privacy widget script for Quickshell
# Detects active microphone, camera, and screenshare usage via PipeWire
# Optimized for speed by piping directly to jq

# Check if required tools are available
if ! command -v pw-dump &>/dev/null || ! command -v jq &>/dev/null; then
    echo '{"visible":false,"text":"","tooltip":"","items":[]}'
    exit 0
fi

# Run pw-dump and parse with jq in a single pipeline for speed
# Extract only running nodes with relevant media classes
result=$(pw-dump 2>/dev/null | jq -c '
    # Filter to running nodes with relevant media classes
    [.[] | select(.type == "PipeWire:Interface:Node") |
     select(.info.state == "running") |
     {
        app_name: (.info.props["application.name"] // .info.props["node.name"] // "Unknown"),
        media_class: .info.props["media.class"]
     } |
     select(.media_class == "Stream/Input/Audio" or 
            .media_class == "Stream/Input/Video" or 
            .media_class == "Video/Source")
    ] |
    
    # Group by type
    {
        audio_in: [.[] | select(.media_class == "Stream/Input/Audio") | .app_name] | unique,
        video_in: [.[] | select(.media_class == "Video/Source") | .app_name] | unique,
        screenshare: [.[] | select(.media_class == "Stream/Input/Video") | .app_name] | unique
    } |
    
    # Build output
    {
        visible: ((.audio_in | length) > 0 or (.video_in | length) > 0 or (.screenshare | length) > 0),
        text: (
            (if (.audio_in | length) > 0 then "󰍬 " else "" end) +
            (if (.video_in | length) > 0 then "󰄀 " else "" end) +
            (if (.screenshare | length) > 0 then "󰙨 " else "" end)
        ) | rtrimstr(" "),
        tooltip: (
            (if (.audio_in | length) > 0 then "Microphone:\\n" + (.audio_in | map("  • " + .) | join("\\n")) + "\\n" else "" end) +
            (if (.video_in | length) > 0 then "Camera:\\n" + (.video_in | map("  • " + .) | join("\\n")) + "\\n" else "" end) +
            (if (.screenshare | length) > 0 then "Screenshare:\\n" + (.screenshare | map("  • " + .) | join("\\n")) + "\\n" else "" end)
        ) | rtrimstr("\\n"),
        items: (
            [.audio_in[] | {type: "audio-in", name: ., icon: "󰍬"}] +
            [.video_in[] | {type: "video-in", name: ., icon: "󰄀"}] +
            [.screenshare[] | {type: "screenshare", name: ., icon: "󰙨"}]
        )
    }
' 2>/dev/null)

# If jq failed or no result, output default
if [[ -z "$result" ]]; then
    echo '{"visible":false,"text":"","tooltip":"","items":[]}'
else
    echo "$result"
fi
