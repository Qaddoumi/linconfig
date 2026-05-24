local mod = "SUPER"
local term = "kitty"
local menu = "rofi -show drun"
local fileManager = "thunar"
local browser = "google-chrome-stable --enable-features=UseOzonePlatform --ozone-platform=wayland"

-- Wrapping multi-line strings in Lua using [[ ]]
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

require("monitors")
require("workspaces")

hl.config({
	monitor = {
		",preferred,auto,1"
	},
	general = {
		gaps_in = 2,
		gaps_out = 1,
		border_size = 2,

        -- Using the Gruvbox color palette for borders
		["col.active_border"] = "rgba(8ec07cff)",
		["col.inactive_border"] = "rgba(3c3836ff)",

		layout = "dwindle",
		resize_on_border = true
	},
	dwindle = {
		preserve_split = true,
		force_split = 2
	},
	decoration = {
		rounding = 0,
		blur = {
			enabled = true,
			size = 3,
			passes = 1,
			new_optimizations = true
		}
	},
	animations = {
		enabled = true,
		bezier = {
			"myBezier, 0.05, 0.9, 0.1, 1.05"
		},
		animation = {
			"windows, 1, 7, myBezier",
			"windowsOut, 1, 7, default, popin 80%",
			"border, 1, 10, default",
			"borderangle, 1, 8, default",
			"fade, 1, 7, default",
			"workspaces, 1, 6, default"
		}
	},
	input = {
        -- run 'ls -la  /usr/share/X11/xkb/symbols/' to get the layouts
		kb_layout = "us,ara",
		kb_options = "grp:alt_shift_toggle",
		numlock_by_default = true,
		follow_mouse = 1,
		touchpad = {
			natural_scroll = true,
			["tap-to-click"] = true,
			middle_button_emulation = true,
			drag_lock = false
		},
		sensitivity = 0 -- -1.0 - 1.0, 0 means no modification
	},
	misc = {
		disable_hyprland_logo = true,
		disable_splash_rendering = true,
		mouse_move_enables_dpms = true,
		key_press_enables_dpms = true,
		vrr = 0
	},
	env = {
        "XDG_CURRENT_DESKTOP,Hyprland",
		"XDG_SESSION_TYPE,wayland",
		"XDG_SESSION_DESKTOP,Hyprland",
		"QT_QPA_PLATFORM,wayland",
		"QT_WAYLAND_DISABLE_WINDOWDECORATION,1",
		"MOZ_ENABLE_WAYLAND,1",
        -- Environment Variables for Multi-GPU ,see the above link
        -- https://wiki.hypr.land/Configuring/Multi-GPU/
        -- Use the stable symlinks generated that i generated with udev rules
        -- Priority: Integrated/Virtual GPU or NVIDIA dGPU (if available) > Intel iGPU > AMD iGPU > Virtual GPU
        -- AQ_DRM_DEVICES,/dev/dri/intel-igpu:/dev/dri/amd-igpu:/dev/dri/virtio-gpu
		"AQ_DRM_DEVICES,/dev/dri/nvidia-dgpu:/dev/dri/intel-igpu:/dev/dri/amd-igpu:/dev/dri/virtio-gpu"
	},
	["exec-once"] = {
		"dbus-update-activation-environment --systemd --all",
		"/usr/lib/xdg-desktop-portal-hyprland &",
		"/usr/lib/xdg-desktop-portal &",
		"xdg-user-dirs-update",
		"/usr/lib/hyprpolkitagent/hyprpolkitagent",
		"/usr/bin/gnome-keyring-daemon --start --components=secrets,pkcs11,ssh",
		"/usr/lib/at-spi-bus-launcher --launch-immediately",
		"copyq --start-server",
		"dunst",
		"swaybg --mode fit --output '*' --image /usr/share/hypr/wall0.png",
        -- Alternative wallpaper daemon (SWWW instead of swaybg)
		[[swayidle -w \
			timeout 300 ']] .. lock_cmd .. [[' \
			timeout 1800 'hyprctl dispatch dpms off' \
			resume 'hyprctl dispatch dpms on' \
			before-sleep 'swaylock -f -c 000000' &]],
        -- This will lock your screen after 5 minutes of inactivity, then turn off
        -- your displays after another 30 minutes, and turn your screens back on when
        -- resumed. It will also lock your screen before your computer goes to sleep.
		"quickshell",
		"flameshot",
        -- Clipboard with X11 sync for XWayland apps (still does not work well)
		"wl-paste --type text --watch xclip -selection clipboard"
        -- X11 to Wayland clipboard bridge (for VM clipboard sharing)
        -- "clipboard-bridge --bidirectional --interval 1.5 > /tmp/clipboard-bridge.log 2>&1"
	},
	bind = {
		mod .. ", Return, exec, " .. term,
		mod .. " SHIFT, q, killactive,",
		mod .. ", d, exec, " .. menu,
		mod .. ", b, exec, " .. browser,
		mod .. ", y, exec, " .. fileManager,
		mod .. ", v, exec, copyq toggle",
		mod .. " SHIFT, t, exec, " .. lock_cmd,
		mod .. ", s, exec, rofi -show emoji -modi emoji -matching regex -sorting-method levenshtein",
		"CTRL_ALT, Delete, exec, powermenu",
		mod .. ", f, fullscreen, 0",
		mod .. ", t, togglefloating,",
		mod .. ", space, focuscurrentorlast,",
		mod .. ", w, layoutmsg, togglesplit",
		mod .. ", e, layoutmsg, toggle",
		mod .. " SHIFT, c, exec, hyprctl reload && notify-send 'Hyprland Config Reloaded'",
		mod .. " SHIFT, e, exit,",
		
		mod .. ", h, movefocus, l",
		mod .. ", j, movefocus, d",
		mod .. ", k, movefocus, u",
		mod .. ", l, movefocus, r",
		
		mod .. ", left, movefocus, l",
		mod .. ", down, movefocus, d",
		mod .. ", up, movefocus, u",
		mod .. ", right, movefocus, r",

		mod .. " SHIFT, h, movewindow, l",
		mod .. " SHIFT, j, movewindow, d",
		mod .. " SHIFT, k, movewindow, u",
		mod .. " SHIFT, l, movewindow, r",

		mod .. " SHIFT, left, movewindow, l",
		mod .. " SHIFT, down, movewindow, d",
		mod .. " SHIFT, up, movewindow, u",
		mod .. " SHIFT, right, movewindow, r",

		mod .. ", 1, workspace, 1",
		mod .. ", 2, workspace, 2",
		mod .. ", 3, workspace, 3",
		mod .. ", 4, workspace, 4",
		mod .. ", 5, workspace, 5",
		mod .. ", 6, workspace, 6",
		mod .. ", 7, workspace, 7",
		mod .. ", 8, workspace, 8",
		mod .. ", 9, workspace, 9",
		mod .. ", 0, workspace, 10",

		mod .. " SHIFT, 1, movetoworkspace, 1",
		mod .. " SHIFT, 2, movetoworkspace, 2",
		mod .. " SHIFT, 3, movetoworkspace, 3",
		mod .. " SHIFT, 4, movetoworkspace, 4",
		mod .. " SHIFT, 5, movetoworkspace, 5",
		mod .. " SHIFT, 6, movetoworkspace, 6",
		mod .. " SHIFT, 7, movetoworkspace, 7",
		mod .. " SHIFT, 8, movetoworkspace, 8",
		mod .. " SHIFT, 9, movetoworkspace, 9",
		mod .. " SHIFT, 0, movetoworkspace, 10",

		mod .. " SHIFT, minus, movetoworkspace, special:scratchpad",
		mod .. ", minus, togglespecialworkspace, scratchpad",
		
		-- Engage the Resize Submap
		mod .. ", r, submap, resize",

		-- Screenshot
		mod .. ", Print, exec, grim -g \"$(slurp)\" - | tee ~/Pictures/$(date +%s).png | wl-copy && notify-send 'Screenshot taken' 'Saved at ~/Pictures and clipboard' || notify-send 'Screenshot failed'",
		-- Gamemode
		mod .. ", g, exec, hyprland-gamemode",
	},
	bindm = {
		mod .. ", mouse:272, movewindow",
		mod .. ", mouse:273, resizewindow"
	},
	bindl = {
		", XF86AudioMute, exec, pactl set-sink-mute @DEFAULT_SINK@ toggle",
		", XF86AudioMicMute, exec, pactl set-source-mute @DEFAULT_SOURCE@ toggle"
	},
	bindle = {
		", XF86AudioLowerVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ -5%",
		", XF86AudioRaiseVolume, exec, pactl set-sink-volume @DEFAULT_SINK@ +5%",
		", XF86MonBrightnessDown, exec, brightnessctl set 5%-",
		", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
	},
	windowrule = {
		"float, title:(quickshell)",
		"border_size 0, title:(quickshell)",
		"opacity 1.0 override 0.5 override 0.8 override, class:(kitty)",

		"float, class:(yad)",
		"center, class:(yad)",
		"size 600 400, class:(yad)",

		"float, class:(zenity)",
		"center, class:(zenity)",
		"size 600 400, class:(zenity)",

		"float, class:(org.pulseaudio.pavucontrol)",
		"center, class:(org.pulseaudio.pavucontrol)",
		"size 600 400, class:(org.pulseaudio.pavucontrol)",

		"float, class:(GtkFileChooserDialog)",
		"center, class:(GtkFileChooserDialog)",
		"size 800 600, class:(GtkFileChooserDialog)",

		"float, class:(kdialog)",
		"center, class:(kdialog)",
		"size 400 300, class:(kdialog)",

		"float, class:(kde5-config-dialog)",
		"center, class:(kde5-config-dialog)",
		"size 500 400, class:(kde5-config-dialog)",

		"float, title:(File Operation Progress|Attention|Confirm|Progress|Rename.*)",
		"center, title:(File Operation Progress|Attention|Confirm|Progress|Rename.*)",
		"size 500 400, title:(File Operation Progress|Attention|Confirm|Progress|Rename.*)",

		"float, title:(Save As|Open Files)",
		"center, title:(Save As|Open Files)",
		"size 600 400, title:(Save As|Open Files)",

		"float, class:(gcr-prompter)",
		"center, class:(gcr-prompter)",

		"float, title:(Authentication Required)",
		"float, title:(Authentication)"
	},
})

-- Handling the resize mode via standard nested Lua tables
hl.config({
	submap = {
		resize = {
			binde = {
				", h, resizeactive, -10 0",
				", j, resizeactive, 0 10",
				", k, resizeactive, 0 -10",
				", l, resizeactive, 10 0",
				", left, resizeactive, -10 0",
				", down, resizeactive, 0 10",
				", up, resizeactive, 0 -10",
				", right, resizeactive, 10 0"
			},
			bind = {
				", Return, submap, reset",
				", escape, submap, reset"
			}
		}
	}
})