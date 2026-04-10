local M = {}

local help = require("atlas.ui.popups.help")
local resolver = require("atlas.core.keymaps")
local utils = require("atlas.utils")
local panel_state = require("atlas.bitbucket.panel.state")
local footer = require("atlas.ui.components.footer")
local bitbucket_actions = require("atlas.bitbucket.actions")
local bitbucket_controller = require("atlas.bitbucket.ui.controller")

local PR_TAB_MODULES = {
	overview = "atlas.bitbucket.panel.tabs.pr.overview",
	activity = "atlas.bitbucket.panel.tabs.pr.activity",
	comments = "atlas.bitbucket.panel.tabs.pr.comments",
	commits = "atlas.bitbucket.panel.tabs.pr.commits",
	files = "atlas.bitbucket.panel.tabs.pr.files",
}

local REPO_TAB_MODULES = {
	overview = "atlas.bitbucket.panel.tabs.repo.overview",
	branches = "atlas.bitbucket.panel.tabs.repo.branches",
	tags = "atlas.bitbucket.panel.tabs.repo.tags",
}

---@param action_id AtlasKeymapActionId|string
---@param map_item table
---@return AtlasHelpKeyItem|nil
local function item(action_id, map_item)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = vim.tbl_deep_extend("force", {}, map_item)
	out.key = #keys == 1 and keys[1] or keys
	return out
end

---@param action_id AtlasKeymapActionId|string
---@param mode string|string[]|nil
---@return { key: string|string[], mode?: string|string[] }|nil
local function remove_item(action_id, mode)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = { key = (#keys == 1 and keys[1] or keys) }
	if mode ~= nil then
		out.mode = mode
	end
	return out
end

---@param tab_key string
---@return table|nil
local function get_tab_module(tab_key)
	local modules = panel_state.panel_type == "repo" and REPO_TAB_MODULES or PR_TAB_MODULES
	local mod = modules[tab_key]
	if mod == nil then
		return nil
	end

	local ok, tab_mod = pcall(require, mod)
	if not ok then
		return nil
	end

	return tab_mod
end

---@return BitbucketPR|nil
local function selected_pr()
	local selected = panel_state.current_item
	if type(selected) ~= "table" then
		return nil
	end

	if panel_state.panel_type ~= "pr" then
		return nil
	end

	return selected
end

---@param buf integer
function M.register(buf)
	local navigation_items = {
		{
			key = "j",
			desc = "Next item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(1)
				end
			end,
		},
		{
			key = "k",
			desc = "Previous item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(-1)
				end
			end,
		},
		{
			key = "gg",
			desc = "First item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(0)
				end
			end,
		},
		{
			key = "G",
			desc = "Last item in tab",
			opts = { silent = true, nowait = true },
			hidden = true,
			callback = function()
				local tab = get_tab_module(panel_state.current_tab)
				if tab ~= nil and type(tab.move_cursor) == "function" then
					tab.move_cursor(math.huge)
				end
			end,
		},
	}

	local bitbucket_items = {}
	local function add(action_id, map_item)
		utils.insert_if(bitbucket_items, item(action_id, map_item))
	end

	add("bitbucket.refresh_tab", {
		desc = "Refresh current tab",
		opts = { silent = true, nowait = true },
		callback = function()
			local tab = get_tab_module(panel_state.current_tab)
			if tab ~= nil and type(tab.refresh) == "function" then
				tab.refresh()
			end
		end,
	})

	add("bitbucket.open_actions", {
		desc = "Open PR actions",
		opts = { silent = true, nowait = true },
		callback = function()
			local pr = selected_pr()
			if pr == nil then
				footer.notify("warn", "No PR selected")
				return
			end

			bitbucket_actions.open({ pr = pr, source = "panel" }, function(result, err)
				if err ~= nil then
					footer.notify("error", tostring(err))
					return
				end

				if result ~= nil and result.message ~= nil and result.message ~= "" then
					footer.notify("info", result.message, 1200)
				end

				if result ~= nil and result.changed_pr then
					bitbucket_controller.refresh_pr(pr, function()
						require("atlas.bitbucket.panel").refresh()
					end)
				end
			end)
		end,
	})

	add("bitbucket.checkout_pr", {
		desc = "Checkout selected PR",
		opts = { silent = true, nowait = true },
		callback = function()
			local pr = selected_pr()
			if pr == nil then
				footer.notify("warn", "No PR selected")
				return
			end

			bitbucket_actions.run("checkout", {
				pr = pr,
				source = "panel",
			}, function() end)
		end,
	})

	add("bitbucket.open_diffview", {
		desc = "Open selected PR diff",
		opts = { silent = true, nowait = true },
		callback = function()
			local pr = selected_pr()
			if pr == nil then
				footer.notify("warn", "No PR selected")
				return
			end

			bitbucket_actions.run("open_diffview", {
				pr = pr,
				source = "panel",
			}, function() end)
		end,
	})

	M.remove(buf)
	help.register("Navigation", navigation_items, { index = 999, buffer = buf })
	help.register("Bitbucket", bitbucket_items, { index = 220, buffer = buf })
end

---@param buf integer
function M.remove(buf)
	help.remove("Navigation", {
		{ key = "j" },
		{ key = "k" },
		{ key = "gg" },
		{ key = "G" },
	}, { buffer = buf })

	local items = {}
	utils.insert_if(items, remove_item("bitbucket.refresh_tab"))
	utils.insert_if(items, remove_item("bitbucket.open_actions"))
	utils.insert_if(items, remove_item("bitbucket.checkout_pr"))
	utils.insert_if(items, remove_item("bitbucket.open_diffview"))
	help.remove("Bitbucket", items, { buffer = buf })
end

return M
