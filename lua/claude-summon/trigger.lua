-- luacheck: globals vim

local M = {}

-- Valid model names (Lua patterns don't support | alternation)
local VALID_MODELS = {
	claude = true,
	opus = true,
	sonnet = true,
	haiku = true,
}

-- Use Neovim's built-in treesitter API for universal comment detection
local function is_ts_comment(bufnr, line_nr)
	-- vim.treesitter.get_node works with unsaved buffer content
	local ok, node = pcall(vim.treesitter.get_node, {
		bufnr = bufnr,
		pos = { line_nr - 1, 0 }, -- 0-indexed row, start of line
	})

	if not ok or not node then
		return false
	end

	-- Walk up tree looking for comment node (universal across 321+ languages)
	while node do
		local node_type = node:type()
		if node_type:find("comment") then
			return true
		end
		node = node:parent()
	end

	return false
end

-- Direct prefix detection - works without treesitter for unsaved buffers
local function is_line_comment_by_prefix(line)
	local trimmed = vim.trim(line)
	-- Common single-line comment prefixes (covers most languages)
	local prefixes = {
		"--", -- Lua, SQL, Haskell, Ada
		"//", -- C, C++, Java, JS, TS, Go, Rust, Swift, Kotlin
		"#", -- Python, Ruby, Bash, Perl, R, YAML, TOML
		";", -- Lisp, Clojure, Assembly, INI
		"'", -- VB, VBA
		"!", -- Fortran
		"%", -- MATLAB, LaTeX, Erlang, Prolog
		"*", -- COBOL (column 7)
		"REM", -- Batch
		"dnl", -- m4
	}
	for _, prefix in ipairs(prefixes) do
		if trimmed:sub(1, #prefix) == prefix then
			return true
		end
	end
	return false
end

local function is_commentstring_comment(bufnr, line)
	local cs = vim.bo[bufnr].commentstring or ""
	if cs == "" or not cs:find("%%s") then
		return false
	end

	-- Handle simple `prefix %s` and `prefix %s suffix` shapes
	local prefix = vim.trim(cs:match("^(.-)%%s") or "")
	local suffix = vim.trim(cs:match("%%s(.-)$") or "")
	local trimmed = vim.trim(line)

	if prefix ~= "" and trimmed:find("^" .. vim.pesc(prefix)) then
		return true
	end

	if prefix ~= "" and suffix ~= "" then
		local pattern = "^" .. vim.pesc(prefix) .. ".+" .. vim.pesc(suffix) .. "$"
		if trimmed:find(pattern) then
			return true
		end
	end

	return false
end

local function is_syntax_comment(bufnr, line_nr)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return false
	end
	local col = (line:find("%S") or 1) - 1
	local syn_id = vim.fn.synID(line_nr, col + 1, true)
	local name = vim.fn.synIDattr(syn_id, "name") or ""
	return name:lower():find("comment", 1, true) ~= nil
end

local function is_comment(bufnr, line_nr)
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return false
	end

	-- Tier 0: Direct prefix check (fastest, works without any setup)
	if is_line_comment_by_prefix(line) then
		return true
	end

	-- Tier 1: Treesitter (most accurate when parser available)
	if is_ts_comment(bufnr, line_nr) then
		return true
	end

	-- Tier 2: Commentstring (vim's built-in)
	if is_commentstring_comment(bufnr, line) then
		return true
	end

	-- Tier 3: Syntax highlighting (ultimate fallback)
	return is_syntax_comment(bufnr, line_nr)
end

function M.parse_trigger(bufnr, line_nr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	line_nr = line_nr or vim.api.nvim_win_get_cursor(0)[1]

	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return nil
	end

	-- Match @word followed by optional message (Lua patterns don't support |)
	local model, message = line:match("@(%w+)%s*(.*)")
	if not model then
		return nil
	end

	-- Validate model is one of the allowed ones
	if not VALID_MODELS[model:lower()] then
		return nil
	end

	if not is_comment(bufnr, line_nr) then
		return nil
	end

	return {
		model = model:lower(),
		message = vim.trim(message),
		line = line_nr,
	}
end

-- Real-time trigger detection state
local watch_state = {
	augroup = nil,
	last_notified_key = nil, -- "bufnr:line:col:model" to track exact position
	last_notified_time = 0,
	debounce_ms = 1000, -- Don't notify same trigger within 1 second
}

-- Check current line for trigger and notify (for real-time feedback)
function M.check_current_line()
	local bufnr = vim.api.nvim_get_current_buf()
	local line_nr = vim.api.nvim_win_get_cursor(0)[1]
	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return nil
	end

	-- Quick check: does line contain @model pattern?
	local model = line:match("@(%w+)")
	if not model or not VALID_MODELS[model:lower()] then
		return nil
	end

	-- Check if it's in a comment
	if not is_comment(bufnr, line_nr) then
		return nil
	end

	-- Create unique key for this trigger (buffer + line + model)
	local key = string.format("%d:%d:%s", bufnr, line_nr, model:lower())
	local now = vim.loop.now()

	-- Debounce: don't notify if same trigger was notified recently
	if watch_state.last_notified_key == key then
		if (now - watch_state.last_notified_time) < watch_state.debounce_ms then
			return nil
		end
	end

	watch_state.last_notified_key = key
	watch_state.last_notified_time = now

	return {
		model = model:lower(),
		line = line_nr,
	}
end

-- Start watching for triggers in real-time
function M.start_watch(send_keymaps)
	if watch_state.augroup then
		return -- Already watching
	end

	-- Build keymap display string
	local keymap_str
	if type(send_keymaps) == "table" then
		keymap_str = table.concat(send_keymaps, " or ")
	else
		keymap_str = send_keymaps or "<leader>as"
	end

	watch_state.augroup = vim.api.nvim_create_augroup("ClaudeSummonTriggerWatch", { clear = true })

	vim.api.nvim_create_autocmd({ "TextChangedI", "CursorMovedI" }, {
		group = watch_state.augroup,
		callback = function()
			local trigger = M.check_current_line()
			if trigger then
				vim.notify(
					string.format("@%s → send with %s", trigger.model, keymap_str),
					vim.log.levels.INFO
				)
			end
		end,
	})
end

-- Stop watching for triggers
function M.stop_watch()
	if watch_state.augroup then
		vim.api.nvim_del_augroup_by_id(watch_state.augroup)
		watch_state.augroup = nil
	end
	watch_state.last_notified_key = nil
	watch_state.last_notified_time = 0
end

-- Toggle watch
function M.toggle_watch(send_keymap)
	if watch_state.augroup then
		M.stop_watch()
		vim.notify("claude-summon: trigger watch disabled", vim.log.levels.INFO)
	else
		M.start_watch(send_keymap)
		vim.notify("claude-summon: trigger watch enabled", vim.log.levels.INFO)
	end
end

return M
