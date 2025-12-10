-- luacheck: globals vim

local uv = vim.loop

local M = {}

local state = {
	model = "claude",
	thinking = "",
	spinner_idx = 1,
	spinner = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" },
	timer = nil,
}

local function stop_spinner()
	if state.timer then
		state.timer:stop()
		state.timer:close()
	end
	state.timer = nil
	state.spinner_idx = 1
end

local function render_status()
	local prefix = string.format("Claude [%s] thinking ", state.model or "claude")
	local spin = state.spinner[state.spinner_idx] or state.spinner[1]
	local msg = state.thinking ~= "" and (" · " .. state.thinking) or ""
	local text = prefix .. spin .. msg
	vim.api.nvim_echo({ { text, "Comment" } }, false, {})
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
	start_spinner()
end

function M.on_thinking(msg)
	state.thinking = msg.message or msg.text or msg.thinking or msg.content or ""
	render_status()
end

function M.on_message(_msg)
	-- First real message ends the thinking phase.
	stop_spinner()
	vim.api.nvim_echo({}, false, {})
end

function M.on_error(err)
	stop_spinner()
	local message = (err and (err.message or err.desc)) or "Unknown error"
	vim.notify("Claude error: " .. message, vim.log.levels.ERROR)
end

function M.on_complete()
	stop_spinner()
end

function M.on_stop()
	stop_spinner()
end

function M.clear()
	stop_spinner()
end

function M.apply_code() end

function M.save() end

function M.export() end

return M
