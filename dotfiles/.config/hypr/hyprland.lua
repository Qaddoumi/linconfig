

local mod = "SUPER"
local term = "kitty"
local menu = "rofi -show drun"
local fileManager = "thunar"
local browser = "google-chrome-stable --enable-features=UseOzonePlatform --ozone-platform=wayland"

-- The swaylock command
local lock_cmd = [[swaylock \
    --color 2d353b \
    --inside-color 3a454a \
    --inside-clear-color 5c6a72 \
    --inside-ver-color 5a524c \
    --inside-wrong-color 543a3a \
    --ring-color 7a8478 \
    --ring-clear-color a7c080 \
    --ring-ver-color dbbc7f \
    --ring-wrong-color e67e80 \
    --key-hl-color d699b6 \
    --bs-hl-color e69875 \
    --separator-color 2d353b \
    --text-color d3c6aa \
    --text-clear-color d3c6aa \
    --text-ver-color d3c6aa \
    --text-wrong-color d3c6aa \
    --indicator-radius 100 \
    --indicator-thickness 10 \
    --font "JetBrainsMono Nerd Font Propo"]]


------------------
---- MONITORS ----
------------------
hl.monitor({
    output   = "",
    mode     = "preferred",
    position = "auto",
    scale    = "1",
})

require("monitors")
require("workspaces")


-------------------
---- AUTOSTART ----
-------------------
hl.on("hyprland.start", function ()
    hl.exec_cmd("dbus-update-activation-environment --systemd --all")
    hl.exec_cmd("/usr/lib/xdg-desktop-portal-hyprland &")
    hl.exec_cmd("/usr/lib/xdg-desktop-portal &")
    hl.exec_cmd("xdg-user-dirs-update")
    hl.exec_cmd("/usr/lib/hyprpolkitagent/hyprpolkitagent")
    hl.exec_cmd("/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh")
    hl.exec_cmd("/usr/lib/at-spi-bus-launcher --launch-immediately")
    hl.exec_cmd("copyq --start-server")
    hl.exec_cmd("dunst")
    hl.exec_cmd("swaybg --mode fit --output '*' --image /usr/share/hypr/wall0.png")
    -- Alternative wallpaper daemon (SWWW instead of swaybg)
    
    local swayidle_cmd = string.format([[swayidle -w \
        timeout 300 '%s' \
        timeout 1800 'hyprctl dispatch dpms off' \
        resume 'hyprctl dispatch dpms on' \
        before-sleep 'swaylock -f -c 000000' &]], lock_cmd)
    hl.exec_cmd(swayidle_cmd)
    -- This will lock your screen after 5 minutes of inactivity, then turn off
		-- your displays after another 30 minutes, and turn your screens back on when
		-- resumed. It will also lock your screen before your computer goes to sleep.
    
    hl.exec_cmd("quickshell")
    hl.exec_cmd("flameshot")
    -- Clipboard with X11 sync for XWayland apps (still does not work well)
    hl.exec_cmd("wl-paste --type text --watch xclip -selection clipboard")
    -- X11 to Wayland clipboard bridge (for VM clipboard sharing)
	-- hl.exec_cmd("clipboard-bridge --bidirectional --interval 1.5 > /tmp/clipboard-bridge.log 2>&1")
end)


-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------
hl.env("XDG_CURRENT_DESKTOP", "Hyprland")
hl.env("XDG_SESSION_TYPE", "wayland")
hl.env("XDG_SESSION_DESKTOP", "Hyprland")
hl.env("QT_QPA_PLATFORM", "wayland")
hl.env("QT_WAYLAND_DISABLE_WINDOWDECORATION", "1")
hl.env("MOZ_ENABLE_WAYLAND", "1")
-- Environment Variables for Multi-GPU ,see the above link
-- https://wiki.hypr.land/Configuring/Advanced-and-Cool/Multi-GPU/
-- Use the stable symlinks generated that i generated with udev rules
-- Priority: Integrated/Virtual GPU or NVIDIA dGPU (if available) > Intel iGPU > AMD iGPU > Virtual GPU
-- AQ_DRM_DEVICES,/dev/dri/intel-igpu:/dev/dri/amd-igpu:/dev/dri/virtio-gpu
hl.env("AQ_DRM_DEVICES", "/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu:/dev/dri/amd-igpu:/dev/dri/virtio-gpu")


