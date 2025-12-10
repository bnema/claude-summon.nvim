-- luacheck: globals vim

local M = {}

local function clamp(val, min, max)
	if val < min then
		return min
	end
	if val > max then
		return max
	end
	return val
end

local function get_surrounding_lines(bufnr, center, count)
	local start_idx = clamp(center - count - 1, 0, vim.api.nvim_buf_line_count(bufnr))
	local end_idx = clamp(center + count, 0, vim.api.nvim_buf_line_count(bufnr))
	return vim.api.nvim_buf_get_lines(bufnr, start_idx, end_idx, false)
end

local function get_visual_selection()
	local mode = vim.fn.mode()
	if mode ~= "v" and mode ~= "V" then
		return nil
	end

	local _, start_line, start_col, _ = unpack(vim.fn.getpos("v"))
	local _, end_line, end_col, _ = unpack(vim.fn.getpos("."))

	if start_line > end_line or (start_line == end_line and start_col > end_col) then
		start_line, end_line = end_line, start_line
		start_col, end_col = end_col, start_col
	end

	local lines = vim.api.nvim_buf_get_text(0, start_line - 1, start_col - 1, end_line - 1, end_col, {})
	return table.concat(lines, "\n")
end

local function relative_path(bufnr)
	local filename = vim.api.nvim_buf_get_name(bufnr)
	if filename == "" then
		return "[No Name]"
	end
	return vim.fn.fnamemodify(filename, ":.")
end

function M.build_context(opts)
	local cfg = opts or {}
	local bufnr = cfg.bufnr or vim.api.nvim_get_current_buf()
	local cursor = cfg.cursor or vim.api.nvim_win_get_cursor(0)
	local line_nr = cursor[1]
	local context_lines = cfg.context_lines or 20

	local trigger_line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]

	return {
		file_path = relative_path(bufnr),
		filetype = vim.bo[bufnr].filetype,
		cursor = { line_nr, cursor[2] + 1 },
		selection = get_visual_selection(),
		before = get_surrounding_lines(bufnr, line_nr, context_lines),
		trigger_line = trigger_line,
		after = get_surrounding_lines(bufnr, line_nr + 1, context_lines),
		related_files = {},
	}
end

return M
