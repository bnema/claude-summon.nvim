-- luacheck: globals vim

local M = {}
local state = {
	dir = nil,
}

local function ensure_dir()
	if not state.dir or state.dir == "" then
		return nil, "history_dir not configured"
	end
	vim.fn.mkdir(state.dir, "p")
	return state.dir, nil
end

function M.setup(cfg)
	state.dir = cfg.history_dir
end

local function default_name()
	return os.date("claude-%Y%m%d-%H%M%S")
end

local function write_file(path, lines)
	local fd = io.open(path, "w")
	if not fd then
		return nil
	end
	fd:write(table.concat(lines or {}, "\n"))
	fd:close()
	return path
end

function M.save(name, lines)
	local dir, err = ensure_dir()
	if not dir then
		vim.notify("claude-summon: " .. err, vim.log.levels.ERROR)
		return nil
	end
	local filename = (name and name ~= "" and name) or default_name()
	local path = dir .. "/" .. filename .. ".md"
	return write_file(path, lines or {})
end

function M.export_markdown(path, lines)
	if path and path ~= "" then
		return write_file(path, lines or {})
	end
	return M.save(nil, lines)
end

function M.list()
	local dir, err = ensure_dir()
	if not dir then
		vim.notify("claude-summon: " .. err, vim.log.levels.ERROR)
		return {}
	end
	local handle = vim.loop.fs_scandir(dir)
	if not handle then
		return {}
	end
	local items = {}
	while true do
		local name = vim.loop.fs_scandir_next(handle)
		if not name then
			break
		end
		table.insert(items, name)
	end
	table.sort(items)
	return items
end

function M.load(_conversation_id)
	vim.notify("History load not implemented yet", vim.log.levels.INFO)
	return nil
end

function M.delete(_conversation_id)
	vim.notify("History delete not implemented yet", vim.log.levels.INFO)
end

return M
