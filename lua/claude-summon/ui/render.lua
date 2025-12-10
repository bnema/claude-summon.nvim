-- luacheck: globals vim

local uv = vim.loop
local panel = require("claude-summon.ui.panel")
local history = require("claude-summon.history")

local M = {}

local state = {
	model = "claude",
	thinking = "",
	spinner_idx = 1,
	spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	timer = nil,
	pending_line = "",
}

local function stop_spinner()
	if state.timer then
		state.timer:stop()
		state.timer:close()
	end
	state.timer = nil
	state.spinner_idx = 1
	panel.set_footer(nil)
end

local function render_status()
	local prefix = string.format("Claude [%s] thinking ", state.model or "claude")
	local spin = state.spinner[state.spinner_idx] or state.spinner[1]
	local msg = state.thinking ~= "" and (" · " .. state.thinking) or ""
	local text = prefix .. spin .. msg
	panel.set_footer(text)
end

local function start_spinner()
	stop_spinner()
	state.timer = uv.new_timer()
	state.timer:start(
		0,
		120,
		vim.schedule_wrap(function()
			state.spinner_idx = (state.spinner_idx % #state.spinner) + 1
			render_status()
		end)
	)
end

function M.setup(_cfg) end

function M.start_stream(payload)
	state.model = payload.model or "claude"
	state.thinking = ""
	state.pending_line = ""
	panel.clear_response()
	start_spinner()
end

function M.on_thinking(msg)
	state.thinking = msg.message or msg.text or msg.thinking or msg.content or ""
	render_status()
end

local function extract_text(msg)
	return msg.delta or msg.text or msg.message or msg.content or msg.result or ""
end

local function append_text(chunk)
	if chunk == "" then
		return
	end
	local combined = state.pending_line .. chunk
	local parts = vim.split(combined, "\n", { plain = true })
	state.pending_line = table.remove(parts) or ""
	if #parts > 0 then
		panel.append(parts)
	end
end

function M.on_message(msg)
	-- First real message ends the thinking phase.
	stop_spinner()
	local text = extract_text(msg)
	if text == "" then
		return
	end
	append_text(text)
end

function M.on_error(err)
	stop_spinner()
	local message = (err and (err.message or err.desc)) or "Unknown error"
	vim.notify("Claude error: " .. message, vim.log.levels.ERROR)
end

function M.on_complete()
	stop_spinner()
	if state.pending_line ~= "" then
		panel.append({ state.pending_line })
		state.pending_line = ""
	end
end

function M.on_stop()
	stop_spinner()
	state.pending_line = ""
end

function M.clear()
	stop_spinner()
	state.pending_line = ""
	panel.clear_response()
end

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
				-- Found start fence
				local reversed = {}
				for j = #block, 1, -1 do
					table.insert(reversed, block[j])
				end
				return reversed
			else
				collecting = true
			end
		else
			if collecting then
				table.insert(block, line)
			end
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

	vim.fn.setreg('"', table.concat(block, "\n"))
	vim.fn.setreg("+", table.concat(block, "\n"))
	vim.notify(("Inserted code block (%d lines)"):format(#block), vim.log.levels.INFO)
end

function M.save()
	local buf = panel.response_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("No response buffer to save", vim.log.levels.WARN)
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local path = history.save(nil, lines)
	if path then
		vim.notify("Saved conversation to " .. path, vim.log.levels.INFO)
	end
end

function M.export()
	local buf = panel.response_buf()
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		vim.notify("No response buffer to export", vim.log.levels.WARN)
		return
	end
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local path = history.export_markdown(nil, lines)
	if path then
		vim.notify("Exported conversation to " .. path, vim.log.levels.INFO)
	end
end

return M
