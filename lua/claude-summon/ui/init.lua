-- luacheck: globals vim

local panel = require("claude-summon.ui.panel")
local render = require("claude-summon.ui.render")
local actions = require("claude-summon.ui.actions")
local context = require("claude-summon.context")
local chat = require("claude-summon.chat")
local history = require("claude-summon.history")

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
	actions.apply_code()
end

function M.yank_code()
	actions.yank_code()
end

function M.diff_code()
	actions.diff_code()
end

function M.preview_code()
	actions.preview_code()
end

function M.save()
	render.save()
end

function M.export()
	render.export()
end

function M.history()
	history.list_claude_sessions(function(sessions, err)
		if err then
			local message = err.message or err.desc or tostring(err)
			vim.notify("claude-summon: " .. message, vim.log.levels.ERROR)
			return
		end

		if not sessions or #sessions == 0 then
			vim.notify("No Claude sessions found for this project", vim.log.levels.INFO)
			return
		end

		local function format_entry(entry)
			local summary = entry.summary or entry.display or entry.session_id
			if entry.timestamp then
				local ts = os.date("%Y-%m-%d %H:%M", entry.timestamp / 1000)
				return string.format("%s — %s (%s)", summary, entry.session_id, ts)
			end
			return string.format("%s — %s", summary, entry.session_id)
		end

		vim.ui.select(sessions, {
			prompt = "Select Claude session to resume",
			format_item = format_entry,
		}, function(choice)
			if not choice then
				return
			end
			chat.resume(choice.session_id)
			M.open(chat.current_model())
			render.load_history({
				"# Continuing session " .. choice.session_id,
				choice.summary or choice.display or "",
				"",
			})
			vim.notify("Resuming Claude session " .. choice.session_id, vim.log.levels.INFO)
		end)
	end)
end

return M
