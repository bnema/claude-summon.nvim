-- luacheck: globals vim

local config = require("claude-summon.config")
local trigger = require("claude-summon.trigger")
local context = require("claude-summon.context")
local chat = require("claude-summon.chat")
local ui = require("claude-summon.ui")

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

local function resolve_model(model)
	if not model then
		return state.config.default_model
	end
	return state.config.model_map["@" .. model] or state.config.default_model
end

function M.setup(opts)
	state.config = config.merge(opts)
	chat.setup(state.config)
	ui.setup(state.config)
	return state.config
end

function M.send()
	local cfg = ensure_setup()
	local trig = trigger.parse_trigger()
	if not trig then
		vim.notify("claude-summon: no @claude/@opus/@sonnet/@haiku trigger found in comment", vim.log.levels.WARN)
		return
	end

	local model_alias = resolve_model(trig.model)
	chat.use_model(model_alias)

	local ctx = context.build_context({
		context_lines = cfg.context_lines,
	})

	ui.open(model_alias)
	ui.start_stream({ model = model_alias, message = trig.message, context = ctx })

	chat.send({
		message = trig.message,
		context = ctx,
		model = model_alias,
		callbacks = {
			on_thinking = function(msg)
				ui.on_thinking(msg)
			end,
			on_message = function(msg)
				ui.on_message(msg)
			end,
			on_error = function(err)
				ui.on_error(err)
			end,
			on_complete = function()
				ui.on_complete()
			end,
		},
	})
end

function M.open()
	ensure_setup()
	ui.open(chat.current_model())
end

function M.close()
	ensure_setup()
	ui.close()
end

function M.toggle()
	ensure_setup()
	ui.toggle()
end

function M.stop()
	ensure_setup()
	chat.stop()
	ui.on_stop()
end

function M.clear()
	ensure_setup()
	chat.reset_session()
	ui.clear()
end

function M.apply_code()
	ensure_setup()
	ui.apply_code()
end

function M.save_conversation()
	ensure_setup()
	ui.save()
end

function M.export_markdown()
	ensure_setup()
	ui.export()
end

return M
