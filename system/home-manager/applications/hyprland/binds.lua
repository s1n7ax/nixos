local mod = "SUPER"
local smod = "SUPER + SHIFT"
local amod = "SUPER + ALT"

-- Window rules
hl.window_rule({ match = { class = "org.kde.digikam" }, workspace = "1" })
hl.window_rule({ match = { class = "steam", float = false }, workspace = "2" })
hl.window_rule({ match = { title = "Steam", float = false }, workspace = "2" })
hl.window_rule({ match = { class = "Tor Browser" }, workspace = "3" })
hl.window_rule({ match = { class = "obsidian" }, workspace = "3" })
hl.window_rule({ match = { class = "firefox" }, workspace = "4" })
hl.window_rule({ match = { class = "LibreWolf" }, workspace = "4" })
hl.window_rule({ match = { class = "com.obsproject.Studio" }, workspace = "5" })
hl.window_rule({ match = { class = "com.github.wwmm.easyeffects" }, workspace = "8" })
hl.window_rule({ match = { class = "pavucontrol" }, workspace = "8" })
hl.window_rule({ match = { class = "org.pulseaudio.pavucontrol" }, workspace = "8" })
hl.window_rule({ match = { class = "steam", title = "Friends List" }, float = true })
hl.window_rule({ match = { class = "Tor Browser" }, float = true })

-- App launchers
hl.bind(mod .. " + P", hl.dsp.exec_cmd("rofi -show drun"))
hl.bind(amod .. " + T", hl.dsp.exec_cmd("firefox"))
hl.bind(amod .. " + S", hl.dsp.exec_cmd("kitty -e vifm"))
hl.bind(amod .. " + R", hl.dsp.exec_cmd("thunar"))
hl.bind(amod .. " + Z", hl.dsp.exec_cmd("slurp | grim -g - - | wl-copy -t image/png"))
hl.bind(
	amod .. " + X",
	hl.dsp.exec_cmd([[slurp | grim -g - -t png ~/Pictures/"$(date +'screenshot %y-%m-%d %H:%M:%S').png"]])
)

-- System
hl.bind(amod .. " + O", hl.dsp.exec_cmd("poweroff"))
hl.bind(
	amod .. " + P",
	hl.dsp.exec_cmd(
		"hyprctl dispatch togglefloating active && hyprctl dispatch resizeactive exact 30% 0 && hyprctl dispatch moveactive 2000 2000"
	)
)
hl.bind(smod .. " + Q", hl.dsp.exit())
hl.bind(mod .. " + Return", hl.dsp.exec_cmd("ghostty"))

-- Floating overlay toggle
hl.bind(
	mod .. " + H",
	hl.dsp.exec_cmd(
		[[if [ "$(hyprctl activewindow -j | jq -r '.floating')" = "false" ]; then hyprctl dispatch togglefloating active && hyprctl dispatch resizeactive exact 35% 35% && hyprctl dispatch movewindow r && hyprctl dispatch movewindow d && hyprctl dispatch pin active; else hyprctl dispatch togglefloating active && hyprctl dispatch pin active; fi]]
	)
)

-- Fullscreen / window state
hl.bind(mod .. " + Q", hl.dsp.window.fullscreen_state({ internal = 2, client = 0 }))
hl.bind(mod .. " + W", hl.dsp.window.fullscreen({ mode = "maximized" }))
hl.bind(mod .. " + F", hl.dsp.window.fullscreen({ mode = "fullscreen" }))
hl.bind(mod .. " + G", hl.dsp.window.close())
hl.bind(mod .. " + K", hl.dsp.window.pin())

-- Layout (dwindle leftovers)
hl.bind(mod .. " + J", hl.dsp.layout("togglesplit"))

-- Cycle focus + bring to top
hl.bind(mod .. " + N", function()
	hl.dispatch(hl.dsp.window.cycle_next({ next = true }))
	hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind(mod .. " + E", function()
	hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
	hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind(mod .. " + M", function()
	hl.dispatch(hl.dsp.window.cycle_next({ next = false }))
	hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)
hl.bind(mod .. " + I", function()
	hl.dispatch(hl.dsp.window.cycle_next({ next = true }))
	hl.dispatch(hl.dsp.window.alter_zorder({ mode = "top" }))
end)

-- Move focused window
hl.bind(smod .. " + M", hl.dsp.window.move({ direction = "l" }))
hl.bind(smod .. " + I", hl.dsp.window.move({ direction = "r" }))
hl.bind(smod .. " + E", hl.dsp.window.move({ direction = "u" }))
hl.bind(smod .. " + N", hl.dsp.window.move({ direction = "d" }))

-- Switch workspaces
hl.bind(mod .. " + A", hl.dsp.focus({ workspace = 1 }))
hl.bind(mod .. " + R", hl.dsp.focus({ workspace = 2 }))
hl.bind(mod .. " + S", hl.dsp.focus({ workspace = 3 }))
hl.bind(mod .. " + T", hl.dsp.focus({ workspace = 4 }))
hl.bind(mod .. " + Z", hl.dsp.focus({ workspace = 5 }))
hl.bind(mod .. " + X", hl.dsp.focus({ workspace = 6 }))
hl.bind(mod .. " + C", hl.dsp.focus({ workspace = 7 }))
hl.bind(mod .. " + D", hl.dsp.focus({ workspace = 8 }))
hl.bind(mod .. " + 9", hl.dsp.focus({ workspace = 9 }))
hl.bind(mod .. " + 0", hl.dsp.focus({ workspace = 10 }))

-- Move active window to a workspace
hl.bind(smod .. " + A", hl.dsp.window.move({ workspace = 1 }))
hl.bind(smod .. " + R", hl.dsp.window.move({ workspace = 2 }))
hl.bind(smod .. " + S", hl.dsp.window.move({ workspace = 3 }))
hl.bind(smod .. " + T", hl.dsp.window.move({ workspace = 4 }))
hl.bind(smod .. " + Z", hl.dsp.window.move({ workspace = 5 }))
hl.bind(smod .. " + X", hl.dsp.window.move({ workspace = 6 }))
hl.bind(smod .. " + C", hl.dsp.window.move({ workspace = 7 }))
hl.bind(smod .. " + D", hl.dsp.window.move({ workspace = 8 }))
hl.bind(smod .. " + 9", hl.dsp.window.move({ workspace = 9 }))
hl.bind(smod .. " + 0", hl.dsp.window.move({ workspace = 10 }))

-- Mouse wheel workspace switching
hl.bind(mod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mod .. " + mouse_up", hl.dsp.focus({ workspace = "e-1" }))

-- Mouse drag/resize
hl.bind(mod .. " + mouse:272", hl.dsp.window.drag(), { mouse = true })
hl.bind(mod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- hyprwhspr-rs: hold ALT+N to dictate
hl.bind("ALT + N", hl.dsp.exec_cmd("hyprwhspr-rs record start"))
hl.bind("ALT + N", hl.dsp.exec_cmd("hyprwhspr-rs record stop"), { release = true })
