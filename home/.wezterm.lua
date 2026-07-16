local wezterm = require("wezterm")
local act = wezterm.action
local swap_pane = act.PaneSelect({ mode = "SwapWithActive" })
local fixed_tab_width = 28
local default_palette_name = "aurora"

local palette_order = {
	"aurora",
	"rose",
	"mocha",
}

local palettes = {
	aurora = {
		background = "#101421",
		foreground = "#DCE7F7",
		cursor = "#A6E3A1",
		selection = "#27364F",
		tab = "#182033",
		tab_hover = "#25314A",
		accent = "#7DCFFF",
		accent_fg = "#101421",
		ansi = { "#1F2430", "#F7768E", "#9ECE6A", "#E0AF68", "#7AA2F7", "#BB9AF7", "#7DCFFF", "#C0CAF5" },
		brights = { "#414868", "#FF9E64", "#B9F27C", "#FFE6A7", "#9ABDF5", "#D5B7FF", "#B4F9F8", "#FFFFFF" },
	},
	rose = {
		background = "#191724",
		foreground = "#E0DEF4",
		cursor = "#EBBCBA",
		selection = "#403D52",
		tab = "#26233A",
		tab_hover = "#393552",
		accent = "#F6C177",
		accent_fg = "#191724",
		ansi = { "#26233A", "#EB6F92", "#9CCFD8", "#F6C177", "#31748F", "#C4A7E7", "#EBBCBA", "#E0DEF4" },
		brights = { "#6E6A86", "#EB6F92", "#9CCFD8", "#F6C177", "#31748F", "#C4A7E7", "#EBBCBA", "#F5F3FF" },
	},
	mocha = {
		background = "#1E1E2E",
		foreground = "#CDD6F4",
		cursor = "#F5E0DC",
		selection = "#45475A",
		tab = "#313244",
		tab_hover = "#45475A",
		accent = "#89B4FA",
		accent_fg = "#11111B",
		ansi = { "#313244", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#CBA6F7", "#94E2D5", "#CDD6F4" },
		brights = { "#585B70", "#F38BA8", "#A6E3A1", "#F9E2AF", "#89B4FA", "#CBA6F7", "#94E2D5", "#FFFFFF" },
	},
}

local function palette(name)
	return palettes[name] or palettes[default_palette_name]
end

local function build_colors(p)
	return {
		foreground = p.foreground,
		background = p.background,
		cursor_bg = p.cursor,
		cursor_border = p.cursor,
		cursor_fg = p.background,
		selection_bg = p.selection,
		selection_fg = p.foreground,
		ansi = p.ansi,
		brights = p.brights,
		tab_bar = {
			background = p.background,
			active_tab = {
				bg_color = p.accent,
				fg_color = p.accent_fg,
				intensity = "Bold",
			},
			inactive_tab = {
				bg_color = p.tab,
				fg_color = p.foreground,
			},
			inactive_tab_hover = {
				bg_color = p.tab_hover,
				fg_color = p.foreground,
			},
			new_tab = {
				bg_color = p.background,
				fg_color = p.foreground,
			},
			new_tab_hover = {
				bg_color = p.tab_hover,
				fg_color = p.foreground,
			},
		},
	}
end

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
config.inactive_pane_hsb = {
	saturation = 0.82,
	brightness = 0.72,
}

config.colors = build_colors(palette(default_palette_name))

config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
	left = 6,
	right = 6,
	top = 6,
	bottom = 4,
}
config.window_background_opacity = 0.96
config.macos_window_background_blur = 18
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

local function short_session_name(session)
	if session == "0" then
		return "tmux"
	end

	session = session:gsub("^cx%-", ""):gsub("^cl%-", "")
	return session
end

local function clean_title(title)
	if title == nil or title == "" then
		return "shell"
	end

	title = title:gsub("\n", " "):gsub("^%s+", ""):gsub("%s+$", "")
	title = title:gsub("^.-%s+❐%s+", "")
	title = title:gsub("%s+●%s+", " | ")
	title = title:gsub("%s+", " ")

	local session, window_index, window_name = title:match("^(.+)%s+|%s+(%d+):(.+)$")
	if session ~= nil and window_name ~= nil then
		title = short_session_name(session) .. " / " .. window_index .. ":" .. window_name:gsub("^%s+", "")
	end

	if title == "" then
		return "shell"
	end
	return title