-----------------------
---- LOOK AND FEEL ----
-----------------------
hl.config({
    general = {
        gaps_in  = 2,
        gaps_out = 1,
        border_size = 2,
        col = {
		-- Using the Gruvbox color palette for borders
            active_border   = "rgba(8ec07cff)",
            inactive_border = "rgba(3c3836ff)",
        },
        layout = "dwindle",
        resize_on_border = true,
    },
    
    dwindle = {
        preserve_split = true,
        force_split = 2,
    },

    decoration = {
        rounding = 0,
        blur = {
            enabled   = true,
            size      = 3,
            passes    = 1,
        },
    },

    animations = {
        enabled = true,
    },
    
    input = {
        -- run 'ls -la  /usr/share/X11/xkb/symbols/' to get the layouts
        kb_layout = "us,ara",
        kb_options = "grp:alt_shift_toggle",
        numlock_by_default = true,
        follow_mouse = 1,
        touchpad = {
            natural_scroll = true,
            tap_to_click = true,
            middle_button_emulation = true,
            drag_lock = false,
        },
        sensitivity = 0, -- -1.0 - 1.0, 0 means no modification
    },
    
    misc = {
        disable_hyprland_logo = true,
        disable_splash_rendering = true,
        mouse_move_enables_dpms = true,
        key_press_enables_dpms = true,
        vrr = 0,
    }
})

-- Animations
hl.curve("myBezier", { type = "bezier", points = { {0.05, 0.9}, {0.1, 1.05} } })
hl.animation({ leaf = "windows", enabled = true, speed = 7, bezier = "myBezier" })
hl.animation({ leaf = "windowsOut", enabled = true, speed = 7, bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border", enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8, bezier = "default" })
hl.animation({ leaf = "fade", enabled = true, speed = 7, bezier = "default" })
hl.animation({ leaf = "workspaces", enabled = true, speed = 6, bezier = "default" })


---------------------
---- KEYBINDINGS ----
---------------------

-- Basic programs
hl.bind(mod .. " + Return", hl.dsp.exec_cmd(term))
hl.bind(mod .. " + SHIFT + Q", hl.dsp.window.close())
hl.bind(mod .. " + D", hl.dsp.exec_cmd(menu))
hl.bind(mod .. " + B", hl.dsp.exec_cmd(browser))
hl.bind(mod .. " + Y", hl.dsp.exec_cmd(fileManager))
hl.bind(mod .. " + V", hl.dsp.exec_cmd("copyq toggle"))
hl.bind(mod .. " + SHIFT + T", hl.dsp.exec_cmd(lock_cmd))
hl.bind(mod .. " + S", hl.dsp.exec_cmd("rofi -show emoji -modi emoji -matching regex -sorting-method levenshtein"))
hl.bind("CTRL + ALT + Delete", hl.dsp.exec_cmd("powermenu"))

-- Window management
hl.bind(mod .. " + F", hl.dsp.exec_cmd("hyprctl dispatch fullscreen 0"))
hl.bind(mod .. " + T", hl.dsp.window.float({ action = "toggle" }))
hl.bind(mod .. " + space", hl.dsp.exec_cmd("hyprctl dispatch focuscurrentorlast"))
hl.bind(mod .. " + W", hl.dsp.exec_cmd("hyprctl dispatch layoutmsg togglesplit"))
hl.bind(mod .. " + E", hl.dsp.exec_cmd("hyprctl dispatch layoutmsg toggle"))
hl.bind(mod .. " + SHIFT + C", hl.dsp.exec_cmd('hyprctl reload && notify-send "Hyprland Config Reloaded"'))
hl.bind(mod .. " + SHIFT + E", hl.dsp.exit())

-- Focus movement - Vim keys
hl.bind(mod .. " + H", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + J", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + K", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + L", hl.dsp.focus({ direction = "right" }))

-- Focus movement - Arrow keys
hl.bind(mod .. " + left", hl.dsp.focus({ direction = "left" }))
hl.bind(mod .. " + down", hl.dsp.focus({ direction = "down" }))
hl.bind(mod .. " + up", hl.dsp.focus({ direction = "up" }))
hl.bind(mod .. " + right", hl.dsp.focus({ direction = "right" }))

-- Move windows - Vim keys
hl.bind(mod .. " + SHIFT + H", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + J", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + K", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + L", hl.dsp.window.move({ direction = "right" }))

-- Move windows - Arrow keys
hl.bind(mod .. " + SHIFT + left", hl.dsp.window.move({ direction = "left" }))
hl.bind(mod .. " + SHIFT + down", hl.dsp.window.move({ direction = "down" }))
hl.bind(mod .. " + SHIFT + up", hl.dsp.window.move({ direction = "up" }))
hl.bind(mod .. " + SHIFT + right", hl.dsp.window.move({ direction = "right" }))

-- Workspaces
for i = 1, 10 do
    local key = i % 10
    hl.bind(mod .. " + " .. key, hl.dsp.focus({ workspace = i }))
    hl.bind(mod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i }))
end

-- Scratchpad
hl.bind(mod .. " + minus", hl.dsp.workspace.toggle_special("scratchpad"))
hl.bind(mod .. " + SHIFT + minus", hl.dsp.window.move({ workspace = "special:scratchpad" }))

-- Mouse bindings
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Media keys
hl.bind("XF86AudioMute", hl.dsp.exec_cmd("pactl set-sink-mute @DEFAULT_SINK@ toggle"), { locked = true })
hl.bind("XF86AudioLowerVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ -5%"), { locked = true, repeating = true })
hl.bind("XF86AudioRaiseVolume", hl.dsp.exec_cmd("pactl set-sink-volume @DEFAULT_SINK@ +5%"), { locked = true, repeating = true })
hl.bind("XF86AudioMicMute", hl.dsp.exec_cmd("pactl set-source-mute @DEFAULT_SOURCE@ toggle"), { locked = true })

-- Brightness keys
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl set 5%-"), { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp", hl.dsp.exec_cmd("brightnessctl set 5%+"), { locked = true, repeating = true })

