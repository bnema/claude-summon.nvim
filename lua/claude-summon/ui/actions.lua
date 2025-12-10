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

function M.diff_code()
	local block = last_code_block()
	if not block or #block == 0 then
		vim.notify("No code block found to diff", vim.log.levels.WARN)
		return
	end

	local scratch = build_diff_buffer(block)
	vim.cmd("tabnew")
	local win = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_buf(win, scratch)
	vim.cmd("diffthis")
	vim.cmd("wincmd p")
	vim.cmd("diffthis")
	vim.notify("Opened diff view with code block", vim.log.levels.INFO)
end

return M