end

local function fit_title(title, width)
	if wezterm.column_width(title) > width then
		if width <= 4 then
			return wezterm.truncate_right(title, width)
		end

		local left = math.floor((width - 3) * 0.58)
		local right = width - 3 - left
		return title:sub(1, left) .. "..." .. title:sub(-right)
	end
	return title .. string.rep(" ", width - wezterm.column_width(title))
end

local function tab_bar_colors(effective_config)
	local colors = effective_config.colors or {}
	local tab_bar = colors.tab_bar or {}
	local active = tab_bar.active_tab or {}
	local inactive = tab_bar.inactive_tab or {}
	local hover = tab_bar.inactive_tab_hover or {}

	return {
		active_bg = active.bg_color or "#7DCFFF",
		active_fg = active.fg_color or "#101421",
		inactive_bg = inactive.bg_color or "#182033",
		inactive_fg = inactive.fg_color or colors.foreground or "#DCE7F7",
		hover_bg = hover.bg_color or "#25314A",
		hover_fg = hover.fg_color or colors.foreground or "#DCE7F7",
	}
end

wezterm.on("format-tab-title", function(tab, tabs, panes, effective_config, hover, max_width)
	local index = tostring(tab.tab_index + 1)
	local prefix = index .. ": "
	local title = clean_title(tab.tab_title)
	if title == "shell" and tab.active_pane ~= nil then
		title = clean_title(tab.active_pane.title)
	end

	local title_width = fixed_tab_width - #prefix - 2
	local tab_colors = tab_bar_colors(effective_config)
	local bg = tab_colors.inactive_bg
	local fg = tab_colors.inactive_fg
	local intensity = "Normal"

	if tab.is_active then
		bg = tab_colors.active_bg
		fg = tab_colors.active_fg
		intensity = "Bold"
	elseif tab.is_last_active then
		bg = tab_colors.hover_bg
		fg = tab_colors.hover_fg
	elseif hover then
		bg = tab_colors.hover_bg
		fg = tab_colors.hover_fg
	end

	return {
		{ Background = { Color = bg } },
		{ Foreground = { Color = fg } },
		{ Attribute = { Intensity = intensity } },
		{ Text = " " .. prefix .. fit_title(title, title_width) .. " " },
	}
end)

local function compact_cwd(uri)
	if uri == nil then
		return ""
	end

	local path = uri.file_path or tostring(uri):gsub("^file://", "")
	local home = os.getenv("HOME")
	if home ~= nil and path:sub(1, #home) == home then
		path = "~" .. path:sub(#home + 1)
	end

	return path:match("([^/]+)$") or path
end

wezterm.on("update-right-status", function(window, pane)
	local effective = window:effective_config()
	local colors = effective.colors or {}
	local tab_bar = colors.tab_bar or {}
	local active = tab_bar.active_tab or {}
	local accent = active.bg_color or "#7DCFFF"
	local foreground = colors.foreground or "#DCE7F7"
	local cwd = compact_cwd(pane:get_current_working_dir())

	window:set_right_status(wezterm.format({
		{ Foreground = { Color = accent } },
		{ Text = " " .. cwd .. " " },
		{ Foreground = { Color = foreground } },
		{ Text = wezterm.strftime("%H:%M ") },
	}))
end)

local function cycle_palette(window)
	wezterm.GLOBAL.venky_palette_index = (wezterm.GLOBAL.venky_palette_index or 1) + 1
	if wezterm.GLOBAL.venky_palette_index > #palette_order then
		wezterm.GLOBAL.venky_palette_index = 1
	end

	local name = palette_order[wezterm.GLOBAL.venky_palette_index]
	local overrides = window:get_config_overrides() or {}
	overrides.colors = build_colors(palette(name))
	window:set_config_overrides(overrides)
	window:toast_notification("WezTerm", "Palette: " .. name, nil, 1400)
end

config.keys = {
	{ key = "Enter", mods = "SHIFT", action = act.SendString("\x1b\r") },
	{ key = "Enter", mods = "CMD", action = act.ToggleFullScreen },
	{ key = "r", mods = "CMD|SHIFT", action = act.ReloadConfiguration },
	{ key = "C", mods = "CMD|SHIFT", action = wezterm.action_callback(cycle_palette) },
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
