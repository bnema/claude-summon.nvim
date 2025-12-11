-- luacheck: globals vim

local M = {}

local state = {
	win = nil,
	buf = nil,
	pending_callback = nil,
	tool_name = nil,
	tool_input = nil,
}

local icons = {
	bash = "\u{f489}",
	read = "\u{f15c}",
	write = "\u{f0c7}",
	edit = "\u{f044}",
	tool = "\u{f0ad}",
	warn = "\u{f071}",
	check = "\u{f00c}",
	times = "\u{f00d}",
}

local tool_icons = {
	Bash = icons.bash,
	Read = icons.read,
	Write = icons.write,
	Edit = icons.edit,
}

-- Format tool input for display
local function format_input(tool_name, tool_input)
	local lines = {}

	if tool_name == "Bash" and tool_input.command then
		table.insert(lines, "Command:")
		-- Split long commands
		local cmd = tool_input.command
		if #cmd > 60 then
			for i = 1, #cmd, 60 do
				table.insert(lines, "  " .. cmd:sub(i, i + 59))
			end
		else
			table.insert(lines, "  " .. cmd)
		end
	elseif tool_input.file_path then
		table.insert(lines, "File: " .. tool_input.file_path)
	elseif tool_input.pattern then
		table.insert(lines, "Pattern: " .. tool_input.pattern)
	elseif tool_input.url then
		table.insert(lines, "URL: " .. tool_input.url)
	else
		-- Show raw input for unknown tools
		for k, v in pairs(tool_input) do
			if type(v) == "string" then
				table.insert(lines, k .. ": " .. v:sub(1, 50))
			end
		end
	end

	return lines
end

-- Close the permission window
local function close_window()
	if state.win and vim.api.nvim_win_is_valid(state.win) then
		vim.api.nvim_win_close(state.win, true)
	end
	if state.buf and vim.api.nvim_buf_is_valid(state.buf) then
		vim.api.nvim_buf_delete(state.buf, { force = true })
	end
	state.win = nil
	state.buf = nil
	state.pending_callback = nil
	state.tool_name = nil
	state.tool_input = nil
end

-- Handle user response
local function respond(allowed, save)
	local callback = state.pending_callback
	local tool_name = state.tool_name
	local tool_input = state.tool_input
	close_window()

	if callback then
		-- Use vim.schedule to avoid issues with nested callbacks
		vim.schedule(function()
			callback(allowed, save, nil)
		end)
	end
end

-- Create keymaps for the permission buffer
local function setup_keymaps(buf)
	local opts = { buffer = buf, nowait = true, silent = true }

	-- y = allow once
	vim.keymap.set("n", "y", function()
		respond(true, false)
	end, opts)

	-- Y = allow and save
	vim.keymap.set("n", "Y", function()
		respond(true, true)
	end, opts)

	-- n = deny once
	vim.keymap.set("n", "n", function()
		respond(false, false)
	end, opts)

	-- N = deny and save
	vim.keymap.set("n", "N", function()
		respond(false, true)
	end, opts)

	-- q/Esc = deny once
	vim.keymap.set("n", "q", function()
		respond(false, false)
	end, opts)
	vim.keymap.set("n", "<Esc>", function()
		respond(false, false)
	end, opts)

	-- Enter = allow once (convenience)
	vim.keymap.set("n", "<CR>", function()
		respond(true, false)
	end, opts)
end

-- Show permission request UI
---@param tool_name string
---@param tool_input table
---@param callback function  -- callback(allowed, save_preference, updated_input)
function M.show(tool_name, tool_input, callback)
	-- Close any existing window
	close_window()

	state.pending_callback = callback
	state.tool_name = tool_name
	state.tool_input = tool_input

	-- Build content
	local icon = tool_icons[tool_name] or icons.tool
	local lines = {
		string.format(" %s  Permission Request", icons.warn),
		"",
		string.format(" %s  %s", icon, tool_name),
		"",
	}

	-- Add formatted input
	local input_lines = format_input(tool_name, tool_input)
	for _, line in ipairs(input_lines) do
		table.insert(lines, " " .. line)
	end

	table.insert(lines, "")
	table.insert(lines, " ─────────────────────────────────")
	table.insert(lines, "")
	table.insert(lines, " [y] Allow  [Y] Allow & Save")
	table.insert(lines, " [n] Deny   [N] Deny & Save")
	table.insert(lines, "")

	-- Calculate window size
	local width = 40
	for _, line in ipairs(lines) do
		width = math.max(width, #line + 4)
	end
	local height = #lines

	-- Create buffer
	state.buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, lines)
	vim.bo[state.buf].modifiable = false
	vim.bo[state.buf].buftype = "nofile"
	vim.bo[state.buf].bufhidden = "wipe"

	-- Calculate position (center of screen)
	local ui = vim.api.nvim_list_uis()[1]
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	-- Create floating window
	state.win = vim.api.nvim_open_win(state.buf, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		style = "minimal",
		border = "rounded",
		title = " Claude Permission ",
		title_pos = "center",
	})

	-- Set highlights
	vim.wo[state.win].winhighlight = "Normal:Normal,FloatBorder:FloatBorder"
	vim.wo[state.win].cursorline = false

	-- Setup keymaps
	setup_keymaps(state.buf)

	-- Focus the window
	vim.api.nvim_set_current_win(state.win)
end

-- Check if permission window is open
function M.is_open()
	return state.win ~= nil and vim.api.nvim_win_is_valid(state.win)
end

-- Force close (e.g., on abort)
function M.close()
	if state.pending_callback then
		respond(false, false)
	else
		close_window()
	end
end

return M
