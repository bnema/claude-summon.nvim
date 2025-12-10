-- luacheck: globals vim

local panel = require("claude-summon.ui.panel")
local render = require("claude-summon.ui.render")

local M = {}
local state = {
	config = nil,
	open = false,
}

function M.setup(cfg)
	state.config = cfg
	panel.setup(cfg)
	render.setup(cfg)
end

function M.open(model)
	state.open = true
	panel.open(model)
end

function M.close()
	state.open = false
	panel.close()
end

function M.toggle()
	if state.open then
		M.close()
	else
		M.open()
	end
end

function M.start_stream(payload)
	render.start_stream(payload)
end

function M.on_message(msg)
	render.on_message(msg)
end

function M.on_error(err)
	render.on_error(err)
end

function M.on_complete()
	render.on_complete()
end

function M.on_stop()
	render.on_stop()
end

function M.clear()
	render.clear()
end

function M.apply_code()
	render.apply_code()
end

function M.save()
	render.save()
end

function M.export()
	render.export()
end

return M
