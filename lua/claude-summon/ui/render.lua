-- luacheck: globals vim

local uv = vim.loop
local panel = require("claude-summon.ui.panel")
local history = require("claude-summon.history")

local M = {}

-- Nerd Font icons (requires a Nerd Font patched terminal font)
local icons = {
	tool = "\u{f0ad}", -- nf-fa-wrench
	bash = "\u{f489}", -- nf-oct-terminal
	read = "\u{f15c}", -- nf-fa-file_text
	write = "\u{f0c7}", -- nf-fa-save
	edit = "\u{f044}", -- nf-fa-pencil_square_o
	glob = "\u{f002}", -- nf-fa-search
	grep = "\u{f0b0}", -- nf-fa-filter
	result = "\u{f061}", -- nf-fa-arrow_right
	success = "\u{f00c}", -- nf-fa-check
	error = "\u{f00d}", -- nf-fa-times
	thinking = "\u{f110}", -- nf-fa-spinner
	code = "\u{f121}", -- nf-fa-code
	folder = "\u{f07b}", -- nf-fa-folder
	file = "\u{f15b}", -- nf-fa-file
}

-- Map tool names to icons (fallback to icons.tool for unknown)
local tool_icons = {
	Bash = icons.bash,
	Read = icons.read,
	Write = icons.write,
	Edit = icons.edit,
	Glob = icons.glob,
	Grep = icons.grep,
	LS = icons.folder,
	Task = "\u{f0ae}", -- nf-fa-tasks
	TodoWrite = "\u{f0ae}", -- nf-fa-tasks
	WebFetch = "\u{f0ac}", -- nf-fa-globe
	WebSearch = "\u{f002}", -- nf-fa-search
	NotebookEdit = "\u{f02d}", -- nf-fa-book
	NotebookRead = "\u{f02d}", -- nf-fa-book
	AskUser = "\u{f128}", -- nf-fa-question
	AskUserQuestion = "\u{f128}", -- nf-fa-question
	AgentOutputTool = "\u{f085}", -- nf-fa-cogs
	KillShell = "\u{f00d}", -- nf-fa-times
	BashOutput = icons.bash,
}

