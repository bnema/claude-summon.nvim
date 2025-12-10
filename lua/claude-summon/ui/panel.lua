-- luacheck: globals vim

local M = {}

local state = {
	model = nil,
	cfg = nil,
	response_buf = nil,
	input_buf = nil,
	response_win = nil,
	input_win = nil,
	on_submit = nil,
}

local function ensure_buffers()
	if not state.response_buf or not vim.api.nvim_buf_is_valid(state.response_buf) then
		state.response_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.response_buf].filetype = "markdown"
		vim.bo[state.response_buf].bufhidden = "hide"
	end

	if not state.input_buf or not vim.api.nvim_buf_is_valid(state.input_buf) then
		state.input_buf = vim.api.nvim_create_buf(false, true)
		vim.bo[state.input_buf].buftype = "prompt"
		vim.bo[state.input_buf].bufhidden = "hide"
	end
end

local function response_config()
	local width = math.floor(vim.o.columns * (state.cfg.panel.width or 0.4))
	local position = state.cfg.panel.position or "right"

	if position == "bottom" then
		return {
			split = "below",
			win = 0,
			height = math.floor(vim.o.lines * 0.4),
		}
	end

	return {
		split = position,
		win = 0,
		width = width,
	}
end

local function input_config()
	if not state.response_win or not vim.api.nvim_win_is_valid(state.response_win) then
		return nil
	end

	return {
		relative = "win",
		win = state.response_win,
		anchor = "SW",
		row = vim.api.nvim_win_get_height(state.response_win),
		col = 0,
		width = vim.api.nvim_win_get_width(state.response_win),
		height = 5,
		border = state.cfg.panel.border or "rounded",
		title = { { " Message ", "FloatTitle" } },
		title_pos = "left",
	}
end

local function open_windows(model)
	ensure_buffers()
	local response_conf = response_config()

	state.response_win = vim.api.nvim_open_win(state.response_buf, true, response_conf)
	vim.api.nvim_win_set_config(state.response_win, {
		title = { { (" Claude [%s] "):format(model or state.model or "claude"), "FloatTitle" } },
		title_pos = "center",
	})
	vim.api.nvim_win_set_option(state.response_win, "winfixwidth", true)

	local input_conf = input_config()
	if input_conf then
		state.input_win = vim.api.nvim_open_win(state.input_buf, false, input_conf)
		vim.fn.prompt_setprompt(state.input_buf, "> ")
		vim.fn.prompt_setcallback(state.input_buf, function(line)
			if state.on_submit then
				state.on_submit(line)
			end
			vim.api.nvim_buf_set_lines(state.input_buf, 0, -1, false, {})
		end)
		-- Focus the input so users can start typing immediately.
		vim.api.nvim_set_current_win(state.input_win)
		vim.keymap.set("n", "q", function()
			M.close()
		end, { buffer = state.response_buf, silent = true })
	end
end

local function close_windows()
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_win_close(state.input_win, true)
	end
	if state.response_win and vim.api.nvim_win_is_valid(state.response_win) then
		vim.api.nvim_win_close(state.response_win, true)
	end
	state.input_win = nil
	state.response_win = nil
end

function M.setup(cfg)
	state.cfg = cfg
end

function M.open(model)
	state.model = model or state.model
	close_windows()
	open_windows(model)
end

function M.close()
	close_windows()
end

function M.model()
	return state.model
end

function M.append(lines)
	if not state.response_buf or not vim.api.nvim_buf_is_valid(state.response_buf) then
		return
	end
	vim.api.nvim_buf_set_lines(state.response_buf, -1, -1, false, lines)
	if state.response_win and vim.api.nvim_win_is_valid(state.response_win) then
		local last = vim.api.nvim_buf_line_count(state.response_buf)
		vim.api.nvim_win_set_cursor(state.response_win, { last, 0 })
	end
end

function M.clear_response()
	if state.response_buf and vim.api.nvim_buf_is_valid(state.response_buf) then
		vim.api.nvim_buf_set_lines(state.response_buf, 0, -1, false, {})
	end
end

function M.set_footer(text)
	if state.response_win and vim.api.nvim_win_is_valid(state.response_win) then
		local footer = text and { { " " .. text .. " ", "FloatFooter" } } or nil
		local cfg = { footer = footer }
		if footer then
			cfg.footer_pos = "center"
		end
		vim.api.nvim_win_set_config(state.response_win, cfg)
	end
end

function M.response_buf()
	return state.response_buf
end

function M.set_response(lines)
	if state.response_buf and vim.api.nvim_buf_is_valid(state.response_buf) then
		vim.api.nvim_buf_set_lines(state.response_buf, 0, -1, false, lines or {})
	end
end

function M.set_submit(fn)
	state.on_submit = fn
end

function M.focus_input()
	if state.input_win and vim.api.nvim_win_is_valid(state.input_win) then
		vim.api.nvim_set_current_win(state.input_win)
	end
end

return M