-- Screenshot & Gamemode
hl.bind("Print", hl.dsp.exec_cmd('grim -g "$(slurp)" - | tee ~/Pictures/$(date +%s).png | wl-copy && notify-send "Screenshot taken" "Saved at ~/Pictures and clipboard" || notify-send "Screenshot failed"'))
hl.bind(mod .. " + G", hl.dsp.exec_cmd("hyprland-gamemode"))

-- Submap: Resize 
-- Note: Submap definitions in Lua are best mapped via hyprctl explicitly if not fully 
-- mapped yet, or you can implement custom Lua logic. Using regular binds for resize.
hl.bind(mod .. " + R", hl.dsp.exec_cmd("hyprctl dispatch submap resize"))
-- Note: The resize bindings inside the submap were omitted from this Lua config 
-- since submap management is usually done natively via the hyprland.conf, 
-- but if you transition fully, you can add them via hyprctl commands or custom logic!


-------------------------
---- WINDOW RULES -------
-------------------------
hl.window_rule({
    name = "quickshell-float",
    match = { title = "quickshell" },
    float = true,
    border_size = 0,
})

hl.window_rule({
    name = "kitty-opacity",
    match = { class = "kitty" },
    opacity = "1.0 0.5 0.8",
})

hl.window_rule({
    name = "yad-rules",
    match = { class = "yad" },
    float = true,
    center = true,
    size = "600 400",
})

hl.window_rule({
    name = "zenity-rules",
    match = { class = "zenity" },
    float = true,
    center = true,
    size = "600 400",
})

hl.window_rule({
    name = "pavucontrol-rules",
    match = { class = "org.pulseaudio.pavucontrol" },
    float = true,
    center = true,
    size = "600 400",
})

hl.window_rule({
    name = "file-chooser-rules",
    match = { class = "GtkFileChooserDialog" },
    float = true,
    center = true,
    size = "800 600",
})

hl.window_rule({
    name = "kdialog-rules",
    match = { class = "kdialog" },
    float = true,
    center = true,
    size = "400 300",
})

hl.window_rule({
    name = "kde5-config-dialog-rules",
    match = { class = "kde5-config-dialog" },
    float = true,
    center = true,
    size = "500 400",
})

hl.window_rule({
    name = "file-ops-rules",
    match = { title = "File Operation Progress|Attention|Confirm|Progress|Rename.*" },
    float = true,
    center = true,
    size = "500 400",
})

hl.window_rule({
    name = "save-as-rules",
    match = { title = "Save As|Open Files" },
    float = true,
    center = true,
    size = "600 400",
})

hl.window_rule({
    name = "gcr-prompter-rules",
    match = { class = "gcr-prompter" },
    float = true,
    center = true,
})

hl.window_rule({
    name = "auth-rules",
    match = { title = "Authentication Required" },
    float = true,
})

hl.window_rule({
    name = "auth-rules-2",
    match = { title = "Authentication" },
    float = true,
})