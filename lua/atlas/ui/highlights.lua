local M = {}

---@type table<string, true>
local dynamic_groups = {}

local dynamic_palette = {
	"#91d7e3",
	"#7dc4e4",
	"#8bd5ca",
	"#eed49f",
	"#f5a97f",
	"#f5bde6",
	"#c6a0f6",
}

---@param text string
---@return integer
local function hash_string(text)
	local h = 0
	for i = 1, #text do
		h = (h * 31 + string.byte(text, i)) % 2147483647
	end
	return h
end

---@type table<string, table>
local groups = {
	AtlasTabInactive = { bg = "#494d64", fg = "#a5adcb" },
	AtlasColumnHeader = { fg = "#7f849c", bold = true },

	AtlasTextMuted = { fg = "#7f849c" },
	AtlasTextPositive = { fg = "#a6da95", bold = true },
	AtlasTextWarning = { fg = "#f9e2af", bold = true },

	AtlasLogInfo = { fg = "#89b4fa", bold = true },
	AtlasLogWarn = { fg = "#f9e2af", bold = true },
	AtlasLogError = { fg = "#f38ba8", bold = true },

	AtlasFooterBackground = { bg = "#202635" },
	AtlasFooterText = { fg = "#7f849c" },

	AtlasJiraTheme = { bg = "#0f4c81", bold = true },
	AtlasBitbucketTheme = { bg = "#1e3a8a", bold = true },
	AtlasGithubTheme = { bg = "#111827", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end
end

---@param name string
---@param opts table
---@return string
function M.ensure_dynamic(name, opts)
	if dynamic_groups[name] then
		return name
	end

	vim.api.nvim_set_hl(0, name, opts or {})
	dynamic_groups[name] = true
	return name
end

---Returns a stable dynamic highlight group for an identifier.
---Same identifier always maps to the same palette color.
---Groups are shared by color index (e.g. AtlasDynColor03), not by namespace.
---@param identifier string|nil
---@return string|nil
function M.dynamic_for(identifier)
	if identifier == nil or identifier == "" then
		return nil
	end

	local idx = (hash_string(identifier) % #dynamic_palette) + 1
	local group = string.format("AtlasDynColor%02d", idx)
	return M.ensure_dynamic(group, { fg = dynamic_palette[idx] })
end

return M
