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
	local raw = msg.delta or msg.text or msg.message or msg.content or msg.result or ""
	if type(raw) == "table" then
		return table.concat(raw, "")
	end
	return raw
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

	if panel.response_buf() then
		panel.set_footer("Press <leader>aa apply · <leader>ay yank · <leader>ad diff · <leader>ap preview")
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

function M.load_history(lines)
	if not lines or #lines == 0 then
		return
	end
	stop_spinner()
	state.pending_line = ""
	panel.set_response(lines)
end

return M
