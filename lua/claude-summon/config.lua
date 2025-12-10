-- luacheck: globals vim

local M = {}

M.defaults = {
	-- SDK
	bin_path = "claude",
	sdk_path = vim.fn.expand("~/projects/claude-code-lua"),

	-- Models
	default_model = "sonnet",
	model_map = {
		["@claude"] = "sonnet",
		["@opus"] = "opus",
		["@sonnet"] = "sonnet",
		["@haiku"] = "haiku",
	},

	-- Context
	context_lines = 20,
	include_related_files = true,

	-- Permissions / tools
	permission_mode = "default", -- default | acceptEdits | bypassPermissions
	permission_callback = nil,
	allowed_tools = {},
	disallowed_tools = {},
	mcp_config_path = nil,
	permission_tool = nil,

	-- UI
	panel = {
		position = "right",
		width = 0.4,
		border = "rounded",
	},

	-- Keymaps
	keymaps = {
		send = { "<C-CR>", "<leader>as" },
		open = "<leader>ao",
		close = "<leader>ac",
		toggle = "<leader>at",
	},

	-- Persistence
	history_dir = vim.fn.stdpath("data") .. "/claude-summon",
	auto_save = false,
}

local function validate_keymaps(keymaps)
	vim.validate({
		send = { keymaps.send, { "string", "table" }, true },
		open = { keymaps.open, { "string" }, true },
		close = { keymaps.close, { "string" }, true },
		toggle = { keymaps.toggle, { "string" }, true },
	})
end

local function validate_panel(panel)
	vim.validate({
		position = { panel.position, { "string" }, true },
		width = { panel.width, { "number" }, true },
		border = { panel.border, { "string", "table" }, true },
	})
	if panel.width and (panel.width <= 0 or panel.width >= 1) then
		error("claude-summon: panel.width must be between 0 and 1")
	end
end

local function validate_list_of_strings(value, name)
	if value == nil then
		return
	end
	if type(value) ~= "table" then
		error(("claude-summon: %s must be a list of strings"):format(name))
	end
	for _, v in ipairs(value) do
		if type(v) ~= "string" then
			error(("claude-summon: %s entries must be strings"):format(name))
		end
	end
end

function M.merge(user_opts)
	local cfg = vim.tbl_deep_extend("force", {}, M.defaults, user_opts or {})

	vim.validate({
		bin_path = { cfg.bin_path, "string" },
		sdk_path = { cfg.sdk_path, "string" },
		default_model = { cfg.default_model, "string" },
		model_map = { cfg.model_map, "table" },
		context_lines = { cfg.context_lines, "number" },
		include_related_files = { cfg.include_related_files, "boolean" },
		history_dir = { cfg.history_dir, "string" },
		auto_save = { cfg.auto_save, "boolean" },
	})

	validate_panel(cfg.panel or {})
	validate_keymaps(cfg.keymaps or {})
	validate_list_of_strings(cfg.allowed_tools, "allowed_tools")
	validate_list_of_strings(cfg.disallowed_tools, "disallowed_tools")

	return cfg
end

return M
