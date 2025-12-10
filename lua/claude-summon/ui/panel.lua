-- luacheck: globals vim

local M = {}

local state = {
	model = nil,
}

function M.setup(_cfg) end

function M.open(model)
	state.model = model
	-- Placeholder: UI will be built in later phase.
end

function M.close() end

function M.model()
	return state.model
end

return M
