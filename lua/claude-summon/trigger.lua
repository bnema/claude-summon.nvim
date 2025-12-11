-- luacheck: globals vim

local M = {}

local TRIGGER_PATTERN = "@(claude|opus|sonnet|haiku)%s+(.*)"

local function is_ts_comment(bufnr, line_nr)
	local ok, ts = pcall(require, "vim.treesitter")
	if not ok then
		return false
	end

	local parser = ts.get_parser(bufnr)
	if not parser then
		return false
	end

	local tree = parser:parse()[1]
	if not tree then
		return false
	end

	local root = tree:root()
	local row = line_nr - 1
	local node = root:named_descendant_for_range(row, 0, row, -1)

	while node do
		if node:type():find("comment") then
			return true
		end
		node = node:parent()
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
	if is_ts_comment(bufnr, line_nr) then
		return true
	end

	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return false
	end

	if is_commentstring_comment(bufnr, line) then
		return true
	end

	return is_syntax_comment(bufnr, line_nr)
end

function M.parse_trigger(bufnr, line_nr)
	bufnr = bufnr or vim.api.nvim_get_current_buf()
	line_nr = line_nr or vim.api.nvim_win_get_cursor(0)[1]

	local line = vim.api.nvim_buf_get_lines(bufnr, line_nr - 1, line_nr, false)[1]
	if not line then
		return nil
	end

	local model, message = line:match(TRIGGER_PATTERN)
	if not model or not message then
		return nil
	end

	if not is_comment(bufnr, line_nr) then
		return nil
	end

	return {
		model = model,
		message = vim.trim(message),
		line = line_nr,
	}
end

return M
