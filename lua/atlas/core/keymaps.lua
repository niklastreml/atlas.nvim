local M = {}

---@class AtlasUIKeymaps
---@field help? AtlasKeymapValue
---@field close? AtlasKeymapValue
---@field toggle_panel? AtlasKeymapValue
---@field previous_panel_tab? AtlasKeymapValue
---@field next_panel_tab? AtlasKeymapValue

---@class AtlasPullsKeymaps
---@field refresh? AtlasKeymapValue
---@field refresh_view? AtlasKeymapValue
---@field open_actions? AtlasKeymapValue
---@field open_in_browser? AtlasKeymapValue
---@field copy_url? AtlasKeymapValue
---@field copy_id? AtlasKeymapValue
---@field open_diff? AtlasKeymapValue
---@field checkout? AtlasKeymapValue
---@field show_details? AtlasKeymapValue

---@class AtlasIssuesKeymaps
---@field refresh? AtlasKeymapValue
---@field refresh_view? AtlasKeymapValue

---@class AtlasKeymapsConfig
---@field ui? AtlasUIKeymaps
---@field pulls? AtlasPullsKeymaps
---@field issues? AtlasIssuesKeymaps

---@alias AtlasKeymapActionId
---| "ui.help"
---| "ui.close"
---| "ui.toggle_panel"
---| "ui.previous_panel_tab"
---| "ui.next_panel_tab"
---| "pulls.refresh"
---| "pulls.refresh_view"
---| "pulls.open_actions"
---| "pulls.open_in_browser"
---| "pulls.copy_url"
---| "pulls.copy_id"
---| "pulls.open_diff"
---| "pulls.checkout"
---| "pulls.show_details"
---| "issues.refresh"
---| "issues.refresh_view"


---@param value AtlasKeymapValue
---@return string[]|nil
local function normalize(value)
	if value == false or value == nil then
		return nil
	end

	if type(value) == "string" then
		if value == "" then
			return nil
		end
		return { value }
	end

	if type(value) ~= "table" then
		return nil
	end

	local keys = {}
	for _, key in ipairs(value) do
		if type(key) == "string" and key ~= "" then
			table.insert(keys, key)
		end
	end

	if #keys == 0 then
		return nil
	end

	return keys
end

---@param action_id AtlasKeymapActionId|string
---@return AtlasKeymapValue
local function from_config(action_id)
	local group, key = tostring(action_id):match("^([^.]+)%.([^.]+)$")
	if group == nil or key == nil then
		return nil
	end

	local keymaps = require("atlas.config").options.keymaps
	if type(keymaps) ~= "table" then
		return nil
	end

	local section = keymaps[group]
	if type(section) ~= "table" then
		return nil
	end

	return section[key]
end

---@param action_id AtlasKeymapActionId|string
---@return string[]|nil
function M.resolve(action_id)
	return normalize(from_config(action_id))
end

---@param action_ids AtlasKeymapActionId[]
---@param builtins string[]
---@return table<string, string[]>
local function conflicts_for(action_ids, builtins)
	---@type table<string, table<string, true>>
	local seen_by_key = {}
	for _, action_id in ipairs(action_ids) do
		local keys = M.resolve(action_id) or {}
		for _, key in ipairs(keys) do
			seen_by_key[key] = seen_by_key[key] or {}
			seen_by_key[key][action_id] = true
		end
	end

	for _, key in ipairs(builtins) do
		seen_by_key[key] = seen_by_key[key] or {}
		seen_by_key[key]["builtin:" .. key] = true
	end

	---@type table<string, string[]>
	local conflicts = {}
	for key, seen in pairs(seen_by_key) do
		local actions = vim.tbl_keys(seen)
		table.sort(actions)
		if #actions > 1 then
			conflicts[key] = actions
		end
	end

	return conflicts
end

---@return table<string, table<string, string[]>>
function M.validate()
	return {
		ui = conflicts_for({
			"ui.help",
			"ui.close",
			"ui.toggle_panel",
			"ui.previous_panel_tab",
			"ui.next_panel_tab",
		}, { "j", "k", "gg", "G" }),
		pulls = conflicts_for({
			"pulls.refresh",
			"pulls.refresh_view",
			"pulls.open_actions",
			"pulls.open_in_browser",
			"pulls.copy_url",
			"pulls.copy_id",
			"pulls.open_diff",
			"pulls.checkout",
			"pulls.show_details",
		}, { "j", "k", "gg", "G" }),
		issues = conflicts_for({
			"issues.refresh",
			"issues.refresh_view",
		}, { "j", "k", "gg", "G" }),
	}
end

return M
