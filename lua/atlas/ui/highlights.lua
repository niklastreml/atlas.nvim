local M = {}

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

---@param identifier string
---@return integer
local function palette_index(identifier)
	return (hash_string(identifier) % #dynamic_palette) + 1
end

---@type table<string, table>
local groups = {
	AtlasTabInactive = { bg = "#494d64", fg = "#a5adcb" },
	AtlasColumnHeader = { fg = "#7f849c", bold = true },
	AtlasSectionHeader = { fg = "#7f849c", bold = true, underline = true },

	AtlasTextMuted = { fg = "#7f849c" },
	AtlasTextMutedItalic = { fg = "#7f849c", italic = true },
	AtlasTextPositive = { fg = "#a6da95", bold = true },
	AtlasTextWarning = { fg = "#f9e2af", bold = true },

	AtlasLogInfo = { fg = "#89b4fa", bold = true },
	AtlasLogWarn = { fg = "#f9e2af", bold = true },
	AtlasLogError = { fg = "#f38ba8", bold = true },

	AtlasFooterBackground = { bg = "#202635" },
	AtlasFooterText = { fg = "#7f849c" },

	AtlasJiraTheme = { bg = "#1e3a8a", bold = true },
	AtlasJiraKey = { fg = "#89b4fa", bold = true },
	AtlasJiraTitle = { link = "CursorLineNr" },
	AtlasJiraEpic = { fg = "#cba6f7", bold = true },
	AtlasJiraStoryPoints = { fg = "#f38ba8", bold = true },
	AtlasChipActive = { fg = "#1e1e2e", bg = "#89b4fa", bold = true },

	AtlasBitbucketTheme = { bg = "#1e3a8a", bold = true },
	AtlasBitbucketPROpen = { fg = "#0b1320", bg = "#93c5fd", bold = true },
	AtlasBitbucketPRMerged = { fg = "#0b1320", bg = "#86efac", bold = true },
	AtlasBitbucketPRDeclined = { fg = "#0b1320", bg = "#fca5a5", bold = true },
	AtlasBitbucketPRDraft = { fg = "#111827", bg = "#fcd34d", bold = true },
}

function M.setup()
	for name, opts in pairs(groups) do
		vim.api.nvim_set_hl(0, name, opts)
	end

	for idx, color in ipairs(dynamic_palette) do
		local fg_name = string.format("AtlasDynColor%02d", idx)
		local bg_name = string.format("AtlasDynBgColor%02d", idx)
		vim.api.nvim_set_hl(0, fg_name, { fg = color })
		vim.api.nvim_set_hl(0, bg_name, { fg = "#1e1e2e", bg = color })
	end
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

	local idx = palette_index(identifier)
	return string.format("AtlasDynColor%02d", idx)
end

---Returns a stable dynamic background highlight group for an identifier.
---Same identifier always maps to the same palette color.
---@param identifier string|nil
---@return string|nil
function M.dynamic_for_bg(identifier)
	if identifier == nil or identifier == "" then
		return nil
	end

	local idx = palette_index(identifier)
	return string.format("AtlasDynBgColor%02d", idx)
end

return M