local state = {
	model = "claude",
	thinking = "",
	spinner_idx = 1,
	spinner = { "\u{28cb}", "\u{28d9}", "\u{28f9}", "\u{28f8}", "\u{28fc}", "\u{28f4}", "\u{28e6}", "\u{28e7}", "\u{28c7}", "\u{28cf}" },
	timer = nil,
	pending_line = "",
	last_tool_id = nil,
	streamed_message_ids = {}, -- Track messages we've already streamed via deltas
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
	state.streamed_message_ids = {} -- Reset tracking for new stream
	panel.set_response({
		"> " .. (payload.message or ""),
		"",
		"Claude:",
	})
	start_spinner()
end

-- Continue an existing conversation (append instead of reset)
function M.continue_stream(payload)
	state.model = payload.model or state.model
	state.thinking = ""
	state.pending_line = ""
	state.streamed_message_ids = {} -- Reset tracking for new response
	-- Append separator and new user message
	panel.append({
		"",
		string.rep("\u{2500}", 40), -- horizontal line separator
		"",
		"> " .. (payload.message or ""),
		"",
		"Claude:",
	})
	start_spinner()
end

function M.on_thinking(msg)
	state.thinking = msg.message or msg.text or msg.thinking or msg.content or ""
	render_status()
end

-- Extract text from nested content structures
local function normalize_text(value)
	if type(value) == "string" then
		return value
	end
	if type(value) ~= "table" then
		return nil
	end
	if type(value.text) == "string" then
		return value.text
	end
	local buf = {}
	for _, v in ipairs(value) do
		local piece = normalize_text(v)
		if piece and piece ~= "" then
			table.insert(buf, piece)
		end
	end
	if #buf > 0 then
		return table.concat(buf, "")
	end
	return nil
end

-- Format tool_use message
local function format_tool_use(block)
	local name = block.name or "Tool"
	local icon = tool_icons[name] or icons.tool
	local input = block.input or {}

	local summary = ""
	if name == "Bash" and input.command then
		summary = input.command
	elseif name == "Read" and input.file_path then
		summary = input.file_path
	elseif name == "Write" and input.file_path then
		summary = input.file_path
	elseif name == "Edit" and input.file_path then
		summary = input.file_path
	elseif name == "Glob" and input.pattern then
		summary = input.pattern
	elseif name == "Grep" and input.pattern then
		summary = input.pattern
	elseif input.description then
		summary = input.description
	end

	if summary ~= "" then
		return string.format("\n%s %s: %s", icon, name, summary)
	end
	return string.format("\n%s %s", icon, name)
end

-- Format tool_result message (minimal - just status icon)
local function format_tool_result(block)
	local is_error = block.is_error
	local icon = is_error and icons.error or icons.success
	-- Just show a simple status indicator, no content details
	return string.format("  %s", icon)
end

-- Format a message block based on its type
local function format_block(block)
	local block_type = block.type
	if block_type == "text" then
		return block.text or ""
	elseif block_type == "tool_use" then
		state.last_tool_id = block.id
		return format_tool_use(block)
	elseif block_type == "tool_result" then
		return format_tool_result(block)
	end
	return ""
end

-- Main message formatter
local function format_message(msg)
	-- Handle stream_event for real-time text deltas (Python SDK format)
	if msg.type == "stream_event" then
		local event = msg.event
		if event then
			local event_type = event.type
			-- Track message ID so we can skip the final complete message
			if event_type == "message_start" and event.message then
				local msg_id = event.message.id
				if msg_id then
					state.streamed_message_ids[msg_id] = true
				end
			end
			-- Handle text deltas for streaming text
			if event_type == "content_block_delta" then
				local delta = event.delta
				if delta then
					if delta.type == "text_delta" then
						local text = delta.text or ""
						-- Indent subagent output for visual distinction
						if msg.parent_tool_use_id and text ~= "" then
							-- Only indent at line starts, not mid-line
							text = text:gsub("\n", "\n  ")
						end
						return text
					elseif delta.type == "thinking_delta" then
						-- Update thinking status instead of displaying
						state.thinking = delta.thinking or ""
						render_status()
						return ""
					end
				end
			end
			-- Show tool_use blocks as they start (real-time tool visibility)
			if event_type == "content_block_start" then
				local content_block = event.content_block
				if content_block and content_block.type == "tool_use" then
					local prefix = msg.parent_tool_use_id and "  " or "" -- Indent subagent tools
					return prefix .. format_tool_use(content_block)
				end
			end
		end
		return ""
	end

	-- Skip system and result messages (metadata, not content)
	if msg.type == "system" or msg.type == "result" then
		return ""
	end

	-- Skip user messages (they just contain tool_result blocks which we handle minimally)
	if msg.type == "user" then
		return ""
	end

	-- Skip assistant messages if we already streamed their content via deltas
	-- Assistant messages have ID at msg.message.id
	if msg.type == "assistant" then
		local nested_id = msg.message and msg.message.id
		if nested_id and state.streamed_message_ids[nested_id] then
			return "" -- Already displayed via stream events
		end
	end

	-- Skip other messages by ID if already streamed
	local msg_id = msg.id or (msg.message and msg.message.id)
	if msg_id and state.streamed_message_ids[msg_id] then
		return ""
	end

	-- Handle delta/partial streaming updates
	if msg.delta then
		local delta = msg.delta
		if type(delta) == "string" then
			return delta
		end
		if type(delta) == "table" and delta.text then
			return delta.text
		end
	end

	if msg.partial then
		local partial = msg.partial
		if type(partial) == "string" then
			return partial
		end
		if type(partial) == "table" and partial.text then
			return partial.text
		end
	end

	-- Handle content array (can contain text, tool_use, tool_result blocks)
	-- For assistant messages, content is at msg.message.content
	-- For other messages, content is at msg.content
	local content = msg.content
	if not content and msg.message and type(msg.message.content) == "table" then
		content = msg.message.content
	end
	if type(content) == "table" then
		local parts = {}
		for _, block in ipairs(content) do
			if type(block) == "table" then
				local formatted = format_block(block)
				if formatted and formatted ~= "" then
					table.insert(parts, formatted)
				end
			elseif type(block) == "string" then
				table.insert(parts, block)
			end
		end
		if #parts > 0 then
			return table.concat(parts, "")
		end
	end

	-- Fallback to simple text fields
	local raw = msg.text or msg.message or msg.result
	if raw then
		return normalize_text(raw) or ""
	end

	return ""
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

	if state.pending_line ~= "" then
		-- Show partial line progress by updating the last line in the buffer.
		panel.update_last_line(state.pending_line)
	end
end

function M.on_message(msg)
	local text = format_message(msg)
	if text == "" then
		return
	end
	-- Only stop spinner when we have actual content to display
	stop_spinner()
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
	state.streamed_message_ids = {}
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
