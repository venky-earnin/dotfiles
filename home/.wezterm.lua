local wezterm = require("wezterm")
local act = wezterm.action
local swap_pane = act.PaneSelect({ mode = "SwapWithActive" })
local fixed_tab_width = 28

local config = wezterm.config_builder()

config.default_prog = { "/bin/zsh", "-l" }
config.automatically_reload_config = true
config.check_for_updates = false
config.audible_bell = "Disabled"

config.font = wezterm.font_with_fallback({
	"JetBrainsMono Nerd Font Mono",
	"MesloLGS Nerd Font Mono",
})
config.font_size = 16.5
config.adjust_window_size_when_changing_font_size = false
config.line_height = 1.0
config.front_end = "WebGpu"
config.freetype_load_target = "HorizontalLcd"

config.colors = {
	foreground = "#CBE0F0",
	background = "#011423",
	cursor_bg = "#47FF9C",
	cursor_border = "#47FF9C",
	cursor_fg = "#011423",
	selection_bg = "#033259",
	selection_fg = "#CBE0F0",
	ansi = { "#214969", "#E52E2E", "#44FFB1", "#FFE073", "#0FC5ED", "#a277ff", "#24EAF7", "#CBE0F0" },
	brights = { "#3D6E8E", "#FF5C5C", "#6BFFC4", "#FFEB99", "#5FD7FF", "#C39BFF", "#5FF4FF", "#FFFFFF" },
}

config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
	left = 6,
	right = 6,
	top = 6,
	bottom = 4,
}
config.macos_window_background_blur = 10
config.initial_cols = 140
config.initial_rows = 42
config.scrollback_lines = 50000
config.leader = { key = "Space", mods = "CTRL", timeout_milliseconds = 1000 }

config.enable_tab_bar = true
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = false
config.show_tab_index_in_tab_bar = false
config.tab_max_width = fixed_tab_width
config.colors.tab_bar = {
	background = "#011423",
	active_tab = {
		bg_color = "#6FA8B8",
		fg_color = "#011423",
		intensity = "Bold",
	},
	inactive_tab = {
		bg_color = "#033259",
		fg_color = "#CBE0F0",
	},
	inactive_tab_hover = {
		bg_color = "#214969",
		fg_color = "#CBE0F0",
	},
}

local function clean_title(title)
	if title == nil or title == "" then
		return "shell"
	end

	title = title:gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
	if title == "" then
		return "shell"
	end
	return title
end

local function fit_title(title, width)
	if wezterm.column_width(title) > width then
		return wezterm.truncate_right(title, width - 1) .. ">"
	end
	return title .. string.rep(" ", width - wezterm.column_width(title))
end

wezterm.on("format-tab-title", function(tab, tabs, panes, effective_config, hover, max_width)
	local index = tostring(tab.tab_index + 1)
	local prefix = index .. ": "
	local title = clean_title(tab.tab_title)
	if title == "shell" and tab.active_pane ~= nil then
		title = clean_title(tab.active_pane.title)
	end

	local title_width = fixed_tab_width - #prefix - 2
	local bg = "#033259"
	local fg = "#CBE0F0"
	local intensity = "Normal"

	if tab.is_active then
		bg = "#6FA8B8"
		fg = "#011423"
		intensity = "Bold"
	elseif tab.is_last_active then
		bg = "#214969"
		fg = "#CBE0F0"
	elseif hover then
		bg = "#214969"
		fg = "#CBE0F0"
	end

	return {
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Attribute = { Intensity = intensity } },
		{ Text = " " .. prefix .. fit_title(title, title_width) .. " " },
	}
end)

