-- Power profiles: desktop refresh rate and effects. Included only when
-- features.hardware.power-profile is enabled; hyprland.nix fills in the
-- @placeholders@.
--
-- "eco"  power-saving profiles: eco monitor mode, no animations/blur/shadows
-- "full" full power, games, disabled: full monitor mode, effects as
--        configured above
--
-- The `power-profile` CLI writes the mode to the display file and switches a
-- running session with `hyprctl eval 'PowerDisplay("eco")'`. Every config
-- load (start, `hyprctl reload`) reads the file again, so a reload keeps the
-- mode; a monitor reconnect reuses the monitor rule set here. A missing or
-- unreadable file means "full".
local power_display = {
	file = "@file@",
	output = "@output@",
	modes = { eco = "@ecoMode@", full = "@fullMode@" },
	-- Effects as configured above, before PowerDisplay touches them.
	stock = {
		animations = hl.get_config("animations.enabled"),
		blur = hl.get_config("decoration.blur.enabled"),
		shadow = hl.get_config("decoration.shadow.enabled"),
	},
	current = nil,
}

function PowerDisplay(mode)
	local monitor_mode = power_display.modes[mode]
	if not monitor_mode then
		error(string.format('PowerDisplay: unknown mode "%s" (eco or full)', tostring(mode)))
	end
	-- A mode switch is a full modeset (the screen blanks); skip it when the
	-- mode is already shown.
	if mode == power_display.current then
		return
	end

	local full = mode == "full"
	local stock = power_display.stock
	-- Merged into the existing rule for this output (position, scale stay).
	hl.monitor({ output = power_display.output, mode = monitor_mode })
	hl.config({
		animations = { enabled = full and stock.animations },
		decoration = {
			blur = { enabled = full and stock.blur },
			shadow = { enabled = full and stock.shadow },
		},
	})
	power_display.current = mode
end

local function saved_display_mode()
	local file = io.open(power_display.file, "r")
	if not file then
		return "full"
	end
	local mode = file:read("*l")
	file:close()
	if power_display.modes[mode] then
		return mode
	end
	return "full"
end

PowerDisplay(saved_display_mode())
