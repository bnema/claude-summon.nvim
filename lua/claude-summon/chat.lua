-- luacheck: globals vim

local M = {}

local state = {
	client = nil,
	model = nil,
	session_id = nil,
	handle = nil,
}

local function ensure_sdk_path(path)
	if not path or path == "" then
		return
	end

	local lua_path = vim.fn.expand(path .. "/lua/?.lua")
	if not string.find(package.path, lua_path, 1, true) then
		package.path = package.path .. ";" .. lua_path
	end
end

local function build_prompt(message, context)
	local parts = {}

	table.insert(parts, "You are assisting inside Neovim. Respond concisely.")
	table.insert(parts, "")
	table.insert(parts, "User request:")
	table.insert(parts, message)

	if not context then
		return table.concat(parts, "\n")
	end

	table.insert(parts, "")
	table.insert(parts, "Context:")
	table.insert(
		parts,
		string.format("- File: %s (type: %s)", context.file_path or "[No Name]", context.filetype or "plain")
	)
	table.insert(
		parts,
		string.format(
			"- Cursor: line %d, col %d",
			context.cursor and context.cursor[1] or 0,
			context.cursor and context.cursor[2] or 0
		)
	)

	if context.trigger_line then
		table.insert(parts, "- Trigger line: " .. context.trigger_line)
	end

	if context.selection and context.selection ~= "" then
		table.insert(parts, "")
		table.insert(parts, "Selected text:")
		table.insert(parts, context.selection)
	end

	if context.before and #context.before > 0 then
		table.insert(parts, "")
		table.insert(parts, "Lines before cursor:")
		table.insert(parts, table.concat(context.before, "\n"))
	end

	if context.after and #context.after > 0 then
		table.insert(parts, "")
		table.insert(parts, "Lines after cursor:")
		table.insert(parts, table.concat(context.after, "\n"))
	end

	return table.concat(parts, "\n")
end

function M.setup(cfg)
	ensure_sdk_path(cfg.sdk_path)

	local claude = require("claude-code")
	state.client = claude.setup({ bin_path = cfg.bin_path })
	state.model = cfg.default_model or "sonnet"
end

function M.current_model()
	return state.model
end

function M.use_model(model_alias)
	state.model = model_alias or state.model
end

function M.stop()
	if state.handle and state.handle.stop then
		state.handle:stop()
	end
	state.handle = nil
end

function M.reset_session()
	state.session_id = nil
end

---@param payload { message: string, context?: table, model?: string, callbacks?: table }
function M.send(payload)
	if not state.client then
		error("claude-summon.chat: client not initialized; call setup()")
	end

	M.stop()

	local message = payload.message or ""
	local prompt = build_prompt(message, payload.context)
	local model_alias = payload.model or state.model

	local opts = { model_alias = model_alias }
	if state.session_id then
		opts.resume_id = state.session_id
	end

	state.handle = state.client:stream_prompt(prompt, opts, function(msg)
		if msg.session_id then
			state.session_id = msg.session_id
		end
		if payload.callbacks and payload.callbacks.on_message then
			payload.callbacks.on_message(msg)
		end
	end, function(err)
		if payload.callbacks and payload.callbacks.on_error then
			payload.callbacks.on_error(err)
		else
			local message_text = err and (err.message or err.desc or tostring(err)) or "Unknown error"
			vim.notify("Claude error: " .. message_text, vim.log.levels.ERROR)
		end
	end, function()
		if payload.callbacks and payload.callbacks.on_complete then
			payload.callbacks.on_complete()
		end
	end)
end

return M