config.keys = {
	{ key = "Enter", mods = "SHIFT", action = act.SendString("\x1b\r") },
	{ key = "Enter", mods = "CMD", action = act.ToggleFullScreen },
	{ key = "r", mods = "CMD|SHIFT", action = act.ReloadConfiguration },
	{ key = "t", mods = "CMD", action = act.SpawnTab("CurrentPaneDomain") },
	{ key = "w", mods = "CMD", action = act.CloseCurrentTab({ confirm = true }) },
	{ key = "d", mods = "CMD", action = act.SplitHorizontal({ domain = "CurrentPaneDomain" }) },
	{ key = "d", mods = "CMD|SHIFT", action = act.SplitVertical({ domain = "CurrentPaneDomain" }) },
	{ key = "z", mods = "CMD|SHIFT", action = act.TogglePaneZoomState },
	{ key = "p", mods = "CMD|SHIFT", action = act.PaneSelect },
	{ key = "LeftArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Left") },
	{ key = "RightArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Right") },
	{ key = "UpArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Up") },
	{ key = "DownArrow", mods = "CMD|OPT", action = act.ActivatePaneDirection("Down") },
	{ key = "h", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Left") },
	{ key = "l", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Right") },
	{ key = "k", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Up") },
	{ key = "j", mods = "CMD|CTRL", action = act.ActivatePaneDirection("Down") },
	{ key = "h", mods = "LEADER", action = act.ActivatePaneDirection("Left") },
	{ key = "l", mods = "LEADER", action = act.ActivatePaneDirection("Right") },
	{ key = "k", mods = "LEADER", action = act.ActivatePaneDirection("Up") },
	{ key = "j", mods = "LEADER", action = act.ActivatePaneDirection("Down") },
	{ key = "LeftArrow", mods = "CMD|OPT|SHIFT", action = swap_pane },
	{ key = "RightArrow", mods = "CMD|OPT|SHIFT", action = swap_pane },
	{ key = "UpArrow", mods = "CMD|OPT|SHIFT", action = swap_pane },
	{ key = "DownArrow", mods = "CMD|OPT|SHIFT", action = swap_pane },
	{ key = "h", mods = "CMD|CTRL|SHIFT", action = swap_pane },
	{ key = "l", mods = "CMD|CTRL|SHIFT", action = swap_pane },
	{ key = "k", mods = "CMD|CTRL|SHIFT", action = swap_pane },
	{ key = "j", mods = "CMD|CTRL|SHIFT", action = swap_pane },
	{ key = "H", mods = "LEADER|SHIFT", action = swap_pane },
	{ key = "L", mods = "LEADER|SHIFT", action = swap_pane },
	{ key = "K", mods = "LEADER|SHIFT", action = swap_pane },
	{ key = "J", mods = "LEADER|SHIFT", action = swap_pane },
	{ key = "LeftArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "RightArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Right", 5 }) },
	{ key = "UpArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Up", 3 }) },
	{ key = "DownArrow", mods = "CMD|CTRL", action = act.AdjustPaneSize({ "Down", 3 }) },
	{ key = "h", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Left", 5 }) },
	{ key = "l", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Right", 5 }) },
	{ key = "k", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Up", 3 }) },
	{ key = "j", mods = "LEADER|CTRL", action = act.AdjustPaneSize({ "Down", 3 }) },
		{ key = "LeftArrow", mods = "CMD|SHIFT", action = act.ActivateTabRelative(-1) },
		{ key = "RightArrow", mods = "CMD|SHIFT", action = act.ActivateTabRelative(1) },
		{ key = "Tab", mods = "CTRL", action = act.ActivateTabRelative(1) },
		{ key = "Tab", mods = "CTRL|SHIFT", action = act.ActivateTabRelative(-1) },
		{ key = "k", mods = "CMD|SHIFT", action = act.ClearScrollback("ScrollbackAndViewport") },
		{
			key = "E",
			mods = "CMD|SHIFT",
			action = act.PromptInputLine({
				description = "Rename current tab",
				action = wezterm.action_callback(function(window, pane, line)
					if line then
						window:active_tab():set_title(line)
					end
				end),
			}),
		},
	}

for i = 1, 8 do
	table.insert(config.keys, {
		key = tostring(i),
		mods = "CMD",
		action = act.ActivateTab(i - 1),
	})
end

table.insert(config.keys, {
	key = "9",
	mods = "CMD",
	action = act.ActivateTab(-1),
})

return config
