-- luacheck: globals vim

local panel = require("claude-summon.ui.panel")
local render = require("claude-summon.ui.render")
local context = require("claude-summon.context")
local chat = require("claude-summon.chat")

local M = {}
local state = {
	config = nil,
	open = false,
}

function M.setup(cfg)
	state.config = cfg
	panel.setup(cfg)
	render.setup(cfg)
	panel.set_submit(function(line)
		if not line or line == "" then
			return
		end

		local ctx = context.build_context({ context_lines = cfg.context_lines })
		local model_alias = chat.current_model()

		M.open(model_alias)
		M.start_stream({ model = model_alias, message = line, context = ctx })

		chat.send({
			message = line,
			context = ctx,
			model = model_alias,
			callbacks = {
				on_thinking = function(msg)
					M.on_thinking(msg)
				end,
				on_message = function(msg)
					M.on_message(msg)
				end,
				on_error = function(err)
					M.on_error(err)
				end,
				on_complete = function()
					M.on_complete()
				end,
			},
		})
	end)
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

function M.on_thinking(msg)
	render.on_thinking(msg)
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

function M.yank_code()
	render.yank_code()
end

function M.diff_code()
	render.diff_code()
end

function M.save()
	render.save()
end

function M.export()
	render.export()
end

return M
