local M = {}

local resolver = require("atlas.core.keymaps")
local help = require("atlas.ui.popups.help")
local utils = require("atlas.utils")
local controller = require("atlas.bitbucket.ui.controller")
local actions = require("atlas.bitbucket.ui.actions")
local bitbucket_actions = require("atlas.bitbucket.actions")
local navigation = require("atlas.ui.navigation")
local footer = require("atlas.ui.components.footer")

---@return BitbucketPR|nil
local function selected_pr()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end
	if node.kind == "pr" and type(node.pr) == "table" then
		return node.pr
	end
	if node.kind == "pr" then
		return node
	end
	return nil
end

---@return table|nil
local function selected_repo()
	local node = navigation.current_item()
	if type(node) ~= "table" then
		return nil
	end

	if node.kind == "repo" then
		return node
	end

	if type(node._repo) == "table" then
		return node._repo
	end

	if node.kind == "pr" and type(node.pr) == "table" then
		return {
			workspace = node.pr.workspace,
			repo_slug = node.pr.repo_slug or node.pr.repo,
			full_name = node.pr.repo_full_name,
		}
	end

	return nil
end

---@param action_id BitbucketActionId|string
local function run_main_pr_action(action_id)
	local pr = selected_pr()
	if pr == nil then
		footer.notify("warn", "No PR selected")
		return
	end

	bitbucket_actions.run(action_id, {
		pr = pr,
		source = "main",
	}, function() end)
end

---@param action_id AtlasKeymapActionId|string
---@param item_opts table
---@return AtlasHelpKeyItem|nil
local function item(action_id, item_opts)
	local keys = resolver.resolve(action_id)
	if keys == nil then
		return nil
	end

	local out = vim.tbl_deep_extend("force", {}, item_opts)
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

---@param buf integer
function M.register(buf)
	local items = {}
	local function add(action_id, item_opts)
		utils.insert_if(items, item(action_id, item_opts))
	end

	add("bitbucket.open_actions", {
		desc = "Open PR actions",
		index = 1,
		callback = function()
			actions.open_pr_actions_popup(selected_pr())
		end,
	})

	add("bitbucket.search", {
		desc = "Search repositories",
		index = 2,
		callback = function()
			actions.open_pr_search_popup()
		end,
	})

	add("bitbucket.toggle_repo_panel", {
		desc = "Toggle repository panel",
		index = 3,
		callback = function()
			local repo = selected_repo()
			if repo == nil then
				footer.notify("warn", "No repository selected")
				return
			end

			local panel = require("atlas.ui.panel")
			local panel_state = require("atlas.ui.panel.state")
			if panel.is_open() then
				local selected = panel_state.selected_item
				if type(selected) == "table" and selected.kind == "repo" then
					panel.close()
					return
				end
			end
			panel.show("bitbucket", repo)
		end,
	})

	add("bitbucket.checkout_pr", {
		desc = "Checkout PR",
		index = 4,
		callback = function()
			run_main_pr_action("checkout")
		end,
	})

	add("bitbucket.open_diffview", {
		desc = "Open PR diff",
		index = 5,
		callback = function()
			run_main_pr_action("open_diffview")
		end,
	})

	add("bitbucket.open_in_browser", {
		desc = "Open PR in browser",
		index = 6,
		callback = function()
			actions.browse_current_pr(selected_pr())
		end,
	})

	add("bitbucket.refresh_pr", {
		desc = "Refetch selected PR",
		index = 8,
		callback = function()
			local panel = require("atlas.ui.panel")
			local panel_state = require("atlas.ui.panel.state")
			if panel.is_open() then
				local selected = panel_state.selected_item
				if type(selected) == "table" and selected.kind == "repo" then
					require("atlas.bitbucket.panel.tabs.repo.overview.controller").refresh()
					return
				end
			end

			actions.refresh_pr(selected_pr())
		end,
	})

	add("bitbucket.refresh_view", {
		desc = "Refresh current Bitbucket view",
		index = 9,
		callback = function()
			controller.refresh_current_view(function()
				navigation.focus_first_item()
			end)
		end,
	})

	add("bitbucket.show_details", {
		desc = "Show PR details",
		index = 10,
		callback = function()
			controller.show_pr_details(buf)
		end,
	})

	add("bitbucket.copy_id", {
		desc = "Copy PR id",
		index = 11,
		callback = function()
			actions.copy_current_pr_id(selected_pr())
		end,
	})

	add("bitbucket.copy_url", {
		desc = "Copy PR URL",
		index = 12,
		callback = function()
			actions.copy_current_pr_url(selected_pr())
		end,
	})

	M.remove(buf)
	help.register("Bitbucket", items, {
		index = 220,
		buffer = buf,
	})
end

---@param buf integer
function M.remove(buf)
	local items = {}
	utils.insert_if(items, remove_item("bitbucket.open_actions"))
	utils.insert_if(items, remove_item("bitbucket.search"))
	utils.insert_if(items, remove_item("bitbucket.toggle_repo_panel"))
	utils.insert_if(items, remove_item("bitbucket.checkout_pr"))
	utils.insert_if(items, remove_item("bitbucket.open_diffview"))
	utils.insert_if(items, remove_item("bitbucket.open_in_browser"))
	utils.insert_if(items, remove_item("bitbucket.refresh_pr"))
	utils.insert_if(items, remove_item("bitbucket.refresh_view"))
	utils.insert_if(items, remove_item("bitbucket.show_details"))
	utils.insert_if(items, remove_item("bitbucket.copy_id"))
	utils.insert_if(items, remove_item("bitbucket.copy_url"))

	help.remove("Bitbucket", items, { buffer = buf })
end

return M
