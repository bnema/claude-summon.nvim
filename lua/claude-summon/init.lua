local config = require("claude-summon.config")

local M = {}
local state = {
	config = nil,
}

local function ensure_setup()
	if state.config then
		return state.config
	end
	error("claude-summon: call setup() before using the plugin")
end

function M.setup(opts)
	state.config = config.merge(opts)
	return state.config
end

function M.send()
	ensure_setup()
end

function M.open()
	ensure_setup()
end

function M.close()
	ensure_setup()
end

function M.toggle()
	ensure_setup()
end

function M.stop()
	ensure_setup()
end

function M.clear()
	ensure_setup()
end

function M.apply_code()
	ensure_setup()
end

function M.save_conversation()
	ensure_setup()
end

function M.export_markdown()
	ensure_setup()
end

return M
