-- luacheck: globals vim

local panel = require("claude-summon.ui.panel")

local M = {}

local function last_code_block()
	local buf = panel.response_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return nil
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local block = {}
	local collecting = false

	for i = #lines, 1, -1 do
		local line = lines[i]
		if line:match("^%s*```") then
			if collecting then
				local reversed = {}
				for j = #block, 1, -1 do
					table.insert(reversed, block[j])
				end
				return reversed
			else
				collecting = true
			end
		elseif collecting then
			table.insert(block, line)
		end
	end

	return nil
end

function M.apply_code()
	local block = last_code_block()
	if not block or #block == 0 then
		vim.notify("No code block found in response", vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_get_current_buf()
	local row = vim.api.nvim_win_get_cursor(0)[1]
	vim.api.nvim_buf_set_lines(buf, row, row, false, block)

	local joined = table.concat(block, "\n")
	vim.fn.setreg('"', joined)
	vim.fn.setreg("+", joined)
	vim.notify(("Inserted code block (%d lines)"):format(#block), vim.log.levels.INFO)
end

function M.yank_code()
	local block = last_code_block()
	if not block or #block == 0 then
		vim.notify("No code block found to yank", vim.log.levels.WARN)
		return
	end
	local joined = table.concat(block, "\n")
	vim.fn.setreg('"', joined)
	vim.fn.setreg("+", joined)
	vim.notify(("Yanked code block (%d lines)"):format(#block), vim.log.levels.INFO)
end

local function build_diff_buffer(block)
	local current_buf = vim.api.nvim_get_current_buf()
	local scratch = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(scratch, 0, -1, false, block)
	vim.bo[scratch].filetype = vim.bo[current_buf].filetype
	return scratch
end

---Show the last code block in a floating preview.
function M.preview_code()
	local block = last_code_block()
	if not block or #block == 0 then
		vim.notify("No code block found to preview", vim.log.levels.WARN)
		return
	end

	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, block)
	vim.bo[buf].filetype = vim.bo[vim.api.nvim_get_current_buf()].filetype
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].modifiable = false

	local width = math.floor(vim.o.columns * 0.6)
	local height = math.floor(vim.o.lines * 0.4)
	local row = math.floor((vim.o.lines - height) / 2)
	local col = math.floor((vim.o.columns - width) / 2)

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = row,
		col = col,
		width = width,
		height = height,
		border = "rounded",
		title = { { " Claude Code Block Preview ", "FloatTitle" } },
		title_pos = "center",
	})

	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })

	vim.keymap.set("n", "<Esc>", function()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end, { buffer = buf, nowait = true, silent = true })
end

function M.diff_code()
	local block = last_code_block()
	if not block or #block == 0 then
		vim.notify("No code block found to diff", vim.log.levels.WARN)
		return
	end

	local scratch = build_diff_buffer(block)
	local current_win = vim.api.nvim_get_current_win()

	vim.cmd("vsplit")
	local scratch_win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(scratch_win, scratch)
	vim.bo[scratch].buftype = "nofile"
	vim.bo[scratch].bufhidden = "wipe"

	-- Enable diff mode between scratch and the original window.
	vim.cmd("diffthis")
	if vim.api.nvim_win_is_valid(current_win) then
		vim.api.nvim_set_current_win(current_win)
		vim.cmd("diffthis")
	end

	-- Provide a quick way to close the diff view and clean up.
	vim.keymap.set("n", "q", function()
		if vim.api.nvim_win_is_valid(current_win) then
			vim.api.nvim_set_current_win(current_win)
			pcall(vim.cmd, "diffoff!")
		end
		if vim.api.nvim_win_is_valid(scratch_win) then
			pcall(vim.cmd, "diffoff!")
			vim.api.nvim_win_close(scratch_win, true)
		end
	end, { buffer = scratch, nowait = true, silent = true })

	vim.notify("Opened diff view with code block", vim.log.levels.INFO)
end

return M
